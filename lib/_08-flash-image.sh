#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/config.env"

if [[ -z "${OUT:-}" ]]; then
  echo "OUT is not set in config.env" >&2
  exit 1
fi

if [[ -z "${FLASH_DRIVE:-}" ]]; then
  echo "FLASH_DRIVE is not set in config.env" >&2
  exit 1
fi

if [[ ! -f "$OUT" ]]; then
  echo "Built ISO not found: $OUT" >&2
  exit 1
fi

if [[ "$FLASH_DRIVE" != /dev/* ]]; then
  echo "FLASH_DRIVE must look like /dev/diskN" >&2
  exit 1
fi

echo "About to flash:"
echo "  image: $OUT"
echo "  drive: $FLASH_DRIVE"

echo "Running: balena local flash \"$OUT\" --drive \"$FLASH_DRIVE\" --yes"
balena local flash "$OUT" --drive "$FLASH_DRIVE" --yes

echo "Flash completed successfully. Ejecting $FLASH_DRIVE for safe removal..."
if diskutil eject "$FLASH_DRIVE"; then
  echo "Drive ejected successfully."
else
  echo "Flash succeeded, but automatic eject failed. You may need to eject it manually in Finder or with diskutil." >&2
fi
