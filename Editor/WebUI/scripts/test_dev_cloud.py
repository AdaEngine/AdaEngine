import importlib.util
from pathlib import Path
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer

spec = importlib.util.spec_from_file_location('dev_cloud', Path(__file__).with_name('dev-cloud.py'))
dev = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dev)


class RoutingTests(unittest.TestCase):
    def test_public_api_boundaries(self):
        self.assertEqual(dev.route('/v1/workspaces/123/history?limit=10'), 28091)
        self.assertEqual(dev.route('/v1/ai/generate'), 28090)
        self.assertEqual(dev.route('/v1/auth/email/verify'), 28081)
        for path in ['/internal/metrics', '/v1/workspaces-evil', '/v1/unknown', '/studio/']:
            self.assertIsNone(dev.route(path))


class FrontendTests(unittest.TestCase):
    def test_all_public_screens_use_one_entry(self):
        from playground_static import target, redirect
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve(); site = root / 'site'; ui = root / 'ui'
            site.mkdir(); ui.mkdir(); (ui / 'index.html').write_text('one shell')
            for path in ['/games', '/games/a', '/create', '/projects/private', '/account?code=x', '/publications/page', '/cloud/projects/new', '/legal/privacy']:
                self.assertEqual(target(path, site, ui), ui / 'index.html')
            for path in ['/', '/studio', '/studio/']:
                self.assertEqual(redirect(path), '/games')
            self.assertEqual(target('/studio/studio.js', site, ui), ui / 'studio.js')
            self.assertEqual(target('/studio/%2e%2e/private', site, ui), ui / '__missing__')


class StorageTests(unittest.TestCase):
    def test_acknowledged_objects_survive_emulator_restart(self):
        import boto3
        from moto.server import ThreadedMotoServer
        from dev_storage import persistent_s3
        with tempfile.TemporaryDirectory() as directory:
            for turn in range(3):
                moto = ThreadedMotoServer(ip_address='127.0.0.1', port=0, verbose=False)
                moto.start()
                host, port = moto.get_host_and_port()
                import urllib.request
                urllib.request.urlopen(urllib.request.Request(f'http://{host}:{port}/moto-api/reset', data=b'{}', method='POST')).close()
                options = dict(aws_access_key_id='test', aws_secret_access_key='test', region_name='us-east-1')
                inner = boto3.client('s3', endpoint_url=f'http://{host}:{port}', **options)
                handler = persistent_s3(inner, 'test-bucket', directory, lambda h, _: dev.forward(h, port))
                server = ThreadingHTTPServer(('127.0.0.1', 0), handler)
                thread = threading.Thread(target=server.serve_forever, daemon=True)
                thread.start()
                client = boto3.client('s3', endpoint_url=f'http://127.0.0.1:{server.server_port}', **options)
                try:
                    if turn == 0:
                        client.put_object(Bucket='test-bucket', Key='workspaces/test.json', Body=b'first', ContentType='application/json')
                        self.assertEqual(len(list(Path(directory).glob('*.object'))), 1)
                    elif turn == 1:
                        obj = client.get_object(Bucket='test-bucket', Key='workspaces/test.json')
                        self.assertEqual(obj['Body'].read(), b'first')
                        self.assertEqual(obj['ContentType'], 'application/json')
                        client.delete_object(Bucket='test-bucket', Key='workspaces/test.json')
                    else:
                        self.assertEqual(client.list_objects_v2(Bucket='test-bucket').get('KeyCount'), 0)
                finally:
                    server.shutdown()
                    server.server_close()
                    moto.stop()


if __name__ == '__main__':
    unittest.main()
