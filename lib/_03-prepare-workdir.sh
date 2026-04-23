#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/config.env"
# shellcheck source=/dev/null
source "$ROOT_DIR/lib/validate-paths.sh"

# Validate WORK directory for safety
if ! validate_work_path "$WORK"; then
  exit 1
fi

# Validate and ensure ROOT is inside WORK
if ! validate_root_path "$ROOT" "$WORK"; then
  exit 1
fi

# Clean up previous build artifacts
if [[ -d "$WORK" ]]; then
  echo "Cleaning previous work directory: $WORK"
  rm -rf "$WORK"
fi

mkdir -p "$ROOT"
rm -f "$OUT"

bsdtar -C "$ROOT" -xf "$ISO"
chmod -R u+w "$ROOT"

echo "Prepared work tree at: $ROOT"
