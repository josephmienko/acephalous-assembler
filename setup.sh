#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"
EXAMPLE_FILE="$SCRIPT_DIR/config.env.example"
SERVER_DOWNLOAD_PAGE="https://ubuntu.com/download/server"
RELEASES_BASE_URL="https://releases.ubuntu.com"

ensure_config_file() {
  if [[ -f "$CONFIG_FILE" ]]; then
    return 0
  fi

  if [[ -f "$EXAMPLE_FILE" ]]; then
    cp "$EXAMPLE_FILE" "$CONFIG_FILE"
    echo "Created $CONFIG_FILE from config.env.example"
    return 0
  fi

  echo "config.env not found, and no config.env.example is available." >&2
  exit 1
}

load_config() {
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
}

latest_lts_version() {
  curl -fsSL "$SERVER_DOWNLOAD_PAGE" \
    | grep -Eo 'Ubuntu [0-9]+\.[0-9]+\.[0-9]+ LTS' \
    | head -1 \
    | awk '{print $2}'
}

extract_iso_version() {
  local iso_path="$1"
  local iso_name
  iso_name="$(basename "$iso_path")"

  if [[ "$iso_name" =~ ubuntu-([0-9]+\.[0-9]+\.[0-9]+)-live-server-amd64\.iso$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  fi
}

update_config_iso_path() {
  local new_iso_path="$1"
  local tmp_file
  tmp_file="$(mktemp)"

  if grep -q '^ISO=' "$CONFIG_FILE"; then
    awk -v new_iso="$new_iso_path" '
      BEGIN { replaced = 0 }
      /^ISO=/ && !replaced {
        print "ISO=\"" new_iso "\""
        replaced = 1
        next
      }
      { print }
      END {
        if (!replaced) {
          print "ISO=\"" new_iso "\""
        }
      }
    ' "$CONFIG_FILE" > "$tmp_file"
  else
    cat "$CONFIG_FILE" > "$tmp_file"
    if [[ -s "$tmp_file" ]]; then
      printf '\n' >> "$tmp_file"
    fi
    printf 'ISO="%s"\n' "$new_iso_path" >> "$tmp_file"
  fi

  mv "$tmp_file" "$CONFIG_FILE"
}

download_latest_iso() {
  local latest_version="$1"
  local target_dir="$2"
  local latest_basename="ubuntu-${latest_version}-live-server-amd64.iso"
  local latest_url="${RELEASES_BASE_URL}/${latest_version}/${latest_basename}"
  local new_iso_path="${target_dir}/${latest_basename}"

  echo "Downloading $latest_url"
  curl -fL "$latest_url" -o "$new_iso_path"
  update_config_iso_path "$new_iso_path"
  echo "Downloaded $new_iso_path"
  echo "Updated $CONFIG_FILE to use the new ISO"
}

ensure_config_file
load_config

echo "Installing dependencies ..."
"$SCRIPT_DIR/lib/_01-install-deps.sh"

echo "Generating a password hash and updating config.env ..."
"$SCRIPT_DIR/lib/_02-generate-password-hash.sh"

load_config

echo "Checking current Ubuntu Server LTS release ..."
LATEST_VERSION="$(latest_lts_version || true)"

if [[ -z "$LATEST_VERSION" ]]; then
  echo "Could not determine the latest Ubuntu Server LTS version from $SERVER_DOWNLOAD_PAGE" >&2
  echo "Setup complete, but release freshness was not checked."
  exit 0
fi

LATEST_BASENAME="ubuntu-${LATEST_VERSION}-live-server-amd64.iso"

if [[ -z "${ISO:-}" ]]; then
  echo "ISO is not set in $CONFIG_FILE"
  printf 'Download %s and update config.env to use it? [y/N] ' "$LATEST_BASENAME"
  read -r REPLY

  case "$REPLY" in
    [Yy]|[Yy][Ee][Ss])
      download_latest_iso "$LATEST_VERSION" "$HOME/Downloads"
      ;;
    *)
      echo "Leaving ISO unset in config.env"
      ;;
  esac

  echo "Setup complete. Review config.env before building."
  exit 0
fi

if [[ ! -f "$ISO" ]]; then
  echo "Configured ISO does not exist: $ISO"
  printf 'Download %s and update config.env to use it? [y/N] ' "$LATEST_BASENAME"
  read -r REPLY

  case "$REPLY" in
    [Yy]|[Yy][Ee][Ss])
      download_latest_iso "$LATEST_VERSION" "$(dirname "$ISO")"
      ;;
    *)
      echo "Keeping current config.env unchanged"
      ;;
  esac

  echo "Setup complete. Review config.env before building."
  exit 0
fi

CURRENT_VERSION="$(extract_iso_version "$ISO")"

if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
  echo "Configured ISO exists and is already the latest Ubuntu Server LTS: $CURRENT_VERSION"
  echo "Setup complete. Review config.env before building."
  exit 0
fi

echo "Configured ISO: $(basename "$ISO")${CURRENT_VERSION:+ (version $CURRENT_VERSION)}"
echo "Latest Ubuntu Server LTS: $LATEST_VERSION"
printf 'Download %s and update config.env to use it? [y/N] ' "$LATEST_BASENAME"
read -r REPLY

case "$REPLY" in
  [Yy]|[Yy][Ee][Ss])
    download_latest_iso "$LATEST_VERSION" "$(dirname "$ISO")"
    ;;
  *)
    echo "Keeping existing ISO in config.env"
    ;;
esac

echo "Setup complete. Review config.env before building."
