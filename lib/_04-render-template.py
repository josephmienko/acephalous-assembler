#!/usr/bin/env python3
"""Render a template file using shell-style key/value config values.

This script reads a simple ``KEY=VALUE`` config file, substitutes matching
``${KEY}`` placeholders in a template file, and writes the rendered result to
an output path.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


def load_config(path: Path) -> dict[str, str]:
    """Load shell-style key-value pairs from a config file.

    Args:
        path: Path to the config file.

    Returns:
        Mapping of config keys to string values.
    """
    data: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if (
            (value.startswith('"') and value.endswith('"'))
            or (value.startswith("'") and value.endswith("'"))
        ):
            value = value[1:-1]
        data[key] = value
    return data


def render_template(template: str, values: dict[str, str]) -> str:
    """Substitute ``${NAME}`` placeholders in a template string.

    Args:
        template: Template text containing placeholders.
        values: Placeholder values.

    Returns:
        Rendered text.

    Raises:
        KeyError: If a referenced placeholder is missing.
    """

    def repl(match: re.Match[str]) -> str:
        """Return the replacement value for a matched placeholder.

        Args:
            match: Regex match object containing a placeholder name.

        Returns:
            Replacement text for the placeholder.
        """
        key = match.group(1)
        if key not in values:
            raise KeyError(f"Missing template variable: {key}")
        return values[key]

    return re.sub(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}", repl, template)


def main() -> int:
    """Parse arguments and render a template.

    Returns:
        Zero on success.
    """
    parser = argparse.ArgumentParser(
        description="Render a template file from config.env"
    )
    parser.add_argument("--config", required=True, help="Path to config.env")
    parser.add_argument("--template", required=True, help="Path to template file")
    parser.add_argument("--output", required=True, help="Path to output file")
    args = parser.parse_args()

    config = load_config(Path(args.config).expanduser())
    template = Path(args.template).expanduser().read_text(encoding="utf-8")
    rendered = render_template(template, config)

    output_path = Path(args.output).expanduser()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered, encoding="utf-8")
    print(f"Wrote {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
