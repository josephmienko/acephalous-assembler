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
Usage: ./setup.sh debian [OPTIONS]

Debian-specific setup for automated preseed installation.

Options:
  --skip-download    Use existing ISO in config.env and do not download
  --download-only    Download/update Debian ISO path and exit

EOF
}

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
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$CONFIG_FILE" ]]; then
  if [[ -f "$EXAMPLE_FILE" ]]; then
    cp "$EXAMPLE_FILE" "$CONFIG_FILE"
    echo "Created $CONFIG_FILE from $EXAMPLE_FILE"
  else
    echo "config.env not found. Create one manually or from example." >&2
    exit 1
  fi
fi

# Add Debian-specific variables if missing
add_config_var "$CONFIG_FILE" "BUILD_VARIANT" "debian"
add_config_var "$CONFIG_FILE" "DEBIAN_SUITE" "bookworm"
add_config_var "$CONFIG_FILE" "LIVE_INSTALLER_HOSTNAME" "debian-installer"
add_config_var "$CONFIG_FILE" "LIVE_INSTALLER_USER" "root"

echo "Installing dependencies ..."
"$ROOT_DIR/lib/_01-install-deps.sh"

if [[ "$SKIP_DOWNLOAD" == "false" ]]; then
  "$ROOT_DIR/lib/_09-download-debian-iso.sh"
fi

if [[ "$DOWNLOAD_ONLY" == "true" ]]; then
  echo "Download-only mode: exiting after Debian ISO update"
  exit 0
fi

echo "Generating a password hash and updating config.env ..."
"$ROOT_DIR/lib/_02-generate-password-hash.sh"

echo "Setup complete. Review config.env before building."
echo ""
echo "For Debian-specific configuration options, see:"
echo "  $SCRIPT_DIR/README-DEBIAN.md"
