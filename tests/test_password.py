"""Tests for password management module."""

from __future__ import annotations

import sys
from pathlib import Path

# Add lib/python to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / "lib" / "python"))

import pytest  # noqa: E402

from assembler.password import (  # noqa: E402
    HAS_CRYPT,
    PasswordManager,
)


class TestPasswordManager:
    """Test cases for PasswordManager."""

    def test_generate_password_length(self) -> None:
        """Test password generation with custom length."""
        pwd = PasswordManager.generate_password(length=20)
        assert len(pwd) == 20

    def test_generate_password_default_length(self) -> None:
        """Test password generation with default length."""
        pwd = PasswordManager.generate_password()
        assert len(pwd) == 16

    def test_hash_password_argon2(self) -> None:
        """Test Argon2 password hashing."""
        pm = PasswordManager()
        hash_value = pm.hash_password("test_password", algorithm="argon2")
        assert hash_value.startswith("$argon2")

    @pytest.mark.skipif(not HAS_CRYPT, reason="crypt module not available")
    def test_hash_password_sha512(self) -> None:
        """Test SHA-512 password hashing."""
        hash_value = PasswordManager.hash_password_sha512("test_password")
        assert hash_value.startswith("$6$")

    def test_verify_password_argon2(self) -> None:
        """Test password verification with Argon2."""
        pm = PasswordManager()
        password = "test_password"
        hash_value = pm.hash_password(password, algorithm="argon2")
        assert pm.verify_password(password, hash_value,  # noqa: E501
                                  algorithm="argon2")
        assert not pm.verify_password("wrong_password", hash_value,  # noqa: E501
                                      algorithm="argon2")

    @pytest.mark.skipif(not HAS_CRYPT, reason="crypt module not available")
    def test_verify_password_sha512(self) -> None:
        """Test password verification with SHA-512."""
        pm = PasswordManager()
        password = "test_password"
        hash_value = pm.hash_password(password, algorithm="sha512")
        assert pm.verify_password(password, hash_value,
                                  algorithm="sha512")
        assert not pm.verify_password("wrong_password", hash_value,
                                      algorithm="sha512")

    def test_detect_hash_algorithm_argon2(self) -> None:
        """Test algorithm detection for Argon2."""
        pm = PasswordManager()
        hash_value = pm.hash_password("test", algorithm="argon2")
        assert PasswordManager.detect_hash_algorithm(hash_value) == "argon2"

    @pytest.mark.skipif(not HAS_CRYPT, reason="crypt module not available")
    def test_detect_hash_algorithm_sha512(self) -> None:
        """Test algorithm detection for SHA-512."""
        hash_value = PasswordManager.hash_password_sha512("test")
        assert PasswordManager.detect_hash_algorithm(hash_value) == "sha512"

    def test_detect_hash_algorithm_unknown(self) -> None:
        """Test algorithm detection for unknown hash."""
        assert PasswordManager.detect_hash_algorithm("not_a_hash") == "unknown"

    def test_unsupported_algorithm(self) -> None:
        """Test that unsupported algorithms raise ValueError."""
        pm = PasswordManager()
        with pytest.raises(ValueError):
            pm.hash_password("test", algorithm="unsupported")
