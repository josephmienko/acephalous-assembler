#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/config.env"

python3 "$SCRIPT_DIR/_992-install-status-server.py" --host 0.0.0.0 --port "$STATUS_PORT"
