#!/usr/bin/env python3
"""Receive and display Ubuntu autoinstall status callbacks.

This server accepts POST requests from Ubuntu autoinstall's ``reporting``
webhook and cloud-init's ``phone_home`` feature. It stores each event as
line-delimited JSON and serves a small HTML status page for quick inspection.
"""

from __future__ import annotations

import argparse
import html
import json
import logging
import os
import sys
import threading
import time
from dataclasses import dataclass, asdict
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse


@dataclass
class Event:
    """Represent a single received webhook or phone-home event.

    Attributes:
        ts: Event timestamp as seconds since the Unix epoch.
        path: Requested HTTP path.
        content_type: Incoming request content type.
        remote: Remote client IP address.
        payload: Parsed request body content.
    """

    ts: float
    path: str
    content_type: str
    remote: str
    payload: Any


class EventStore:
    """Store received events in memory and append them to a JSONL log file."""

    def __init__(self, logfile: Path) -> None:
        """Initialize a thread-safe event store.

        Args:
            logfile: Path to the line-delimited JSON event log file.
        """
        self.logfile = logfile
        self._lock = threading.Lock()
        self._events: list[Event] = []

    def add(self, event: Event) -> None:
        """Persist a newly received event.

        Args:
            event: Event to store in memory and append to disk.
        """
        with self._lock:
            self._events.append(event)
            self.logfile.parent.mkdir(parents=True, exist_ok=True)
            with self.logfile.open("a", encoding="utf-8") as f:
                f.write(json.dumps(asdict(event), ensure_ascii=False) + "\n")

    def latest(self, limit: int = 100) -> list[Event]:
        """Return the most recent stored events.

        Args:
            limit: Maximum number of events to return.

        Returns:
            A list containing up to ``limit`` most recent events.
        """
        with self._lock:
            return list(self._events[-limit:])

    def count(self) -> int:
        """Count currently stored events.

        Returns:
            The number of events currently held in memory.
        """
        with self._lock:
            return len(self._events)


def make_handler(store: EventStore):
    """Create an HTTP request handler bound to the given event store.

    Args:
        store: Event store used to persist received requests.

    Returns:
        A ``BaseHTTPRequestHandler`` subclass that serves the status endpoints.
    """

    class Handler(BaseHTTPRequestHandler):
        """Serve webhook ingestion, health, and status-page requests."""

        server_version = "InstallStatusServer/1.0"

        def log_message(self, format: str, *args: object) -> None:
            """Route HTTP request log lines through the standard logger.

            Args:
                format: Log format string from ``BaseHTTPRequestHandler``.
                *args: Positional values interpolated into ``format``.
            """
            logging.info("%s - %s", self.address_string(), format % args)

        def _read_body(self) -> bytes:
            """Read the full request body from the current HTTP request.

            Returns:
                Raw request body bytes.
            """
            length = int(self.headers.get("Content-Length", "0"))
            return self.rfile.read(length)

        def _parse_payload(self, body: bytes) -> Any:
            """Parse an incoming request body based on its content type.

            Args:
                body: Raw request body bytes.

            Returns:
                Parsed JSON or form data when possible, otherwise a dictionary
                containing the raw decoded body.
            """
            ctype = (
                self.headers.get("Content-Type", "")
                .split(";", 1)[0]
                .strip()
                .lower()
            )
            text = body.decode("utf-8", errors="replace")
            if not body:
                return {}
            if ctype == "application/json":
                try:
                    return json.loads(text)
                except json.JSONDecodeError:
                    return {"_raw": text}
            if ctype == "application/x-www-form-urlencoded":
                parsed = parse_qs(text, keep_blank_values=True)
                return {
                    k: v if len(v) != 1 else v[0]
                    for k, v in parsed.items()
                }
            return {"_raw": text}

        def _store_event(self, payload: Any) -> None:
            """Create and store an ``Event`` from the current request.

            Args:
                payload: Parsed request payload to persist.
            """
            event = Event(
                ts=time.time(),
                path=self.path,
                content_type=self.headers.get("Content-Type", ""),
                remote=self.client_address[0],
                payload=payload,
            )
            store.add(event)
            payload_json = json.dumps(
                payload, ensure_ascii=False
            )
            logging.info(
                "event path=%s payload=%s",
                self.path,
                payload_json,
            )

        def do_post(self) -> None:
            """Accept and acknowledge an incoming status callback."""
            body = self._read_body()
            payload = self._parse_payload(body)
            self._store_event(payload)
            self.send_response(HTTPStatus.OK)
            self.send_header(
                "Content-Type", "application/json; charset=utf-8"
            )
            self.end_headers()
            self.wfile.write(b'{"ok": true}\n')

        def do_get(self) -> None:
            """Serve either the health endpoint or the HTML status page."""
            parsed = urlparse(self.path)
            if parsed.path == "/healthz":
                self.send_response(HTTPStatus.OK)
                self.send_header(
                    "Content-Type", "application/json; charset=utf-8"
                )
                self.end_headers()
                health_data = json.dumps({
                    "ok": True,
                    "events": store.count(),
                })
                self.wfile.write(health_data.encode("utf-8"))
                return

            if parsed.path != "/":
                self.send_error(HTTPStatus.NOT_FOUND, "Not Found")
                return

            events = store.latest(100)
            rows: list[str] = []
            for ev in reversed(events):
                payload_json = json.dumps(
                    ev.payload, indent=2, ensure_ascii=False
                )
                pretty = html.escape(payload_json)
                timestamp = time.strftime(
                    "%Y-%m-%d %H:%M:%S",
                    time.localtime(ev.ts),
                )
                remote_escaped = html.escape(ev.remote)
                path_escaped = html.escape(ev.path)
                ctype_escaped = html.escape(ev.content_type)
                rows.append(
                    "<div class='event'>"
                    f"<div><strong>{html.escape(timestamp)}</strong>"
                    f" &middot; {remote_escaped}"
                    f" &middot; {path_escaped}</div>"
                    f"<div class='ctype'>{ctype_escaped}</div>"
                    f"<pre>{pretty}</pre>"
                    "</div>"
                )

            rows_html = "".join(rows) if rows else "<p>No events yet.</p>"
            page = f"""<!doctype html>
<html lang=\"en\">
<head>
<meta charset=\"utf-8\">
<meta name=\"viewport\" \
content=\"width=device-width,initial-scale=1\">
<title>Ubuntu Install Status</title>
<style>
body {{
  font-family: -apple-system, BlinkMacSystemFont,
    sans-serif;
  margin: 2rem;
  line-height: 1.4;
}}
code, pre {{
  font-family: ui-monospace, SFMono-Regular, Menlo,
    monospace;
}}
.event {{
  border: 1px solid #ddd;
  border-radius: 12px;
  padding: 1rem;
  margin-bottom: 1rem;
}}
.ctype {{
  color: #666;
  margin: 0.25rem 0 0.75rem;
}}
pre {{
  white-space: pre-wrap;
  word-break: break-word;
  background: #f7f7f7;
  padding: 0.75rem;
  border-radius: 8px;
}}
.small {{ color: #666; }}
</style>
</head>
<body>
<h1>Ubuntu install status</h1>
<p class=\"small\">POST endpoints: <code>/install-status</code> \
and <code>/first-boot/&lt;instance-id&gt;/</code>. \
Health check: <code>/healthz</code>.</p>
<p><strong>{store.count()}</strong> event(s) received.</p>
{rows_html}
</body>
</html>
"""
            body = page.encode("utf-8")
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    return Handler


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse command-line options for the status server.

    Args:
        argv: Raw command-line arguments excluding the executable
            name.

    Returns:
        Parsed argument namespace.
    """
    parser = argparse.ArgumentParser(
        description="Receive Ubuntu autoinstall status webhooks"
    )
    parser.add_argument(
        "--host",
        default="0.0.0.0",
        help="Bind host, default 0.0.0.0",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=8080,
        help="Bind port, default 8080",
    )
    parser.add_argument(
        "--logfile",
        default="install_status_events.jsonl",
        help="Path to line-delimited JSON event log",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    """Start the HTTP status server and serve requests until interrupted.

    Args:
        argv: Raw command-line arguments excluding the executable name.

    Returns:
        Zero when the server shuts down cleanly.
    """
    args = parse_args(argv)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )

    store = EventStore(Path(args.logfile))
    handler = make_handler(store)
    server = ThreadingHTTPServer((args.host, args.port), handler)

    logging.info("listening on http://%s:%s", args.host, args.port)
    logging.info("status page:   http://localhost:%s/", args.port)
    logging.info("health check:  http://localhost:%s/healthz", args.port)
    logging.info("event log:     %s", os.path.abspath(args.logfile))

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logging.info("shutting down")
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
