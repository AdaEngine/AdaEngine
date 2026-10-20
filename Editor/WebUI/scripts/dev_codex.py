"""Optional local Codex provider. Credentials stay with the installed CLI."""
from collections import deque
import http.client
import json
import logging
from pathlib import Path
import queue
import subprocess
import threading
import time
import uuid

PROVIDER = 'local-codex'
ERROR = 'Local Codex request failed. Check the development server log.'


class CodexError(RuntimeError):
    pass


class Client:
    def __init__(self, executable, cwd):
        self.cwd = str(cwd)
        self.process = subprocess.Popen([str(executable), 'app-server', '--listen', 'stdio://'],
                                        cwd=cwd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.DEVNULL, text=True, bufsize=1)
        self.incoming = queue.Queue()
        self.events = deque()
        self.counter = 0
        def read():
            try:
                for line in self.process.stdout:
                    self.incoming.put(json.loads(line))
            finally:
                self.incoming.put(None)
        self.reader = threading.Thread(target=read, daemon=True)
        self.reader.start()
        try:
            self.rpc('initialize', {'clientInfo': {'name': 'ada_studio_web_dev', 'title': 'Ada Studio Web development', 'version': '0.1.0'}})
            self.send({'method': 'initialized', 'params': {}})
            configuration = self.rpc('config/read', {'includeLayers': False})['config']
            # A thread must not inherit the user's MCP servers, plugins, shell or
            # host workflows: the browser owns all editing and approval tools.
            self.config = {'mcp_servers.' + name + '.enabled': False for name in configuration.get('mcp_servers', {})}
            self.config.update({'features.' + name: False for name in
                                ['shell_tool', 'unified_exec', 'apps', 'plugins', 'hooks', 'multi_agent',
                                 'memories', 'skill_search', 'image_generation', 'view_image', 'sleep_tool',
                                 'code_mode', 'browser_use', 'in_app_browser', 'workspace_dependencies', 'goals']})
            self.config.update({'features.skip_host_skill_discovery': True, 'web_search': 'disabled',
                                'project_doc_max_bytes': 0})
        except BaseException:
            self.close()
            raise

    def send(self, value):
        self.process.stdin.write(json.dumps(value) + '\n')
        self.process.stdin.flush()

    def read(self, timeout=45):
        try:
            value = self.incoming.get(timeout=timeout)
        except queue.Empty as error:
            raise TimeoutError('Codex did not reply') from error
        if value is None:
            raise CodexError('Codex app-server exited')
        # Built-in tools are disabled. Decline any unexpected server request.
        if 'method' in value and 'id' in value:
            self.send({'id': value['id'], 'error': {'code': -32601, 'message': 'Only browser tools are available'}})
        return value

    def rpc(self, method, params):
        self.counter += 1
        request_id = self.counter
        self.send({'id': request_id, 'method': method, 'params': params})
        while True:
            value = self.read()
            if value.get('id') == request_id and 'method' not in value:
                if 'error' in value:
                    raise CodexError(value['error'].get('message', 'Codex RPC failed'))
                return value['result']
            self.events.append(value)

    def close(self):
        if self.process.poll() is None:
            self.process.terminate()
            try: self.process.wait(timeout=5)
            except subprocess.TimeoutExpired: self.process.kill(); self.process.wait()
        self.reader.join(timeout=1)
        for pipe in [self.process.stdin, self.process.stdout]:
            pipe.close()

    def __enter__(self): return self
    def __exit__(self, *_): self.close()


def validate_request(body, models):
    if body.get('providerID') != PROVIDER or body.get('billingMode') != 'codex':
        raise ValueError('Invalid local Codex provider')
    if body.get('model') not in models or body.get('mode') not in ('build', 'plan'):
        raise ValueError('Invalid model or mode')
    uuid.UUID(body['operationID'])
    messages, tools = body.get('messages'), body.get('tools')
    if not isinstance(messages, list) or not messages or not isinstance(tools, list) or len(tools) > 96:
        raise ValueError('Invalid conversation or tools')
    for tool in tools:
        function = tool.get('function', {})
        name = function.get('name', '')
        if not isinstance(name, str) or not name.startswith('editor_') or not name.replace('_', '').isalnum():
            raise ValueError('Invalid browser tool')
    if len(json.dumps(body).encode()) > 2 * 1024 * 1024:
        raise ValueError('Request too large')


def output_schema(names):
    call = {'type': 'object', 'properties': {'name': {'type': 'string', 'enum': names},
             'arguments': {'type': 'string'}}, 'required': ['name', 'arguments'], 'additionalProperties': False}
    return {'type': 'object', 'properties': {'text': {'type': 'string'},
            'toolCalls': {'type': 'array', 'items': call}}, 'required': ['text', 'toolCalls'], 'additionalProperties': False}


def normalize_output(text, tools):
    value = json.loads(text)
    names = {t['function']['name'] for t in tools}
    calls = value['toolCalls']
    if not isinstance(value['text'], str) or not isinstance(calls, list) or len(calls) > 40:
        raise CodexError('Invalid Codex response')
    result = []
    for call in calls:
        if call['name'] not in names or not isinstance(json.loads(call['arguments']), dict):
            raise CodexError('Codex returned an unavailable tool or invalid arguments')
        result.append({'id': 'codex_' + uuid.uuid4().hex, 'type': 'function',
                       'function': {'name': call['name'], 'arguments': call['arguments']}})
    return value['text'], result


class Bridge:
    def __init__(self, executable, directory):
        self.executable = executable
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True)
        self.models = []
        self.active = threading.BoundedSemaphore(2)
        self.completion_active = threading.BoundedSemaphore(1)
        self.completion_efforts = {}

    def catalog(self):
        with Client(self.executable, self.directory) as client:
            account = client.rpc('account/read', {'refreshToken': False})
            if (account.get('account') or {}).get('type') != 'chatgpt':
                raise CodexError('Sign in to Codex with ChatGPT using codex login')
            result = client.rpc('model/list', {'limit': 100})
        entries = sorted(result['data'], key=lambda m: not m.get('isDefault'))
        self.completion_efforts = {entry['model']: next((effort for effort in ('low', 'minimal', 'none')
            if effort in [(option.get('reasoningEffort') if isinstance(option, dict) else option) for option in (entry.get('supportedReasoningEfforts') or [])]), None) for entry in entries}
        self.models = [{'id': m['model'], 'title': m['displayName'], 'tools': True,
                        'vision': 'image' in m.get('inputModalities', [])} for m in entries]
        return {'id': PROVIDER, 'title': 'Codex', 'transport': 'codex', 'models': self.models}

    def generate(self, body):
        validate_request(body, {m['id'] for m in self.models})
        if not self.active.acquire(blocking=False):
            raise CodexError('Local Codex is busy')
        try:
            with Client(self.executable, self.directory) as client:
                names = [t['function']['name'] for t in body['tools']]
                if not names:
                    raise ValueError('No browser tools supplied')
                thread = client.rpc('thread/start', {
                    'model': body['model'], 'cwd': str(self.directory.resolve()),
                    'sandbox': 'read-only', 'approvalPolicy': 'never', 'ephemeral': True,
                    'config': client.config,
                    'baseInstructions': 'You are the Ada Studio web assistant. Follow the browser host context. '
                        'Your only tools are the browser functions described in the input. Return their requests '
                        'in toolCalls as JSON argument strings; the browser executes them with normal approval and Undo. '
                        'Never use host filesystem, shell, MCP, plugins or other Codex tools. Stop after requesting '
                        'tools and use their recorded results in the next response. Do not claim success without evidence. '
                        'The supplied conversation contains labelled user, assistant and tool messages. '
                        'Return text and an empty toolCalls array when finished or waiting for the user.'})
                # Images remain explicit model inputs; they never become host files.
                messages = []
                images = []
                for message in body['messages']:
                    message = dict(message)
                    for image in message.pop('images', []):
                        if not image.startswith(('data:image/png;base64,', 'data:image/jpeg;base64,')):
                            raise ValueError('Invalid image')
                        images.append({'type': 'image', 'url': image})
                    messages.append(message)
                prompt = json.dumps({'mode': body['mode'], 'tools': body['tools'], 'conversation': messages}, ensure_ascii=False)
                turn = client.rpc('turn/start', {'threadId': thread['thread']['id'],
                    'input': [{'type': 'text', 'text': prompt}, *images],
                    'outputSchema': output_schema(names)})
                turn_id = turn['turn']['id']
                text, final, usage = '', None, None
                deadline = time.monotonic() + 300
                while time.monotonic() < deadline:
                    if client.events:
                        value = client.events.popleft()
                    else:
                        try: value = client.read(timeout=1)
                        except TimeoutError:
                            yield None
                            continue
                    method, params = value.get('method'), value.get('params', {})
                    if params.get('turnId') not in (None, turn_id): continue
                    if method == 'item/agentMessage/delta': text += params.get('delta', '')
                    if method == 'item/completed' and params.get('item', {}).get('type') == 'agentMessage':
                        final = params['item']['text']
                    if method == 'thread/tokenUsage/updated': usage = params['tokenUsage'].get('last')
                    if method == 'turn/completed':
                        if params['turn']['status'] != 'completed':
                            raise CodexError('Codex turn did not complete')
                        answer, calls = normalize_output(final or text, body['tools'])
                        if answer: yield {'type': 'text', 'text': answer}
                        for call in calls: yield {'type': 'tool', 'call': call}
                        if usage: yield {'type': 'usage', 'inputTokens': usage.get('inputTokens', 0), 'outputTokens': usage.get('outputTokens', 0)}
                        yield {'type': 'complete'}
                        return
                raise TimeoutError('Codex turn timed out')
        finally:
            self.active.release()


def upstream(handler, path):
    """Use real Identity admission; never turn the CLI into an unauthenticated route."""
    connection = http.client.HTTPConnection('127.0.0.1', 28081, timeout=15)
    headers = {key: handler.headers[key] for key in ['Authorization', 'Cookie'] if handler.headers.get(key)}
    try:
        connection.request('GET', path, headers=headers)
        response = connection.getresponse()
        return response.status, response.read()
    finally:
        connection.close()


def handle(handler, bridge, provider, origin):
    path = handler.path.split('?', 1)[0]
    if path == '/v1/ai/complete':
        from dev_completion import handle_completion
        return handle_completion(handler, bridge, origin)
    if path not in ('/v1/ai/providers', '/v1/ai/generate'):
        return False
    # Inspect a bounded body only on generate. All other providers retain Cloud routing.
    body = None
    if path.endswith('/generate'):
        if handler.command != 'POST': return False
        size = int(handler.headers.get('Content-Length', '0'))
        if not 0 < size <= 2 * 1024 * 1024:
            handler.send_error(413)
            return True
        raw = handler.rfile.read(size)
        try:
            body = json.loads(raw)
        except (ValueError, TypeError):
            handler.send_error(400)
            return True
        if not isinstance(body, dict):
            handler.send_error(400)
            return True
        if body.get('providerID') != PROVIDER:
            # The edge's normal forwarder still needs the original body.
            from io import BytesIO
            handler.rfile = BytesIO(raw)
            return False
    elif handler.command != 'GET': return False
    status, data = upstream(handler, '/v1/me')
    if status != 200:
        handler.send_response(status)
        handler.send_header('Content-Type', 'application/json')
        handler.end_headers()
        handler.wfile.write(data)
        return True
    if body is None:
        connection = http.client.HTTPConnection('127.0.0.1', 28090, timeout=15)
        headers = {key: handler.headers[key] for key in ['Authorization', 'Cookie'] if handler.headers.get(key)}
        try:
            connection.request('GET', '/v1/ai/providers', headers=headers)
            response = connection.getresponse()
            raw = response.read()
            if response.status != 200:
                handler.send_response(response.status)
                handler.send_header('Content-Type', 'application/json')
                handler.end_headers()
                handler.wfile.write(raw)
                return True
            data = json.dumps(json.loads(raw) + [provider]).encode()
        finally: connection.close()
        handler.send_response(200)
        handler.send_header('Content-Type', 'application/json')
        handler.send_header('Cache-Control', 'no-store')
        handler.end_headers()
        handler.wfile.write(data)
        return True
    if handler.headers.get('Origin') != origin:
        handler.send_error(403)
        return True
    try:
        validate_request(body, {m['id'] for m in bridge.models})
    except (ValueError, KeyError, TypeError):
        handler.send_error(400)
        return True
    handler.send_response(200)
    handler.send_header('Content-Type', 'text/event-stream')
    handler.send_header('Cache-Control', 'no-store')
    handler.send_header('Connection', 'close')
    handler.end_headers()
    handler.close_connection = True
    generator = bridge.generate(body)
    try:
        for event in generator:
            handler.wfile.write(('data: ' + json.dumps(event) + '\n\n').encode() if event else b': keep-alive\n\n')
            handler.wfile.flush()
    except (BrokenPipeError, ConnectionResetError):
        pass
    except Exception:
        logging.exception('Local Codex request failed')
        handler.wfile.write(('data: ' + json.dumps({'type': 'error', 'message': ERROR}) + '\n\n').encode())
        handler.wfile.flush()
    finally:
        generator.close()
    return True
