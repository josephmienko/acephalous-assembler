#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"
OPENSSL_BIN="$(brew --prefix openssl@3)/bin/openssl"

touch "$CONFIG_FILE"

if ! grep -q '^PASSWORD_HASH=' "$CONFIG_FILE"; then
  printf "Enter the password to hash for the Ubuntu installer: " >&2
  IFS= read -r -s PASSWORD
  printf "\n" >&2

  PASSWORD_HASH="$("$OPENSSL_BIN" passwd -6 "$PASSWORD")"
  printf "PASSWORD_HASH='%s'\n" "$PASSWORD_HASH" >> "$CONFIG_FILE"

  echo "Generated new PASSWORD_HASH and saved to $CONFIG_FILE"
else
  echo "PASSWORD_HASH already exists. Using persisted value."
fi