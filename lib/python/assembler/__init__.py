"""Acephalous Assembler - Automated Linux ISO and disk image builder.

Core modules for configuration management, password hashing, template
rendering, and build orchestration.
"""

__version__ = "0.4.0"

from .config import ConfigManager

__all__ = [
    "ConfigManager",
    "PasswordManager",
    "WorkflowContext",
    "BuildOrchestrator",
    "FlashOperation",
    "FlashValidator",
]


def __getattr__(name: str) -> object:
    """Load optional modules only when requested."""
    if name == "PasswordManager":
        from .password import PasswordManager

        return PasswordManager
    elif name == "WorkflowContext":
        from .build import WorkflowContext

        return WorkflowContext
    elif name == "BuildOrchestrator":
        from .build import BuildOrchestrator

        return BuildOrchestrator
    elif name == "FlashOperation":
        from .build import FlashOperation

        return FlashOperation
    elif name == "FlashValidator":
        from .build import FlashValidator

        return FlashValidator
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
