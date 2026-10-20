from collections import deque
from io import BytesIO
from pathlib import Path
import json
import threading
import unittest
from unittest.mock import patch
from dev_codex import CodexError, PROVIDER
from dev_completion import validate_completion, completion_suffix, complete, handle_completion

BODY = {'providerID': PROVIDER, 'billingMode': 'codex', 'model': 'selected', 'text': 'A game about a bakery in space where', 'language': 'en', 'dimension': 3, 'players': 'single'}


class CompletionTests(unittest.TestCase):
    def test_model_bounds_and_suffix_only_response(self):
        validate_completion(BODY, {'selected'})
        for change in [{'model': 'other'}, {'text': ''}, {'text': 'x' * 2001}, {'tools': []}, {'billingMode': 'byok'}]:
            with self.assertRaises(ValueError): validate_completion(dict(BODY, **change), {'selected'})
        self.assertEqual(completion_suffix(json.dumps({'suffix': ' players bake bread in zero gravity.'}), BODY['text']), ' players bake bread in zero gravity.')
        self.assertEqual(completion_suffix(json.dumps({'suffix': BODY['text'] + ' I bake.'}), BODY['text']), ' I bake.')
        for suffix in ['x' * 241, '```code```', 'new\nline']:
            with self.assertRaises(CodexError): completion_suffix(json.dumps({'suffix': suffix}), BODY['text'])

    def test_completion_uses_selected_model_without_tools_and_closes_on_cancellation(self):
        calls, closed = [], []
        class FakeClient:
            config = {'features.shell_tool': False}
            def __init__(self, *_): self.events = deque([
                {'method': 'item/agentMessage/delta', 'params': {'turnId': 'turn', 'delta': '{"suffix":" I bake bread."}'}},
                {'method': 'turn/completed', 'params': {'turnId': 'turn', 'turn': {'status': 'completed'}}}])
            def rpc(self, name, params):
                calls.append((name, params))
                return {'thread': {'id': 'ephemeral'}} if name == 'thread/start' else {'turn': {'id': 'turn'}}
            def __enter__(self): return self
            def __exit__(self, *_): closed.append(True)
        class Bridge:
            executable = 'codex'; directory = Path('/tmp'); models = [{'id': 'selected'}]
            completion_active = threading.BoundedSemaphore(1); completion_efforts = {'selected': 'low'}
        bridge = Bridge()
        events = list(complete(bridge, BODY, FakeClient))
        self.assertEqual(events[-1], {'type': 'completion', 'suffix': ' I bake bread.'})
        thread = calls[0][1]; turn = calls[1][1]
        self.assertEqual(thread['model'], 'selected'); self.assertTrue(thread['ephemeral']); self.assertEqual(thread['sandbox'], 'read-only')
        self.assertEqual(turn['effort'], 'low'); self.assertNotIn('tools', turn); self.assertNotIn('conversation', turn)
        generator = complete(bridge, BODY, FakeClient)
        self.assertIsNone(next(generator)); generator.close()
        self.assertEqual(len(closed), 2)
        self.assertTrue(bridge.completion_active.acquire(blocking=False)); bridge.completion_active.release()

    def test_completion_keeps_origin_and_identity_admission(self):
        class Handler:
            command = 'POST'
            def __init__(self, origin):
                raw = json.dumps(BODY).encode(); self.rfile = BytesIO(raw); self.wfile = BytesIO()
                self.headers = {'Origin': origin, 'Content-Length': str(len(raw))}; self.status = None
            def send_error(self, status): self.status = status
            def send_response(self, status): self.status = status
            def send_header(self, *_): pass
            def end_headers(self): pass
        class Bridge: models = [{'id': 'selected'}]
        blocked = Handler('http://evil.test'); handle_completion(blocked, Bridge(), 'http://localhost:8080')
        self.assertEqual(blocked.status, 403)
        signedout = Handler('http://localhost:8080')
        with patch('dev_completion.upstream', return_value=(401, b'{}')):
            handle_completion(signedout, Bridge(), 'http://localhost:8080')
        self.assertEqual(signedout.status, 401)
