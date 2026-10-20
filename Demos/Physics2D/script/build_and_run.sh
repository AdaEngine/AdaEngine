#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
DEMO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$DEMO_ROOT/../.." && pwd)"
BUILD_PATH="${ADAENGINE_PHYSICS2D_BUILD_PATH:-/tmp/adaengine-box2d-3.2-build}"
mkdir -p "$BUILD_PATH"
APP="$DEMO_ROOT/dist/Physics2DDemo.app"
export ADAENGINE_DISABLE_SWAN=1
export ADAENGINE_SKIP_SWIFTLINT=1
case "$MODE" in run|--verify|--debug|--logs|--telemetry) ;; *) echo "usage: $0 [run|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;; esac
for demo_pid in $(pgrep -f "$APP/Contents/MacOS/Physics2DDemo" || true); do
    demo_command="$(ps -p "$demo_pid" -o command= || true)"
    if [[ "$demo_command" == "$APP/Contents/MacOS/Physics2DDemo" || "$demo_command" == "$APP/Contents/MacOS/Physics2DDemo "* ]]; then
        kill "$demo_pid"
    fi
done
mkdir -p "$DEMO_ROOT/dist"
if ! swift build --package-path "$REPO_ROOT" --scratch-path "$BUILD_PATH" --disable-sandbox --product Physics2DDemo > "$DEMO_ROOT/dist/build.log" 2>&1; then
    tail -60 "$DEMO_ROOT/dist/build.log"
    exit 1
fi
BIN="$(swift build --package-path "$REPO_ROOT" --scratch-path "$BUILD_PATH" --disable-sandbox --show-bin-path)"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Physics2DDemo" "$APP/Contents/MacOS/"
for resource in "$BIN"/*.bundle; do
    [[ -d "$resource" ]] && cp -R "$resource" "$APP/"
done
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Physics2DDemo</string>
<key>CFBundleIdentifier</key><string>org.adaengine.demo.physics2d</string>
<key>CFBundleName</key><string>AdaEngine Box2D playground</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
: > "$DEMO_ROOT/dist/runtime.log"
rm -f "$DEMO_ROOT/dist/proof/verification.json"
if [[ "$MODE" == --debug ]]; then
    /usr/bin/lldb -- "$APP/Contents/MacOS/Physics2DDemo"
    exit
fi
OPEN_ARGS=(-n "$APP" --stdout "$DEMO_ROOT/dist/runtime.log" --stderr "$DEMO_ROOT/dist/runtime.log" --args)
if [[ "$MODE" == --verify ]]; then OPEN_ARGS+=(--verify --proof-directory "$DEMO_ROOT/dist/proof"); fi
/usr/bin/open "${OPEN_ARGS[@]}"
case "$MODE" in
    --verify)
        for attempt in {1..60}; do
            if rg -q 'Physics2DDemo verification PASS' "$DEMO_ROOT/dist/runtime.log"; then
                cat "$DEMO_ROOT/dist/runtime.log"
                exit 0
            fi
            if rg -q 'verification FAIL|Fatal error' "$DEMO_ROOT/dist/runtime.log"; then
                tail -40 "$DEMO_ROOT/dist/runtime.log"
                exit 1
            fi
            sleep 1
        done
        tail -40 "$DEMO_ROOT/dist/runtime.log"
        echo 'Physics2DDemo verification timed out' >&2
        exit 1
        ;;
    --logs|--telemetry) /usr/bin/log stream --info --style compact --predicate 'process == "Physics2DDemo"' ;;
esac
