#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config.env"
# shellcheck source=/dev/null
source "$CONFIG_FILE"

INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS="${INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS:-false}"
BUILD_VARIANT="${BUILD_VARIANT:-ubuntu}"

if [[ -e "$OUT" ]]; then
  echo "Removing previous output ISO: $OUT"
  rm -f "$OUT"
fi

XORRISO_ARGS=(
  -indev "$ISO"
  -outdev "$OUT"
  -update "$ROOT/boot/grub/grub.cfg" /boot/grub/grub.cfg
)

case "$BUILD_VARIANT" in
  ubuntu)
    XORRISO_ARGS+=(
      -update "$ROOT/autoinstall.yaml" /autoinstall.yaml
    )
    if [[ "$INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS" == "true" ]]; then
      XORRISO_ARGS+=(
        -update "$ROOT/nocloud/user-data" /nocloud/user-data
        -update "$ROOT/nocloud/meta-data" /nocloud/meta-data
      )
    fi
    ;;
  debian)
    XORRISO_ARGS+=(
      -update "$ROOT/preseed.cfg" /preseed.cfg
    )
    for cfg in "$ROOT"/isolinux/*.cfg; do
      [[ -f "$cfg" ]] || continue
      XORRISO_ARGS+=(
        -update "$cfg" "/isolinux/$(basename "$cfg")"
      )
    done
    ;;
  *)
    echo "Error: _07-build-iso.sh does not support BUILD_VARIANT=$BUILD_VARIANT" >&2
    exit 1
    ;;
esac

XORRISO_ARGS+=(
  -update "$ROOT/md5sum.txt" /md5sum.txt
)

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
