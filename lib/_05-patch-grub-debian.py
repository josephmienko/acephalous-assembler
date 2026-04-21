#!/usr/bin/env python3
"""Patch Debian installer GRUB config for preseed-based automated installation.

The script lowers the boot timeout, ensures the first menu entry is selected by
default, and adds a preseed URL argument to automatically load preseed configuration.
"""

from __future__ import annotations

import argparse
from pathlib import Path


PRESEED_ARG_PREFIX = "preseed/url="


def patch_linux_line(line: str, preseed_url: str) -> str:
    """Normalize the installer kernel line and add preseed URL argument.

    Args:
        line: Original GRUB ``linux`` line.
        preseed_url: URL pointing to preseed configuration file.

    Returns:
        Patched GRUB ``linux`` line.
    """
    leading = line[: len(line) - len(line.lstrip())]
    body = line.lstrip()

    if " ---" in body:
        pre, _, post = body.partition(" ---")
        has_trailer = True
    else:
        pre = body
        post = ""
        has_trailer = False

    parts = pre.split()
    if len(parts) < 2:
        return line

    command = parts[0]
    kernel = parts[1]
    # Remove existing preseed arguments
    args = [
        arg
        for arg in parts[2:]
        if not arg.startswith(PRESEED_ARG_PREFIX)
    ]

    # Add preseed URL argument
    if preseed_url:
        args.append(f"{PRESEED_ARG_PREFIX}{preseed_url}")

    rebuilt = leading + " ".join([command, kernel, *args])
    if has_trailer:
        rebuilt += " ---" + post
    return rebuilt


def main() -> int:
    """Apply GRUB changes to an extracted Debian ISO tree.

    Returns:
        Zero on success.

    Raises:
        SystemExit: If the installer kernel line cannot be found.
    """
    parser = argparse.ArgumentParser(
        description="Patch Debian installer grub.cfg for automated preseed installation"
    )
    parser.add_argument(
        "--root",
        required=True,
        help="Extracted ISO root directory",
    )
    parser.add_argument(
        "--preseed-url",
        default="",
        help="URL to preseed configuration file (e.g., file:///cdrom/preseed.cfg)",
    )
    args = parser.parse_args()

    preseed_url = args.preseed_url

    root = Path(args.root).expanduser()
    grub_cfg = root / "boot/grub/grub.cfg"
    text = grub_cfg.read_text(encoding="utf-8")

    # Lower boot timeout
    if "set timeout=30" in text:
        text = text.replace("set timeout=30", "set timeout=1", 1)
    elif "set timeout=10" in text:
        text = text.replace("set timeout=10", "set timeout=1", 1)
    elif "set timeout=" not in text:
        text = "set timeout=1\n" + text

    # Set default boot entry
    if "set default=" not in text:
        text = "set default=0\n" + text

    lines = text.splitlines()
    patched = False
    for i, line in enumerate(lines):
        stripped = line.lstrip()
        if (
            stripped.startswith("linux")
            and "/install/vmlinuz" in stripped
            and not patched
        ):
            lines[i] = patch_linux_line(line, preseed_url)
            patched = True

    if not patched:
        raise SystemExit(
            "Could not find linux /install/vmlinuz line in boot/grub/grub.cfg"
        )

    grub_cfg.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Patched {grub_cfg}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
