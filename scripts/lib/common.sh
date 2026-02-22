#!/usr/bin/env bash
# common.sh — Shared utility functions for taco-claude scripts
# Source this file: source "$(dirname "$0")/lib/common.sh"

# Resolve taco-claude root from any script location
resolve_taco_root() {
  local script_path="$1"
  local script_dir
  script_dir="$(cd "$(dirname "$script_path")" && pwd)"
  # If called from scripts/lib/, go up 2 levels; from scripts/, go up 1 level
  if [[ "$(basename "$script_dir")" == "lib" ]]; then
    cd "$script_dir/../.." && pwd
  else
    cd "$script_dir/.." && pwd
  fi
}

# ISO 8601 UTC timestamp
now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Logging
log_info() {
  printf '[INFO] %s\n' "$*" >&2
}

log_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

# Ensure directory exists
ensure_dir() {
  [[ -d "$1" ]] || mkdir -p "$1"
}

# Escape string for JSON value
json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | tr '\n' ' '
}

# Append event to JSONL log
# Usage: append_event "$project_root" "$event" "$feature" "$details"
append_event() {
  local root="$1" event="$2" feature="${3:-}" details="${4:-}"
  local logfile="$root/.dev/events.jsonl"

  ensure_dir "$root/.dev"
  [[ -f "$logfile" ]] || : > "$logfile"

  local ts event_e feature_e details_e
  ts="$(now_iso)"
  event_e="$(json_escape "$event")"
  feature_e="$(json_escape "$feature")"
  details_e="$(json_escape "$details")"

  printf '{"ts":"%s","event":"%s","feature":"%s","details":"%s"}\n' \
    "$ts" "$event_e" "$feature_e" "$details_e" >> "$logfile"
}

# Atomic file write (write to tmp, then mv)
atomic_write() {
  local file="$1" content="$2"
  local tmp="${file}.tmp.$$"
  printf '%s' "$content" > "$tmp"
  mv "$tmp" "$file"
}

# Ensure a line exists in a file (idempotent add)
ensure_line_in_file() {
  local file="$1" line="$2"
  [[ -f "$file" ]] || : > "$file"
  if grep -Fxq "$line" "$file" 2>/dev/null; then
    return 0
  fi
  printf '%s\n' "$line" >> "$file"
}

# Remove a line from a file
remove_line_from_file() {
  local file="$1" line="$2"
  [[ -f "$file" ]] || return 0
  local tmp="${file}.tmp.$$"
  grep -Fvx "$line" "$file" > "$tmp" 2>/dev/null || true
  mv "$tmp" "$file"
}
