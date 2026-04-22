#!/usr/bin/env bash
# Prepare Home Assistant OS disk image
# Decompresses, mounts partitions, and prepares for config injection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=/dev/null
source "$ROOT_DIR/config.env"

# Decompress image if needed
if [[ "$HA_IMAGE" == *.gz ]]; then
  echo "Decompressing: $HA_IMAGE"
  gunzip -fk "$HA_IMAGE"
  HA_IMAGE="${HA_IMAGE%.gz}"
fi

# Create work directory
rm -rf "$WORK"
mkdir -p "$WORK"

# Copy uncompressed image to work directory
cp "$HA_IMAGE" "$ROOT.img"
echo "Prepared disk image at: $ROOT.img"

# Get image size info
IMAGE_SIZE=$(stat -f%z "$ROOT.img" 2>/dev/null || stat -c%s "$ROOT.img" 2>/dev/null)
echo "Image size: $IMAGE_SIZE bytes"

# On macOS, use hdiutil to mount; on Linux, use losetup
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS: Use hdiutil
  echo "Mounting image on macOS..."
  MOUNT_POINT=$(mktemp -d)
  hdiutil attach "$ROOT.img" -mountpoint "$MOUNT_POINT" -nobrowse 2>/dev/null || true
  
  # Store mount point for unmounting later
  echo "$MOUNT_POINT" > "$WORK/.mount_point"
  
  # Set ROOT to the mounted filesystem
  ROOT="$MOUNT_POINT"
else
  # Linux: Use losetup for loop device
  echo "Mounting image on Linux..."
  LOOP_DEVICE=$(sudo losetup -f)
  sudo losetup "$LOOP_DEVICE" "$ROOT.img"
  
  # Get partition information
  # HA OS typically has: boot (FAT32) and rootfs (ext4)
  # Mount rootfs to $ROOT
  mkdir -p "$ROOT"
  PART1=$(sudo fdisk -l "$LOOP_DEVICE" | grep -oE "${LOOP_DEVICE}p?[0-9]" | head -1)
  sudo mount "$PART1" "$ROOT"
  
  # Store for cleanup
  echo "$LOOP_DEVICE" > "$WORK/.loop_device"
fi

chmod -R u+w "$ROOT" 2>/dev/null || sudo chmod -R u+w "$ROOT"

echo "Prepared work tree at: $ROOT"
