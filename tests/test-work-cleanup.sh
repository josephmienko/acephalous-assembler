#!/usr/bin/env bash
# Tests for WORK directory validation in _03-prepare-workdir.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  WORK Directory Cleanup Validation Tests                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Create a temporary home for testing
TEST_HOME=$(mktemp -d)
trap "rm -rf $TEST_HOME" EXIT

export HOME="$TEST_HOME"

test_count=0
pass_count=0

# Create the validate_work_path function locally for testing
validate_work_path() {
  local work_path="$1"
  
  # Expand ~ to absolute path (without eval for safety)
  if [[ "$work_path" == "~" ]]; then
    work_path="$HOME"
  elif [[ "$work_path" == "~"/* ]]; then
    work_path="${HOME}${work_path#\\~}"
  fi
  
  # Resolve to absolute path (handle non-existent directories)
  if [[ -d "$work_path" ]]; then
    work_path=$(cd "$work_path" && pwd)
  else
    # For non-existent paths, construct absolute path manually
    if [[ "$work_path" == /* ]]; then
      # Already absolute
      :
    else
      # Relative path - make it absolute relative to HOME
      work_path="$(cd "$HOME" && pwd)/$work_path"
    fi
  fi
  
  # Reject empty or critical system paths
  case "$work_path" in
    "" | "/" | "/home" | "/var" | "/usr" | "/etc" | "/root" | "/opt" | "/srv" | \
    "/bin" | "/sbin" | "/lib" | "/lib64" | "/boot" | "/sys" | "/proc" | "/dev" | "/tmp")
      return 1
      ;;
  esac
  
  # Explicitly reject bare $HOME
  if [[ "$work_path" == "$HOME" ]]; then
    return 1
  fi
  
  # Only allow under explicit safe roots
  if [[ "$work_path" == /tmp/* ]] || [[ "$work_path" == /var/tmp/* ]] || [[ "$work_path" == "$HOME"/tmp* ]]; then
    return 0
  fi
  
  return 1
}

test_path() {
  local path="$1"
  local should_pass="$2"
  local description="$3"
  
  test_count=$((test_count + 1))
  
  if validate_work_path "$path"; then
    result="PASS"
    symbol="✓"
  else
    result="FAIL"
    symbol="✗"
  fi
  
  if [[ "$should_pass" == "pass" && "$result" == "PASS" ]] || [[ "$should_pass" == "fail" && "$result" == "FAIL" ]]; then
    echo "✓ $symbol $description (as expected: $result)"
    pass_count=$((pass_count + 1))
  else
    echo "✗ ✗ $description (UNEXPECTED: $result, expected $should_pass)"
  fi
}

echo "=== Paths that SHOULD BE REJECTED ==="
test_path "/" "fail" "Reject /"
test_path "/home" "fail" "Reject /home"
test_path "/var" "fail" "Reject /var"
test_path "/usr" "fail" "Reject /usr"
test_path "/etc" "fail" "Reject /etc"
test_path "/root" "fail" "Reject /root"
test_path "$HOME" "fail" "Reject bare \$HOME"
test_path "$HOME/Documents" "fail" "Reject \$HOME/Documents"
test_path "$HOME/Downloads" "fail" "Reject \$HOME/Downloads"
test_path "/tmp" "fail" "Reject /tmp itself (must be /tmp/*)"

echo ""
echo "=== Paths that SHOULD BE ALLOWED ==="
test_path "/tmp/build" "pass" "Allow /tmp/build"
test_path "/tmp/aa-build" "pass" "Allow /tmp/aa-build"
test_path "/var/tmp/build" "pass" "Allow /var/tmp/build"
test_path "$HOME/tmp" "pass" "Allow \$HOME/tmp"
test_path "$HOME/tmp/build" "pass" "Allow \$HOME/tmp/build"
test_path "$HOME/.build" "fail" "Reject \$HOME/.build (doesn't match safe pattern)"

echo ""
echo "========== Test Summary =========="
echo "Total:  $test_count"
echo "Passed: $pass_count"
echo "Failed: $((test_count - pass_count))"
echo "================================="

if [[ $pass_count -eq $test_count ]]; then
  echo "✓ All WORK cleanup validation tests passed"
  exit 0
else
  echo "✗ Some tests failed"
  exit 1
fi

