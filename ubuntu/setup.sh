#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"
EXAMPLE_FILE="$SCRIPT_DIR/config.env.example"

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

set_config_value() {
  local key="$1"
  local value="$2"
  local tmp
  tmp="$(mktemp)"

  if [[ -f "$CONFIG_FILE" ]] && grep -q "^${key}=" "$CONFIG_FILE"; then
    awk -v key="$key" -v value="$value" '
      BEGIN { replaced = 0 }
      $0 ~ "^" key "=" {
        print key "=\"" value "\""
        replaced = 1
        next
      }
      { print }
      END {
        if (!replaced) {
          print key "=\"" value "\""
        }
      }
    ' "$CONFIG_FILE" > "$tmp"
  else
    cat "$CONFIG_FILE" > "$tmp"
    printf '%s="%s"\n' "$key" "$value" >> "$tmp"
  fi

  mv "$tmp" "$CONFIG_FILE"
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

set_config_value \
  "INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS" \
  "$INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS"

"$SCRIPT_DIR/../lib/_01-install-deps.sh"
"$SCRIPT_DIR/../lib/_02-generate-password-hash.sh"

echo "Setup complete. Review config.env before building."
echo "INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS=$INCLUDE_NOCLOUD_INSTALLER_CREDENTIALS"
