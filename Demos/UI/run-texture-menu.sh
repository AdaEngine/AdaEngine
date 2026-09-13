#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${ADA_TEXTURE_MENU_BUILD:-/tmp/adaengine-kenney-build}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/tmp/adaengine-kenney-modules}"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
swift build --disable-sandbox --package-path "$ROOT" --scratch-path "$BUILD" --product TextureMenuExample
BIN="$(swift build --disable-sandbox --package-path "$ROOT" --scratch-path "$BUILD" --show-bin-path)"
APP="$BUILD/TextureMenuExample.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/TextureMenuExample" "$APP/Contents/MacOS/TextureMenuExample"
# SwiftPM resource accessors look inside the main bundle on macOS.
for bundle in "$BIN"/AdaEngine_Ada*.bundle "$BIN"/AdaEngine_TextureMenuExample.bundle; do
    [ -d "$bundle" ] || continue
    cp -R "$bundle" "$APP/"
done
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TextureMenuExample</string>
<key>CFBundleIdentifier</key><string>org.adaengine.TextureMenuExample</string>
<key>CFBundleName</key><string>Texture Menu</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
/usr/bin/pkill -x TextureMenuExample 2>/dev/null || true
/usr/bin/open -n "$APP"
