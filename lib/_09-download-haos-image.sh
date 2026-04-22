#!/usr/bin/env bash
# Download Home Assistant OS for Raspberry Pi 5
# Fetches the latest release from GitHub if not already present

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=/dev/null
source "$ROOT_DIR/config.env"

# If image is already provided/exists, use it
if [[ -f "${HA_IMAGE:-}" ]]; then
  echo "Using existing HA image: $HA_IMAGE"
  exit 0
fi

# Determine download path
DOWNLOAD_DIR="${HOME}/Downloads"
mkdir -p "$DOWNLOAD_DIR"

# Fetch latest release info from Home Assistant GitHub
echo "Fetching latest Home Assistant OS release for Raspberry Pi 5..."
RELEASE_JSON=$(curl -sf "https://api.github.com/repos/home-assistant/operating-system/releases/latest")

if [[ -z "$RELEASE_JSON" ]]; then
  echo "Error: Could not fetch latest HA OS release from GitHub" >&2
  exit 1
fi

# Find the RPi5 image URL
HA_DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url": "[^"]*rpi5[^"]*\.img\.gz"' | head -1 | cut -d'"' -f4)

if [[ -z "$HA_DOWNLOAD_URL" ]]; then
  echo "Error: Could not find Raspberry Pi 5 image in release assets" >&2
  exit 1
fi

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

# Export for use in other scripts
export HA_IMAGE

echo "HA_IMAGE='$HA_IMAGE'" >> "$ROOT_DIR/config.env"
