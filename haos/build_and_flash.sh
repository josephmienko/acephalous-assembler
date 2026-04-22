#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/config.env"

# Source shared functions
# shellcheck source=/dev/null
source "$ROOT_DIR/lib/_00-common-functions.sh"

# Validate config and password hash
if ! validate_config_and_hash "$CONFIG_FILE"; then
  exit 1
fi

# Load config into environment
load_config "$CONFIG_FILE"

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

echo ""
echo "Home Assistant OS image built: $OUT"
echo ""
echo "To flash to Raspberry Pi 5:"
echo "  ./build_and_flash.sh flash"
