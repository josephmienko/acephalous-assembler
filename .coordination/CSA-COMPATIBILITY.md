# Handoff Schema v2.0 — Crooked Sentry Appliance Integration

**Document Version**: 1.0  
**Schema Version**: 2.0  
**Date**: April 23, 2026

---

## Overview

Acephalous Assembler (AA) emits a machine-readable handoff artifact after successfully building and flashing OS media. This handoff is the source of truth for downstream provisioning by Crooked Sentry Appliance (CSA).

**Location**: `.coordination/handoff-${HOSTNAME}-${TIMESTAMP}.json`

**Example**: See [.coordination/handoff-v2.example.json](.coordination/handoff-v2.example.json)

---

## Canonical Fields CSA Must Consume

The following fields are required and guaranteed to be present:

### Top-Level

- `schema_version`: Always "2.0" (breaking changes increment major version)
- `build.variant`: "ubuntu" | "debian" | "haos"
- `build.status`: Always "media_and_flash_complete" (build phase done, installation not yet started)

### Machine Information

- `machine.hostname`: Target system hostname
- `machine.os_family`: "Ubuntu" | "Debian" | "Home Assistant OS"
- `machine.os_version`: Version string (e.g., "24.04 LTS", "bookworm", "latest")
- `machine.network.mode`: "dhcp" | "static"
- `machine.network.ip_address`: IP address or null (null if DHCP)

### Bootstrap Configuration

- `bootstrap.ssh_user`: SSH user for appliance provisioning (e.g., "ubuntu", "debian", "homeassistant")
- `bootstrap.ssh_port`: SSH port (typically 22)
- `bootstrap.status`: Always "not_yet_installed" at handoff time (target system not yet booted)
- `bootstrap.marker_supported`: Boolean indicating whether target supports first-boot marker
- `bootstrap.marker_path`: Path to first-boot marker file (all variants use `/var/lib/acephalous-assembler/bootstrap-complete`)

### Verification Status

- `verification.ssh_verified`: Always false at handoff time (not yet verified)
- `verification.first_boot_observed`: Always false at handoff time (not yet observed)

---

## Fields NOT to Consume

The handoff deliberately excludes secrets and appliance-specific fields:

- ❌ No password hashes
- ❌ No private keys or SSH credentials
- ❌ No camera credentials
- ❌ No authentication tokens
- ❌ No `appliance.*` fields (CSA owns appliance state)
- ❌ No `ssh.*` nested under bootstrap (use `bootstrap.ssh_user` and `bootstrap.ssh_port`)

---

## CSA Consumption Workflow

### 1. Read Handoff

```bash
# After AA completes, read the handoff file
HANDOFF=$(cat .coordination/handoff-*.json | tail -1)
```

### 2. Extract Target Information

Use the jq examples below:

```bash
# Get hostname
HOSTNAME=$(echo "$HANDOFF" | jq -r '.machine.hostname')

# Get IP address (may be null if DHCP)
IP_ADDRESS=$(echo "$HANDOFF" | jq -r '.machine.network.ip_address')

# Get SSH user
SSH_USER=$(echo "$HANDOFF" | jq -r '.bootstrap.ssh_user')

# Get SSH port
SSH_PORT=$(echo "$HANDOFF" | jq -r '.bootstrap.ssh_port')

# Get marker path
MARKER_PATH=$(echo "$HANDOFF" | jq -r '.bootstrap.marker_path')

# Get OS family for conditional logic
OS_FAMILY=$(echo "$HANDOFF" | jq -r '.machine.os_family')
```

### 3. Wait for Installation to Complete

Poll or listen for the target system to boot and reach first-boot marker:

```bash
# Wait for marker to appear (via SSH)
# This indicates bootstrap phase is complete

until ssh -o ConnectTimeout=5 "${SSH_USER}@${HOSTNAME}" \
    "test -f ${MARKER_PATH}"; do
  echo "Waiting for first-boot marker..."
  sleep 5
done

echo "Target system booted and ready for provisioning."
```

### 4. Update Verification Fields

After confirming SSH access and marker:

```bash
# CSA should update the handoff with verification results
# (CSA owns this update, not AA)

HANDOFF_UPDATED=$(echo "$HANDOFF" | jq \
  '.verification.ssh_verified = true | .verification.first_boot_observed = true')

echo "$HANDOFF_UPDATED" > .coordination/handoff-verified.json
```

### 5. Proceed with Appliance Provisioning

Use the target information (hostname, IP, SSH user) to:

- Deploy SSH keys for appliance user
- Configure Frigate and Docker Compose stack
- Set up MQTT (if applicable)
- Install Home Assistant integrations
- Configure backup scheduling

---

## jq Cheat Sheet

### Extract All Required Fields

```bash
jq '{
  hostname: .machine.hostname,
  ip_address: .machine.network.ip_address,
  ssh_user: .bootstrap.ssh_user,
  ssh_port: .bootstrap.ssh_port,
  marker_path: .bootstrap.marker_path,
  os_family: .machine.os_family,
  os_version: .machine.os_version,
  variant: .build.variant
}' handoff-*.json
```

### Check Schema Version

```bash
jq -r '.schema_version' handoff-*.json
# Output: 2.0
```

### Validate Required Fields Present

```bash
jq 'has("machine") and has("bootstrap") and has("verification")' handoff-*.json
# Output: true
```

### Pretty-Print Full Handoff

```bash
jq '.' handoff-*.json
```

---

## Schema Stability

**Breaking Changes** (increment major version):

- Rename or remove required fields
- Change field types
- Restructure top-level sections

**Non-Breaking Changes** (increment minor version):

- Add new optional fields
- Add new optional sections
- Change description text

**Current Version**: 2.0 (stable)  
**No Breaking Changes Anticipated**: This schema is designed for long-term compatibility.

---

## CSA Integration Checklist

Before deploying CSA, verify:

- [ ] CSA reads `schema_version` and handles v2.0
- [ ] CSA extracts hostname and IP from `machine.*`
- [ ] CSA uses `bootstrap.ssh_user` and `bootstrap.ssh_port` for SSH
- [ ] CSA waits for marker at `bootstrap.marker_path`
- [ ] CSA does NOT expect `appliance.*` or `ssh.*` top-level fields
- [ ] CSA archives handoff with verification updates
- [ ] Tests pass: `bash tests/run-all-tests.sh && poetry run pytest tests/ -v`

---

## Example: Minimal CSA Integration Script

```bash
#!/usr/bin/env bash
# Example CSA integration script

set -euo pipefail

# Find handoff
HANDOFF_FILE=$(find .coordination -name "handoff-*.json" -type f | head -1)
if [[ -z "$HANDOFF_FILE" ]]; then
  echo "No handoff file found."
  exit 1
fi

# Extract fields
HOSTNAME=$(jq -r '.machine.hostname' "$HANDOFF_FILE")
IP_ADDRESS=$(jq -r '.machine.network.ip_address' "$HANDOFF_FILE")
SSH_USER=$(jq -r '.bootstrap.ssh_user' "$HANDOFF_FILE")
SSH_PORT=$(jq -r '.bootstrap.ssh_port' "$HANDOFF_FILE")
MARKER_PATH=$(jq -r '.bootstrap.marker_path' "$HANDOFF_FILE")

echo "Target: $HOSTNAME (${IP_ADDRESS:-DHCP})"
echo "SSH: $SSH_USER@$HOSTNAME:$SSH_PORT"

# Wait for first-boot marker
echo "Waiting for target system to boot..."
MAX_WAIT=300
ELAPSED=0
until ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
    "${SSH_USER}@${HOSTNAME}" "test -f ${MARKER_PATH}"; do
  if (( ELAPSED >= MAX_WAIT )); then
    echo "Timeout waiting for first-boot marker."
    exit 1
  fi
  echo "  ... (${ELAPSED}s elapsed)"
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

echo "✓ Target system booted and ready."
echo "✓ Proceed with appliance provisioning."
```

---

## Support

For schema questions or CSA integration issues:

- Review [.coordination/handoff-v2.example.json](.coordination/handoff-v2.example.json) for field examples
- Check [tests/test_handoff.py](../tests/test_handoff.py) for field validation rules
- Run: `python3 lib/_99-generate-handoff.py --config config.env --dry-run` to see real output

---

**AA owns**: OS provisioning, bootstrap status signaling, handoff generation  
**CSA owns**: Verification, appliance services, credential management
