#!/usr/bin/env python3
"""Exercise real auth/workspace APIs, optionally restarting a task-owned stack."""
import argparse
import base64
import hashlib
import http.client
import json
from pathlib import Path
import secrets
import subprocess
import sys
import time
import uuid

UI = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--restart', action='store_true', help='Own a launcher process and test full persistence across its restart')
args = parser.parse_args()
origin = 'http://localhost:8080'
children = []
log = None


def call(path, body=None, method=None, token=None, expected=200, extra_headers=None):
    connection = http.client.HTTPConnection('localhost', 8080, timeout=60)
    headers = {'Content-Type': 'application/json', **(extra_headers or {})}
    if token: headers['Authorization'] = 'Bearer ' + token
    data = json.dumps(body).encode() if body is not None else None
    connection.request(method or ('POST' if body is not None else 'GET'), path, data, headers)
    response = connection.getresponse()
    raw = response.read()
    connection.close()
    if response.status != expected:
        raise RuntimeError(f'{path}: expected {expected}, received {response.status}: {raw[:300]!r}')
    try:
        return json.loads(raw) if raw else None
    except json.JSONDecodeError:
        return raw


def launch():
    child = subprocess.Popen([sys.executable, str(UI / 'scripts/dev-cloud.py')], stdout=log, stderr=subprocess.STDOUT)
    children.append(child)
    for _ in range(240):
        if child.poll() is not None: raise RuntimeError('Launcher failed; see .local/cloud/smoke-launcher.log')
        try:
            call('/v1/legal')
            return child
        except (OSError, RuntimeError): time.sleep(.5)
    raise RuntimeError('Launcher not ready')


def stop(child):
    child.terminate()
    child.wait(timeout=40)
    children.remove(child)


try:
    if args.restart:
        log = (UI / '.local/cloud/smoke-launcher.log').open('a')
        child = launch()
    assert b'Ada Playground' in call('/games')
    if (UI / '.local/studio-web/player/AdaWebPlayer.wasm').exists():
        for asset in ['studio-preview.html', 'studio-player.js', 'runtime.mjs', 'AdaWebPlayer.wasm']:
            connection = http.client.HTTPConnection('127.0.0.1', 8081, timeout=10)
            connection.request('HEAD', '/' + asset)
            response = connection.getresponse()
            assert response.status == 200, (asset, response.status)
            if asset.endswith('.wasm'):
                assert response.getheader('Content-Type') == 'application/wasm'
            connection.close()
        print('PASS: isolated Player entrypoint, runtime and WASM routes.', flush=True)
    email = f'development-{uuid.uuid4().hex[:12]}@example.test'
    # Give each test a separate trusted-proxy client identity so repeated smoke
    # runs do not consume the ordinary browser's three-attempt email budget.
    private = json.loads((UI / '.local/cloud/configuration.json').read_text())
    network = uuid.uuid4().hex
    auth_headers = {'X-Ada-Proxy-Token': private['PROXY_SHARED_SECRET'],
                    'X-Ada-Client-IP': '2001:db8:' + ':'.join(network[n:n + 4] for n in range(0, 24, 4))}
    verifier = secrets.token_urlsafe(32)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip('=')
    flow = call('/v1/auth/start', {'provider': 'email', 'email': email, 'client': 'native', 'challenge': challenge}, extra_headers=auth_headers)
    codefile = UI / '.local/cloud/inbox' / (hashlib.sha256(email.encode()).hexdigest() + '.json')
    code = json.loads(codefile.read_text())['code']
    session = call('/v1/auth/email/verify', {'flowId': flow['flowId'], 'verifier': verifier, 'code': code}, extra_headers=auth_headers)
    token = session['accessToken']
    call('/v1/me', token=token)
    assert call('/v1/ai/studio-config', token=token)['enabled']
    assert all(p.get('transport') == 'codex' for p in call('/v1/ai/providers', token=token))
    call('/v1/workspaces', expected=401)
    call('/internal/metrics', expected=404)
    snapshot = json.loads(subprocess.check_output(['node', '--input-type=module', '-e', "import {template} from './src/documents.js'; console.log(JSON.stringify(template(3)))"], cwd=UI))
    snapshot['title'] = 'Локальная проверка Studio'
    operation = str(uuid.uuid4())
    record = call('/v1/workspaces', {'operationID': operation, 'snapshot': snapshot}, token=token)
    duplicate = call('/v1/workspaces', {'operationID': operation, 'snapshot': snapshot}, token=token)
    assert duplicate['id'] == record['id']
    path = '/v1/workspaces/' + record['id']
    snapshot['title'] = 'Локальная проверка — сохранено'
    saved = call(path, {'operationID': str(uuid.uuid4()), 'expectedRevision': 1, 'snapshot': snapshot, 'checkpoint': True}, 'PUT', token)
    assert saved['revision'] == 2
    assert call(path, token=token)['snapshot'] == snapshot
    call(path, {'operationID': str(uuid.uuid4()), 'expectedRevision': 1, 'snapshot': snapshot}, 'PUT', token, expected=409)
    # Exercise the real cookie CSRF boundary, even though this probe uses native auth.
    call('/v1/workspaces', {'operationID': str(uuid.uuid4()), 'snapshot': snapshot}, expected=403,
         extra_headers={'Cookie': '__Host-ada_session=' + token, 'Origin': 'http://evil.test'})
    print('PASS: real email/PKCE auth, config, create, idempotency, save/reopen, conflict, unauthenticated access and origin rejection.', flush=True)
    if args.restart:
        stop(child)
        child = launch()
        assert call(path, token=token)['snapshot'] == snapshot
        assert call(path, token=token)['revision'] == 2
        print('PASS: PostgreSQL metadata, Redis session and S3 project content survive a full stack restart.', flush=True)
finally:
    for child in children[:]: stop(child)
    if log: log.close()
