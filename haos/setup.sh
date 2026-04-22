#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config.env"
EXAMPLE_FILE="$SCRIPT_DIR/config.env.example"

# Source shared functions
# shellcheck source=/dev/null
source "$ROOT_DIR/lib/_00-common-functions.sh"

usage() {
  cat <<'EOF'
Usage: ./setup.sh haos [OPTIONS]

Home Assistant OS setup for Raspberry Pi 5 headless deployment.

Options:
  --skip-download    Use existing HA_IMAGE in config.env (don't re-download)
  --download-only    Download image and exit (don't configure)

Examples:
  ./setup.sh haos
  ./setup.sh haos --skip-download
  ./setup.sh haos --download-only

EOF
}

# Create config.env from example if missing
if [[ ! -f "$CONFIG_FILE" ]]; then
  if [[ -f "$EXAMPLE_FILE" ]]; then
    cp "$EXAMPLE_FILE" "$CONFIG_FILE"
    echo "Created $CONFIG_FILE from $EXAMPLE_FILE"
    echo "Please edit $CONFIG_FILE with your Home Assistant settings"
  else
    echo "config.env not found. Create one manually or from example." >&2
    exit 1
  fi
fi

# Parse options
SKIP_DOWNLOAD="false"
DOWNLOAD_ONLY="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-download)
      SKIP_DOWNLOAD="true"
      shift
      ;;
    --download-only)
      DOWNLOAD_ONLY="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

# Download HA OS image if needed
if [[ "$SKIP_DOWNLOAD" == "false" ]]; then
  echo "Downloading Home Assistant OS for Raspberry Pi 5..."
  "$ROOT_DIR/lib/_09-download-haos-image.sh"
fi

if [[ "$DOWNLOAD_ONLY" == "true" ]]; then
  echo "Download-only mode: exiting after image download"
  exit 0
fi

# Validate config and password hash
if ! validate_config_and_hash "$CONFIG_FILE"; then
  exit 1
fi

# Load config
load_config "$CONFIG_FILE"

echo ""
echo "Home Assistant OS configuration:"
echo "  Hostname: $HOSTNAME"
echo "  Static IP: ${HA_STATIC_IP:-DHCP}"
echo "  Location: $HA_LOCATION_NAME"
echo "  Timezone: $HA_TIMEZONE"
echo ""
echo "Ready to build. Run: ./build_and_flash.sh"
