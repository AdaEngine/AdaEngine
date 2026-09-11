#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
fold_build="${FOLD_BUILD_PATH:-/tmp/fold-build}"
fold_cache="${FOLD_CACHE_PATH:-/tmp/fold-cache}"
export CLANG_MODULE_CACHE_PATH="${FOLD_CLANG_CACHE_PATH:-/tmp/fold-clang}"
swift build --scratch-path "$fold_build" --cache-path "$fold_cache" --product Fold
fold_bin="$(swift build --scratch-path "$fold_build" --cache-path "$fold_cache" --show-bin-path)"
# Stop only this demo; AdaEditor and other games keep running.
pkill -x Fold >/dev/null 2>&1 || true
python3 script/stage_app.py "$fold_bin" "$PWD/dist/Fold.app"
codesign --force --deep --sign - "$PWD/dist/Fold.app"
open -n "$PWD/dist/Fold.app"
