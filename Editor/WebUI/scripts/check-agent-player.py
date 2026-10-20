#!/usr/bin/env python3
"""Separate browser QA server for the production fixed Player and bundled examples.

This serves bundled fixture data only, has no Cloud credentials and adds no QA
routes or objects to Studio. Open the printed URL and use the visible controls.
"""
import argparse
import base64
import http.server
import json
from pathlib import Path
import threading
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=38080)
    parser.add_argument('--player-port', type=int, default=38081)
    parser.add_argument('--player', type=Path, default=ROOT / '.local/studio-web/player')
    parser.add_argument('--verify-native', type=Path, metavar='ADASTUDIO', help='Validate the exported projects with the native CLI, then exit')
    options = parser.parse_args()
    if options.verify_native:
        data = json.loads((ROOT / 'dist/agent-resources.json').read_text())
        results = []
        with tempfile.TemporaryDirectory(prefix='ada-browser-examples-') as temporary:
            root = Path(temporary).resolve()
            for example in data['examples']:
                folder = (root / example['id']).resolve()
                folder.relative_to(root)
                folder.mkdir()
                for path, content in {**{p: v.encode() for p, v in example['files'].items()},
                                      **{p: base64.b64decode(v, validate=True) for p, v in example.get('assets', {}).items()}}.items():
                    target = (folder / path).resolve()
                    target.relative_to(folder)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(content)
                checked = subprocess.run([str(options.verify_native.resolve()), '--ada-studio-cli', 'validate', '--project', str(folder), '--format', 'json'], capture_output=True, text=True)
                report = json.loads(checked.stdout)
                results.append({'id': example['id'], 'ok': report.get('ok') is True and checked.returncode == 0, 'details': report.get('details'), 'diagnostics': report.get('diagnostics')})
        print(json.dumps(results, indent=2))
        raise SystemExit(0 if all(result['ok'] for result in results) else 1)
    origin = f'http://localhost:{options.port}'
    class Fixture(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == '/fixtures.json':
                data = json.loads((ROOT / 'dist/agent-resources.json').read_text())
                body = json.dumps({'contract': data['contract'], 'examples': data['examples'],
                                   'previewURL': f'http://127.0.0.1:{options.player_port}/studio-preview.html'}).encode()
                content_type = 'application/json'
            elif self.path == '/':
                body = (ROOT / 'test/player-harness.html').read_bytes()
                content_type = 'text/html; charset=utf-8'
            else:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header('Content-Type', content_type)
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
    class Player(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(options.player), **kwargs)
        def do_GET(self):
            if self.path == '/studio-player-config.json':
                body = json.dumps({'allowedOrigins': [origin]}).encode()
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            else:
                super().do_GET()
    for port, handler in [(options.port, Fixture), (options.player_port, Player)]:
        server = http.server.ThreadingHTTPServer(('127.0.0.1', port), handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
    print(origin, flush=True)
    threading.Event().wait()


if __name__ == '__main__':
    main()
