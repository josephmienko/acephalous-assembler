"""Configuration management for shell-style config files.

Loads and validates environment configuration from simple KEY=VALUE files.
"""

from __future__ import annotations

from pathlib import Path


class ConfigManager:
    """Manage configuration loaded from a .env-style file.

    Provides type-safe access to configuration values with defaults.
    Compatible with shell-style KEY=VALUE format.
    """

    def __init__(self, config_path: Path | str) -> None:
        """Initialize ConfigManager with a config file.

        Args:
            config_path: Path to the config.env file.

        Raises:
            FileNotFoundError: If config file does not exist.
        """
        self.config_path = Path(config_path)
        if not self.config_path.exists():
            msg = f"Config file not found: {self.config_path}"
            raise FileNotFoundError(msg)
        self.data = self._load_values()

    def _load_values(self) -> dict[str, str]:
        """Load shell-style KEY=VALUE entries without external dependencies."""
        values: dict[str, str] = {}

        for raw_line in self.config_path.read_text(
            encoding="utf-8",
        ).splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            if line.startswith("export "):
                line = line[len("export "):].lstrip()

            key, _, raw_value = line.partition("=")
            key = key.strip()
            if not key:
                continue

            values[key] = self._parse_value(raw_value.strip())

        return values

    @staticmethod
    def _parse_value(raw_value: str) -> str:
        """Parse a simple shell value, including quoted values."""
        if len(raw_value) >= 2 and raw_value[0] == raw_value[-1] == "'":
            return raw_value[1:-1]

        if len(raw_value) >= 2 and raw_value[0] == raw_value[-1] == '"':
            value = raw_value[1:-1]
            replacements = {
                r"\\": "\\",
                r"\"": '"',
                r"\$": "$",
                r"\`": "`",
            }
            for old, new in replacements.items():
                value = value.replace(old, new)
            return value

        if " #" in raw_value:
            raw_value = raw_value.split(" #", 1)[0].rstrip()

        return raw_value

    def get(self, key: str, default: str = "") -> str:
        """Get a configuration value with a default.

        Args:
            key: Configuration key.
            default: Default value if key is not found.

        Returns:
            Configuration value or default.
        """
        return self.data.get(key, default)

    def get_int(self, key: str, default: int = 0) -> int:
        """Get a configuration value as an integer.

        Args:
            key: Configuration key.
            default: Default value if key is not found or not a valid int.

        Returns:
            Configuration value as integer or default.
        """
        try:
            return int(self.data.get(key, str(default)))
        except ValueError:
            return default

    def get_bool(self, key: str, default: bool = False) -> bool:
        """Get a configuration value as a boolean.

        Args:
            key: Configuration key.
            default: Default value if key is not found.

        Returns:
            Configuration value as boolean or default.
        """
        value = self.data.get(key, "").lower()
        if value in ("true", "1", "yes", "on"):
            return True
        if value in ("false", "0", "no", "off"):
            return False
        return default

    def __getitem__(self, key: str) -> str:
        """Get a configuration value using dict-style access.

        Args:
            key: Configuration key.

        Returns:
            Configuration value.

        Raises:
            KeyError: If key is not found.
        """
        return self.data[key]

    def __contains__(self, key: str) -> bool:
        """Check if a configuration key exists.

        Args:
            key: Configuration key.

        Returns:
            True if key exists, False otherwise.
        """
        return key in self.data

    def to_dict(self) -> dict[str, str]:
        """Export all configuration as a dictionary.

        Returns:
            Dictionary of all configuration values.
        """
        return dict(self.data)

    def set_value(self, key: str, value: str) -> None:
        """Set a configuration value in memory.

        Note: This does NOT write to the config file. Use save() to persist.

        Args:
            key: Configuration key.
            value: Configuration value.
        """
        self.data[key] = value

    def save(self) -> None:
        """Write current configuration back to file.

        Preserves formatting and comments where possible,
        updates or appends changed values.
        """
        # Read original file to preserve structure
        original_lines = (
            self.config_path.read_text(encoding="utf-8").splitlines(
                keepends=True
            )
        )
        updated_keys: set[str] = set()
        output_lines: list[str] = []

        # Update existing keys
        for line in original_lines:
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                output_lines.append(line)
                continue

            if "=" in stripped:
                key, _ = stripped.split("=", 1)
                key = key.strip()
                if key in self.data:
                    # Preserve indentation and recreate the line
                    indent = len(line) - len(line.lstrip())
                    val = self.data[key]
                    output_lines.append(
                        f"{' ' * indent}{key}='{val}'\n"
                    )
                    updated_keys.add(key)
                    continue

            output_lines.append(line)

        # Append new keys
        for key, value in self.data.items():
            if key not in updated_keys:
                output_lines.append(f'{key}="{value}"\n')

        # Write back
        output_text = "".join(output_lines)
        self.config_path.write_text(output_text, encoding="utf-8")
