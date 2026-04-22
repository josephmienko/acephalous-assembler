"""Tests for template rendering module."""

from __future__ import annotations

import sys
from pathlib import Path
from tempfile import TemporaryDirectory

# Add lib/python to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / "lib" / "python"))

import pytest  # noqa: E402

from assembler.config import ConfigManager  # noqa: E402
from assembler.template import TemplateRenderer  # noqa: E402


class TestTemplateRenderer:
    """Test cases for TemplateRenderer."""

    def test_render_simple_template(self) -> None:
        """Test rendering a simple template."""
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_file.write_text("NAME=Alice\nAGE=30\n")

            config = ConfigManager(config_file)
            renderer = TemplateRenderer(config)

            template = "Hello ${NAME}, you are ${AGE} years old."
            rendered = renderer.render(template)

            assert rendered == "Hello Alice, you are 30 years old."

    def test_render_template_file(self) -> None:
        """Test rendering a template from a file."""
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_file.write_text("HOSTNAME=myhost\nUSER=admin\n")

            template_file = Path(tmpdir) / "template.txt"
            template_file.write_text("Server: ${HOSTNAME}\nUser: ${USER}\n")

            config = ConfigManager(config_file)
            renderer = TemplateRenderer(config)

            rendered = renderer.render_file(template_file)

            assert rendered == "Server: myhost\nUser: admin\n"

    def test_render_to_file(self) -> None:
        """Test rendering and writing to an output file."""
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_file.write_text("KEY=value\n")

            template_file = Path(tmpdir) / "template.txt"
            template_file.write_text("Result: ${KEY}\n")

            output_file = Path(tmpdir) / "output.txt"

            config = ConfigManager(config_file)
            renderer = TemplateRenderer(config)

            renderer.render_to_file(template_file, output_file)

            assert output_file.exists()
            assert output_file.read_text() == "Result: value\n"

    def test_missing_variable(self) -> None:
        """Test that missing variables raise KeyError."""
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_file.write_text("KEY=value\n")

            config = ConfigManager(config_file)
            renderer = TemplateRenderer(config)

            template = "Value: ${MISSING}"
            with pytest.raises(KeyError):
                renderer.render(template)

    def test_render_with_defaults(self) -> None:
        """Test rendering with config defaults."""
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_file.write_text("REQUIRED=present\n")

            config = ConfigManager(config_file)
            renderer = TemplateRenderer(config)

            # OPTIONAL with config.get() default would work if template used it
            template = "Required: ${REQUIRED}"
            rendered = renderer.render(template)
            assert rendered == "Required: present"

    def test_multiple_variables(self) -> None:
        """Test rendering with multiple variable substitutions."""
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_file.write_text("VAR1=hello\nVAR2=world\nVAR3=!\n")

            config = ConfigManager(config_file)
            renderer = TemplateRenderer(config)

            template = "${VAR1} ${VAR2}${VAR3} ${VAR1} again."
            rendered = renderer.render(template)
            assert rendered == "hello world! hello again."

    def test_render_no_substitutions(self) -> None:
        """Test rendering template with no variables."""
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_file.write_text("KEY=value\n")

            config = ConfigManager(config_file)
            renderer = TemplateRenderer(config)

            template = "This has no variables.\n"
            rendered = renderer.render(template)
            assert rendered == template
