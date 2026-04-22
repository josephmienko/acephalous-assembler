"""Tests for configuration management module."""

from __future__ import annotations

import sys
from pathlib import Path
from tempfile import TemporaryDirectory

# Add lib/python to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / "lib" / "python"))

import pytest  # noqa: E402

from assembler.config import ConfigManager  # noqa: E402


class TestConfigManager:
    """Test cases for ConfigManager."""

    def test_load_config_basic(self) -> None:
        """Test loading a basic config file."""
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_file.write_text("KEY1=value1\nKEY2=value2\n")

            config = ConfigManager(config_file)
            assert config.get("KEY1") == "value1"
            assert config.get("KEY2") == "value2"

    def test_load_config_with_quotes(self) -> None:
        """Test loading config with quoted values."""
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_file.write_text(
                'KEY1="value with spaces"\nKEY2=\'single quotes\'\n'
            )

            config = ConfigManager(config_file)
            assert config.get("KEY1") == "value with spaces"  # noqa: E501
            assert config.get("KEY2") == "single quotes"

    def test_load_config_with_comments(self) -> None:
        """Test loading config with comments."""
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_text = (
                "# This is a comment\nKEY1=value1\n"
                "# Another comment\n"
            )
            config_file.write_text(config_text)

            config = ConfigManager(config_file)
            assert config.get("KEY1") == "value1"

    def test_missing_config_file(self) -> None:
        """Test that FileNotFoundError is raised for missing file."""
        with pytest.raises(FileNotFoundError):
            ConfigManager(Path("/nonexistent/config.env"))

    def test_get_with_default(self) -> None:
        """Test get with default value."""
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_file.write_text("KEY1=value1\n")

            config = ConfigManager(config_file)
            assert config.get("KEY1") == "value1"
            assert config.get("MISSING", "default") == "default"

    def test_get_int(self) -> None:
        """Test getting integer values."""
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_file.write_text("PORT=8080\nINVALID=notanumber\n")

            config = ConfigManager(config_file)
            assert config.get_int("PORT") == 8080
            assert config.get_int("MISSING", 9000) == 9000
            assert config.get_int("INVALID", 9000) == 9000

    def test_get_bool(self) -> None:
        """Test getting boolean values."""
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_text = (
                "ENABLED=true\nDISABLED=false\nYES=yes\nNO=no\n"
                "ON=on\nOFF=off\n"
            )
            config_file.write_text(config_text)

            config = ConfigManager(config_file)
            assert config.get_bool("ENABLED") is True
            assert config.get_bool("DISABLED") is False
            assert config.get_bool("YES") is True
            assert config.get_bool("NO") is False
            assert config.get_bool("ON") is True
            assert config.get_bool("OFF") is False
            assert config.get_bool("MISSING", True) is True

    def test_dict_access(self) -> None:
        """Test dict-style access."""
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_file.write_text("KEY1=value1\n")

            config = ConfigManager(config_file)
            assert config["KEY1"] == "value1"
            with pytest.raises(KeyError):
                _ = config["NONEXISTENT"]

    def test_contains(self) -> None:
        """Test 'in' operator."""
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_file.write_text("KEY1=value1\n")

            config = ConfigManager(config_file)
            assert "KEY1" in config
            assert "MISSING" not in config

    def test_to_dict(self) -> None:
        """Test conversion to dictionary."""
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_file.write_text("KEY1=value1\nKEY2=value2\n")

            config = ConfigManager(config_file)
            config_dict = config.to_dict()
            assert config_dict == {"KEY1": "value1", "KEY2": "value2"}

    def test_set_and_save(self) -> None:
        """Test setting values and saving."""
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_file.write_text("KEY1=value1\nKEY2=value2\n")

            config = ConfigManager(config_file)
            config.set_value("KEY1", "new_value")
            config.set_value("KEY3", "value3")
            config.save()

            # Reload and check
            config2 = ConfigManager(config_file)
            assert config2.get("KEY1") == "new_value"
            assert config2.get("KEY2") == "value2"
            assert config2.get("KEY3") == "value3"
