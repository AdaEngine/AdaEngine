#!/usr/bin/env python3
"""Install the small DOM editor and strip non-runtime debug metadata from AdaPlayer."""
import argparse
import gzip
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]


def read_leb(data, offset):
    value, shift = 0, 0
    while offset < len(data) and shift <= 35:
        byte = data[offset]
        offset += 1
        value |= (byte & 127) << shift
        if not byte & 128:
            return value, offset
        shift += 7
    raise ValueError('Invalid WebAssembly section length')


def strip_debug(data):
    if data[:8] != b'\0asm\x01\0\0\0':
        raise ValueError('Expected a WebAssembly 1 module')
    output = bytearray(data[:8])
    offset = 8
    while offset < len(data):
        start, kind = offset, data[offset]
        size, payload = read_leb(data, offset + 1)
        end = payload + size
        if end > len(data):
            raise ValueError('Truncated WebAssembly section')
        name = ''
        if kind == 0:
            count, name_start = read_leb(data, payload)
            if name_start + count > end:
                raise ValueError('Invalid custom section name')
            name = data[name_start:name_start + count].decode('utf-8')
        # Retain imports, exports, code, data, reflection and target_features.
        if not (kind == 0 and (name.startswith('.debug_') or name in ('name', '.swift_ast', '.swift1_autolink_entries'))):
            output.extend(data[start:end])
        offset = end
    return bytes(output)


def prepare(output, ui=None):
    ui = Path(ui or ROOT / 'Editor/WebUI/dist').resolve()
    if not (ui / 'studio.js').is_file():
        raise RuntimeError('Build Editor/WebUI first: pnpm install && pnpm build')
    editor = Path(output) / 'studio'
    editor.mkdir(parents=True, exist_ok=True)
    for file in ui.iterdir():
        if file.is_file():
            shutil.copy2(file, editor / file.name)
    # Old export artifacts may coexist for rollback; index.html has no reference to editor WASM.
    player = Path(output) / 'player/AdaWebPlayer.wasm'
    if player.is_file():
        previous = player.stat().st_size
        data = strip_debug(player.read_bytes())
        if len(data) != previous:
            player.write_bytes(data)
        compressed = gzip.compress(data, compresslevel=6, mtime=0)
        player.with_suffix('.wasm.gz').write_bytes(compressed)
        print('AdaPlayer: %.1f MiB module / %.1f MiB gzip (was %.1f MiB)' % (len(data) / 2**20, len(compressed) / 2**20, previous / 2**20))
    print('DOM editor: ' + str(editor))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--ui-dist', type=Path)
    args = parser.parse_args()
    prepare(args.output.resolve(), args.ui_dist)
