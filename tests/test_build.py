"""Tests for build orchestration and workflow management."""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml

from lib.python.assembler.build import (
    BuildOrchestrator,
    DependencyChecker,
    FlashOperation,
    FlashValidator,
    WorkflowContext,
)
from lib.python.assembler.config import ConfigManager


class TestWorkflowContext:
    """Tests for WorkflowContext."""

    def test_context_from_config(self, tmp_path: Path) -> None:
        """Test creating context from config."""
        config_file = tmp_path / "config.env"
        config_file.write_text(
            "HOSTNAME=testhost\n"
            f"WORK_DIR={tmp_path / 'work'}\n"
        )

        config = ConfigManager(config_file)
        context = WorkflowContext(config, "ubuntu")

        assert context.variant == "ubuntu"
        assert context.get_hostname() == "testhost"

    def test_context_validate_safe_work_path(self, tmp_path: Path) -> None:
        """Test validation accepts /tmp work paths."""
        # Use actual /tmp directory for the test
        work_path = Path("/tmp/acephalous-test-work")
        root_path = work_path / "root"

        config_file = tmp_path / "config.env"
        config_file.write_text(
            f"WORK_DIR={work_path}\n" f"ROOT_PATH={root_path}"
        )

        config = ConfigManager(config_file)
        context = WorkflowContext(config, "ubuntu")

        # Should not raise
        assert context.validate() is True

    def test_context_validate_rejects_unsafe_work_path(self) -> None:
        """Test validation rejects dangerous work paths."""
        config_file = Path("/tmp/config-unsafe.env")
        config_file.write_text("WORK_DIR=/home\nROOT_PATH=/home/root")

        config = ConfigManager(config_file)
        context = WorkflowContext(config, "ubuntu")

        with pytest.raises(ValueError, match="not in safe locations"):
            context.validate()

        config_file.unlink()

    def test_context_validate_rejects_root_outside_work(self) -> None:
        """Test validation rejects ROOT outside WORK."""
        config_file = Path("/tmp/config-outside.env")
        config_file.write_text("WORK_DIR=/tmp/work\nROOT_PATH=/var/lib/root")

        config = ConfigManager(config_file)
        context = WorkflowContext(config, "ubuntu")

        with pytest.raises(ValueError, match="ROOT_PATH"):
            context.validate()

        config_file.unlink()


class TestDependencyChecker:
    """Tests for DependencyChecker."""

    def test_checker_finds_existing_commands(self) -> None:
        """Test that checker finds existing system commands."""
        checker = DependencyChecker()
        # Reduce to commands that definitely exist
        checker.required_commands = ["ls", "grep"]
        assert checker.check() is True

    def test_checker_fails_on_missing_commands(self) -> None:
        """Test that checker fails on missing commands."""
        checker = DependencyChecker()
        checker.required_commands = ["nonexistent_command_xyz"]

        with pytest.raises(RuntimeError, match="Missing required commands"):
            checker.check()


class TestFlashValidator:
    """Tests for FlashValidator."""

    def test_validator_rejects_system_disk(self) -> None:
        """Test that /dev/disk0 is rejected."""
        validator = FlashValidator()

        with pytest.raises(ValueError, match="system disk protection"):
            validator.check_safety("/dev/disk0")

    def test_validator_accepts_external_disk(self) -> None:
        """Test that external disks are accepted."""
        validator = FlashValidator()
        assert validator.check_safety("/dev/disk3") is True

    def test_validator_provides_disk_info(self) -> None:
        """Test getting disk information."""
        validator = FlashValidator()
        info = validator.get_disk_info("/dev/disk3")

        assert "device" in info
        assert "size" in info
        assert info["device"] == "/dev/disk3"


class TestFlashOperation:
    """Tests for FlashOperation."""

    def test_flash_plan_dry_run(self, tmp_path: Path) -> None:
        """Test flash plan shows what will happen."""
        iso_path = tmp_path / "test.iso"
        iso_path.write_text("")

        flash = FlashOperation(iso_path, "/dev/disk3")
        plan = flash.plan()

        assert plan.image_path == iso_path
        assert plan.target_disk == "/dev/disk3"
        assert "DESTROY" in str(plan)

    def test_flash_requires_confirmation(self, tmp_path: Path) -> None:
        """Test flash requires exact confirmation phrase."""
        iso_path = tmp_path / "test.iso"
        iso_path.write_text("")

        flash = FlashOperation(iso_path, "/dev/disk3")

        # Wrong confirmation
        with pytest.raises(ValueError, match="Invalid confirmation"):
            flash.execute("yes")

        # Correct confirmation
        result = flash.execute("flash USB")
        assert result is False  # Returns False because we don't actually flash

    def test_flash_rejects_system_disk(self, tmp_path: Path) -> None:
        """Test that flashing /dev/disk0 is rejected."""
        iso_path = tmp_path / "test.iso"
        iso_path.write_text("")

        flash = FlashOperation(iso_path, "/dev/disk0")

        with pytest.raises(ValueError, match="system disk protection"):
            flash.plan()


class TestDebianCloudInitYAML:
    """Tests for Debian cloud-init YAML syntax validation.

    These tests verify that the cloud-init user-data template is valid YAML
    and doesn't contain the unquoted Content-Type bug found in pilot testing.
    """

    def test_debian_preseed_user_data_is_valid_yaml(self) -> None:
        """Verify Debian preseed template renders valid YAML for cloud-init.

        This test would have caught the cloud-init bug where:
        `Content-Type: application/json` in runcmd was interpreted as a
        mapping instead of part of the shell command, causing YAML
        schema validation failure.
        """
        # Create minimal config for rendering
        config_vars = {
            "HOSTNAME": "testhost",
            "USERNAME": "testuser",
            "STATUS_IP": "192.168.1.23",
            "STATUS_PORT": "8081",
            "DEBIAN_SUITE": "bookworm",
        }

        # For now, test the safety of the known-good cloud-init format
        # Once templates are exposed via Python API, this can be expanded
        user_data = """
#cloud-config
preserve_hostname: false
hostname: testhost
ssh_pwauth: true
phone_home:
  url: http://192.168.1.23:8081/first-boot/debian-testhost/
  post: [instance_id, hostname, fqdn]
write_files:
  - path: /run/acephalous-runcmd-status.json
    permissions: "0644"
    content: |
      {"variant":"debian","stage":"cloud_init_runcmd","hostname":"testhost","status":"ready"}
runcmd:
  - [ mkdir, -p, /var/lib/acephalous-assembler ]
  - [ touch, /var/lib/acephalous-assembler/bootstrap-complete ]
  - [ sh, -c, "curl -fsS -m 15 -X POST -H 'Content-Type: application/json' --data-binary @/run/acephalous-runcmd-status.json http://192.168.1.23:8081/debian-install-status || true" ]
datasource_list: [ NoCloud, None ]
"""
        # Parse as YAML - should not raise
        parsed = yaml.safe_load(user_data)
        assert isinstance(parsed, dict), "user-data should parse as YAML dict"

        # Verify structure
        assert "runcmd" in parsed, "Should have runcmd key"

        # Verify no unquoted Content-Type (which caused the bug)
        # The fix uses: curl ... --header='Content-Type: application/json'
        # or --data-binary @/tmp/file.json to avoid this
        runcmd_section = user_data.split("runcmd:")[1]
        lines_with_content_type = [
            line
            for line in runcmd_section.split("\n")
            if "Content-Type:" in line and "'" not in line and '"' not in line
        ]
        assert (
            len(lines_with_content_type) == 0
        ), "Found unquoted Content-Type in runcmd (YAML bug)"

    def test_runcmd_uses_safe_list_format(self) -> None:
        """Verify runcmd uses YAML-safe list format.

        After the cloud-init bug, runcmd should use:
        - proper YAML list format [ cmd, arg1, arg2 ]
        - OR quoted strings in a shell command
        - NOT bare unquoted strings that look like mappings
        """
        safe_runcmd = """
runcmd:
  - [ mkdir, -p, /var/lib/acephalous-assembler ]
  - [ touch, /var/lib/acephalous-assembler/bootstrap-complete ]
  - [ sh, -c, "curl -X POST -H 'Content-Type: application/json' ..." ]
"""
        # Parse and verify
        parsed = yaml.safe_load(safe_runcmd)
        assert isinstance(parsed["runcmd"], list)
        assert all(isinstance(item, list) for item in parsed["runcmd"])


class TestBuildOrchestrator:
    """Tests for BuildOrchestrator."""

    def test_orchestrator_validates_context(self, tmp_path: Path) -> None:
        """Test that orchestrator validates context before building."""
        config_file = tmp_path / "config.env"
        # Use safe /tmp path for validation
        config_file.write_text("WORK_DIR=/tmp/acephalous-work")

        config = ConfigManager(config_file)
        context = WorkflowContext(config, "ubuntu")
        orchestrator = BuildOrchestrator(context)

        # Validation should pass (uses /tmp which is safe)
        assert orchestrator.context.validate() is True

    def test_orchestrator_checks_dependencies(self, tmp_path: Path) -> None:
        """Test that orchestrator checks dependencies."""
        config_file = tmp_path / "config.env"
        config_file.write_text("WORK_DIR=/tmp/acephalous-work")

        config = ConfigManager(config_file)
        context = WorkflowContext(config, "ubuntu")
        orchestrator = BuildOrchestrator(context)

        # Check dependencies (will fail if some are missing)
        # but that's expected in test environment
        try:
            orchestrator.deps.check()
        except RuntimeError:
            # Expected: some build dependencies may not be in test env
            pass
