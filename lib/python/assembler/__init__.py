"""Acephalous Assembler - Automated Linux ISO and disk image builder.

Core modules for configuration management, password hashing, and template
rendering.
"""

__version__ = "0.4.0"

from .config import ConfigManager
from .password import PasswordManager

__all__ = ["ConfigManager", "PasswordManager"]
