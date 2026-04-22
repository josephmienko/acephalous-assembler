"""Template rendering utilities.

Renders configuration-driven templates with variable substitution.
"""

from __future__ import annotations

import re
from pathlib import Path

from .config import ConfigManager


class TemplateRenderer:
    """Render templates by substituting ${VARIABLE} placeholders.

    Compatible with shell-style variable substitution.
    """

    def __init__(self, config: ConfigManager) -> None:
        """Initialize TemplateRenderer with a ConfigManager.

        Args:
            config: ConfigManager instance with loaded configuration.
        """
        self.config = config

    def render(self, template_text: str) -> str:
        """Render a template string by substituting placeholders.

        Replaces ${KEY} placeholders with values from the config.

        Args:
            template_text: Template text containing ${VARIABLE} placeholders.

        Returns:
            Rendered text with variables substituted.

        Raises:
            KeyError: If a referenced variable is missing from config.
        """

        def repl(match: re.Match[str]) -> str:
            key = match.group(1)
            if key not in self.config:
                raise KeyError(f"Missing template variable: {key}")
            return self.config[key]

        return re.sub(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}", repl, template_text)

    def render_file(self, template_path: Path | str) -> str:
        """Render a template file.

        Args:
            template_path: Path to the template file.

        Returns:
            Rendered content.

        Raises:
            FileNotFoundError: If template file does not exist.
            KeyError: If a variable is missing from config.
        """
        template_path = Path(template_path)
        return self.render(template_path.read_text(encoding="utf-8"))

    def render_to_file(
        self,
        template_path: Path | str,
        output_path: Path | str,
    ) -> None:
        """Render a template file and write to output.

        Args:
            template_path: Path to the template file.
            output_path: Path where rendered output will be written.

        Raises:
            FileNotFoundError: If template file does not exist.
            KeyError: If a variable is missing from config.
        """
        output_path = Path(output_path)
        rendered = self.render_file(template_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(rendered, encoding="utf-8")
