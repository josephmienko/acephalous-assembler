#!/usr/bin/env python3
"""Patch Ubuntu installer GRUB config for autoinstall booting.

The script lowers the boot timeout, ensures the first menu entry is selected by
default, and optionally adds a local NoCloud datasource path for temporary live
installer SSH credentials.
"""

from __future__ import annotations

import argparse
from pathlib import Path


SEED_ARG = r"ds=nocloud\;s=/cdrom/nocloud/"


def patch_linux_line(line: str, include_nocloud: bool) -> str:
    """Normalize the installer kernel line and add required arguments.

    Args:
        line: Original GRUB ``linux`` line.
        include_nocloud: Whether to add the NoCloud datasource argument.

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
    args = [
        arg
        for arg in parts[2:]
        if arg != "autoinstall" and not arg.startswith("ds=nocloud")
    ]
    args.append("autoinstall")
    if include_nocloud:
        args.append(SEED_ARG)

    rebuilt = leading + " ".join([command, kernel, *args])
    if has_trailer:
        rebuilt += " ---" + post
    return rebuilt


def main() -> int:
    """Apply GRUB changes to an extracted ISO tree.

    Returns:
        Zero on success.

    Raises:
        SystemExit: If the installer kernel line cannot be found.
    """
    parser = argparse.ArgumentParser(
        description="Patch Ubuntu installer grub.cfg for autoinstall booting"
    )
    parser.add_argument(
        "--root",
        required=True,
        help="Extracted ISO root directory",
    )
    parser.add_argument(
        "--include-nocloud",
        choices=["true", "false"],
        default="false",
        help="Whether to add the NoCloud datasource path",
    )
    args = parser.parse_args()

    include_nocloud = args.include_nocloud == "true"

    root = Path(args.root).expanduser()
    grub_cfg = root / "boot/grub/grub.cfg"
    text = grub_cfg.read_text(encoding="utf-8")

    if "set timeout=30" in text:
        text = text.replace("set timeout=30", "set timeout=1", 1)
    elif "set timeout=10" in text:
        text = text.replace("set timeout=10", "set timeout=1", 1)
    elif "set timeout=" not in text:
        text = "set timeout=1\n" + text

    if "set default=" not in text:
        text = "set default=0\n" + text

    lines = text.splitlines()
    patched = False
    for i, line in enumerate(lines):
        stripped = line.lstrip()
        if (
            stripped.startswith("linux")
            and "/casper/vmlinuz" in stripped
            and not patched
        ):
            lines[i] = patch_linux_line(line, include_nocloud)
            patched = True

    if not patched:
        raise SystemExit(
            "Could not find linux /casper/vmlinuz line in boot/grub/grub.cfg"
        )

    grub_cfg.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Patched {grub_cfg}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
