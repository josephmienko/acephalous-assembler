#!/usr/bin/env bash
# Integration tests for variant setup scripts

# Get correct paths when being sourced
TEST_FILE_DIR="${TEST_FILE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$TEST_FILE_DIR/.." && pwd)}"

# Ensure TEST_TMP_DIR is set (for standalone execution)
if [[ -z "${TEST_TMP_DIR:-}" ]]; then
  TEST_TMP_DIR="$(mktemp -d)"
  export TEST_TMP_DIR
fi

# Note: Don't re-source test-helpers.sh since run-all-tests.sh already sources it

# Import color codes if not already defined
if [[ -z "${BLUE:-}" ]]; then
  BLUE='\033[0;34m'
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  NC='\033[0m'
fi

# Test Suite: Ubuntu setup
echo -e "\n${BLUE}=== Testing ubuntu/setup.sh ===${NC}"

TEST_UBUNTU_ENV="$TEST_TMP_DIR/ubuntu-test"
mkdir -p "$TEST_UBUNTU_ENV"

# Copy necessary files
cp "$PROJECT_ROOT/ubuntu/config.env.example" "$TEST_UBUNTU_ENV/config.env.example"
cp "$PROJECT_ROOT/lib/_00-common-functions.sh" "$TEST_UBUNTU_ENV/"

# Create mock dependencies script that doesn't actually install
cat > "$TEST_UBUNTU_ENV/_01-install-deps.sh" <<'EOF'
#!/usr/bin/env bash
# Mock deps script
exit 0
EOF
chmod +x "$TEST_UBUNTU_ENV/_01-install-deps.sh"

# Create mock password hash script
cat > "$TEST_UBUNTU_ENV/_02-generate-password-hash.sh" <<'EOF'
#!/usr/bin/env bash
source "$(cd "$(dirname "$0")" && pwd)/_00-common-functions.sh"
set_config_value "$1/config.env" "PASSWORD_HASH" "\$6\$rounds=656000\$test"
EOF
chmod +x "$TEST_UBUNTU_ENV/_02-generate-password-hash.sh"

# Note: We can't easily test the actual setup.sh since it requires user interaction
# Instead, we verify the file structure is correct

assert_file_exists "ubuntu/setup.sh exists" \
  "$PROJECT_ROOT/ubuntu/setup.sh"

assert_file_contains "ubuntu/setup.sh sources common functions" \
  "$PROJECT_ROOT/ubuntu/setup.sh" "_00-common-functions"

assert_file_contains "ubuntu/setup.sh sets BUILD_VARIANT" \
  "$PROJECT_ROOT/ubuntu/setup.sh" 'BUILD_VARIANT.*ubuntu'

# Test Suite: Debian setup
echo -e "\n${BLUE}=== Testing debian/setup.sh ===${NC}"

assert_file_exists "debian/setup.sh exists" \
  "$PROJECT_ROOT/debian/setup.sh"

assert_file_contains "debian/setup.sh sources common functions" \
  "$PROJECT_ROOT/debian/setup.sh" "_00-common-functions"

assert_file_contains "debian/setup.sh sets BUILD_VARIANT to debian" \
  "$PROJECT_ROOT/debian/setup.sh" 'debian'

assert_file_contains "debian/setup.sh uses add_config_var" \
  "$PROJECT_ROOT/debian/setup.sh" 'add_config_var'

# Test Suite: Build dispatch logic
echo -e "\n${BLUE}=== Testing root build dispatcher ===${NC}"

assert_file_exists "root build_and_flash.sh exists" \
  "$PROJECT_ROOT/build_and_flash.sh"

assert_file_contains "root dispatcher routes ubuntu variant" \
  "$PROJECT_ROOT/build_and_flash.sh" 'BUILD_VARIANT.*ubuntu'

assert_file_contains "root dispatcher routes debian variant" \
  "$PROJECT_ROOT/build_and_flash.sh" 'BUILD_VARIANT.*debian'

# Test Suite: Variant build scripts
echo -e "\n${BLUE}=== Testing variant build scripts ===${NC}"

assert_file_exists "ubuntu/build_and_flash.sh exists" \
  "$PROJECT_ROOT/ubuntu/build_and_flash.sh"

assert_file_contains "ubuntu/build_and_flash.sh sources common functions" \
  "$PROJECT_ROOT/ubuntu/build_and_flash.sh" "_00-common-functions"

assert_file_contains "ubuntu/build_and_flash.sh validates config" \
  "$PROJECT_ROOT/ubuntu/build_and_flash.sh" "validate_config_and_hash"

assert_file_exists "debian/build_and_flash.sh exists" \
  "$PROJECT_ROOT/debian/build_and_flash.sh"

assert_file_contains "debian/build_and_flash.sh sources common functions" \
  "$PROJECT_ROOT/debian/build_and_flash.sh" "_00-common-functions"

assert_file_contains "debian/build_and_flash.sh validates config" \
  "$PROJECT_ROOT/debian/build_and_flash.sh" "validate_config_and_hash"

# Print summary
echo ""
print_test_summary || EXIT_CODE=1

exit "${EXIT_CODE:-0}"
