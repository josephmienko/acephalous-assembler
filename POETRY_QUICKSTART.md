# Quick Poetry Setup

Get started with the Python development environment in under 2 minutes.

## 1. Install Poetry (one-time)

```bash
curl -sSL https://install.python-poetry.org | python3 -
export PATH="$HOME/.local/bin:$PATH"  # Add to ~/.zshrc or ~/.bashrc
```

Verify: `poetry --version`

## 2. Install Project Dependencies

```bash
cd acephalous-assembler
poetry install
```

This creates a virtual environment and installs all dependencies.

## 3. Activate Virtual Environment

```bash
poetry shell
```

Or use any command with: `poetry run <command>`

## 4. Test It Works

```bash
# View help
python3 lib/python/assembler/cli.py --help

# Generate a password hash
python3 lib/python/assembler/cli.py hash --verbose

# Run tests
poetry run pytest
```

## Common Commands

```bash
# List installed packages
poetry show

# Check for outdated packages
poetry update --dry-run

# Update all packages
poetry update

# Add a new package
poetry add package-name

# Add dev-only package
poetry add --group dev package-name

# Build distribution
poetry build

# Run a script
poetry run python script.py

# Run tests with coverage
poetry run pytest --cov=assembler
```

## Without Poetry?

Use traditional pip:

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

See [DEVELOPMENT.md](DEVELOPMENT.md) for full details.
