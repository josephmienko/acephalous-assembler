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

# Reject system disk (/dev/disk0) on macOS
if [[ "$FLASH_DRIVE" == "/dev/disk0" ]]; then
  echo "Error: /dev/disk0 is typically your system disk. Use a USB/external device." >&2
  echo "Override this check by explicitly setting FLASH_DRIVE_OVERRIDE=true if sure." >&2
  exit 1
fi

RAW_DRIVE="${FLASH_DRIVE/\/dev\/disk/\/dev\/rdisk}"

# Query disk information
DISK_INFO=$(diskutil info "$FLASH_DRIVE" 2>/dev/null || echo "")
DISK_SIZE=$(echo "$DISK_INFO" | grep "Disk Size:" | head -1)
DISK_IDENT=$(echo "$DISK_INFO" | grep "Device Identifier:" | head -1 || echo "Device Identifier: unknown")

echo ""
echo "⚠️  DESTRUCTIVE OPERATION — USB WILL BE ERASED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Image:  $OUT"
echo "Drive:  $FLASH_DRIVE ($RAW_DRIVE)"
if [[ -n "$DISK_SIZE" ]]; then
  echo "$DISK_SIZE" | sed 's/^/Size:   /'
fi
echo "$DISK_IDENT" | sed 's/^/ID:     /'
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "All data on $FLASH_DRIVE will be destroyed."
echo "Type 'flash USB' (exactly) to proceed, or press Ctrl+C to cancel:"
read -r -p "> " REPLY

if [[ "$REPLY" != "flash USB" ]]; then
  echo "Cancelled (did not match confirmation phrase)."
  exit 1
fi

diskutil unmountDisk "$FLASH_DRIVE"

sudo dd if="$OUT" of="$RAW_DRIVE" bs=4m
sync

diskutil eject "$FLASH_DRIVE"

echo "Flash complete and drive ejected."