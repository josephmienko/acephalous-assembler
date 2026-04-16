#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/config.env"

xorriso \
  -indev "$ISO" \
  -outdev "$OUT" \
  -update "$ROOT/boot/grub/grub.cfg" /boot/grub/grub.cfg \
  -update "$ROOT/autoinstall.yaml" /autoinstall.yaml \
  -update "$ROOT/md5sum.txt" /md5sum.txt \
  -boot_image any replay \
  -commit

echo
echo "Built: $OUT"
echo "Flash that ISO to USB."
echo "Installer status target: http://${STATUS_IP}:${STATUS_PORT}/install-status"
echo "First boot callback target: http://${STATUS_IP}:${STATUS_PORT}/first-boot/<instance-id>/"
