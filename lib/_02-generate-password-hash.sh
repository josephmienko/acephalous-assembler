#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config.env"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/_00-common-functions.sh"

touch "$CONFIG_FILE"

if ! grep -q '^PASSWORD_HASH=' "$CONFIG_FILE"; then
  echo "Generating password hash using SHA-512 crypt..." >&2

  password="$(openssl rand -base64 18)"
  salt="$(openssl rand -hex 8)"
  hash_value="$(printf '%s\n' "$password" |
    openssl passwd -6 -salt "$salt" -stdin)"
  escaped_hash_value="${hash_value//$/\\$}"

  set_config_value "$CONFIG_FILE" "PASSWORD_HASH" "$escaped_hash_value"

  echo "Password: $password"
  echo "Algorithm: sha512"
  echo "Config key: PASSWORD_HASH"
  echo "Updated $CONFIG_FILE: PASSWORD_HASH=***"
  echo "Generated new PASSWORD_HASH and saved to config.env"
else
  echo "PASSWORD_HASH already exists. Using persisted value."
fi
