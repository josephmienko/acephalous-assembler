#!/usr/bin/env python3
"""Patch Debian installer GRUB config for preseed-based automated \
    installation.

The script lowers the boot timeout, ensures the first menu \
    entry is selected by
default, and adds a preseed file argument to automatically \
    load preseed configuration.
"""

from __future__ import annotations

import argparse
from pathlib import Path


PRESEED_ARG_PREFIX = "preseed/file="
AUTO_ARGS = ["auto=true", "priority=critical"]


def _without_existing_preseed(args: list[str]) -> list[str]:
    """Remove existing preseed arguments from a boot argument list."""
    prefixes = (PRESEED_ARG_PREFIX, "preseed/url=")
    return [arg for arg in args if not arg.startswith(prefixes)]


def _with_required_args(args: list[str], preseed_url: str) -> list[str]:
    """Add automated install and preseed arguments if missing."""
    updated = _without_existing_preseed(args)
    for arg in AUTO_ARGS:
        if arg not in updated:
            updated.append(arg)
    if preseed_url:
        updated.append(f"{PRESEED_ARG_PREFIX}{preseed_url}")
    return updated


def patch_linux_line(line: str, preseed_url: str) -> str:
    """Normalize the installer kernel line and add preseed file argument.

    Args:
        line: Original GRUB ``linux`` line.
        preseed_url: File path pointing to preseed configuration file
            (e.g., /cdrom/preseed.cfg).

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
    args = _with_required_args(parts[2:], preseed_url)

    rebuilt = leading + " ".join([command, kernel, *args])
    if has_trailer:
        rebuilt += " ---" + post
    return rebuilt


def patch_append_line(line: str, preseed_url: str) -> str:
    """Patch an isolinux append line with automated install arguments."""
    leading = line[: len(line) - len(line.lstrip())]
    body = line.lstrip()
    if not body.startswith("append "):
        return line

    if " ---" in body:
        pre, _, post = body.partition(" ---")
        has_trailer = True
    else:
        pre = body
        post = ""
        has_trailer = False

    parts = pre.split()
    if not parts:
        return line

    args = _with_required_args(parts[1:], preseed_url)
    rebuilt = leading + " ".join(["append", *args])
    if has_trailer:
        rebuilt += " ---" + post
    return rebuilt


def patch_timeout(text: str) -> str:
    """Lower boot menu timeout and ensure the first entry is default."""
    if "set timeout=30" in text:
        text = text.replace("set timeout=30", "set timeout=1", 1)
    elif "set timeout=10" in text:
        text = text.replace("set timeout=10", "set timeout=1", 1)
    elif "set timeout=" not in text:
        text = "set timeout=1\n" + text

    if "set default=" not in text:
        text = "set default=0\n" + text

    return text


def main() -> int:
    """Apply GRUB changes to an extracted Debian ISO tree.

    Returns:
        Zero on success.

    Raises:
        SystemExit: If the installer kernel line cannot be found.
    """
    parser = argparse.ArgumentParser(
        description="Patch Debian installer grub.cfg \
            for automated preseed installation"
    )
    parser.add_argument(
        "--root",
        required=True,
        help="Extracted ISO root directory",
    )
    parser.add_argument(
        "--preseed-url",
        default="",
        help="File path to preseed configuration file (e.g., \
            /cdrom/preseed.cfg)",
    )
    args = parser.parse_args()

    preseed_url = args.preseed_url

    root = Path(args.root).expanduser()
    grub_cfg = root / "boot/grub/grub.cfg"
    text = patch_timeout(grub_cfg.read_text(encoding="utf-8"))
    lines = text.splitlines()

    # Patch the first installer entry so the default boot path is unattended.
    grub_candidates = [
        i for i, line in enumerate(lines)
        if line.lstrip().startswith("linux")
        and "/install" in line
        and "vmlinuz" in line
    ]

    if not grub_candidates:
        raise SystemExit(
            "Could not find Debian installer linux vmlinuz line in "
            "boot/grub/grub.cfg"
        )

    first_grub_index = grub_candidates[0]
    lines[first_grub_index] = patch_linux_line(
        lines[first_grub_index],
        preseed_url,
    )
    grub_cfg.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Patched {grub_cfg}")

    default_isolinux_files = {"gtk.cfg", "txt.cfg"}
    patched_isolinux = []
    for cfg in (root / "isolinux").glob("*.cfg"):
        cfg_lines = cfg.read_text(encoding="utf-8").splitlines()
        changed = False
        for i, line in enumerate(cfg_lines):
            stripped = line.lstrip()
            if (
                stripped.startswith("append ")
                and "initrd=/install" in stripped
                and (
                    cfg.name in default_isolinux_files
                    or "auto=true" in stripped
                )
            ):
                cfg_lines[i] = patch_append_line(line, preseed_url)
                changed = True
        if changed:
            cfg.write_text("\n".join(cfg_lines) + "\n", encoding="utf-8")
            patched_isolinux.append(cfg)

    for cfg in patched_isolinux:
        print(f"Patched {cfg}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
