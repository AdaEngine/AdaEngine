#!/usr/bin/env python3
"""Prepare the pinned Yams fork with its WASI floating-point precision constant.

Only a task-local dependency copy changes; the repository and shared SwiftPM
checkouts are never rewritten. DBL_DECIMAL_DIG for IEEE 754 binary64 is 17.
"""
import argparse
from pathlib import Path
import subprocess

REVISION = 'fb676da5b91f677ab8e8d06b7fcde45b25181531'


def prepare(destination, source=None):
    destination = Path(destination).resolve()
    if not (destination / '.git').exists():
        destination.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['git', 'clone', '--no-checkout', str(source or 'https://github.com/SpectralDragon/Yams.git'), str(destination)], check=True)
        subprocess.run(['git', '-C', str(destination), 'checkout', '--detach', REVISION], check=True)
    head = subprocess.check_output(['git', '-C', str(destination), 'rev-parse', 'HEAD'], text=True).strip()
    if head != REVISION:
        raise RuntimeError('Unexpected Yams revision in the task-local compatibility copy')
    source = destination / 'Sources/Yams/Representer.swift'
    text = source.read_text(encoding='utf-8')
    marker = '#if os(WASI)\nprivate let DBL_DECIMAL_DIG: Int32 = 17\n#endif\n'
    if marker not in text:
        text = text.replace('import Foundation\n', 'import Foundation\n\n' + marker, 1)
        source.write_text(text, encoding='utf-8')
    return destination


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--source', type=Path)
    args = parser.parse_args()
    print(prepare(args.output, args.source))
