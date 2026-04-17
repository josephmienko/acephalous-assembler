#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config.env"
# shellcheck source=/dev/null
source "$CONFIG_FILE"

INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS="${INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS:-false}"

XORRISO_ARGS=(
  -indev "$ISO"
  -outdev "$OUT"
  -update "$ROOT/boot/grub/grub.cfg" /boot/grub/grub.cfg
  -update "$ROOT/autoinstall.yaml" /autoinstall.yaml
  -update "$ROOT/md5sum.txt" /md5sum.txt
)

if [[ "$INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS" == "true" ]]; then
  XORRISO_ARGS+=(
    -update "$ROOT/nocloud/user-data" /nocloud/user-data
    -update "$ROOT/nocloud/meta-data" /nocloud/meta-data
  )
fi

XORRISO_ARGS+=(
  -boot_image any replay
  -commit
)

xorriso "${XORRISO_ARGS[@]}"

echo
echo "Built: $OUT"
echo "Flash that ISO to USB."
echo "Installer status target: http://${STATUS_IP}:${STATUS_PORT}/install-status"
echo "First boot callback target: http://${STATUS_IP}:${STATUS_PORT}/first-boot/<instance-id>/"
if [[ "$INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS" == "true" ]]; then
  echo "Included NoCloud live-installer credentials for user: ${LIVE_INSTALLER_USER}"
fi
