#!/usr/bin/env bash
# Test runner: Executes all test suites and generates report

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Source helpers
# shellcheck source=/dev/null
source "$SCRIPT_DIR/test-helpers.sh"

# Setup and cleanup
setup_test_env
trap cleanup_test_env EXIT

# Overall counters
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

# Helper to run and track test file
run_and_track_tests() {
  local test_file="$1"
  
  if [[ ! -f "$test_file" ]]; then
    echo -e "${RED}Test file not found: $test_file${NC}"
    return 1
  fi
  
  # Export paths for test files to use
  export TEST_FILE_DIR="$(cd "$(dirname "$test_file")" && pwd)"
  export PROJECT_ROOT

  # Source the test file to run its tests in the same shell context
  # This preserves environment variables like TEST_TMP_DIR
  # shellcheck source=/dev/null
  source "$test_file" || return 1
}

# Main test execution
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Ubuntu Install Status Bundle - Automated Test Suite       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Run all test files
TEST_FILES=(
  "$SCRIPT_DIR/test-common-functions.sh"
  "$SCRIPT_DIR/test-variant-setup.sh"
)

EXIT_CODE=0
for test_file in "${TEST_FILES[@]}"; do
  if ! run_and_track_tests "$test_file"; then
    EXIT_CODE=1
  fi
done

# Print final summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Final Test Report                                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ $EXIT_CODE -eq 0 ]]; then
  echo -e "${GREEN}All tests passed!${NC}"
else
  echo -e "${RED}Some tests failed. Please review the output above.${NC}"
fi

echo ""
echo "Test run completed at: $(date)"
echo ""

exit $EXIT_CODE
