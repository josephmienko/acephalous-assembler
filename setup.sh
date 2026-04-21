#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VARIANT="${1:-ubuntu}"

case "$VARIANT" in
  ubuntu)
    exec "$SCRIPT_DIR/ubuntu/setup.sh" "${@:2}"
    ;;
  debian)
    exec "$SCRIPT_DIR/debian/setup.sh" "${@:2}"
    ;;
  -h|--help)
    cat <<'EOF'
Usage: ./setup.sh [VARIANT] [OPTIONS]

Variants:
  ubuntu    Ubuntu Server autoinstall (default)
  debian    Debian preseed installer

Ubuntu options:
  --include-nocloud-installer-credentials[=true|false]
      Include known live-installer SSH credentials

Debian options:
  (see debian/README-DEBIAN.md)

Examples:
  ./setup.sh
  ./setup.sh ubuntu --include-nocloud-installer-credentials
  ./setup.sh debian
EOF
    exit 0
    ;;
  *)
    echo "Error: Unknown variant '$VARIANT'" >&2
    echo "Run: ./setup.sh --help" >&2
    exit 1
    ;;
esac
