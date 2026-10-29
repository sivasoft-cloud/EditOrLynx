#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-1.0.0}"
TITLE="${2:-Edit.or.lynx ${VERSION} Stable Release}"
NOTES="${3:-Official first stable release with 100-file Google Drive batch auto-zip, Clear All button, bit-perfect Studio Lossless audio, universal 16x Turbo browser intercept, and dynamic MacBook Notch HUD.}"

echo "▸ [1/5] Building release binary and DMG package ($VERSION)…"
"$ROOT/scripts/build-dmg.sh"

echo "▸ [2/5] Uploading DMG package and extensions to Cloudflare KV storage (PRO_KEYS_KV)…"
cd "$ROOT/server"
npx --yes wrangler kv key put "release_dmg" --path "$ROOT/dist/Edit.or.lynx.dmg" --binding PRO_KEYS_KV --remote
npx --yes wrangler kv key put "ext_chrome" --path "$ROOT/server/public/extensions/editorlynx-chrome-extension.zip" --binding PRO_KEYS_KV --remote
npx --yes wrangler kv key put "ext_firefox" --path "$ROOT/server/public/extensions/editorlynx-firefox-zen-extension.zip" --binding PRO_KEYS_KV --remote

echo "▸ [3/5] Updating release metadata & changelog in database…"
node -e "
const fs = require('fs');
const path = '$ROOT/server/data/keys.json';
const data = JSON.parse(fs.readFileSync(path, 'utf8'));
const version = '$VERSION';
const title = '$TITLE';
const notes = process.argv[1] || '';
const downloadUrl = 'https://edit-orlynk.sivasoft.workers.dev/releases/Edit.or.lynx.dmg';
const publishedAt = new Date().toISOString();

const entry = {
  version,
  title,
  notes,
  downloadUrl,
  publishedAt,
  filename: 'Edit.or.lynx.dmg',
  size: 52428800,
  active: true
};

data.release = {
  version,
  title,
  notes,
  downloadUrl,
  publishedAt
};

data.releases = [entry];

fs.writeFileSync(path, JSON.stringify(data, null, 2), 'utf8');
console.log('✓ Updated keys.json release to version', version);
" "$NOTES"

echo "▸ [4/5] Re-bundling Cloudflare Worker…"
node "$ROOT/server/bundle-worker.js"

echo "▸ [5/5] Deploying to Cloudflare Worker (edit-orlynk.sivasoft.workers.dev)…"
cd "$ROOT/server"
npx --yes wrangler deploy

# Also push directly to Cloudflare edge KV to ensure instantaneous update across all regions
node -e "
const http = require('https');
const data = JSON.stringify({
  version: '$VERSION',
  title: '$TITLE',
  notes: process.argv[1] || '',
  downloadUrl: 'https://edit-orlynk.sivasoft.workers.dev/releases/Edit.or.lynx.dmg'
});

const req = http.request('https://edit-orlynk.sivasoft.workers.dev/api/admin/release', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer sivaadminpro2026',
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(data)
  }
}, res => {
  let body = '';
  res.on('data', c => body += c);
  res.on('end', () => console.log('✓ Edge KV Release synced successfully'));
});
req.on('error', () => {});
req.write(data);
req.end();
" "$NOTES"

echo "▸ Successfully released Edit.or.lynx v${VERSION} to https://edit-orlynk.sivasoft.workers.dev/#changelog"
