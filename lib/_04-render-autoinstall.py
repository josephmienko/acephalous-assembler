#!/usr/bin/env python3
"""Render an Ubuntu autoinstall file from a template and environment config.

This script reads a simple ``KEY=VALUE`` config file, substitutes matching
``${KEY}`` placeholders in a template file, and writes the rendered result to
the requested output path.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


def load_config(path: Path) -> dict[str, str]:
    """Load shell-style key-value pairs from a config file.

    The parser accepts one ``KEY=VALUE`` pair per line. Blank lines and comment
    lines that start with ``#`` are ignored. Matching single or double quotes
    around values are removed.

    Args:
        path: Path to the config file to parse.

    Returns:
        A dictionary mapping config keys to string values.
    """
    data: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
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
        template: Template text containing placeholder variables.
        values: Mapping of placeholder names to replacement values.

    Returns:
        The rendered template text.

    Raises:
        KeyError: If the template references a variable that is not present in
            ``values``.
    """

    def repl(match: re.Match[str]) -> str:
        """Return the replacement value for a matched placeholder.

        Args:
            match: Regular-expression match containing a placeholder name.

        Returns:
            The replacement string for the matched placeholder.

        Raises:
            KeyError: If the placeholder name does not exist in ``values``.
        """
        key = match.group(1)
        if key not in values:
            raise KeyError(f"Missing template variable: {key}")
        return values[key]

    return re.sub(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}", repl, template)


def main() -> int:
    """Parse command-line arguments and render the autoinstall file.

    Returns:
        Zero on success.
    """
    parser = argparse.ArgumentParser(
        description="Render autoinstall.yaml from config.env"
        )
    parser.add_argument("--config", required=True)
    parser.add_argument("--template", required=True)
    parser.add_argument("--output", required=True)
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
