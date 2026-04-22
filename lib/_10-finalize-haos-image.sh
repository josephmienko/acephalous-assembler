#!/usr/bin/env bash
# Finalize Home Assistant OS disk image
# Unmounts partitions and prepares final .img for flashing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=/dev/null
source "$ROOT_DIR/config.env"

# Determine if we need to unmount
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS: Unmount using hdiutil
  if [[ -f "$WORK/.mount_point" ]]; then
    MOUNT_POINT=$(cat "$WORK/.mount_point")
    if [[ -d "$MOUNT_POINT" ]]; then
      echo "Unmounting: $MOUNT_POINT"
      hdiutil detach "$MOUNT_POINT" 2>/dev/null || true
      rm -rf "$MOUNT_POINT"
    fi
  fi
else
  # Linux: Unmount and remove loop device
  if [[ -f "$WORK/.loop_device" ]]; then
    LOOP_DEVICE=$(cat "$WORK/.loop_device")
    if [[ -b "$LOOP_DEVICE" ]]; then
      echo "Unmounting and releasing loop device: $LOOP_DEVICE"
      sudo umount "$ROOT" 2>/dev/null || true
      sudo losetup -d "$LOOP_DEVICE"
    fi
  fi
fi

# Prepare final output image
if [[ ! -f "$OUT" ]]; then
  echo "Copying to output: $OUT"
  cp "$ROOT.img" "$OUT"
fi

# Compress if desired (optional)
# gzip -9 "$OUT" -c > "${OUT}.gz"

echo "Final image: $OUT"
echo "Ready for flashing to micro-SD"
