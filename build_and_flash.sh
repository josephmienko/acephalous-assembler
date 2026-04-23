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
  haos)
    exec "$SCRIPT_DIR/haos/build_and_flash.sh"
    ;;
  *)
    echo "Error: Unknown BUILD_VARIANT '$BUILD_VARIANT' in config.env" >&2
    echo "Supported variants: ubuntu, debian, haos" >&2
    exit 1
    ;;
esac

