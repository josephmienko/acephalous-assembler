#!/usr/bin/env python3
"""Render a template file using shell-style key/value config values.

This script reads a simple ``KEY=VALUE`` config file, substitutes matching
``${KEY}`` placeholders in a template file, and writes the rendered result to
an output path.

Uses the ``assembler`` package for config loading and template rendering.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Add lib/python to path to import assembler module
sys.path.insert(0, str(Path(__file__).parent / "python"))

from assembler.config import ConfigManager  # noqa: E402
from assembler.template import TemplateRenderer  # noqa: E402


def main() -> int:
    """Parse arguments and render a template.

    Returns:
        Zero on success.
    """
    parser = argparse.ArgumentParser(
        description="Render a template file from config.env"
    )
    parser.add_argument("--config", required=True,
                        help="Path to config.env")
    parser.add_argument("--template", required=True,
                        help="Path to template file")
    parser.add_argument("--output", required=True,
                        help="Path to output file")
    args = parser.parse_args()

    config_path = Path(args.config).expanduser()
    template_path = Path(args.template).expanduser()
    output_path = Path(args.output).expanduser()

    # Load configuration
    config = ConfigManager(config_path)

    # Render template using the loaded config
    renderer = TemplateRenderer(config)
    renderer.render_to_file(template_path, output_path)

    print(f"Wrote {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
