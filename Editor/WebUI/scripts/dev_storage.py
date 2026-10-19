"""Durable object mirror for the local Moto S3 emulator, outside production code."""
import hashlib
from http.server import BaseHTTPRequestHandler
import json
import os
from pathlib import Path
import threading
from urllib.parse import unquote, urlsplit


def persistent_s3(client, bucket, directory, forward):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    client.create_bucket(Bucket=bucket)
    # One atomically replaced file per object contains metadata and payload.
    for path in directory.glob('*.object'):
        metadata, data = path.read_bytes().split(b'\n', 1)
        metadata = json.loads(metadata)
        client.put_object(Bucket=bucket, Key=metadata['key'], Body=data, ContentType=metadata['contentType'])
    lock = threading.Lock()

    class Storage(BaseHTTPRequestHandler):
        def log_message(self, *_): pass
        def dispatch(self):
            # Serialize writes and mirror the committed Moto object before returning
            # success to Cloud. A launcher restart restores acknowledged objects.
            with lock:
                from io import BytesIO
                output, original = BytesIO(), self.wfile
                self.wfile = output
                try:
                    forward(self, 29001)
                    response = output.getvalue()
                    status = int(response.split(b' ', 2)[1])
                    path = unquote(urlsplit(self.path).path).split('/', 2)
                    if status < 300 and len(path) == 3 and path[1] == bucket:
                        key = path[2]
                        target = directory / (hashlib.sha256(key.encode()).hexdigest() + '.object')
                        if self.command in ('PUT', 'POST'):
                            obj = client.get_object(Bucket=bucket, Key=key)
                            header = json.dumps({'key': key, 'contentType': obj['ContentType']}).encode()
                            temporary = target.with_suffix('.tmp')
                            with temporary.open('wb') as file:
                                file.write(header + b'\n' + obj['Body'].read())
                                file.flush()
                                os.fsync(file.fileno())
                            os.replace(temporary, target)
                        elif self.command == 'DELETE':
                            target.unlink(missing_ok=True)
                    original.write(response)
                    original.flush()
                finally:
                    self.wfile = original
        do_GET = do_HEAD = do_PUT = do_POST = do_DELETE = dispatch
    return Storage
