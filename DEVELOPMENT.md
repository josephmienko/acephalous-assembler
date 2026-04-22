# Development Guide

This project uses **Poetry** for Python dependency management and environment isolation.

## Prerequisites

- **Python 3.11+** (use `pyenv` to manage versions)
- **Poetry** (install via `curl -sSL https://install.python-poetry.org | python3 -`)

## Setup

### Quick Start with Poetry

```bash
# Install dependencies and create virtual environment
poetry install

# Activate the virtual environment
poetry shell

# Or run commands directly without activating
poetry run python -m assembler.cli hash --help
```

### Without Poetry (pip)

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install requirements
pip install -r requirements.txt
```

## Project Structure

```txt
lib/python/
├── assembler/                    # Main package
│   ├── __init__.py
│   ├── cli.py                    # CLI entry point
│   ├── config.py                 # ConfigManager class
│   ├── password.py               # PasswordManager class
│   └── template.py               # TemplateRenderer class
└── requirements.txt              # For pip fallback
```

## Usage

### Generate a Password Hash (for setup.sh)

```bash
# Generate Argon2 hash with random password
python3 lib/python/assembler/cli.py hash

# Generate SHA-512 hash (for older Debian)
python3 lib/python/assembler/cli.py hash --algorithm sha512

# Generate hash with specific password
python3 lib/python/assembler/cli.py hash --password mypassword

# Verbose output (shows generated password)
python3 lib/python/assembler/cli.py hash --verbose
```

### Set Password in Config File

```bash
# Generate and save to config.env (called by setup.sh)
python3 lib/python/assembler/cli.py set-config config.env --verbose

# With custom algorithm
python3 lib/python/assembler/cli.py set-config config.env --algorithm sha512
```

### Use in Python Scripts

```python
from lib.python.assembler import ConfigManager, PasswordManager
from lib.python.assembler.template import TemplateRenderer

# Load configuration
config = ConfigManager("config.env")

# Render templates
renderer = TemplateRenderer(config)
rendered = renderer.render_file("templates/autoinstall.template.yaml")

# Hash passwords
pm = PasswordManager()
hash_value = pm.hash_password("password123")
```

## Development Tasks

### Run Tests

```bash
poetry run pytest
poetry run pytest --cov=assembler
```

### Format Code

```bash
poetry run black lib/python/assembler
```

### Lint Code

```bash
poetry run ruff check lib/python/assembler
```

### Type Check

```bash
poetry run mypy lib/python/assembler
```

## Dependencies

### Core Dependencies

- **python-dotenv** — Load .env-style config files
- **argon2-cffi** — Modern password hashing (Argon2)
- **PyYAML** — YAML parsing (for future use)

### Development Dependencies

- **pytest** — Testing framework
- **pytest-cov** — Code coverage reports
- **black** — Code formatter
- **ruff** — Fast Python linter
- **mypy** — Static type checker

## Algorithms Explained

### Argon2 (Default)

Modern, GPU-resistant, configurable. Use for all new deployments.

- Format: `$argon2id$v=19$m=65540,t=3,p=4$...`
- Supported: Ubuntu, Debian 12+, Home Assistant OS
- Recommendation: **Yes, use this**

### SHA-512 (Legacy)

Used by Debian preseed for older systems. Not suitable for new deployments.

- Format: `$6$salt$...`
- Supported: Debian Installer (preseed)
- Recommendation: **Use only for Debian preseed compatibility**

## Upgrading Dependencies

```bash
# Check for outdated packages
poetry update --dry-run

# Update to latest compatible versions
poetry update

# Lock file will be automatically updated
```

## Troubleshooting

### "poetry: command not found"

Install Poetry:

```bash
curl -sSL https://install.python-poetry.org | python3 -
export PATH="$HOME/.local/bin:$PATH"
```

### Python version mismatch

Install Python 3.11 via pyenv:

```bash
pyenv install 3.11.9
pyenv local 3.11.9
```

### "ModuleNotFoundError: No module named 'assembler'"

Ensure you're using Poetry's virtual environment:

```bash
poetry shell
# or use: poetry run python <script>
```

## References

- [Poetry Documentation](https://python-poetry.org/docs/)
- [Argon2 Specification](https://en.wikipedia.org/wiki/Argon2)
- [Python Hashing Best Practices](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
