#!/usr/bin/env bash
# Test utilities and helpers
# Source this file in test scripts: source tests/test-helpers.sh

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Temporary test directory
TEST_TMP_DIR=""

# Setup test environment
setup_test_env() {
  TEST_TMP_DIR="$(mktemp -d)"
  export TEST_TMP_DIR
  echo "Test environment: $TEST_TMP_DIR" >&2
}

# Cleanup test environment
cleanup_test_env() {
  if [[ -n "$TEST_TMP_DIR" && -d "$TEST_TMP_DIR" ]]; then
    rm -rf "$TEST_TMP_DIR"
  fi
}

# Assert that a command succeeds
assert_success() {
  local description="$1"
  shift
  
  TESTS_RUN=$((TESTS_RUN + 1))
  
  if "$@" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} $description"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $description"
    echo "  Command: $*"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Assert that a command fails
assert_failure() {
  local description="$1"
  shift
  
  TESTS_RUN=$((TESTS_RUN + 1))
  
  if ! "$@" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} $description"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $description"
    echo "  Command: $* (expected to fail)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Assert that command output contains a string
assert_output_contains() {
  local description="$1"
  local expected="$2"
  shift 2
  
  TESTS_RUN=$((TESTS_RUN + 1))
  
  local output
  output=$("$@" 2>&1)
  
  if echo "$output" | grep -q "$expected"; then
    echo -e "${GREEN}✓${NC} $description"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $description"
    echo "  Expected output to contain: $expected"
    echo "  Actual output: $output"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Assert file exists
assert_file_exists() {
  local description="$1"
  local filepath="$2"
  
  TESTS_RUN=$((TESTS_RUN + 1))
  
  if [[ -f "$filepath" ]]; then
    echo -e "${GREEN}✓${NC} $description"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $description"
    echo "  File not found: $filepath"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Assert file contains string
assert_file_contains() {
  local description="$1"
  local filepath="$2"
  local expected="$3"
  
  TESTS_RUN=$((TESTS_RUN + 1))
  
  if [[ ! -f "$filepath" ]]; then
    echo -e "${RED}✗${NC} $description"
    echo "  File not found: $filepath"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
  
  if grep -q "$expected" "$filepath"; then
    echo -e "${GREEN}✓${NC} $description"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $description"
    echo "  Expected file to contain: $expected"
    echo "  File: $filepath"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Print test summary
print_test_summary() {
  echo ""
  echo -e "${BLUE}========== Test Summary ==========${NC}"
  echo -e "  Total:  $TESTS_RUN"
  echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
  if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
  fi
  echo -e "${BLUE}=================================${NC}"
  echo ""
  
  if [[ $TESTS_FAILED -gt 0 ]]; then
    return 1
  fi
  return 0
}

# Run a test file
run_test_file() {
  local test_file="$1"
  
  echo ""
  echo -e "${BLUE}Running: $test_file${NC}"
  echo -e "${BLUE}-----------------------------------${NC}"
  
  # Source the test file
  # shellcheck source=/dev/null
  source "$test_file"
}

# Export functions and variables for use in test files
export -f assert_success
export -f assert_failure
export -f assert_output_contains
export -f assert_file_exists
export -f assert_file_contains
export TESTS_RUN TESTS_PASSED TESTS_FAILED
export PROJECT_ROOT TEST_TMP_DIR
