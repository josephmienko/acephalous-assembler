#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "config.env not found." >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$CONFIG_FILE"
set +a

: "${OUT:?OUT is not set in config.env}"
: "${FLASH_DRIVE:?FLASH_DRIVE is not set in config.env}"

if [[ ! -f "$OUT" ]]; then
  echo "ISO not found: $OUT" >&2
  exit 1
fi

if [[ ! "$FLASH_DRIVE" =~ ^/dev/disk[0-9]+$ ]]; then
  echo "FLASH_DRIVE must be a whole-disk device like /dev/disk2" >&2
  exit 1
fi

RAW_DRIVE="${FLASH_DRIVE/\/dev\/disk/\/dev\/rdisk}"

echo "About to erase and flash:"
echo "  image: $OUT"
echo "  drive: $FLASH_DRIVE"
echo "  raw:   $RAW_DRIVE"
read -r -p "Continue? [y/N] " REPLY
[[ "$REPLY" =~ ^[Yy]$ ]] || exit 1

diskutil unmountDisk "$FLASH_DRIVE"

sudo dd if="$OUT" of="$RAW_DRIVE" bs=4m
sync

diskutil eject "$FLASH_DRIVE"

echo "Flash complete and drive ejected."