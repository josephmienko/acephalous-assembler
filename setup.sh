#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"
EXAMPLE_FILE="$SCRIPT_DIR/config.env.example"

if [[ ! -f "$CONFIG_FILE" ]]; then
  cp "$EXAMPLE_FILE" "$CONFIG_FILE"
  echo "Created $CONFIG_FILE from config.env.example"
fi

"$SCRIPT_DIR/lib/_01-install-deps.sh"
"$SCRIPT_DIR/lib/_02-generate-password-hash.sh"

echo "Setup complete. Review config.env before building."