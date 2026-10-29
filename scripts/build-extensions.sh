#!/usr/bin/env bash
# Assembles the two loadable extension folders from Extension/shared and the app icon.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHARED="$ROOT/Extension/shared"
ICON="$ROOT/assets/AppIcon.icns"

for browser in chrome firefox; do
  target="$ROOT/Extension/$browser"
  mkdir -p "$target/icons"
  cp "$SHARED/background.js" "$SHARED/content.js" "$SHARED/popup.html" "$SHARED/popup.css" "$SHARED/popup.js" "$target/"
done

if [ -f "$ICON" ]; then
  for size in 16 32 48 128; do
    for browser in chrome firefox; do
      out="$ROOT/Extension/$browser/icons/$size.png"
      sips -s format png -z "$size" "$size" "$ICON" --out "$out" >/dev/null
    done
  done
fi

# Package zip archives for web download
PUB_EXT="$ROOT/server/public/extensions"
mkdir -p "$PUB_EXT"
(cd "$ROOT/Extension/chrome" && zip -q -r "$PUB_EXT/editorlynx-chrome-extension.zip" .)
(cd "$ROOT/Extension/firefox" && zip -q -r "$PUB_EXT/editorlynx-firefox-zen-extension.zip" .)

echo "Chrome:   $ROOT/Extension/chrome"
echo "Firefox:  $ROOT/Extension/firefox"
echo "Web Zips: $PUB_EXT"
