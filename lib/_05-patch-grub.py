#!/usr/bin/env python3
"""Patch Ubuntu installer GRUB config for unattended autoinstall booting.

The script lowers the boot timeout, ensures the first menu entry is selected by
default, and adds the ``autoinstall`` kernel argument to the installer entry.
"""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> int:
    """Apply zero-touch autoinstall changes to an extracted ISO tree.

    Returns:
        Zero on success.

    Raises:
        SystemExit: If the expected installer kernel line cannot be
            found in the GRUB configuration.
    """
    parser = argparse.ArgumentParser(
        description="Patch Ubuntu installer grub.cfg for "
        "zero-touch autoinstall"
    )
    parser.add_argument(
        "--root",
        required=True,
        help="Extracted ISO root directory",
    )
    args = parser.parse_args()

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
        has_linux = stripped.startswith("linux")
        has_vmlinuz = "/casper/vmlinuz" in stripped
        no_autoinstall = "autoinstall" not in stripped
        if has_linux and has_vmlinuz and no_autoinstall and not patched:
            if " ---" in line:
                lines[i] = line.replace(" ---", " autoinstall ---", 1)
            else:
                lines[i] = line + " autoinstall"
            patched = True

    if not patched:
        raise SystemExit(
            "Could not find linux /casper/vmlinuz line in "
            "boot/grub/grub.cfg"
        )

    grub_cfg.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Patched {grub_cfg}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
