#!/usr/bin/env python3
"""Run the real Cloud services with isolated, persistent loopback development data."""
import argparse
import http.client
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from io import BytesIO
import json
import logging
import os
from pathlib import Path
import secrets
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
from urllib.parse import urlsplit, unquote
import urllib.error
import urllib.request

from playground_static import redirect as frontend_redirect, target as frontend_target
from dev_inbox import inject_html, script as inbox_script

UI = Path(__file__).resolve().parents[1]
ENGINE = UI.parents[1]
SERVICES = {'Identity': 28081, 'Settings': 28082, 'Billing': 28083,
            'Publishing': 28084, 'Catalog': 28085, 'Delivery': 28086,
            'BuildWorker': 28087, 'MultiplayerRelay': 28089,
            'AIService': 28090, 'Workspace': 28091}
HOP_HEADERS = {'connection', 'transfer-encoding', 'keep-alive', 'upgrade', 'host'}


def route(path):
    """Only public API routes are reachable through the browser edge."""
    path = urlsplit(path).path
    for prefix, service in [('/v1/ai', 'AIService'), ('/v1/workspaces', 'Workspace'),
                            ('/v1/settings', 'Settings'), ('/v1/billing', 'Billing'),
                            ('/v1/uploads', 'Publishing'), ('/v1/publications', 'Publishing'),
                            ('/v1/game-releases', 'Publishing'), ('/v1/multiplayer', 'MultiplayerRelay'),
                            ('/v1/catalog', 'Catalog'), ('/v1/pages', 'Catalog'),
                            ('/v1/media', 'Catalog'), ('/v1/auth', 'Identity'),
                            ('/v1/me', 'Identity'), ('/v1/legal', 'Identity'),
                            ('/v1/availability', 'Identity')]:
        if path == prefix or path.startswith(prefix + '/'):
            return SERVICES[service]
    return None


def wait_http(url, children):
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        for name, child in children:
            if child.poll() is not None:
                raise RuntimeError(f'{name} stopped; inspect its log in the state directory')
        try:
            with urllib.request.urlopen(url, timeout=2) as response:
                if response.status < 300:
                    return
        except (OSError, urllib.error.URLError):
            time.sleep(.25)
    raise RuntimeError('Not ready: ' + url)


def forward(handler, port, headers=None):
    length = int(handler.headers.get('Content-Length', '0'))
    if length < 0 or length > 96 * 1024 * 1024:
        handler.send_error(413)
        return
    body = handler.rfile.read(length) if length else None
    outgoing = {k: v for k, v in handler.headers.items()
                if k.lower() not in HOP_HEADERS and not k.lower().startswith('x-forwarded-')}
    outgoing.update(headers or {})
    connection = http.client.HTTPConnection('127.0.0.1', port, timeout=180)
    try:
        connection.request(handler.command, handler.path, body, outgoing)
        response = connection.getresponse()
        handler.send_response(response.status)
        for key, value in response.getheaders():
            if key.lower() not in HOP_HEADERS:
                handler.send_header(key, value)
        handler.send_header('Connection', 'close')
        handler.end_headers()
        if handler.command != 'HEAD':
            while chunk := response.read1(65536):
                handler.wfile.write(chunk)
                handler.wfile.flush()
    finally:
        connection.close()
        handler.close_connection = True



def codex_preference(state, requested=None):
    if requested is not None:
        return requested
    path = state / 'development-options.json'
    if not path.exists():
        return False
    value = json.loads(path.read_text())
    if not isinstance(value, dict) or not isinstance(value.get('codex'), bool):
        raise ValueError('Invalid development-options.json: expected a codex boolean')
    return value['codex']


def remember_codex_preference(state, enabled):
    path = state / 'development-options.json'
    temporary = path.with_suffix('.tmp')
    with os.fdopen(os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), 'w') as file:
        json.dump({'codex': enabled}, file)
        file.write('\n')
    os.replace(temporary, path)


def development_studio_config(provider):
    # Public metadata only; generation still requires Identity admission and Origin.
    return {'development': True, 'codexEnabled': provider is not None, 'providers': [provider] if provider else []}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cloud', type=Path, default=ENGINE.parent / 'adaengine-service')
    parser.add_argument('--website', type=Path, default=ENGINE.parent / 'My Projects/adawebsite/dist')
    parser.add_argument('--state', type=Path, default=UI / '.local/cloud')
    parser.add_argument('--bin-dir', type=Path)
    parser.add_argument('--player', type=Path, default=UI / '.local/studio-web/player')
    parser.add_argument('--port', type=int, default=8080)
    parser.add_argument('--codex', action=argparse.BooleanOptionalAction, default=None, help='Offer the local Codex CLI sign-in; remembered for this state directory (--no-codex disables it)')
    parser.add_argument('--pg-bin', type=Path, default=Path(os.getenv('PG_BIN', '/opt/homebrew/opt/postgresql@17/bin')))
    parser.add_argument('--redis', default=os.getenv('REDIS_SERVER', '/opt/homebrew/opt/redis/bin/redis-server'))
    parser.add_argument('--kafka', type=Path, default=Path(os.getenv('KAFKA_HOME', str(ENGINE.parent / 'adaengine-service/.local/ugc-tooling/kafka_2.13-4.1.2'))))
    parser.add_argument('--check', action='store_true', help='Check prerequisites without starting services')
    args = parser.parse_args()
    state = args.state.resolve()
    requested_codex = args.codex
    try:
        args.codex = codex_preference(state, requested_codex)
    except (ValueError, OSError) as error:
        parser.error(str(error))
    binaries = (args.bin_dir or state / 'build/debug').resolve()
    required = [args.cloud / 'Package.swift', args.website / 'index.html', UI / 'dist/studio.js',
                args.pg_bin / 'initdb', args.pg_bin / 'postgres', Path(args.redis),
                args.kafka / 'bin/kafka-server-start.sh'] + [binaries / name for name in SERVICES]
    missing = [str(path) for path in required if not path.exists()]
    try:
        import boto3
        from moto.server import ThreadedMotoServer
    except ImportError:
        missing.append('Python packages: pip install -r scripts/dev-requirements.txt')
    if missing:
        parser.error('Missing prerequisites:\n' + '\n'.join(missing))
    if args.codex and not shutil.which('codex'):
        parser.error('Install Codex CLI and run codex login before using --codex')
    if args.check:
        print('Cloud tools, binaries, frontend and website are present.')
        print('Player: ' + ('present' if (args.player / 'AdaWebPlayer.wasm').exists() else 'missing; export it before scene/Play testing'))
        return
    # Preflight every owned port before launching anything. Never adopt another stack.
    for port in [args.port, 8081, 25432, 26379, 29092, 29093, 29000, 29001, 28088, *SERVICES.values()]:
        with socket.socket() as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                sock.bind(('127.0.0.1', port))
            except OSError as error:
                parser.error(f'Port {port} is occupied: {error}')
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(state, 0o700)
    config = state / 'configuration.json'
    if not config.exists():
        private = {key: secrets.token_hex(32) for key in
                   ['ACCESS_TOKEN_SECRET', 'INTERNAL_SECRET', 'EMAIL_CODE_SECRET', 'PROXY_SHARED_SECRET', 'S3_SECRET_KEY']}
        with os.fdopen(os.open(config, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'w') as file:
            json.dump(private, file)
    private = json.loads(config.read_text())
    origin = f'http://localhost:{args.port}'
    codex_bridge = codex_provider = None
    if args.codex:
        from dev_codex import Bridge
        codex_bridge = Bridge(shutil.which('codex'), state / 'codex-workspace')
        codex_provider = codex_bridge.catalog()
    if requested_codex is not None:
        remember_codex_preference(state, args.codex)
    env = {k: v for k, v in os.environ.items() if k in ('PATH', 'HOME', 'USER', 'TMPDIR', 'LANG', 'JAVA_HOME', 'DYLD_LIBRARY_PATH')}
    env.update(private)
    env.update(BIND_ADDRESS='127.0.0.1', DEPLOYMENT_ENV='development', CLOUD_DEV_COUNTRY='RU',
               CLOUD_ROLLOUT_MODE='regional', REDIS_URL='redis://127.0.0.1:26379/0',
               KAFKA_BROKERS='127.0.0.1:29092', WEB_ORIGIN=origin, API_ORIGIN=origin,
               MAIL_URL='http://127.0.0.1:28088', LEGAL_STATUS='draft',
               S3_ENDPOINT='http://127.0.0.1:29000', S3_REGION='us-east-1',
               S3_BUCKET='studio-development', S3_ACCESS_KEY='local-development-only',
               STUDIO_WEB_ENABLED='true', STUDIO_PUBLISHING_ENABLED='false',
               STUDIO_PREVIEW_URL='http://127.0.0.1:8081/studio-preview.html',
               STUDIO_PROVIDERS=os.getenv('STUDIO_PROVIDERS', '[]'),
               GAMES_DOMAIN='games.localhost', GAMES_PORT_SUFFIX=':28086',
               PYTHON_EXECUTABLE=sys.executable, MULTIPLAYER_ENABLED='false',
               ARCHIVE_VALIDATOR=str(args.cloud / 'scripts/validate_archive.py'),
               IMAGE_SANITIZER=str(args.cloud / 'scripts/sanitize_image.py'))
    # Provider keys are opt-in and never persisted by the launcher.
    for provider in json.loads(env['STUDIO_PROVIDERS']):
        key = provider.get('apiKeyEnvironment', '')
        if key and key in os.environ:
            env[key] = os.environ[key]
    for name in ['Billing', 'Publishing', 'Catalog']:
        env[name.upper() + '_URL'] = f'http://127.0.0.1:{SERVICES[name]}'
    if not env.get('JAVA_HOME') and Path('/opt/homebrew/opt/openjdk@21').exists():
        env['JAVA_HOME'] = '/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home'
    children, servers, logs = [], [], []
    moto = None

    def launch(name, command, extra=None):
        log = (state / (name + '.log')).open('a')
        logs.append(log)
        child = subprocess.Popen([str(x) for x in command], cwd=args.cloud, env=dict(env, **(extra or {})), stdout=log, stderr=subprocess.STDOUT)
        children.append((name, child))

    def sql(database, statement):
        return subprocess.check_output([str(args.pg_bin / 'psql'), '-h', '127.0.0.1', '-p', '25432', '-d', database, '-v', 'ON_ERROR_STOP=1', '-Atc', statement], text=True).strip()

    def serve(port, handler):
        server = ThreadingHTTPServer(('127.0.0.1', port), handler)
        server.daemon_threads = True
        servers.append(server)
        threading.Thread(target=server.serve_forever, daemon=True).start()

    def stop_signal(*_):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, stop_signal)
    signal.signal(signal.SIGINT, stop_signal)
    try:
        pgdata = state / 'postgres'
        if not (pgdata / 'PG_VERSION').exists():
            subprocess.run([str(args.pg_bin / 'initdb'), '-D', str(pgdata), '-A', 'trust', '--no-locale', '--encoding=UTF8'], check=True, stdout=subprocess.DEVNULL)
        # Fluent pools reserve connections per event loop in each service.
        connections = max(200, (os.cpu_count() or 8) * len(SERVICES) * 2 + 32)
        launch('postgres', [args.pg_bin / 'postgres', '-D', pgdata, '-h', '127.0.0.1', '-p', '25432',
                            '-c', 'unix_socket_directories=', '-c', f'max_connections={connections}', '-c', 'shared_buffers=128MB'])
        for _ in range(120):
            if subprocess.run([str(args.pg_bin / 'pg_isready'), '-h', '127.0.0.1', '-p', '25432', '-d', 'postgres'], stdout=subprocess.DEVNULL).returncode == 0:
                break
            time.sleep(.25)
        user = sql('postgres', 'SELECT current_user')
        launch('redis', [args.redis, '--bind', '127.0.0.1', '--port', '26379', '--dir', state, '--appendonly', 'yes'])
        kafka_config = state / 'kafka.properties'
        kafka_config.write_text(f'''process.roles=broker,controller
node.id=1
controller.quorum.voters=1@127.0.0.1:29093
listeners=PLAINTEXT://127.0.0.1:29092,CONTROLLER://127.0.0.1:29093
advertised.listeners=PLAINTEXT://127.0.0.1:29092
controller.listener.names=CONTROLLER
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
log.dirs={state / 'kafka'}
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
num.partitions=1
''')
        if not (state / 'kafka/meta.properties').exists():
            subprocess.run([str(args.kafka / 'bin/kafka-storage.sh'), 'format', '-t', 'MkU3OEVBNTcwNTJENDM2Qk', '-c', str(kafka_config)], env=env, check=True, stdout=subprocess.DEVNULL)
        launch('kafka', [args.kafka / 'bin/kafka-server-start.sh', kafka_config], {'KAFKA_HEAP_OPTS': '-Xms128m -Xmx512m'})
        # Werkzeug otherwise logs presigned S3 query strings.
        logging.getLogger('werkzeug').setLevel(logging.ERROR)
        moto = ThreadedMotoServer(ip_address='127.0.0.1', port=29001, verbose=False)
        moto.start()
        s3 = boto3.client('s3', endpoint_url='http://127.0.0.1:29001', aws_access_key_id=env['S3_ACCESS_KEY'], aws_secret_access_key=env['S3_SECRET_KEY'], region_name='us-east-1')
        from dev_storage import persistent_s3
        storage_handler = persistent_s3(s3, env['S3_BUCKET'], state / 'objects', forward)
        serve(29000, storage_handler)
        inbox = state / 'inbox'
        inbox.mkdir(exist_ok=True)

        class Mailbox(SimpleHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                if self.headers.get('Authorization') != 'Bearer ' + private['INTERNAL_SECRET']:
                    self.send_error(401)
                    return
                size = int(self.headers.get('Content-Length', '0'))
                if not 0 < size <= 4096:
                    self.send_error(413)
                    return
                import hashlib
                value = json.loads(self.rfile.read(size))
                value['createdAt'] = time.time()
                (inbox / (hashlib.sha256(value['to'].encode()).hexdigest() + '.json')).write_text(json.dumps(value))
                self.send_response(204)
                self.end_headers()
            def do_GET(self):
                import html
                rows = [json.loads(p.read_text()) for p in inbox.glob('*.json')]
                body = ('<!doctype html><meta charset="utf-8"><h1>Local development inbox</h1><p>No external email is sent.</p>' + ''.join('<p>' + html.escape(r['to']) + ': <strong>' + html.escape(r['code']) + '</strong></p>' for r in rows if r['createdAt'] > time.time() - 600)).encode()
                self.send_response(200)
                self.send_header('Content-Type', 'text/html; charset=utf-8')
                self.send_header('Cache-Control', 'no-store')
                self.end_headers()
                self.wfile.write(body)
        serve(28088, Mailbox)
        for name, port in SERVICES.items():
            database = 'studio_dev_' + name.lower()
            if sql('postgres', f"SELECT 1 FROM pg_database WHERE datname='{database}'") != '1':
                sql('postgres', 'CREATE DATABASE ' + database)
            launch(name, [binaries / name], {'PORT': str(port), 'DATABASE_URL': f'postgres://{user}@127.0.0.1:25432/{database}?sslmode=disable'})
        for port in SERVICES.values():
            wait_http(f'http://127.0.0.1:{port}/health/ready', children)

        class Edge(SimpleHTTPRequestHandler):
            def __init__(self, *a, **kw): super().__init__(*a, directory=str(args.website), **kw)
            def dispatch(self):
                if self.headers.get('Host') != f'localhost:{args.port}':
                    self.send_response(307)
                    self.send_header('Location', origin + '/games')
                    self.end_headers()
                    return
                # Preserve origin checks and cookies exactly as the real API expects.
                development_path = urlsplit(self.path).path
                if self.command in ('GET', 'HEAD') and development_path == '/__dev/studio-config':
                    data = json.dumps(development_studio_config(codex_provider)).encode()
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Content-Length', str(len(data)))
                    self.send_header('Cache-Control', 'no-store')
                    self.end_headers()
                    if self.command == 'GET': self.wfile.write(data)
                    return
                if self.command in ('GET', 'HEAD') and development_path in ('/__dev/inbox.js', '/__dev/localization.js'):
                    data = inbox_script(UI) if development_path == '/__dev/inbox.js' else (UI / 'src/localization.js').read_bytes()
                    self.send_response(200)
                    self.send_header('Content-Type', 'text/javascript; charset=utf-8')
                    self.send_header('Content-Length', str(len(data)))
                    self.send_header('Cache-Control', 'no-store')
                    self.send_header('X-Content-Type-Options', 'nosniff')
                    self.end_headers()
                    if self.command == 'GET': self.wfile.write(data)
                    return
                if codex_bridge:
                    from dev_codex import handle
                    if handle(self, codex_bridge, codex_provider, origin):
                        return
                port = route(self.path)
                if port:
                    forward(self, port)
                elif self.path.startswith('/v1/') or self.path.startswith('/internal'):
                    self.send_error(404)
                elif self.command not in ('GET', 'HEAD'):
                    self.send_error(405)
                else:
                    path = urlsplit(self.path).path
                    if frontend_redirect(path):
                        self.send_response(302)
                        self.send_header('Location', frontend_redirect(path))
                        self.end_headers()
                        return
                    super().do_HEAD() if self.command == 'HEAD' else super().do_GET()
            def translate_path(self, path):
                return str(frontend_target(path, args.website, UI / 'dist'))
            def send_head(self):
                target = Path(self.translate_path(self.path))
                if target.resolve() in ((UI / 'dist/index.html').resolve(), (args.website / 'index.html').resolve()) and target.is_file():
                    data = inject_html(target.read_bytes())
                    self.send_response(200)
                    self.send_header('Content-Type', 'text/html; charset=utf-8')
                    self.send_header('Content-Length', str(len(data)))
                    self.send_header('Cache-Control', 'no-store')
                    self.end_headers()
                    return BytesIO(data)
                return super().send_head()
            do_GET = do_HEAD = do_POST = do_PUT = do_PATCH = do_DELETE = dispatch
        serve(args.port, Edge)
        if (args.player / 'studio-preview.html').exists():
            class Player(SimpleHTTPRequestHandler):
                def __init__(self, *a, **kw): super().__init__(*a, directory=str(args.player), **kw)
            serve(8081, Player)
        print(f'Playground: {origin}/games\nSign in: {origin}/cloud\nInbox: http://127.0.0.1:28088/\nState and logs: {state}', flush=True)
        if not (args.player / 'studio-preview.html').exists():
            print('Player is missing: export AdaWebPlayer for scene/Play. Editing and saving remain available.', flush=True)
        while True:
            for name, child in children:
                if child.poll() is not None:
                    raise RuntimeError(f'{name} stopped; inspect {state / (name + ".log")}')
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        for server in servers:
            server.shutdown()
            server.server_close()
        # Stop consumers before persistence services. Preserve all state on disk.
        for group in [children[3:], children[:3]]:
            for _, child in reversed(group):
                if child.poll() is None: child.terminate()
            deadline = time.monotonic() + 10
            for _, child in reversed(group):
                try: child.wait(timeout=max(.1, deadline - time.monotonic()))
                except subprocess.TimeoutExpired: child.kill(); child.wait()
        if moto: moto.stop()
        for log in logs: log.close()


if __name__ == '__main__':
    main()
