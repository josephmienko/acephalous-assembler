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

"$ROOT_DIR/lib/_03-prepare-workdir.sh"

# Render preseed configuration
python3 "$ROOT_DIR/lib/_04-render-template.py" \
  --config "$CONFIG_FILE" \
  --template "$SCRIPT_DIR/templates/preseed.template" \
  --output "$ROOT/preseed.cfg"

# For now, we don't patch GRUB - Debian uses kernel boot parameters
# The preseed URL would need to be passed as a kernel argument
# TODO: implement lib/_05-patch-grub-debian.py for preseed/url= argument

python3 "$ROOT_DIR/lib/_06-rebuild-md5.py" --root "$ROOT"

"$ROOT_DIR/lib/_07-build-iso.sh"
"$ROOT_DIR/lib/_08-flash-image.sh"

echo ""
echo "Debian preseed ISO built: $OUT"
echo ""
echo "Preseed configuration: $ROOT/preseed.cfg"
echo "To customize preseed, edit the template and rebuild:"
echo "  $SCRIPT_DIR/templates/preseed.template"
