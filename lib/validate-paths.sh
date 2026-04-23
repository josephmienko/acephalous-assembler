#!/usr/bin/env bash
# Sourceable path validation library for acephalous-assembler
#
# This library provides functions to validate WORK and ROOT directories
# before performing destructive operations like rm -rf.
#
# Usage:
#   source lib/validate-paths.sh
#   validate_work_path "$WORK" || exit 1
#   validate_root_path "$ROOT" "$WORK" || exit 1

# Validate WORK directory for safety
# Reject dangerous paths that could cause broad system damage if rm -rf runs
#
# Arguments:
#   $1: WORK path (may contain ~, relative paths, nonexistent directories)
#
# Returns:
#   0 if safe, 1 if dangerous
#
# Accepts:
#   - /tmp/aa-build (and other /tmp/* subdirs)
#   - /var/tmp/my-build (and other /var/tmp/* subdirs)
#   - $HOME/tmp (and $HOME/tmp/* subdirs)
#   - Nonexistent directories under safe roots
#
# Rejects:
#   - / (system root)
#   - /home, /var, /usr, /etc, /root, /opt, /srv, /bin, /sbin, /lib*, /boot, /sys, /proc, /dev, /tmp itself
#   - Bare $HOME
#   - $HOME/Documents, $HOME/Downloads, etc. (must be under $HOME/tmp*)
validate_work_path() {
  local work_path="$1"
  
  if [[ -z "$work_path" ]]; then
    echo "Error: WORK directory is empty/unset." >&2
    return 1
  fi
  
  # Expand ~ to absolute path (safe, no eval)
  if [[ "$work_path" == "~" ]]; then
    work_path="$HOME"
  elif [[ "$work_path" == "~"/* ]]; then
    work_path="${HOME}${work_path#\~}"
  fi
  
  # Convert to absolute path if not already
  # For nonexistent paths, we use dirname to find the parent and resolve from there
  local abs_work_path
  if [[ "$work_path" == /* ]]; then
    # Already absolute
    abs_work_path="$work_path"
  else
    # Relative: make absolute from current directory
    abs_work_path="$(cd . && pwd)/$work_path"
  fi
  
  # Normalize path (remove trailing slashes, etc.)
  abs_work_path="${abs_work_path%/}"
  
  # Reject empty or critical system paths
  case "$abs_work_path" in
    "" | "/" | "/home" | "/var" | "/usr" | "/etc" | "/root" | "/opt" | "/srv" | \
    "/bin" | "/sbin" | "/lib" | "/lib64" | "/boot" | "/sys" | "/proc" | "/dev" | "/tmp")
      echo "Error: WORK directory is too dangerous for cleanup: '$abs_work_path'" >&2
      echo "WORK must be inside /tmp, /var/tmp, or \$HOME with a repo-specific/build-specific leaf directory." >&2
      return 1
      ;;
  esac
  
  # Explicitly reject bare $HOME
  if [[ "$abs_work_path" == "$HOME" ]]; then
    echo "Error: WORK cannot be \$HOME itself." >&2
    echo "Use \$HOME/tmp or \$HOME/tmp/build or similar." >&2
    return 1
  fi
  
  # Only allow under explicit safe roots (even if nonexistent)
  if [[ "$abs_work_path" == /tmp/* ]] || [[ "$abs_work_path" == /var/tmp/* ]] || [[ "$abs_work_path" == "$HOME"/tmp* ]]; then
    return 0
  fi
  
  echo "Error: WORK path must be under /tmp/*, /var/tmp/*, or \$HOME/tmp*" >&2
  echo "Got: '$abs_work_path'" >&2
  return 1
}

# Validate ROOT directory for safety
# ROOT must be a subdirectory of WORK to ensure containment
#
# Arguments:
#   $1: ROOT path (may contain variables, relative paths)
#   $2: WORK path (already validated by validate_work_path)
#
# Returns:
#   0 if safe, 1 if dangerous
#
# Behavior:
#   - If ROOT is unset, derives it as $WORK/root (safe default)
#   - If ROOT is set, validates that it is inside WORK
#   - Rejects ROOT outside WORK
validate_root_path() {
  local root_path="${1:-}"
  local work_path="$2"
  
  if [[ -z "$work_path" ]]; then
    echo "Error: WORK path not provided to validate_root_path." >&2
    return 1
  fi
  
  # Normalize WORK path for comparison
  work_path="${work_path%/}"
  
  # If ROOT is unset, derive as $WORK/root
  if [[ -z "$root_path" ]]; then
    echo "ROOT is unset; deriving as \$WORK/root"
    root_path="$work_path/root"
    # Export for caller
    export ROOT="$root_path"
  fi
  
  # Expand any variables or ~ in ROOT
  if [[ "$root_path" == "~" ]]; then
    root_path="$HOME"
  elif [[ "$root_path" == "~"/* ]]; then
    root_path="${HOME}${root_path#\~}"
  fi
  
  # Substitute $WORK in ROOT if present
  root_path="${root_path/\$WORK/$work_path}"
  root_path="${root_path//\$\{WORK\}/$work_path}"
  
  # Convert to absolute path
  local abs_root_path
  if [[ "$root_path" == /* ]]; then
    abs_root_path="$root_path"
  else
    abs_root_path="$(cd . && pwd)/$root_path"
  fi
  
  # Normalize
  abs_root_path="${abs_root_path%/}"
  
  # Normalize work_path for comparison
  local abs_work_path="$work_path"
  if [[ "$abs_work_path" != /* ]]; then
    abs_work_path="$(cd . && pwd)/$abs_work_path"
  fi
  abs_work_path="${abs_work_path%/}"
  
  # Check if ROOT is inside WORK
  # ROOT must match WORK/ followed by something else (proper directory containment)
  # This prevents prefix-matching bugs like WORK=/tmp/work matching ROOT=/tmp/work-evil/root
  if [[ "$abs_root_path" == "$abs_work_path"/* ]]; then
    # ROOT is properly inside WORK as a subdirectory
    return 0
  elif [[ "$abs_root_path" == "$abs_work_path" ]]; then
    # ROOT is the same as WORK (not allowed)
    echo "Error: ROOT cannot be the same as WORK. ROOT should be a subdirectory of WORK." >&2
    return 1
  else
    echo "Error: ROOT is outside WORK." >&2
    echo "ROOT must be a subdirectory of WORK for safety." >&2
    echo "WORK: $abs_work_path" >&2
    echo "ROOT: $abs_root_path" >&2
    return 1
  fi
}
