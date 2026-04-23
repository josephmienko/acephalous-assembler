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

    def test_debian_preseed_renders_cloud_init_seed(self) -> None:
        """Debian preseed should seed cloud-init for first boot."""
        repo_root = Path(__file__).parent.parent
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_file.write_text(
                "\n".join([
                    'HOSTNAME="debian-host"',
                    'USERNAME="debian"',
                    'PASSWORD_HASH="\\$6\\$salt\\$hash"',
                    'DEBIAN_SUITE="trixie"',
                    'STATUS_IP="192.168.0.15"',
                    'STATUS_PORT="8081"',
                ])
            )

            config = ConfigManager(config_file)
            renderer = TemplateRenderer(config)
            rendered = renderer.render_file(
                repo_root / "debian" / "templates" / "preseed.template"
            )

            assert "/debian-install-status" in rendered
            assert "/first-boot/debian-debian-host/" in rendered
            assert 'status":"selected_disk"' in rendered
            assert 'debconf-set partman-auto/disk "$target_disk"' in rendered
            assert "d-i partman-auto/method string regular" in rendered
            assert "d-i partman-auto/choose_recipe select atomic" in rendered
            assert "d-i partman-partitioning/confirm_write_new_label boolean true" in rendered
            assert "d-i partman/confirm_nooverwrite boolean true" in rendered
            assert "d-i pkgsel/include string openssh-server cloud-init curl" in rendered
            assert "write_files:" in rendered
            assert "/run/acephalous-runcmd-status.json" in rendered
            assert "  - [ mkdir, -p, /var/lib/acephalous-assembler ]" in rendered
            assert "  - [ touch, /var/lib/acephalous-assembler/bootstrap-complete ]" in rendered
            assert "--data-binary @/run/acephalous-runcmd-status.json" in rendered
            assert '- curl -fsS -m 15 -X POST -H "Content-Type: application/json"' not in rendered
            assert "/var/lib/cloud/seed/nocloud/user-data" in rendered
            assert "/var/lib/cloud/seed/nocloud/meta-data" in rendered
            assert "datasource_list: [ NoCloud, None ]" in rendered
            assert "phone_home:" in rendered
            assert "runcmd:" in rendered
            assert "acephalous-status-callback.sh" not in rendered
            assert "acephalous-bootstrap-complete.service" not in rendered

    def test_haos_callback_renders_status_endpoint(self) -> None:
        """HAOS callback should use STATUS_IP and post homeassistant-ready."""
        repo_root = Path(__file__).parent.parent
        with TemporaryDirectory() as tmpdir:
            config_file = Path(tmpdir) / "config.env"
            config_file.write_text(
                "\n".join([
                    'HOSTNAME="homeassistant"',
                    'STATUS_IP="192.168.0.15"',
                    'STATUS_PORT="8081"',
                ])
            )

            config = ConfigManager(config_file)
            renderer = TemplateRenderer(config)
            rendered = renderer.render_file(
                repo_root
                / "haos"
                / "templates"
                / "ha-status-callback.sh.template"
            )

            assert "http://192.168.0.15:8081/homeassistant-ready" in rendered
            assert '\\"variant\\": \\"haos\\"' in rendered
            assert "${HA_STATUS_IP" not in rendered
