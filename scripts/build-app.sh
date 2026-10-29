#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"

CONFIG="release"
APP="$ROOT/dist/Edit.or.lynx.app"

echo "▸ Building Edit.or.lynx ($CONFIG)…"
swift build -c "$CONFIG"

echo "▸ Assembling app bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/LoginItems"

cp "$ROOT/.build/$CONFIG/Pounce" "$APP/Contents/MacOS/Edit.or.lynx"
cp "$ROOT/assets/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Copy download engines, media extractors, companion notch, and sounds from Lynx suite
SOURCE_APP="/Applications/Lynx Download Manager.app"
if [ -d "$SOURCE_APP" ]; then
    echo "▸ Bundling acceleration engines and companion notch..."
    cp "$SOURCE_APP/Contents/MacOS/ffmpeg" "$APP/Contents/MacOS/" 2>/dev/null || true
    cp "$SOURCE_APP/Contents/MacOS/ffprobe" "$APP/Contents/MacOS/" 2>/dev/null || true
    cp "$SOURCE_APP/Contents/MacOS/aria2" "$APP/Contents/MacOS/" 2>/dev/null || true
    if [ -d "$SOURCE_APP/Contents/Resources/yt-dlp" ]; then
        cp -R "$SOURCE_APP/Contents/Resources/yt-dlp" "$APP/Contents/Resources/"
    fi
    if [ -d "$SOURCE_APP/Contents/Resources/sounds" ]; then
        cp -R "$SOURCE_APP/Contents/Resources/sounds" "$APP/Contents/Resources/"
    fi
    if [ -d "$SOURCE_APP/Contents/Resources/mediaremote" ]; then
        cp -R "$SOURCE_APP/Contents/Resources/mediaremote" "$APP/Contents/Resources/"
    fi
    if [ -d "$SOURCE_APP/Contents/Library/LoginItems/LynxNotch.app" ]; then
        cp -R "$SOURCE_APP/Contents/Library/LoginItems/LynxNotch.app" "$APP/Contents/Library/LoginItems/"
    fi
fi

shopt -s nullglob
for bundle in "$ROOT/.build/$CONFIG"/*.bundle; do
    cp -R "$bundle" "$APP/Contents/Resources/"
done
shopt -u nullglob

# The loadable browser extensions travel with the app, so Settings can reveal them.
"$ROOT/scripts/build-extensions.sh" >/dev/null
cp -R "$ROOT/Extension" "$APP/Contents/Resources/Extension"

echo "▸ Signing (ad-hoc)…"
xattr -cr "$APP" 2>/dev/null || true
codesign --force --sign - "$APP/Contents/MacOS/Edit.or.lynx" 2>/dev/null || true
codesign --force --sign - "$APP" 2>/dev/null || true

echo "▸ Installing to /Applications/Edit.or.lynx.app…"
rm -rf "/Applications/Edit.or.lynx.app"
cp -R "$APP" "/Applications/Edit.or.lynx.app"
xattr -cr "/Applications/Edit.or.lynx.app" 2>/dev/null || true
codesign --force --sign - "/Applications/Edit.or.lynx.app/Contents/MacOS/Edit.or.lynx" 2>/dev/null || true
codesign --force --sign - "/Applications/Edit.or.lynx.app" 2>/dev/null || true

echo "▸ Creating DMG package…"
DMG="$ROOT/dist/Edit.or.lynx.dmg"
rm -f "$DMG"
hdiutil create -volname "Edit.or.lynx" -srcfolder "$APP" -ov -format UDZO "$DMG" >/dev/null 2>&1 || true

echo "▸ Done: /Applications/Edit.or.lynx.app"
echo "  DMG: $DMG"
echo "  Launch with: open \"/Applications/Edit.or.lynx.app\""
