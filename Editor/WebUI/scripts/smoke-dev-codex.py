#!/usr/bin/env python3
"""Opt-in live Codex smoke: real CLI inference followed by a production document tool."""
import base64
import hashlib
import http.client
import json
from pathlib import Path
import secrets
import subprocess
import uuid

UI = Path(__file__).resolve().parents[1]
private = json.loads((UI / '.local/cloud/configuration.json').read_text())


def request(path, body=None, token=None, headers=None, expected=200):
    connection = http.client.HTTPConnection('localhost', 8080, timeout=300)
    outgoing = {'Content-Type': 'application/json', 'Origin': 'http://localhost:8080', **(headers or {})}
    if token: outgoing['Authorization'] = 'Bearer ' + token
    connection.request('POST' if body is not None else 'GET', path, json.dumps(body) if body is not None else None, outgoing)
    response = connection.getresponse()
    data = response.read()
    mime = response.getheader('Content-Type', '')
    connection.close()
    assert response.status == expected, (path, response.status, data[:200])
    return json.loads(data) if 'application/json' in mime else data.decode()


email = 'codex-smoke-' + uuid.uuid4().hex[:12] + '@example.test'
proof = secrets.token_urlsafe(32)
challenge = base64.urlsafe_b64encode(hashlib.sha256(proof.encode()).digest()).decode().rstrip('=')
network = uuid.uuid4().hex
headers = {'X-Ada-Proxy-Token': private['PROXY_SHARED_SECRET'], 'X-Ada-Client-IP': '2001:db8:' + ':'.join(network[n:n + 4] for n in range(0, 24, 4))}
flow = request('/v1/auth/start', {'provider': 'email', 'email': email, 'client': 'native', 'challenge': challenge}, headers=headers)
code = json.loads((UI / '.local/cloud/inbox' / (hashlib.sha256(email.encode()).hexdigest() + '.json')).read_text())['code']
token = request('/v1/auth/email/verify', {'flowId': flow['flowId'], 'verifier': proof, 'code': code}, headers=headers)['accessToken']
providers = request('/v1/ai/providers', token=token)
provider = next(p for p in providers if p.get('transport') == 'codex')
assert 'apiKey' not in json.dumps(provider)
model = provider['models'][0]['id']
tools = json.loads(subprocess.check_output(['node', '--input-type=module', '-e', "import {tools} from './src/agent.js'; console.log(JSON.stringify(tools.filter(t=>t.function.name==='editor_file_write')))"], cwd=UI))
body = {'operationID': str(uuid.uuid4()), 'providerID': provider['id'], 'model': model, 'billingMode': 'codex', 'mode': 'build',
        'messages': [{'role': 'user', 'content': 'Request editor_file_write exactly once with path Docs/CodexSmoke.md and content codex test. The browser will execute it. Do not claim it is saved yet.'}], 'tools': tools}
request('/v1/ai/generate', body, expected=401)
request('/v1/ai/generate', body, token=token, headers={'Origin': 'http://evil.test'}, expected=403)
raw = request('/v1/ai/generate', body, token=token)
events = [json.loads(line[6:]) for line in raw.splitlines() if line.startswith('data: ')]
assert not any(e['type'] == 'error' for e in events), events
assert events[-1]['type'] == 'complete'
calls = [e['call'] for e in events if e['type'] == 'tool']
assert len(calls) == 1 and calls[0]['function']['name'] == 'editor_file_write', events
args = json.loads(calls[0]['function']['arguments'])
assert args == {'path': 'Docs/CodexSmoke.md', 'content': 'codex test'}, args
# Execute the returned call through the same production document/Undo path used by the UI.
script = """
import assert from 'node:assert/strict';
import {Document,template,file} from './src/documents.js';
import {runTool} from './src/agent.js';
import {decode} from './src/platform.js';
let raw=''; for await (const c of process.stdin) raw+=c;
const call=JSON.parse(raw);
const document=new Document(template(3));
const studio={document,get snapshot(){return document.snapshot},changed(){}};
await runTool(studio,call.function.name,JSON.parse(call.function.arguments));
assert.equal(decode(file(document.snapshot,'Docs/CodexSmoke.md').data),'codex test');
document.undo();
assert.equal(file(document.snapshot,'Docs/CodexSmoke.md'),undefined);
console.log('PASS: live Codex call executed by the production document tool and reverted through Undo');
"""
subprocess.run(['node', '--input-type=module', '-e', script], cwd=UI, input=json.dumps(calls[0]).encode(), check=True)
print('PASS: Codex catalog, real ChatGPT-authenticated inference, no API key, session admission and origin rejection')
