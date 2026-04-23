"""Tests for handoff artifact generation."""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

# Add lib/python to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / "lib" / "python"))

import pytest  # noqa: E402


def test_handoff_generation_ubuntu() -> None:
    """Test handoff generation for Ubuntu variant."""
    config_dict = {
        "HOSTNAME": "optiplex3080",
        "USERNAME": "ubuntu",
        "BUILD_VARIANT": "ubuntu",
        "ISO": "/home/user/ubuntu-24.04.iso",
        "STATUS_IP": "192.168.1.23",
        "STATUS_PORT": "8081",
    }

    spec = importlib.util.spec_from_file_location(
        "_99_generate_handoff",
        Path(__file__).parent.parent / "lib" / "_99-generate-handoff.py",
    )
    if spec is None or spec.loader is None:
        pytest.skip("Could not load _99-generate-handoff.py")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    handoff = module.generate_handoff(config_dict)

    assert handoff["schema_version"] == "2.0"
    assert handoff["machine"]["hostname"] == "optiplex3080"
    assert handoff["machine"]["os_family"] == "Ubuntu"
    assert handoff["bootstrap"]["ssh_user"] == "ubuntu"
    assert handoff["bootstrap"]["ssh_port"] == 22
    assert handoff["bootstrap"]["marker_supported"] is True
    marker_path = (
        "/var/lib/acephalous-assembler/bootstrap-complete"
    )
    assert handoff["bootstrap"]["marker_path"] == marker_path
    assert handoff["bootstrap"]["status"] == "not_yet_installed"
    assert handoff["build"]["status"] == "media_and_flash_complete"
    assert "verification" in handoff
    assert handoff["verification"]["ssh_verified"] is False
    assert handoff["verification"]["first_boot_observed"] is False
    assert "status_server" in handoff["bootstrap"]


def test_handoff_generation_debian() -> None:
    """Test handoff generation for Debian variant."""
    config_dict = {
        "HOSTNAME": "debian-server",
        "USERNAME": "debian",
        "BUILD_VARIANT": "debian",
        "DEBIAN_SUITE": "bookworm",
    }

    spec = importlib.util.spec_from_file_location(
        "_99_generate_handoff",
        Path(__file__).parent.parent / "lib" / "_99-generate-handoff.py",
    )
    if spec is None or spec.loader is None:
        pytest.skip("Could not load _99-generate-handoff.py")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    handoff = module.generate_handoff(config_dict)

    assert handoff["machine"]["os_family"] == "Debian"
    assert handoff["machine"]["os_version"] == "Bookworm"
    assert handoff["machine"]["hostname"] == "debian-server"


def test_handoff_generation_haos_static() -> None:
    """Test handoff generation for HAOS with static IP."""
    config_dict = {
        "HOSTNAME": "homeassistant",
        "USERNAME": "homeassistant",
        "BUILD_VARIANT": "haos",
        "HA_STATIC_IP": "192.168.1.42",
    }

    spec = importlib.util.spec_from_file_location(
        "_99_generate_handoff",
        Path(__file__).parent.parent / "lib" / "_99-generate-handoff.py",
    )
    if spec is None or spec.loader is None:
        pytest.skip("Could not load _99-generate-handoff.py")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    handoff = module.generate_handoff(config_dict)

    assert handoff["machine"]["os_family"] == "Home Assistant OS"
    assert handoff["machine"]["network"]["mode"] == "static"
    assert handoff["machine"]["network"]["ip_address"] == "192.168.1.42"


def test_handoff_generation_haos_dhcp() -> None:
    """Test handoff generation for HAOS with DHCP."""
    config_dict = {
        "HOSTNAME": "homeassistant",
        "USERNAME": "homeassistant",
        "BUILD_VARIANT": "haos",
        "HA_STATIC_IP": "",
    }

    spec = importlib.util.spec_from_file_location(
        "_99_generate_handoff",
        Path(__file__).parent.parent / "lib" / "_99-generate-handoff.py",
    )
    if spec is None or spec.loader is None:
        pytest.skip("Could not load _99-generate-handoff.py")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    handoff = module.generate_handoff(config_dict)

    assert handoff["machine"]["network"]["mode"] == "dhcp"
    assert handoff["machine"]["network"]["ip_address"] is None


def test_handoff_generation_haos_direct_image() -> None:
    """Direct HAOS images should not claim injected marker support."""
    config_dict = {
        "HOSTNAME": "homeassistant",
        "USERNAME": "stale-debian-user",
        "HA_USERNAME": "homeassistant",
        "BUILD_VARIANT": "haos",
        "HAOS_DIRECT_IMAGE": "true",
        "HA_STATIC_IP": "",
    }

    spec = importlib.util.spec_from_file_location(
        "_99_generate_handoff",
        Path(__file__).parent.parent / "lib" / "_99-generate-handoff.py",
    )
    if spec is None or spec.loader is None:
        pytest.skip("Could not load _99-generate-handoff.py")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    handoff = module.generate_handoff(config_dict)

    assert handoff["bootstrap"]["ssh_user"] == "homeassistant"
    assert handoff["bootstrap"]["marker_supported"] is False
    assert handoff["bootstrap"]["marker_path"] is None
    assert "Official Home Assistant OS image" in handoff["handoff_notes"]


def test_handoff_generation_no_secrets() -> None:
    """Verify that handoff contains no password hashes or secrets."""
    config_dict = {
        "HOSTNAME": "testhost",
        "USERNAME": "testuser",
        "BUILD_VARIANT": "ubuntu",
        "PASSWORD_HASH": "$argon2id$v=19$m=65540,t=3,p=4$...",
        "STATUS_IP": "192.168.1.23",
    }

    spec = importlib.util.spec_from_file_location(
        "_99_generate_handoff",
        Path(__file__).parent.parent / "lib" / "_99-generate-handoff.py",
    )
    if spec is None or spec.loader is None:
        pytest.skip("Could not load _99-generate-handoff.py")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    handoff = module.generate_handoff(config_dict)

    # Serialize to JSON and check for secrets
    json_str = json.dumps(handoff)
    assert "PASSWORD_HASH" not in json_str
    assert "$argon2id" not in json_str
    assert "REPLACE_WITH_REAL_HASH" not in json_str


def test_handoff_csa_required_fields() -> None:
    """Verify all fields required by CSA are present and correctly typed."""
    config_dict = {
        "HOSTNAME": "testhost",
        "USERNAME": "testuser",
        "BUILD_VARIANT": "ubuntu",
        "ISO": "/path/to/ubuntu-24.04.iso",
        "STATUS_IP": "192.168.1.23",
        "STATUS_PORT": "8081",
    }

    spec = importlib.util.spec_from_file_location(
        "_99_generate_handoff",
        Path(__file__).parent.parent / "lib" / "_99-generate-handoff.py",
    )
    if spec is None or spec.loader is None:
        pytest.skip("Could not load _99-generate-handoff.py")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    handoff = module.generate_handoff(config_dict)

    # Canonical CSA-required fields per CSA-COMPATIBILITY.md
    # Check schema_version is string
    assert isinstance(handoff["schema_version"], str)
    assert handoff["schema_version"] == "2.0"

    # Check nested required fields
    assert "build" in handoff
    assert "variant" in handoff["build"]
    assert "status" in handoff["build"]
    build_status = handoff["build"]["status"]
    assert build_status == "media_and_flash_complete"

    assert "machine" in handoff
    assert "hostname" in handoff["machine"]
    assert "os_family" in handoff["machine"]
    assert "os_version" in handoff["machine"]
    assert "network" in handoff["machine"]
    assert "mode" in handoff["machine"]["network"]
    assert "ip_address" in handoff["machine"]["network"]

    assert "bootstrap" in handoff
    assert "ssh_user" in handoff["bootstrap"]
    assert "ssh_port" in handoff["bootstrap"]
    assert "status" in handoff["bootstrap"]
    assert "marker_supported" in handoff["bootstrap"]
    assert "marker_path" in handoff["bootstrap"]
    assert handoff["bootstrap"]["status"] == "not_yet_installed"
    assert handoff["bootstrap"]["marker_supported"] is True
    marker_path_expected = (
        "/var/lib/acephalous-assembler/bootstrap-complete"
    )
    assert handoff["bootstrap"]["marker_path"] == marker_path_expected

    assert "verification" in handoff
    assert "ssh_verified" in handoff["verification"]
    assert "first_boot_observed" in handoff["verification"]
    assert handoff["verification"]["ssh_verified"] is False
    assert handoff["verification"]["first_boot_observed"] is False

    # Verify NO appliance.* or ssh.* top-level fields
    # CSA should not expect these
    assert "appliance" not in handoff
    assert "ssh" not in handoff
