#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "config.env not found. Run ./setup.sh first." >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$CONFIG_FILE"
set +a

BUILD_VARIANT="${BUILD_VARIANT:-ubuntu}"

case "$BUILD_VARIANT" in
  ubuntu)
    exec "$SCRIPT_DIR/ubuntu/build_and_flash.sh"
    ;;
  debian)
    exec "$SCRIPT_DIR/debian/build_and_flash.sh"
    ;;
  *)
    echo "Error: Unknown BUILD_VARIANT '$BUILD_VARIANT' in config.env" >&2
    exit 1
    ;;
esac
  echo "Run ./setup.sh first, or update config.env manually." >&2
  exit 1
fi

"$SCRIPT_DIR/lib/_03-prepare-workdir.sh"

python3 "$SCRIPT_DIR/lib/_04-render-template.py" \
  --config "$CONFIG_FILE" \
  --template "$SCRIPT_DIR/templates/autoinstall.template.yaml" \
  --output "$ROOT/autoinstall.yaml"

if [[ "$INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS" == "true" ]]; then
  mkdir -p "$ROOT/nocloud"

  python3 "$SCRIPT_DIR/lib/_04-render-template.py" \
    --config "$CONFIG_FILE" \
    --template "$SCRIPT_DIR/templates/nocloud-user-data.template.yaml" \
    --output "$ROOT/nocloud/user-data"

  python3 "$SCRIPT_DIR/lib/_04-render-template.py" \
    --config "$CONFIG_FILE" \
    --template "$SCRIPT_DIR/templates/nocloud-meta-data.template" \
    --output "$ROOT/nocloud/meta-data"
else
  rm -rf "$ROOT/nocloud"
fi

python3 "$SCRIPT_DIR/lib/_05-patch-grub.py" \
  --root "$ROOT" \
  --include-nocloud "$INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS"
python3 "$SCRIPT_DIR/lib/_06-rebuild-md5.py" --root "$ROOT"

"$SCRIPT_DIR/lib/_07-build-iso.sh"
"$SCRIPT_DIR/lib/_08-flash-image.sh"
