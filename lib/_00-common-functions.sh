#!/usr/bin/env bash
# Shared functions for Ubuntu and Debian variants
# Source this file to get access to common utilities

# Load config.env from specified path
# Usage: load_config /path/to/config.env
load_config() {
  local config_file="$1"
  
  if [[ ! -f "$config_file" ]]; then
    echo "Config file not found: $config_file" >&2
    return 1
  fi
  
  set -a
  # shellcheck source=/dev/null
  source "$config_file"
  set +a
}

# Validate that config file exists and PASSWORD_HASH is set properly
# Usage: validate_config_and_hash /path/to/config.env
validate_config_and_hash() {
  local config_file="$1"
  
  if [[ ! -f "$config_file" ]]; then
    echo "config.env not found. Run ./setup.sh first." >&2
    return 1
  fi
  
  # Source the config to check PASSWORD_HASH
  if ! load_config "$config_file"; then
    return 1
  fi
  
  if [[ -z "${PASSWORD_HASH:-}" || "${PASSWORD_HASH}" == *REPLACE_WITH_REAL_HASH* ]]; then
    echo "PASSWORD_HASH is missing or still set to the placeholder in config.env." >&2
    echo "Run ./setup.sh first, or update config.env manually." >&2
    return 1
  fi
}

# Set config value: replaces if exists, appends if not
# Usage: set_config_value /path/to/config.env KEY VALUE
set_config_value() {
  local config_file="$1"
  local key="$2"
  local value="$3"
  local tmp
  tmp="$(mktemp)"

  if [[ -f "$config_file" ]] && grep -q "^${key}=" "$config_file"; then
    awk -v key="$key" -v value="$value" '
      BEGIN { replaced = 0 }
      $0 ~ "^" key "=" {
        print key "=\"" value "\""
        replaced = 1
        next
      }
      { print }
      END {
        if (!replaced) {
          print key "=\"" value "\""
        }
      }
    ' "$config_file" > "$tmp"
  else
    cat "$config_file" > "$tmp" 2>/dev/null || true
    printf '%s="%s"\n' "$key" "$value" >> "$tmp"
  fi

  mv "$tmp" "$config_file"
}

# Add config variable if it doesn't exist
# Usage: add_config_var /path/to/config.env KEY VALUE
add_config_var() {
  local config_file="$1"
  local key="$2"
  local value="$3"

  if [[ ! -f "$config_file" ]]; then
    printf '%s="%s"\n' "$key" "$value" > "$config_file"
    return
  fi

  if ! grep -q "^${key}=" "$config_file"; then
    printf '%s="%s"\n' "$key" "$value" >> "$config_file"
  fi
}

# Set BUILD_VARIANT and call setup functions
# Usage: setup_variant VARIANT_NAME CONFIG_FILE ROOT_CONFIG_FILE
setup_variant() {
  local variant="$1"
  local variant_config="$2"
  local root_config="$3"
  
  # Ensure root config exists, copying from example if needed
  if [[ ! -f "$root_config" ]]; then
    local example_dir
    example_dir="$(dirname "$variant_config")"
    local example_file="$example_dir/config.env.example"
    
    if [[ -f "$example_file" ]]; then
      cp "$example_file" "$root_config"
      echo "Created $root_config from $example_file"
    else
      echo "Error: config.env not found and no example available" >&2
      return 1
    fi
  fi
  
  # Set the variant
  set_config_value "$root_config" "BUILD_VARIANT" "$variant"
}
