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

if [[ -z "${PASSWORD_HASH:-}" || "${PASSWORD_HASH}" == *REPLACE_WITH_REAL_HASH* ]]; then
  echo "PASSWORD_HASH is missing or still set to the placeholder in config.env." >&2
  echo "Run ./setup.sh first, or update config.env manually." >&2
  exit 1
fi

"$SCRIPT_DIR/lib/_03-prepare-workdir.sh"

python3 "$SCRIPT_DIR/lib/_04-render-autoinstall.py" \
  --config "$CONFIG_FILE" \
  --template "$SCRIPT_DIR/templates/autoinstall.template.yaml" \
  --output "$ROOT/autoinstall.yaml"

python3 "$SCRIPT_DIR/lib/_05-patch-grub.py" --root "$ROOT"
python3 "$SCRIPT_DIR/lib/_06-rebuild-md5.py" --root "$ROOT"

"$SCRIPT_DIR/lib/_07-build-iso.sh"
"$SCRIPT_DIR/lib/_08-flash-image.sh"