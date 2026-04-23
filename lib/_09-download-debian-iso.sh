#!/usr/bin/env bash
# Download the current Debian amd64 netinst ISO when config.env has no usable ISO.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config.env"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/_00-common-functions.sh"

if [[ -f "$CONFIG_FILE" ]]; then
  load_config "$CONFIG_FILE"
fi

if [[ -n "${ISO:-}" && -f "$ISO" ]]; then
  echo "Using existing Debian ISO: $ISO"
  exit 0
fi

DOWNLOAD_DIR="${HOME}/Downloads"
INDEX_URL="${DEBIAN_ISO_INDEX_URL:-https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/}"
mkdir -p "$DOWNLOAD_DIR"

echo "Fetching current Debian amd64 netinst ISO listing..."
index_html="$(curl -fsSL "$INDEX_URL")"
filename="$(printf '%s\n' "$index_html" |
  sed -n 's/.*href="\([^"]*debian-[0-9][0-9.]*-amd64-netinst\.iso\)".*/\1/p' |
  head -1)"

if [[ -z "$filename" ]]; then
  echo "Error: Could not find Debian amd64 netinst ISO in: $INDEX_URL" >&2
  exit 1
fi

download_url="${INDEX_URL%/}/$filename"
iso_path="$DOWNLOAD_DIR/$filename"

if [[ ! -f "$iso_path" ]]; then
  echo "Downloading: $filename"
  curl -fL -C - -o "$iso_path" "$download_url"
  echo "Downloaded to: $iso_path"
else
  echo "Debian ISO already exists: $iso_path"
fi

version="${filename#debian-}"
version="${version%-amd64-netinst.iso}"
major="${version%%.*}"
suite="${DEBIAN_SUITE:-}"

case "$major" in
  12) suite="bookworm" ;;
  13) suite="trixie" ;;
  14) suite="forky" ;;
  *)
    if [[ -z "$suite" ]]; then
      echo "Error: Unknown Debian major version '$major'; set DEBIAN_SUITE in config.env." >&2
      exit 1
    fi
    echo "Warning: Unknown Debian major version '$major'; keeping DEBIAN_SUITE=$suite" >&2
    ;;
esac

set_config_value "$CONFIG_FILE" "BUILD_VARIANT" "debian"
set_config_value "$CONFIG_FILE" "ISO" "$iso_path"
set_config_value "$CONFIG_FILE" "OUT" "$DOWNLOAD_DIR/debian-${version}-autoinstall.iso"
set_config_value "$CONFIG_FILE" "DEBIAN_SUITE" "$suite"

echo "Updated config.env:"
echo "  ISO=$iso_path"
echo "  OUT=$DOWNLOAD_DIR/debian-${version}-autoinstall.iso"
echo "  DEBIAN_SUITE=$suite"
