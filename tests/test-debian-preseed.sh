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
echo "=== Test 5: Verify Debian 13 /install.amd default boot entry is patched ==="
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/boot/grub" "$tmpdir/isolinux"
cat > "$tmpdir/boot/grub/grub.cfg" <<'EOF'
menuentry --hotkey=g 'Graphical install' {
    linux    /install.amd/vmlinuz vga=788 --- quiet
    initrd   /install.amd/gtk/initrd.gz
}
submenu --hotkey=a 'Advanced options ...' {
    menuentry '... Automated install' {
        linux    /install.amd/vmlinuz auto=true priority=critical vga=788 --- quiet
        initrd   /install.amd/initrd.gz
    }
}
EOF
cat > "$tmpdir/isolinux/gtk.cfg" <<'EOF'
default installgui
label installgui
	menu label ^Graphical install
	menu default
	kernel /install.amd/vmlinuz
	append vga=788 initrd=/install.amd/gtk/initrd.gz --- quiet
EOF
python3 "$ROOT_DIR/lib/_05-patch-grub-debian.py" \
  --root "$tmpdir" \
  --preseed-url /cdrom/preseed.cfg >/dev/null

if grep -q 'linux /install.amd/vmlinuz vga=788 auto=true priority=critical preseed/file=/cdrom/preseed.cfg --- quiet' "$tmpdir/boot/grub/grub.cfg"; then
  echo "✓ Default GRUB installer entry is patched for unattended boot"
else
  echo "✗ Default GRUB installer entry was not patched"
  sed -n '1,40p' "$tmpdir/boot/grub/grub.cfg"
  exit 1
fi

if grep -q 'append vga=788 initrd=/install.amd/gtk/initrd.gz auto=true priority=critical preseed/file=/cdrom/preseed.cfg --- quiet' "$tmpdir/isolinux/gtk.cfg"; then
  echo "✓ Default isolinux installer entry is patched for unattended boot"
else
  echo "✗ Default isolinux installer entry was not patched"
  sed -n '1,40p' "$tmpdir/isolinux/gtk.cfg"
  exit 1
fi

echo ""
echo "✓ All Debian preseed argument tests passed"
exit 0
