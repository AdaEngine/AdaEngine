#!/usr/bin/env python3
"""Prepare task-local Python and Swift build caches for npm run dev."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import venv

UI = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--cloud', type=Path, default=UI.parents[1].parent / 'adaengine-service')
parser.add_argument('--website-source', type=Path, default=UI.parents[1].parent / 'My Projects/adawebsite')
parser.add_argument('--skip-cloud-build', action='store_true')
args = parser.parse_args()
if not (args.cloud / 'Package.swift').exists():
    parser.error('Pass --cloud /absolute/path/to/adaengine-service')
local = UI / '.local'
local.mkdir(exist_ok=True)
python = local / 'venv/bin/python'
if not python.exists():
    venv.create(local / 'venv', with_pip=True)
subprocess.run([str(python), '-m', 'pip', 'install', '-r', str(UI / 'scripts/dev-requirements.txt')], check=True)
subprocess.run(['npm', 'run', 'build:panels'], cwd=args.website_source, check=True)
subprocess.run(['npm', 'run', 'build'], cwd=UI, env=dict(os.environ, ADA_CLOUD_PANELS_DIST=str(args.website_source.resolve() / 'dist-panels')), check=True)
if not args.skip_cloud_build:
    subprocess.run(['swift', 'build', '--package-path', str(args.cloud.resolve()),
                    '--scratch-path', str(local / 'cloud/build'), '--disable-index-store',
                    '--disable-sandbox', '-j', '4'], env=dict(os.environ, ADA_CLOUD_ONLY='1'), check=True)
print('Ready: npm run dev. Export AdaPlayer separately for scene/Play; see README.md.')
