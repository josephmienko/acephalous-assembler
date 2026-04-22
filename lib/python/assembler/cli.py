#!/usr/bin/env python3
"""CLI tool for password generation and hashing.

Used by setup.sh scripts to generate and manage password hashes.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Add parent to path to import assembler module
sys.path.insert(0, str(Path(__file__).parent))

from assembler.config import ConfigManager  # noqa: E402
from assembler.password import PasswordManager  # noqa: E402


def generate_hash(args: argparse.Namespace) -> int:
    """Generate a password hash."""
    pm = PasswordManager()

    # Generate password if not provided
    if args.password:
        password = args.password
    else:
        password = PasswordManager.generate_password(args.length)

    # Generate hash
    hash_value = pm.hash_password(password, algorithm=args.algorithm)

    if args.verbose:
        print(f"Password: {password}")
        print(f"Algorithm: {args.algorithm}")
    print(hash_value)

    return 0


def set_in_config(args: argparse.Namespace) -> int:
    """Generate hash and set in config.env."""
    config = ConfigManager(args.config)
    pm = PasswordManager()

    # Generate password if not provided
    if args.password:
        password = args.password
    else:
        password = PasswordManager.generate_password(args.length)

    # Generate hash
    hash_value = pm.hash_password(password, algorithm=args.algorithm)

    # Update config
    config.set_value(args.key, hash_value)
    config.save()

    if args.verbose:
        print(f"Password: {password}")
        print(f"Algorithm: {args.algorithm}")
        print(f"Config key: {args.key}")
    print(f"Updated {args.config}: {args.key}=***")

    return 0


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Password generation and hashing utility",
    )
    subparsers = parser.add_subparsers(dest="command", help="Subcommand")

    # Subcommand: hash
    hash_cmd = subparsers.add_parser("hash", help="Generate a password hash")
    hash_cmd.add_argument(
        "-p",
        "--password",
        help="Password to hash (if not provided, generates random)",
    )
    hash_cmd.add_argument(
        "-a",
        "--algorithm",
        choices=["argon2", "sha512"],
        default="argon2",
        help="Hashing algorithm (default: argon2)",
    )
    hash_cmd.add_argument(
        "-l", "--length", type=int, default=16,
        help="Length of generated password"
    )
    hash_cmd.add_argument("-v", "--verbose", action="store_true",
                          help="Verbose output")
    hash_cmd.set_defaults(func=generate_hash)

    # Subcommand: set-config
    set_cmd = subparsers.add_parser(
        "set-config",
        help="Generate hash and set in config file",
    )
    set_cmd.add_argument("config", help="Path to config.env file")
    set_cmd.add_argument(
        "-k",
        "--key",
        default="PASSWORD_HASH",
        help="Config key to set (default: PASSWORD_HASH)",
    )
    set_cmd.add_argument(
        "-p",
        "--password",
        help="Password to hash (if not provided, generates random)",
    )
    set_cmd.add_argument(
        "-a",
        "--algorithm",
        choices=["argon2", "sha512"],
        default="argon2",
        help="Hashing algorithm (default: argon2)",
    )
    set_cmd.add_argument(
        "-l", "--length", type=int, default=16,
        help="Length of generated password"
    )
    set_cmd.add_argument("-v", "--verbose", action="store_true",
                         help="Verbose output")
    set_cmd.set_defaults(func=set_in_config)

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        return 1

    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
