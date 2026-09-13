#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build="${STARQUEST_BUILD_PATH:-/tmp/starquest-build}"
export CLANG_MODULE_CACHE_PATH="/tmp/starquest-modules"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
swift build --disable-sandbox --scratch-path "$build" --product StarQuest
bin="$(swift build --disable-sandbox --scratch-path "$build" --show-bin-path)"
pkill -x StarQuest >/dev/null 2>&1 || true
python3 script/stage_app.py "$bin" "$PWD/dist/StarQuest.app"
codesign --force --deep --sign - "$PWD/dist/StarQuest.app"
open -n "$PWD/dist/StarQuest.app"
