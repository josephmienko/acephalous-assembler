#!/usr/bin/env bash
# Unit tests for lib/_00-common-functions.sh

# Get correct paths when being sourced
TEST_FILE_DIR="${TEST_FILE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$TEST_FILE_DIR/.." && pwd)}"

# Ensure TEST_TMP_DIR is set (for standalone execution)
if [[ -z "${TEST_TMP_DIR:-}" ]]; then
  TEST_TMP_DIR="$(mktemp -d)"
  export TEST_TMP_DIR
fi

# Note: Don't re-source test-helpers.sh here since run-all-tests.sh already sources it
# and it may interfere with already-set variables

# Import color codes if not already defined
if [[ -z "${BLUE:-}" ]]; then
  BLUE='\033[0;34m'
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  NC='\033[0m'
fi

# Source the functions to test
# shellcheck source=/dev/null
source "$PROJECT_ROOT/lib/_00-common-functions.sh"

# Test Suite: load_config()
echo -e "\n${BLUE}=== Testing load_config() ===${NC}"

assert_failure "load_config fails with non-existent file" \
  load_config "/nonexistent/config.env"

# Create a valid config file for testing
echo 'TEST_VAR=test_value' > "$TEST_TMP_DIR/test.env"

# Test load_config success inline
test_load_config() {
  load_config "$TEST_TMP_DIR/test.env"
}
assert_success "load_config succeeds with valid file" test_load_config

# Test Suite: set_config_value()
echo -e "\n${BLUE}=== Testing set_config_value() ===${NC}"

# Create a test config file
TEST_CONFIG="$TEST_TMP_DIR/config.env"
cat > "$TEST_CONFIG" <<'EOF'
KEY1="value1"
KEY2="value2"
EOF

# Test set_config_value inline
test_set_existing_key() {
  set_config_value "$TEST_CONFIG" KEY1 'new_value'
  grep -q 'KEY1="new_value"' "$TEST_CONFIG"
}
assert_success "set_config_value replaces existing key" test_set_existing_key

assert_file_contains "KEY1 was updated correctly" "$TEST_CONFIG" 'KEY1="new_value"'

test_set_new_key() {
  set_config_value "$TEST_CONFIG" NEW_KEY 'new_value'
  grep -q 'NEW_KEY="new_value"' "$TEST_CONFIG"
}
assert_success "set_config_value appends new key" test_set_new_key

assert_file_contains "NEW_KEY was appended" "$TEST_CONFIG" 'NEW_KEY="new_value"'

# Test Suite: add_config_var()
echo -e "\n${BLUE}=== Testing add_config_var() ===${NC}"

TEST_CONFIG2="$TEST_TMP_DIR/config2.env"
cat > "$TEST_CONFIG2" <<'EOF'
EXISTING="value"
EOF

test_add_new_var() {
  add_config_var "$TEST_CONFIG2" NEW_VAR 'new_value'
  grep -q 'NEW_VAR="new_value"' "$TEST_CONFIG2"
}
assert_success "add_config_var adds new variable" test_add_new_var

assert_file_contains "NEW_VAR was added" "$TEST_CONFIG2" 'NEW_VAR="new_value"'

test_no_duplicate_vars() {
  add_config_var "$TEST_CONFIG2" EXISTING 'different'
  [ "$(grep -c 'EXISTING=' "$TEST_CONFIG2")" -eq 1 ]
}
assert_success "add_config_var does not duplicate existing variable" test_no_duplicate_vars

# Test Suite: validate_config_and_hash()
echo -e "\n${BLUE}=== Testing validate_config_and_hash() ===${NC}"

# Config without PASSWORD_HASH
TEST_CONFIG3="$TEST_TMP_DIR/config3.env"
cat > "$TEST_CONFIG3" <<'EOF'
HOSTNAME="test"
EOF

assert_failure "validate_config_and_hash fails without PASSWORD_HASH" \
  validate_config_and_hash "$TEST_CONFIG3"

# Config with placeholder PASSWORD_HASH
TEST_CONFIG4="$TEST_TMP_DIR/config4.env"
cat > "$TEST_CONFIG4" <<'EOF'
PASSWORD_HASH="REPLACE_WITH_REAL_HASH"
EOF

assert_failure "validate_config_and_hash fails with placeholder PASSWORD_HASH" \
  validate_config_and_hash "$TEST_CONFIG4"

# Config with valid PASSWORD_HASH
TEST_CONFIG5="$TEST_TMP_DIR/config5.env"
cat > "$TEST_CONFIG5" <<'EOF'
PASSWORD_HASH="\$6\$rounds=656000\$abc123"
EOF

assert_success "validate_config_and_hash succeeds with valid PASSWORD_HASH" \
  validate_config_and_hash "$TEST_CONFIG5"

# Print summary
echo ""
print_test_summary || EXIT_CODE=1

exit "${EXIT_CODE:-0}"
