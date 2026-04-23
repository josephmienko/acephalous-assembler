#!/usr/bin/env bash
# Comprehensive path validation tests for WORK and ROOT
#
# Tests exercise the real validation functions from lib/validate-paths.sh
# instead of copying/duplicating the logic.
#
# Run with: bash tests/test-path-validation.sh

set -u

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the real validation library
source "$ROOT_DIR/lib/validate-paths.sh"

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to run a test
run_test() {
  local test_name="$1"
  local expected_result="$2" # "pass" or "fail"
  local actual_result="$3"   # "pass" or "fail"
  
  TESTS_RUN=$((TESTS_RUN + 1))
  
  if [[ "$expected_result" == "$actual_result" ]]; then
    echo -e "${GREEN}✓${NC} $test_name (as expected: $expected_result)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} $test_name (expected: $expected_result, got: $actual_result)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Create temp work directory for tests
TEMP_WORK_ROOT=$(mktemp -d) || exit 1
trap "rm -rf $TEMP_WORK_ROOT" EXIT

# Initialize test counters before running tests
print_header() {
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║  $1"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
}

# ============================================================================
# WORK PATH VALIDATION TESTS
# ============================================================================

print_header "WORK PATH VALIDATION — Dangerous Paths (should be rejected)"

# Test dangerous system paths
for dangerous_path in "/" "/home" "/var" "/usr" "/etc" "/root" "/opt" "/srv" "/bin" "/sbin" "/lib" "/boot" "/sys" "/proc" "/dev" "/tmp"; do
  validate_work_path "$dangerous_path" > /dev/null 2>&1
  result=$?
  if [[ $result -eq 1 ]]; then
    run_test "Reject $dangerous_path" "fail" "fail"
  else
    run_test "Reject $dangerous_path" "fail" "pass"
  fi
done

print_header "WORK PATH VALIDATION — Bare User Directories (should be rejected)"

# Test bare $HOME
validate_work_path "$HOME" > /dev/null 2>&1
result=$?
if [[ $result -eq 1 ]]; then
  run_test "Reject bare \$HOME" "fail" "fail"
else
  run_test "Reject bare \$HOME" "fail" "pass"
fi

# Test common user directories
for user_dir in "Documents" "Downloads" "Desktop" "Pictures"; do
  if [[ -d "$HOME/$user_dir" ]]; then
    validate_work_path "$HOME/$user_dir" > /dev/null 2>&1
    result=$?
    if [[ $result -eq 1 ]]; then
      run_test "Reject \$HOME/$user_dir" "fail" "fail"
    else
      run_test "Reject \$HOME/$user_dir" "fail" "pass"
    fi
  fi
done

print_header "WORK PATH VALIDATION — Safe Paths (should be accepted)"

# Test /tmp/* subdirectories
for safe_dir in "/tmp/aa-build" "/tmp/test-build" "/tmp/aa-ubuntu"; do
  validate_work_path "$safe_dir" > /dev/null 2>&1
  result=$?
  if [[ $result -eq 0 ]]; then
    run_test "Accept $safe_dir" "pass" "pass"
  else
    run_test "Accept $safe_dir" "pass" "fail"
  fi
done

# Test /var/tmp/* subdirectories
for safe_dir in "/var/tmp/aa-build" "/var/tmp/debian-build"; do
  validate_work_path "$safe_dir" > /dev/null 2>&1
  result=$?
  if [[ $result -eq 0 ]]; then
    run_test "Accept $safe_dir" "pass" "pass"
  else
    run_test "Accept $safe_dir" "pass" "fail"
  fi
done

# Test $HOME/tmp* subdirectories
for safe_dir in "$HOME/tmp" "$HOME/tmp/aa-build" "$HOME/tmp-build"; do
  validate_work_path "$safe_dir" > /dev/null 2>&1
  result=$?
  if [[ $result -eq 0 ]]; then
    run_test "Accept $safe_dir" "pass" "pass"
  else
    run_test "Accept $safe_dir" "pass" "fail"
  fi
done

# Test nonexistent safe paths
nonexistent_safe_paths=(
  "/tmp/nonexistent-aa-build"
  "/var/tmp/nonexistent-build"
  "$HOME/tmp/nonexistent-aa"
)

for safe_dir in "${nonexistent_safe_paths[@]}"; do
  validate_work_path "$safe_dir" > /dev/null 2>&1
  result=$?
  if [[ $result -eq 0 ]]; then
    run_test "Accept nonexistent safe path: $safe_dir" "pass" "pass"
  else
    run_test "Accept nonexistent safe path: $safe_dir" "pass" "fail"
  fi
done

print_header "WORK PATH VALIDATION — Edge Cases (should be rejected)"

# Test /tmp itself (not /tmp/*)
validate_work_path "/tmp" > /dev/null 2>&1
result=$?
if [[ $result -eq 1 ]]; then
  run_test "Reject /tmp itself (must be /tmp/*)" "fail" "fail"
else
  run_test "Reject /tmp itself (must be /tmp/*)" "fail" "pass"
fi

# Test unset WORK
validate_work_path "" > /dev/null 2>&1
result=$?
if [[ $result -eq 1 ]]; then
  run_test "Reject empty WORK" "fail" "fail"
else
  run_test "Reject empty WORK" "fail" "pass"
fi

# ============================================================================
# ROOT PATH VALIDATION TESTS
# ============================================================================

print_header "ROOT PATH VALIDATION — ROOT inside WORK (should pass)"

# Test ROOT inside WORK
SAFE_WORK="/tmp/test-work-$$"
mkdir -p "$SAFE_WORK"

validate_root_path "$SAFE_WORK/root" "$SAFE_WORK" > /dev/null 2>&1
result=$?
if [[ $result -eq 0 ]]; then
  run_test "Accept ROOT=$SAFE_WORK/root inside WORK=$SAFE_WORK" "pass" "pass"
else
  run_test "Accept ROOT=$SAFE_WORK/root inside WORK=$SAFE_WORK" "pass" "fail"
fi

# Test ROOT inside WORK with $WORK variable
validate_root_path '$WORK/root' "$SAFE_WORK" > /dev/null 2>&1
result=$?
if [[ $result -eq 0 ]]; then
  run_test "Accept ROOT=\$WORK/root inside WORK" "pass" "pass"
else
  run_test "Accept ROOT=\$WORK/root inside WORK" "pass" "fail"
fi

# Test ROOT unset (should derive as $WORK/root)
unset ROOT
validate_root_path "" "$SAFE_WORK" > /dev/null 2>&1
result=$?
if [[ $result -eq 0 ]]; then
  run_test "Accept ROOT unset (derive as \$WORK/root)" "pass" "pass"
else
  run_test "Accept ROOT unset (derive as \$WORK/root)" "pass" "fail"
fi

# Verify ROOT was exported
if [[ "${ROOT:-}" == "$SAFE_WORK/root" ]]; then
  run_test "Verify ROOT exported as \$WORK/root" "pass" "pass"
else
  run_test "Verify ROOT exported as \$WORK/root" "pass" "fail"
fi

print_header "ROOT PATH VALIDATION — ROOT outside WORK (should fail)"

# Test ROOT outside WORK
OUTSIDE_WORK="/tmp/outside-$$"
mkdir -p "$OUTSIDE_WORK"

validate_root_path "$OUTSIDE_WORK" "$SAFE_WORK" > /dev/null 2>&1
result=$?
if [[ $result -eq 1 ]]; then
  run_test "Reject ROOT=$OUTSIDE_WORK outside WORK=$SAFE_WORK" "fail" "fail"
else
  run_test "Reject ROOT=$OUTSIDE_WORK outside WORK=$SAFE_WORK" "fail" "pass"
fi

# Test ROOT same as WORK (not allowed)
validate_root_path "$SAFE_WORK" "$SAFE_WORK" > /dev/null 2>&1
result=$?
if [[ $result -eq 1 ]]; then
  run_test "Reject ROOT same as WORK" "fail" "fail"
else
  run_test "Reject ROOT same as WORK" "fail" "pass"
fi

print_header "ROOT PATH VALIDATION — Nonexistent Paths (should still validate containment)"

# Test nonexistent ROOT inside WORK
NONEXISTENT_ROOT="$SAFE_WORK/nonexistent-root-subdir"
validate_root_path "$NONEXISTENT_ROOT" "$SAFE_WORK" > /dev/null 2>&1
result=$?
if [[ $result -eq 0 ]]; then
  run_test "Accept nonexistent ROOT inside WORK" "pass" "pass"
else
  run_test "Accept nonexistent ROOT inside WORK" "pass" "fail"
fi

# Test nonexistent ROOT outside WORK
NONEXISTENT_OUTSIDE="/tmp/other-dir-$$/nonexistent-root"
validate_root_path "$NONEXISTENT_OUTSIDE" "$SAFE_WORK" > /dev/null 2>&1
result=$?
if [[ $result -eq 1 ]]; then
  run_test "Reject nonexistent ROOT outside WORK" "fail" "fail"
else
  run_test "Reject nonexistent ROOT outside WORK" "fail" "pass"
fi

print_header "ROOT PATH VALIDATION — Regression Tests (PREFIX MATCHING BUG)"

# Regression Test 1: WORK=/tmp/work, ROOT=/tmp/work-evil/root
# This must FAIL because /tmp/work-evil/root is NOT inside /tmp/work
WORK_REG1="/tmp/work-$$"
ROOT_REG1="/tmp/work-evil-$$/root"
mkdir -p "$WORK_REG1"

validate_root_path "$ROOT_REG1" "$WORK_REG1" > /dev/null 2>&1
result=$?
if [[ $result -eq 1 ]]; then
  run_test "Reject /tmp/work-evil/root when WORK=/tmp/work (prefix matching bug)" "fail" "fail"
else
  run_test "Reject /tmp/work-evil/root when WORK=/tmp/work (prefix matching bug)" "fail" "pass"
fi

# Regression Test 2: WORK=/tmp/work, ROOT=/tmp/work2/root
# This must FAIL because /tmp/work2/root is NOT inside /tmp/work
WORK_REG2="/tmp/work2-$$"
ROOT_REG2="/tmp/work2-other-$$/root"
mkdir -p "$WORK_REG2"

validate_root_path "$ROOT_REG2" "$WORK_REG2" > /dev/null 2>&1
result=$?
if [[ $result -eq 1 ]]; then
  run_test "Reject /tmp/work2-other/root when WORK=/tmp/work2 (similar names)" "fail" "fail"
else
  run_test "Reject /tmp/work2-other/root when WORK=/tmp/work2 (similar names)" "fail" "pass"
fi

# Regression Test 3: WORK and ROOT are the same (already tested but be explicit)
WORK_REG3="/tmp/work-same-$$"
mkdir -p "$WORK_REG3"

validate_root_path "$WORK_REG3" "$WORK_REG3" > /dev/null 2>&1
result=$?
if [[ $result -eq 1 ]]; then
  run_test "Reject ROOT == WORK" "fail" "fail"
else
  run_test "Reject ROOT == WORK" "fail" "pass"
fi

print_header "ROOT PATH VALIDATION — Valid Containment Tests"

# Valid Test 1: WORK=/tmp/work, ROOT=/tmp/work/root (proper subdirectory)
WORK_VALID1="/tmp/work-valid-$$"
mkdir -p "$WORK_VALID1"

validate_root_path "$WORK_VALID1/root" "$WORK_VALID1" > /dev/null 2>&1
result=$?
if [[ $result -eq 0 ]]; then
  run_test "Accept /tmp/work/root inside /tmp/work (proper subdirectory)" "pass" "pass"
else
  run_test "Accept /tmp/work/root inside /tmp/work (proper subdirectory)" "pass" "fail"
fi

# Valid Test 2: WORK=/tmp/work, ROOT=/tmp/work/nested/root (nested subdirectory)
WORK_VALID2="/tmp/work-nested-$$"
mkdir -p "$WORK_VALID2"

validate_root_path "$WORK_VALID2/nested/root" "$WORK_VALID2" > /dev/null 2>&1
result=$?
if [[ $result -eq 0 ]]; then
  run_test "Accept /tmp/work/nested/root inside /tmp/work (nested)" "pass" "pass"
else
  run_test "Accept /tmp/work/nested/root inside /tmp/work (nested)" "pass" "fail"
fi

# Cleanup regression test directories
rm -rf "$WORK_REG1" "$ROOT_REG1" "$WORK_REG2" "$ROOT_REG2" "$WORK_REG3" "$WORK_VALID1" "$WORK_VALID2"

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Test Summary"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Total:  $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

# Cleanup
rm -rf "$SAFE_WORK" "$OUTSIDE_WORK"

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓ All tests passed${NC}"
  exit 0
else
  echo -e "${RED}✗ Some tests failed${NC}"
  exit 1
fi
