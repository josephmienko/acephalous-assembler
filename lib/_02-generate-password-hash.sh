#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config.env"
VARIANT="${1:-ubuntu}"

# Determine hashing algorithm based on variant
# Ubuntu/HA OS: use modern Argon2
# Debian preseed: can use Argon2 too (supported in Debian 12+) or SHA512 for older
ALGORITHM="argon2"
if [[ "$VARIANT" == "debian" ]]; then
  # Debian preseed supports both; default to Argon2 unless old version
  ALGORITHM="argon2"
fi

touch "$CONFIG_FILE"

if ! grep -q '^PASSWORD_HASH=' "$CONFIG_FILE"; then
  echo "Generating password hash using $ALGORITHM..." >&2
  python3 "$SCRIPT_DIR/python/assembler/cli.py" \
    set-config "$CONFIG_FILE" \
    --key PASSWORD_HASH \
    --algorithm "$ALGORITHM" \
    --verbose
  echo "Generated new PASSWORD_HASH and saved to config.env"
else
  echo "PASSWORD_HASH already exists. Using persisted value."
fi