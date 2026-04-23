"""Build orchestration and workflow management.

Coordinates the complete build workflow:
- Configuration validation
- Dependency checking
- Template rendering
- Image building
- Handoff generation
"""

from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .config import ConfigManager
from .password import PasswordManager


@dataclass
class WorkflowContext:
    """Manages configuration, paths, and environment for build/flash operations."""

    config: ConfigManager
    variant: str
    work_path: Path | None = None
    root_path: Path | None = None

    def __post_init__(self) -> None:
        """Initialize paths from config if not provided."""
        if self.work_path is None:
            work_str = self.config.get("WORK_DIR")
            self.work_path = Path(work_str) if work_str else None

        if self.root_path is None:
            root_str = self.config.get("ROOT_PATH")
            self.root_path = Path(root_str) if root_str else None

    def validate(self) -> bool:
        """Validate WORK and ROOT paths for safety.

        Returns:
            True if paths are valid and safe.

        Raises:
            ValueError: If paths are dangerous or invalid.
        """
        if not self.work_path:
            raise ValueError("WORK_DIR not set in config")

        # Check WORK is in safe locations
        safe_roots = [Path("/tmp"), Path("/var/tmp"), Path.home()]
        is_safe = any(
            str(self.work_path).startswith(str(safe_root))
            for safe_root in safe_roots
        )
        if not is_safe:
            raise ValueError(
                f"WORK_DIR {self.work_path} not in safe locations"
            )

        # Check ROOT is inside WORK (if specified)
        if self.root_path:
            try:
                self.root_path.relative_to(self.work_path)
            except ValueError as e:
                raise ValueError(
                    f"ROOT_PATH {self.root_path} not inside "
                    f"WORK_DIR {self.work_path}"
                ) from e

        return True

    def get_iso_path(self) -> Path:
        """Get expected ISO output path based on variant."""
        if not self.work_path:
            raise ValueError("WORK_DIR not set")

        iso_name = f"{self.variant}-server-autoinstall-*.iso"
        return self.work_path / iso_name

    def get_hostname(self) -> str:
        """Get configured hostname."""
        return self.config.get("HOSTNAME", "unknown")


class DependencyChecker:
    """Checks for required system dependencies."""

    def __init__(self) -> None:
        """Initialize dependency checker."""
        self.required_commands = [
            "xorriso",
            "git",
            "wget",
            "openssl",
        ]

    def check(self) -> bool:
        """Check all required dependencies are installed.

        Returns:
            True if all dependencies present.

        Raises:
            RuntimeError: If required commands are missing.
        """
        missing = []
        for cmd in self.required_commands:
            result = subprocess.run(
                ["which", cmd],
                capture_output=True,
            )
            if result.returncode != 0:
                missing.append(cmd)

        if missing:
            raise RuntimeError(
                f"Missing required commands: {', '.join(missing)}"
            )

        return True


class BuildOrchestrator:
    """Orchestrates the complete build workflow for an OS variant."""

    def __init__(self, context: WorkflowContext) -> None:
        """Initialize build orchestrator.

        Args:
            context: WorkflowContext with configuration and paths.
        """
        self.context = context
        self.deps = DependencyChecker()

    def build(self) -> Path:
        """Execute full build workflow.

        Returns:
            Path to built ISO.

        Raises:
            RuntimeError: If build fails at any step.
        """
        # Validate dependencies
        self.deps.check()

        # Validate paths
        self.context.validate()

        # TODO: Orchestrate variant-specific build steps
        # 1. Render templates (autoinstall.yaml, preseed.cfg, user-data)
        # 2. Download/prepare base image if needed
        # 3. Patch bootloader (GRUB, kernel args)
        # 4. Build ISO or prepare image
        # 5. Rebuild checksums
        # 6. Generate handoff metadata

        # Placeholder: return dummy ISO path
        return self.context.work_path / "output.iso"


class FlashValidator:
    """Validates disk targets before flashing."""

    # System disks that should never be flashed
    PROTECTED_DISKS = {"/dev/disk0"}

    def check_safety(self, target_disk: str) -> bool:
        """Check if target disk is safe to flash.

        Args:
            target_disk: Disk identifier (e.g., /dev/disk3)

        Returns:
            True if disk is safe to flash.

        Raises:
            ValueError: If disk is protected or invalid.
        """
        if target_disk in self.PROTECTED_DISKS:
            raise ValueError(
                f"Cannot flash {target_disk}: system disk protection"
            )

        return True

    def get_disk_info(self, target_disk: str) -> dict[str, Any]:
        """Get disk information (size, model, etc.)

        Args:
            target_disk: Disk identifier

        Returns:
            Dictionary with disk metadata.
        """
        # TODO: Implement disk info retrieval
        return {
            "device": target_disk,
            "size": "8GB",
            "model": "Generic USB",
        }


@dataclass
class FlashPlan:
    """Represents a planned flash operation (dry-run)."""

    image_path: Path
    target_disk: str
    disk_info: dict[str, Any]

    def __str__(self) -> str:
        """String representation of flash plan."""
        return (
            f"Flash Plan:\n"
            f"  Image: {self.image_path}\n"
            f"  Target: {self.target_disk}\n"
            f"  Size: {self.disk_info.get('size', 'unknown')}\n"
            f"  Model: {self.disk_info.get('model', 'unknown')}\n"
            f"  WARNING: This will DESTROY all data on {self.target_disk}"
        )


class FlashOperation:
    """Handles USB flash with safety checks and confirmation."""

    CONFIRMATION_PHRASE = "flash USB"

    def __init__(self, image_path: Path, target_disk: str) -> None:
        """Initialize flash operation.

        Args:
            image_path: Path to ISO or image file.
            target_disk: Target disk identifier.
        """
        self.image = image_path
        self.target = target_disk
        self.validator = FlashValidator()

    def plan(self) -> FlashPlan:
        """Show what will happen (dry-run).

        Returns:
            FlashPlan describing the operation.

        Raises:
            ValueError: If target disk is unsafe.
        """
        self.validator.check_safety(self.target)
        disk_info = self.validator.get_disk_info(self.target)
        return FlashPlan(self.image, self.target, disk_info)

    def execute(self, confirmation: str = "") -> bool:
        """Execute flash operation if confirmation phrase matches.

        Args:
            confirmation: User confirmation phrase.

        Returns:
            True if flash succeeded.

        Raises:
            ValueError: If confirmation phrase is invalid.
            RuntimeError: If flash operation fails.
        """
        if confirmation != self.CONFIRMATION_PHRASE:
            raise ValueError(
                f'Invalid confirmation. Say "{self.CONFIRMATION_PHRASE}"'
            )

        # TODO: Implement actual flash operation via dd/Disk Utility
        # For now, this is a no-op to prevent accidental flashing
        return False
