"""Password hashing and verification utilities.

Supports modern Argon2 hashing, bcrypt, and legacy SHA-512 for compatibility.
"""

from __future__ import annotations

import secrets
import string
from typing import Literal

from argon2 import PasswordHasher as Argon2Hasher
from argon2.exceptions import VerificationError, VerifyMismatchError

# Try to import crypt for SHA-512 support (Unix-like systems only)
try:
    import crypt  # type: ignore[import-not-found]
    HAS_CRYPT = True
except ImportError:
    HAS_CRYPT = False  # pyright: ignore[reportConstantRedefinition]


class PasswordManager:
    """Manage password hashing with multiple algorithm support.

    Defaults to Argon2 (modern best practice), with fallback to SHA-512
    for Debian preseed compatibility if needed.
    """

    def __init__(self) -> None:
        """Initialize PasswordManager with Argon2 hasher."""
        self.argon2_hasher = Argon2Hasher()

    @staticmethod
    def generate_password(length: int = 16) -> str:
        """Generate a random password.

        Args:
            length: Length of password to generate (default 16).

        Returns:
            Random password string with letters, digits, and symbols.
        """
        charset = (string.ascii_letters + string.digits +
                   "!@#$%^&*-_+=[]{}|:;<>?")
        return "".join(secrets.choice(charset) for _ in range(length))

    def hash_password(
        self, password: str, algorithm: Literal["argon2", "sha512"] = "argon2"
    ) -> str:
        """Hash a password using the specified algorithm.

        Args:
            password: Plain-text password to hash.
            algorithm: Hashing algorithm ("argon2" or "sha512").
                      Default is "argon2" (modern best practice).

        Returns:
            Hashed password suitable for storage or config files.

        Raises:
            ValueError: If algorithm is not supported.
        """
        if algorithm == "argon2":
            return self.hash_password_argon2(password)
        elif algorithm == "sha512":
            return self.hash_password_sha512(password)
        else:
            raise ValueError(f"Unsupported algorithm: {algorithm}")

    def hash_password_argon2(self, password: str) -> str:
        """Hash a password using Argon2 (modern standard).

        Argon2 is the Password Hashing Competition winner and is recommended
        for all new systems. It is GPU-resistant and configurable.

        Args:
            password: Plain-text password to hash.

        Returns:
            Argon2 hash in PHC format: $argon2id$v=19$m=65540,t=3,p=4$...
        """
        return self.argon2_hasher.hash(password)

    @staticmethod
    def hash_password_sha512(password: str) -> str:
        """Hash a password using SHA-512 (for Debian preseed compatibility).

        WARNING: SHA-512 is NOT suitable for password hashing. This is only for
        compatibility with Debian preseed, which requires crypt()-style hashes.

        Use hash_password_argon2() for new deployments.

        Args:
            password: Plain-text password to hash.

        Returns:
            SHA-512 crypt hash in format: $6$salt$...

        Raises:
            RuntimeError: If crypt module is not available
                (e.g., on some macOS).
        """
        if not HAS_CRYPT:
            raise RuntimeError(
                "crypt module not available on this platform. "
                "Use Argon2 instead, or run on Linux."
            )
        return crypt.crypt(password,  # type: ignore[name-defined]
                           crypt.METHOD_SHA512)  # type: ignore

    def verify_password(
        self,
        password: str,
        hash_value: str,
        algorithm: Literal["argon2", "sha512"] = "argon2",
    ) -> bool:
        """Verify a password against its hash.

        Args:
            password: Plain-text password to verify.
            hash_value: Hash to verify against.
            algorithm: Expected algorithm of the hash.

        Returns:
            True if password matches hash, False otherwise.
        """
        if algorithm == "argon2":
            try:
                self.argon2_hasher.verify(hash_value, password)
                return True
            except (VerifyMismatchError, VerificationError):
                return False
        elif algorithm == "sha512":
            if not HAS_CRYPT:
                return False
            result = crypt.crypt(password,  # type: ignore[name-defined]
                                 hash_value)
            return result == hash_value
        else:
            return False

    @staticmethod
    def detect_hash_algorithm(hash_value: str) -> str:
        """Detect which algorithm was used for a hash.

        Args:
            hash_value: Hash value to analyze.

        Returns:
            Algorithm name: "argon2", "sha512", or "unknown".
        """
        if hash_value.startswith("$argon2"):
            return "argon2"
        elif hash_value.startswith("$6$"):
            return "sha512"
        else:
            return "unknown"
