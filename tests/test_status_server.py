"""Tests for the install status HTTP server."""

from __future__ import annotations

import http.client
import importlib.util
import json
import sys
import threading
from http.server import ThreadingHTTPServer
from pathlib import Path
from tempfile import TemporaryDirectory
from types import ModuleType


def load_status_server_module() -> ModuleType:
    """Load the status server script as a module for testing."""
    repo_root = Path(__file__).resolve().parent.parent
    module_path = repo_root / "lib" / "_992-install-status-server.py"
    spec = importlib.util.spec_from_file_location(
        "install_status_server",
        module_path,
    )
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def test_status_server_accepts_debian_and_haos_paths() -> None:
    """Arbitrary variant callback paths should be accepted and displayed."""
    module = load_status_server_module()

    with TemporaryDirectory() as tmpdir:
        store = module.EventStore(Path(tmpdir) / "events.jsonl")
        handler = module.make_handler(store)
        server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        port = server.server_address[1]
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()

        try:
            for path, variant in (
                ("/debian-install-status", "debian"),
                ("/homeassistant-ready", "haos"),
            ):
                conn = http.client.HTTPConnection("127.0.0.1", port)
                conn.request(
                    "POST",
                    path,
                    body=json.dumps({"variant": variant}),
                    headers={"Content-Type": "application/json"},
                )
                response = conn.getresponse()
                assert response.status == 200
                response.read()
                conn.close()

            assert store.count() == 2
            paths = [event.path for event in store.latest()]
            assert paths == ["/debian-install-status", "/homeassistant-ready"]

            conn = http.client.HTTPConnection("127.0.0.1", port)
            conn.request("GET", "/")
            response = conn.getresponse()
            page = response.read().decode("utf-8")
            conn.close()

            assert response.status == 200
            assert "Acephalous install status" in page
            assert "/debian-install-status" in page
            assert "/homeassistant-ready" in page
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)
