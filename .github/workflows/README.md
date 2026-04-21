# GitHub Actions Workflows

This directory contains automated CI/CD workflows for the Ubuntu Install Status Bundle.

## Available Workflows

### validate.yml
**Runs on:** Push to main/develop, Pull requests

**Jobs:**
- **shellcheck** — Lints all shell scripts for syntax errors and style issues
- **structure** — Validates required directories and files exist with correct permissions
- **tests** — Runs the automated test suite (12+ tests)

**Output:** ✓ Green check when all validations pass

### coverage.yml
**Runs on:** Push to main/develop, Pull requests

**Jobs:**
- **coverage** — Analyzes code and test coverage
  - Runs Python coverage analysis
  - Generates HTML coverage reports
  - Comments on PRs with coverage stats
  - Creates coverage percentage badge

**Output:**
- Coverage report artifact (HTML + summary)
- Coverage badge (green/yellow/red based on %)
- Automatic PR comments with coverage data

### status.yml
**Runs on:** Push to main/develop, Pull requests

**Jobs:**
- **python-validation** — Checks Python script syntax and runs pylint
- **yaml-validation** — Validates YAML and config files
- **build-status** — Creates build status badge

**Output:**
- Status badge
- Python syntax validation report
- YAML/config validation report

## Artifacts

Each workflow generates artifacts available for 7-30 days:

| Artifact | Workflow | Contents |
|----------|----------|----------|
| test-results | validate | Test execution logs |
| coverage-report | coverage | HTML coverage, coverage.txt, badge SVG |
| status-badge | status | SVG build/coverage badges |

## Badge URLs

Add these to your README or other docs:

```markdown
[![Validation](https://github.com/yourusername/ubuntu_install_status_bundle/actions/workflows/validate.yml/badge.svg)](https://github.com/yourusername/ubuntu_install_status_bundle/actions/workflows/validate.yml)
[![Coverage](https://github.com/yourusername/ubuntu_install_status_bundle/actions/workflows/coverage.yml/badge.svg)](https://github.com/yourusername/ubuntu_install_status_bundle/actions/workflows/coverage.yml)
[![Status](https://github.com/yourusername/ubuntu_install_status_bundle/actions/workflows/status.yml/badge.svg)](https://github.com/yourusername/ubuntu_install_status_bundle/actions/workflows/status.yml)
```

## Local Testing

Run the same validations locally before pushing:

```bash
# All tests
./tests/run-all-tests.sh

# ShellCheck manually
find . -name "*.sh" -type f | xargs shellcheck

# Python syntax check
find lib -name "*.py" -type f -exec python3 -m py_compile {} +

# YAML validation
find . -name "*.yaml" -o -name "*.yml" | xargs -I {} python3 -c "import yaml; yaml.safe_load(open('{}'))"
```

## Troubleshooting

**ShellCheck failures:** Run `shellcheck script.sh` to see specific issues

**Coverage low:** Add more tests to `tests/` directory and update `run-all-tests.sh`

**Workflow not running:** Check that branch is main or develop, or adjust branches in workflow file

## Configuration

To customize workflows:

1. Edit `.github/workflows/*.yml` files
2. Update branch names if needed
3. Adjust artifact retention days (default 7-30)
4. Add additional checks or jobs as needed
5. Update README badge URLs with your repository path
