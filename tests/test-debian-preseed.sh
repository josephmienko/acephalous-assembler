#!/usr/bin/env bash
# Test to verify Debian preseed argument is correct

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Debian Preseed Argument Verification                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Test 1: Verify PRESEED_ARG_PREFIX in Python script
echo "=== Test 1: Verify preseed/file argument in _05-patch-grub-debian.py ==="
if grep -q 'PRESEED_ARG_PREFIX = "preseed/file="' "$ROOT_DIR/lib/_05-patch-grub-debian.py"; then
  echo "✓ PRESEED_ARG_PREFIX is correctly set to 'preseed/file='"
else
  echo "✗ PRESEED_ARG_PREFIX is not set correctly"
  exit 1
fi

# Test 2: Verify debian/build_and_flash.sh uses /cdrom/preseed.cfg (not file:///cdrom/...)
echo ""
echo "=== Test 2: Verify debian/build_and_flash.sh passes correct argument ==="
if grep -q 'preseed-url "/cdrom/preseed.cfg"' "$ROOT_DIR/debian/build_and_flash.sh"; then
  echo "✓ debian/build_and_flash.sh passes /cdrom/preseed.cfg (not file:///...)"
else
  echo "✗ debian/build_and_flash.sh does not pass correct argument"
  exit 1
fi

# Test 3: Verify the patcher documentation mentions preseed/file not preseed/url
echo ""
echo "=== Test 3: Verify documentation mentions preseed/file ==="
if grep -q "preseed file argument" "$ROOT_DIR/lib/_05-patch-grub-debian.py"; then
  echo "✓ Documentation mentions 'preseed file argument'"
else
  echo "✗ Documentation doesn't mention preseed file argument"
  exit 1
fi

# Test 4: Verify no leftover preseed/url references in build script
echo ""
echo "=== Test 4: Verify no preseed/url in debian/build_and_flash.sh ==="
if grep -q 'preseed/url' "$ROOT_DIR/debian/build_and_flash.sh"; then
  echo "✗ debian/build_and_flash.sh still contains preseed/url"
  exit 1
else
  echo "✓ No preseed/url found in debian/build_and_flash.sh"
fi

echo ""
echo "✓ All Debian preseed argument tests passed"
exit 0
