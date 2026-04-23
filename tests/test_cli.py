"""Tests for directly executing the assembler CLI module."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


def test_cli_direct_execution_imports_package() -> None:
    """Direct execution should work without PYTHONPATH or Poetry."""
    repo_root = Path(__file__).resolve().parent.parent
    cli_path = repo_root / "lib" / "python" / "assembler" / "cli.py"
    env = os.environ.copy()
    env.pop("PYTHONPATH", None)

    result = subprocess.run(
        [sys.executable, str(cli_path), "--help"],
        cwd=repo_root,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0
    assert "Password generation and hashing utility" in result.stdout
