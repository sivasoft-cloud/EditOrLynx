#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="release"
APP_NAME="Edit.or.lynx"
APP_ID="com.editor.lynx"
RELEASE_APP="$ROOT/dist/${APP_NAME}.app"
SYSTEM_APP="/Applications/${APP_NAME}.app"
DMG_PATH="$ROOT/dist/${APP_NAME}.dmg"

if [ -z "${SDKROOT:-}" ] && [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]; then
    export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
fi

echo "==> Building unified ${APP_NAME} (${CONFIG}) containing Download Manager + SuperIsland notch engine..."
cd "$ROOT"
swift build -c "$CONFIG"

echo "==> Assembling ${APP_NAME}.app bundle ($RELEASE_APP)..."
rm -rf "$RELEASE_APP"
mkdir -p "$RELEASE_APP/Contents/MacOS" "$RELEASE_APP/Contents/Resources"

# 1. Binary (Unified Download Manager + SuperIsland engine)
cp "$ROOT/.build/$CONFIG/EditOrLynx" "$RELEASE_APP/Contents/MacOS/${APP_NAME}"
chmod +x "$RELEASE_APP/Contents/MacOS/${APP_NAME}"

# 2. Plist configuration
cp "$ROOT/SuperIsland/SuperIsland/Info.plist" "$RELEASE_APP/Contents/Info.plist"
plutil -replace CFBundleName -string "${APP_NAME}" "$RELEASE_APP/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string "${APP_NAME}" "$RELEASE_APP/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "${APP_ID}" "$RELEASE_APP/Contents/Info.plist"
plutil -replace CFBundleExecutable -string "${APP_NAME}" "$RELEASE_APP/Contents/Info.plist"
plutil -replace CFBundleIconFile -string "AppIcon" "$RELEASE_APP/Contents/Info.plist"

# 3. App Icon
if [ -f "$ROOT/assets/AppIcon.icns" ]; then
    cp "$ROOT/assets/AppIcon.icns" "$RELEASE_APP/Contents/Resources/AppIcon.icns"
elif [ -f "$ROOT/SuperIsland/icon.icns" ]; then
    cp "$ROOT/SuperIsland/icon.icns" "$RELEASE_APP/Contents/Resources/AppIcon.icns"
fi

# 4. Resource bundles & Desktop runtime
shopt -s nullglob
for bundle in "$ROOT/.build/$CONFIG"/*.bundle; do
    cp -R "$bundle" "$RELEASE_APP/Contents/Resources/"
done
shopt -u nullglob
if [ -d "$ROOT/Sources/Pounce/Resources/desktop" ]; then
    cp -R "$ROOT/Sources/Pounce/Resources/desktop" "$RELEASE_APP/Contents/Resources/desktop"
fi

# 5. Bundled island extensions
DEST_EXT="$RELEASE_APP/Contents/Resources/BundledExtensions"
mkdir -p "$DEST_EXT"
for ext in whatsapp-web linear-mentions lastfm-scrobbler; do
    SRC="$ROOT/SuperIsland/Extensions/${ext}"
    if [ -d "$SRC" ]; then
        rsync -a --delete --exclude="node_modules/" --exclude=".DS_Store" "${SRC}/" "${DEST_EXT}/${ext}/"
    fi
done

# 6. Node binary for background extension runtime
if [ -f "/opt/homebrew/bin/node" ]; then
    cp "/opt/homebrew/bin/node" "$RELEASE_APP/Contents/Resources/node"
elif which node >/dev/null 2>&1; then
    cp "$(which node)" "$RELEASE_APP/Contents/Resources/node"
fi
chmod +x "$RELEASE_APP/Contents/Resources/node" 2>/dev/null || true

# 6.5 Torrent binary (aria2c) for BitTorrent engine
mkdir -p "$RELEASE_APP/Contents/Resources/bin"
if [ -f "/opt/homebrew/bin/aria2c" ]; then
    cp "/opt/homebrew/bin/aria2c" "$RELEASE_APP/Contents/Resources/bin/aria2c"
    chmod +x "$RELEASE_APP/Contents/Resources/bin/aria2c"
elif which aria2c >/dev/null 2>&1; then
    cp "$(which aria2c)" "$RELEASE_APP/Contents/Resources/bin/aria2c"
    chmod +x "$RELEASE_APP/Contents/Resources/bin/aria2c"
fi

# 7. Browser extensions (Chrome / Firefox companion for download manager)
if [ -d "$ROOT/Extension" ]; then
    cp -R "$ROOT/Extension" "$RELEASE_APP/Contents/Resources/Extension"
fi

# 8. Helper scripts
mkdir -p "$RELEASE_APP/Contents/Resources/scripts"
for script in connect-extension.sh release-stable.sh build-dmg.sh; do
    if [ -f "$ROOT/scripts/${script}" ]; then
        cp "$ROOT/scripts/${script}" "$RELEASE_APP/Contents/Resources/scripts/"
        chmod +x "$RELEASE_APP/Contents/Resources/scripts/${script}"
    fi
done

echo "==> Signing ${APP_NAME}.app (ad-hoc)..."
codesign --force --deep --sign - "$RELEASE_APP" >/dev/null 2>&1 || true

echo "==> Installing system app: ${SYSTEM_APP}..."
rm -rf "$SYSTEM_APP"
cp -R "$RELEASE_APP" "$SYSTEM_APP"
codesign --force --deep --sign - "$SYSTEM_APP" >/dev/null 2>&1 || true

echo "==> Packaging ${APP_NAME}.dmg..."
STAGING="/tmp/editorlynx-dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$RELEASE_APP" "$STAGING/${APP_NAME}.app"
xattr -cr "$STAGING/${APP_NAME}.app" 2>/dev/null || true
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG_PATH"
mkdir -p "$ROOT/dist"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG_PATH" >/dev/null

rm -rf "$STAGING"

# Copy DMG to public distribution endpoints
mkdir -p "$ROOT/server/public" "$ROOT/server/public/releases"
cp "$DMG_PATH" "$ROOT/server/public/${APP_NAME}.dmg"
cp "$DMG_PATH" "$ROOT/server/public/releases/${APP_NAME}.dmg"

echo "==> Successfully built and packaged ${APP_NAME}!"
echo "    App Bundle: $RELEASE_APP"
echo "    System App: $SYSTEM_APP"
echo "    DMG Dist:   $DMG_PATH"
echo "    Web DMG:    $ROOT/server/public/${APP_NAME}.dmg"
