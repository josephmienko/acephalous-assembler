#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config.env"

# Source shared functions
# shellcheck source=/dev/null
source "$ROOT_DIR/lib/_00-common-functions.sh"

# Validate config and password hash
if ! validate_config_and_hash "$CONFIG_FILE"; then
  exit 1
fi

# Load config into environment
load_config "$CONFIG_FILE"

INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS="${INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS:-false}"

"$ROOT_DIR/lib/_03-prepare-workdir.sh"

python3 "$ROOT_DIR/lib/_04-render-template.py" \
  --config "$CONFIG_FILE" \
  --template "$SCRIPT_DIR/templates/autoinstall.template.yaml" \
  --output "$ROOT/autoinstall.yaml"

if [[ "$INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS" == "true" ]]; then
  mkdir -p "$ROOT/nocloud"

  python3 "$ROOT_DIR/lib/_04-render-template.py" \
    --config "$CONFIG_FILE" \
    --template "$SCRIPT_DIR/templates/nocloud-user-data.template.yaml" \
    --output "$ROOT/nocloud/user-data"

  python3 "$ROOT_DIR/lib/_04-render-template.py" \
    --config "$CONFIG_FILE" \
    --template "$SCRIPT_DIR/templates/nocloud-meta-data.template" \
    --output "$ROOT/nocloud/meta-data"
else
  rm -rf "$ROOT/nocloud"
fi

python3 "$ROOT_DIR/lib/_05-patch-grub.py" \
  --root "$ROOT" \
  --include-nocloud "$INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS"
python3 "$ROOT_DIR/lib/_06-rebuild-md5.py" --root "$ROOT"

"$ROOT_DIR/lib/_07-build-iso.sh"
"$ROOT_DIR/lib/_08-flash-image.sh"

# Generate handoff artifact for downstream appliance provisioning
echo ""
echo "Generating handoff artifact..."
python3 "$ROOT_DIR/lib/_99-generate-handoff.py" \
  --config "$CONFIG_FILE" \
  --output-dir "$ROOT_DIR/.coordination"

echo ""
echo "✓ Ubuntu autoinstall ISO build and flash complete."
echo ""
echo "Handoff documentation: .coordination/handoff-${HOSTNAME}-*.json"
echo "Next: Use crooked-sentry-appliance to configure and deploy appliance services."
