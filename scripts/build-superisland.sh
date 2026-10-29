#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "==> Invoking unified build-app.sh for Edit.or.lynx..."
exec "$ROOT/scripts/build-app.sh"
