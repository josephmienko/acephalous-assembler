#!/usr/bin/env python3
"""Rebuild the ``md5sum.txt`` file for an extracted Ubuntu ISO tree.
Ubuntu installation media includes ``md5sum.txt`` at the ISO root. After files
such as ``grub.cfg`` or ``autoinstall.yaml`` are modified, this script updates
that checksum file so the repacked ISO remains internally consistent.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path


def file_md5(path: Path) -> str:
    """Compute the MD5 checksum for a file.

    Args:
        path: File to hash.

    Returns:
        The hexadecimal MD5 digest for the file contents.
    """
    h = hashlib.md5()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    """Recreate ``md5sum.txt`` for all files in the extracted ISO root.

    Returns:
        Zero on success.
    """
    parser = argparse.ArgumentParser(
        description="Rebuild md5sum.txt for extracted Ubuntu ISO tree"
    )
    parser.add_argument(
        "--root", required=True, help="Extracted ISO root directory"
    )
    args = parser.parse_args()

    root = Path(args.root).expanduser()
    md5sum = root / "md5sum.txt"
    entries: list[str] = []

    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.name == "md5sum.txt":
            continue
        rel = "./" + path.relative_to(root).as_posix()
        entries.append(f"{file_md5(path)}  {rel}")

    md5sum.write_text("\n".join(entries) + "\n", encoding="utf-8")
    print(f"Wrote {md5sum}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
