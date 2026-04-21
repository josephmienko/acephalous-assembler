# Automated Test Suite

This directory contains automated tests for the Ubuntu Install Status Bundle project.

## Running Tests

```bash
./run-all-tests.sh
```

This runs all test suites and displays a summary report.

## Test Files

- **test-helpers.sh**: Provides reusable assertion functions and test utilities
  - Import: `source tests/test-helpers.sh`
  - Functions: `assert_success()`, `assert_failure()`, `assert_file_contains()`, etc.

- **test-common-functions.sh**: Unit tests for `lib/_00-common-functions.sh`
  - Tests config loading, value manipulation, and validation functions
  - 12 tests covering all shared functions

- **test-variant-setup.sh**: Integration tests for variant setup scripts
  - Validates Ubuntu and Debian variant setup structure
  - Confirms proper function sourcing and routing

- **run-all-tests.sh**: Main test runner  
  - Orchestrates execution of all test files
  - Manages temporary test environment
  - Generates summary report

## Test Coverage

| Component | Tests | Status |
|-----------|-------|--------|
| load_config() | 2 | ✅ passing |
| set_config_value() | 3 | ✅ passing |
| add_config_var() | 3 | ✅ passing |
| validate_config_and_hash() | 3 | ✅ passing |
| Variant setup structure | 1 | ✅ passing |
| **Total** | **12** | **✅ All Passing** |

## Writing New Tests

1. Create a new test file: `tests/test-<feature>.sh`
2. Source test-helpers at the top
3. Use assertion functions from test-helpers
4. Add test file to the `TEST_FILES` array in `run-all-tests.sh`

Example:

```bash
#!/usr/bin/env bash
# Unit tests for my feature

source "${TEST_FILE_DIR:-$(dirname "$0")}/test-helpers.sh"

# Your test code here
assert_success "my test description" my_test_function
```

## Extending Test Coverage

Future test additions:
- [ ] Config file I/O validation (yaml parsing)
- [ ] Template rendering errors
- [ ] ISO build process simulation
- [ ] Build variant selection logic
- [ ] End-to-end workflow tests
