#!/usr/bin/env python3
"""Generate handoff JSON artifact for downstream appliance provisioning.

This script creates a machine-readable handoff file that documents the
bootstrap state after acephalous-assembler completes. The handoff file is
consumed by crooked-sentry-appliance (or similar) for next-phase
provisioning.

Handoff file is created in\
      `.coordination/handoff-${HOSTNAME}-${TIMESTAMP}.json`
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def _determine_os_info(
    config_dict: dict[str, str],
    build_variant: str,
) -> tuple[str, str]:
    """Determine OS family and version.

    Args:
        config_dict: Configuration dictionary.
        build_variant: Build variant (ubuntu, debian, haos).

    Returns:
        Tuple of (os_family, os_version).
    """
    os_family = "unknown"
    os_version = "unknown"

    if build_variant == "ubuntu":
        os_family = "Ubuntu"
        iso_path = config_dict.get("ISO", "")
        if "24.04" in iso_path:
            os_version = "24.04 LTS"
        elif "22.04" in iso_path:
            os_version = "22.04 LTS"
        else:
            os_version = "Server"
    elif build_variant == "debian":
        os_family = "Debian"
        debian_suite = config_dict.get("DEBIAN_SUITE", "bookworm")
        os_version = debian_suite.capitalize()
    elif build_variant == "haos":
        os_family = "Home Assistant OS"
        os_version = "latest"

    return os_family, os_version


def _determine_network_info(
    config_dict: dict[str, str],
    build_variant: str,
) -> tuple[str, str | None]:
    """Determine network mode and IP address.

    Args:
        config_dict: Configuration dictionary.
        build_variant: Build variant (ubuntu, debian, haos).

    Returns:
        Tuple of (network_mode, ip_address).
    """
    network_mode = "unknown"
    ip_address: str | None = None

    if build_variant == "haos":
        ha_static_ip = config_dict.get("HA_STATIC_IP", "")
        if ha_static_ip:
            network_mode = "static"
            ip_address = ha_static_ip
        else:
            network_mode = "dhcp"
    else:
        network_mode = "dhcp"

    return network_mode, ip_address


def _get_status_server(
    status_ip: str,
    status_port: str,
) -> dict[str, Any] | None:
    """Build status server configuration.

    Args:
        status_ip: Status server IP address.
        status_port: Status server port.

    Returns:
        Status server dict or None if not configured.
    """
    if status_ip and status_port:
        return {
            "ip": status_ip,
            "port": int(status_port),
            "webhook_path": "/install-status or /homeassistant-ready",
        }
    return None


def generate_handoff(
    config_dict: dict[str, str],
) -> dict[str, Any]:
    """Generate handoff data structure.

    Args:
        config_dict: Configuration from config.env (all vars as strings).

    Returns:
        Dictionary ready for JSON serialization.
    """
    hostname = config_dict.get("HOSTNAME", "unknown")
    username = config_dict.get("USERNAME", "unknown")
    ssh_port = 22
    build_variant = config_dict.get("BUILD_VARIANT", "unknown")
    status_ip = config_dict.get("STATUS_IP", "")
    status_port = config_dict.get("STATUS_PORT", "8081")

    # Determine OS family and version
    os_family, os_version = _determine_os_info(config_dict, build_variant)

    # Determine network mode and IP address
    network_mode, ip_address = _determine_network_info(
        config_dict,
        build_variant,
    )

    # Build status server configuration
    status_server = _get_status_server(status_ip, status_port)

    timestamp = datetime.now(timezone.utc).isoformat()

    # Determine which variants support first-boot markers
    marker_supported = build_variant in ("ubuntu", "debian", "haos")

    return {
        "schema_version": "2.0",
        "generated_at": timestamp,
        "repo": {
            "name": "acephalous-assembler",
            "version": "0.4.0",
            "url": "https://github.com/josephmienko/acephalous-assembler",
        },
        "build": {
            "variant": build_variant,
            "timestamp": timestamp,
            "status": "media_and_flash_complete",
        },
        "machine": {
            "hostname": hostname,
            "os_family": os_family,
            "os_version": os_version,
            "network": {
                "mode": network_mode,
                "ip_address": ip_address,
            },
        },
        "bootstrap": {
            "ssh_user": username,
            "ssh_port": ssh_port,
            "status": "not_yet_installed",
            "marker_supported": marker_supported,
            "marker_path": (
                "/var/lib/acephalous-assembler/bootstrap-complete"
            ),
            "status_server": status_server,
        },
        "verification": {
            "ssh_verified": False,
            "first_boot_observed": False,
            "notes": (
                "These fields are not populated at build time. "
                "After target system boots and first-boot systemd unit "
                "completes, crooked-sentry-appliance should: (1) verify "
                "SSH access, (2) check for marker file, (3) update "
                "verification fields, (4) archive this handoff for audit."
            ),
        },
        "handoff_notes": (
            "Media and flash complete. ISO/image is ready for installation. "
            "This is a pre-installation handoff: the target system has not "
            "yet booted. Downstream appliance provisioning should use "
            "machine.hostname and bootstrap.ssh_user to access the system "
            "after installation completes and first-boot marker is created."
        ),
    }


def main() -> int:
    """Parse arguments and generate handoff file.

    Returns:
        Zero on success, non-zero on error.
    """
    parser = argparse.ArgumentParser(
        description="Generate handoff JSON for downstream\
              appliance provisioning",
    )
    parser.add_argument(
        "--config",
        required=True,
        help="Path to config.env file",
    )
    parser.add_argument(
        "--output-dir",
        default=".coordination",
        help="Output directory for handoff file (default: .coordination)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print handoff JSON to stdout without writing file",
    )

    args = parser.parse_args()

    # Load config
    config_path = Path(args.config).expanduser()
    if not config_path.exists():
        print(f"Error: config file not found: {config_path}", file=sys.stderr)
        return 1

    config_dict: dict[str, str] = {}
    try:
        with open(config_path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    key, _, value = line.partition("=")
                    # Remove quotes
                    value = value.strip('"\'')
                    config_dict[key.strip()] = value
    except OSError as e:
        print(
            f"Error reading config file: {e}",
            file=sys.stderr,
        )
        return 1

    # Generate handoff data
    handoff = generate_handoff(config_dict)

    if args.dry_run:
        print(json.dumps(handoff, indent=2))
        return 0

    # Write handoff file
    output_dir = Path(args.output_dir).expanduser()
    output_dir.mkdir(parents=True, exist_ok=True)

    hostname = config_dict.get("HOSTNAME", "unknown")
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    output_file = (
        output_dir / f"handoff-{hostname}-{timestamp}.json"
    )

    try:
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(handoff, f, indent=2)
        print(f"Handoff file generated: {output_file}")
        return 0
    except OSError as e:
        print(
            f"Error writing handoff file: {e}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
