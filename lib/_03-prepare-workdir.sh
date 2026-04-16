#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/config.env"

rm -rf "$WORK"
mkdir -p "$ROOT"
rm -f "$OUT"

bsdtar -C "$ROOT" -xf "$ISO"
chmod -R u+w "$ROOT"

echo "Prepared work tree at: $ROOT"
