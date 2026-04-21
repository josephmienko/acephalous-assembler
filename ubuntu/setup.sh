#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config.env"
EXAMPLE_FILE="$SCRIPT_DIR/config.env.example"

# Source shared functions
# shellcheck source=/dev/null
source "$ROOT_DIR/lib/_00-common-functions.sh"

INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS="false"

usage() {
  cat <<'EOF'
Usage: ./setup.sh [--include-nocloud-installer-credentials[=true|false]]

Options:
  --include-nocloud-installer-credentials[=BOOL]
      When true, future builds include a NoCloud seed that sets known live
      installer SSH credentials for the temporary installer environment.
      When omitted or set to false, builds use the standard working autoinstall
      ISO without the extra NoCloud installer seed.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --include-nocloud-installer-credentials)
      if [[ $# -gt 1 && ! "$2" =~ ^-- ]]; then
        INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS="$2"
        shift 2
      else
        INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS="true"
        shift
      fi
      ;;
    --include-nocloud-installer-credentials=*)
      INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS="${1#*=}"
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

case "${INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS,,}" in
  true|false)
    INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS="${INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS,,}"
    ;;
  *)
    echo "--include-nocloud-installer-credentials must be true or false" >&2
    exit 1
    ;;
esac

if [[ ! -f "$CONFIG_FILE" ]]; then
  cp "$EXAMPLE_FILE" "$CONFIG_FILE"
  echo "Created $CONFIG_FILE from config.env.example"
fi

set_config_value "$CONFIG_FILE" \
  "INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS" \
  "$INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS"

set_config_value "$CONFIG_FILE" "BUILD_VARIANT" "ubuntu"

"$ROOT_DIR/lib/_01-install-deps.sh"
"$ROOT_DIR/lib/_02-generate-password-hash.sh"

echo "Setup complete. Review config.env before building."
echo "INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS=$INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS"
