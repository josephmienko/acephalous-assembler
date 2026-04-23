#!/usr/bin/env bash
# Download Home Assistant OS for Raspberry Pi 5
# Fetches the latest release from GitHub if not already present

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=/dev/null
source "$ROOT_DIR/config.env"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_00-common-functions.sh"

# If image is already provided/exists, use it
if [[ -f "${HA_IMAGE:-}" ]]; then
  echo "Using existing HA image: $HA_IMAGE"
  case "$HA_IMAGE" in
    *.img.xz|*.img.gz)
      set_config_value "$ROOT_DIR/config.env" "OUT" "${HA_IMAGE%.*}"
      ;;
    *.img)
      set_config_value "$ROOT_DIR/config.env" "OUT" "$HA_IMAGE"
      ;;
  esac
  exit 0
fi

# Determine download path
DOWNLOAD_DIR="${HOME}/Downloads"
mkdir -p "$DOWNLOAD_DIR"

# Fetch latest release info from Home Assistant GitHub
echo "Fetching latest Home Assistant OS release for Raspberry Pi 5..."
RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/home-assistant/operating-system/releases/latest")

if [[ -z "$RELEASE_JSON" ]]; then
  echo "Error: Could not fetch latest HA OS release from GitHub" >&2
  exit 1
fi

# Find the RPi5 image URL. Current HAOS releases use .img.xz; keep .img.gz
# fallback for older releases.
ASSET_LINE=$(printf '%s' "$RELEASE_JSON" | python3 -c '
import json
import sys

release = json.load(sys.stdin)
assets = release.get("assets", [])
matches = []
for asset in assets:
    name = asset.get("name", "")
    url = asset.get("browser_download_url", "")
    if "rpi5" in name and (name.endswith(".img.xz") or name.endswith(".img.gz")):
        matches.append((name, url))

matches.sort(key=lambda item: (not item[0].endswith(".img.xz"), item[0]))
if matches:
    print(matches[0][0] + "\t" + matches[0][1])
')

if [[ -z "$ASSET_LINE" ]]; then
  echo "Error: Could not find Raspberry Pi 5 image in release assets" >&2
  exit 1
fi

HA_FILENAME="${ASSET_LINE%%$'\t'*}"
HA_DOWNLOAD_URL="${ASSET_LINE#*$'\t'}"
HA_FILENAME=$(basename "$HA_DOWNLOAD_URL")
HA_IMAGE="${DOWNLOAD_DIR}/${HA_FILENAME}"

# Download if not already present
if [[ ! -f "$HA_IMAGE" ]]; then
  echo "Downloading: $HA_FILENAME"
  curl -fL -o "$HA_IMAGE" "$HA_DOWNLOAD_URL"
  echo "Downloaded to: $HA_IMAGE"
else
  echo "Image already exists: $HA_IMAGE"
fi

case "$HA_IMAGE" in
  *.img.xz|*.img.gz)
    OUT="${HA_IMAGE%.*}"
    ;;
  *.img)
    OUT="$HA_IMAGE"
    ;;
  *)
    echo "Error: Unexpected HA image extension: $HA_IMAGE" >&2
    exit 1
    ;;
esac

set_config_value "$ROOT_DIR/config.env" "HA_IMAGE" "$HA_IMAGE"
set_config_value "$ROOT_DIR/config.env" "OUT" "$OUT"
echo "Updated config.env:"
echo "  HA_IMAGE=$HA_IMAGE"
echo "  OUT=$OUT"
