#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config.env"

# Source shared functions
# shellcheck source=/dev/null
source "$ROOT_DIR/lib/_00-common-functions.sh"

load_config "$CONFIG_FILE"
HAOS_DIRECT_IMAGE="${HAOS_DIRECT_IMAGE:-false}"

prepare_direct_image() {
  if [[ ! -f "${OUT:-}" ]]; then
    if [[ -z "${HA_IMAGE:-}" || ! -f "$HA_IMAGE" ]]; then
      "$ROOT_DIR/lib/_09-download-haos-image.sh"
      load_config "$CONFIG_FILE"
    fi

    case "$HA_IMAGE" in
      *.img.xz)
        echo "Decompressing HAOS image: $HA_IMAGE -> $OUT"
        xz -dkc "$HA_IMAGE" > "${OUT}.tmp"
        mv "${OUT}.tmp" "$OUT"
        ;;
      *.img.gz)
        echo "Decompressing HAOS image: $HA_IMAGE -> $OUT"
        gunzip -c "$HA_IMAGE" > "${OUT}.tmp"
        mv "${OUT}.tmp" "$OUT"
        ;;
      *.img)
        echo "Copying HAOS image: $HA_IMAGE -> $OUT"
        cp "$HA_IMAGE" "$OUT"
        ;;
      *)
        echo "Error: unsupported HA_IMAGE extension: ${HA_IMAGE:-unset}" >&2
        exit 1
        ;;
    esac
  fi
}

if [[ "$HAOS_DIRECT_IMAGE" == "true" ]]; then
  echo "Flashing official Home Assistant OS image for Raspberry Pi 5..."
  echo "Mode: direct image (no config injection)"
  echo ""

  prepare_direct_image
  "$ROOT_DIR/lib/_08-flash-image.sh"

  echo ""
  echo "Generating handoff artifact..."
  python3 "$ROOT_DIR/lib/_99-generate-handoff.py" \
    --config "$CONFIG_FILE" \
    --output-dir "$ROOT_DIR/.coordination"

  echo ""
  echo "✓ Home Assistant OS direct image flash complete."
  echo ""
  echo "Home Assistant OS image flashed: $OUT"
  echo "Handoff documentation: .coordination/handoff-${HOSTNAME}-*.json"
  exit 0
fi

# Validate config and password hash for image injection mode.
if ! validate_config_and_hash "$CONFIG_FILE"; then
  exit 1
fi

echo "Building Home Assistant OS image for Raspberry Pi 5..."
echo ""

# 1. Prepare disk image (decompress and mount)
echo "[1/5] Preparing disk image..."
"$ROOT_DIR/lib/_03-prepare-haos-workdir.sh"

# 2. Render network configuration (if static IP configured)
if [[ -n "${HA_STATIC_IP:-}" ]]; then
  echo "[2/5] Injecting static network configuration..."
  NM_CONN_DIR="$ROOT/etc/NetworkManager/system-connections"
  mkdir -p "$NM_CONN_DIR"
  
  python3 "$ROOT_DIR/lib/_04-render-template.py" \
    --config "$CONFIG_FILE" \
    --template "$SCRIPT_DIR/templates/eth0-static.nmconnection.template" \
    --output "$NM_CONN_DIR/eth0-static.nmconnection"
  
  chmod 600 "$NM_CONN_DIR/eth0-static.nmconnection"
else
  echo "[2/5] Skipping network configuration (DHCP enabled)..."
fi

# 3. Render Home Assistant configuration.yaml
echo "[3/5] Injecting Home Assistant configuration..."
HA_CONFIG_DIR="$ROOT/root/.homeassistant"
mkdir -p "$HA_CONFIG_DIR"

python3 "$ROOT_DIR/lib/_04-render-template.py" \
  --config "$CONFIG_FILE" \
  --template "$SCRIPT_DIR/templates/configuration.yaml.template" \
  --output "$HA_CONFIG_DIR/configuration.yaml"

# Create automations, scripts, scenes if missing
[[ -f "$HA_CONFIG_DIR/automations.yaml" ]] || echo "automation:" > "$HA_CONFIG_DIR/automations.yaml"
[[ -f "$HA_CONFIG_DIR/scripts.yaml" ]] || echo "script:" > "$HA_CONFIG_DIR/scripts.yaml"
[[ -f "$HA_CONFIG_DIR/scenes.yaml" ]] || echo "scene:" > "$HA_CONFIG_DIR/scenes.yaml"

# 4. Inject first-boot status callback (if monitoring enabled)
if [[ -n "${STATUS_IP:-}" ]]; then
  echo "[4/5] Injecting first-boot status callback..."
  
  # Render and place systemd service
  python3 "$ROOT_DIR/lib/_04-render-template.py" \
    --config "$CONFIG_FILE" \
    --template "$SCRIPT_DIR/templates/ha-first-boot-status.service.template" \
    --output "$ROOT/etc/systemd/system/ha-first-boot-status.service"
  
  # Render and place callback script
  python3 "$ROOT_DIR/lib/_04-render-template.py" \
    --config "$CONFIG_FILE" \
    --template "$SCRIPT_DIR/templates/ha-status-callback.sh.template" \
    --output "$ROOT/usr/local/bin/ha-status-callback.sh"
  
  chmod +x "$ROOT/usr/local/bin/ha-status-callback.sh"
  
  # Enable the service (will run on first boot)
  mkdir -p "$ROOT/etc/systemd/system/multi-user.target.wants"
  ln -sf ../ha-first-boot-status.service "$ROOT/etc/systemd/system/multi-user.target.wants/ha-first-boot-status.service"
else
  echo "[4/5] Skipping status monitoring..."
fi

# 5. Unmount and finalize
echo "[5/5] Finalizing image..."
"$ROOT_DIR/lib/_10-finalize-haos-image.sh"

# Generate handoff artifact for downstream appliance provisioning
echo ""
echo "Generating handoff artifact..."
python3 "$ROOT_DIR/lib/_99-generate-handoff.py" \
  --config "$CONFIG_FILE" \
  --output-dir "$ROOT_DIR/.coordination"

echo ""
echo "✓ Home Assistant OS image build complete."
echo ""
echo "Home Assistant OS image built: $OUT"
echo "Handoff documentation: .coordination/handoff-${HOSTNAME}-*.json"
echo ""
echo "To flash to Raspberry Pi 5:"
echo "  cd .."
echo "  ./build_and_flash.sh"
echo ""
echo "Next: Use crooked-sentry-appliance to configure Frigate, backups, and other services."
