#!/usr/bin/env bash
# event-log.sh — JSONL event logging utility
# Source this file: source "$(dirname "$0")/event-log.sh"
set -euo pipefail

# Append an event to .dev/events.jsonl
# Usage: log_event "$project_root" "$event" "$feature" "$details"
log_event() {
  local root="$1"
  local event="$2"
  local feature="${3:-}"
  local details="${4:-}"

  local log_dir="${root}/.dev"
  local log_file="${log_dir}/events.jsonl"

  mkdir -p "$log_dir"
  [[ -f "$log_file" ]] || : > "$log_file"

  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # JSON-escape strings
  event=$(printf '%s' "$event" | sed 's/\\/\\\\/g; s/"/\\"/g')
  feature=$(printf '%s' "$feature" | sed 's/\\/\\\\/g; s/"/\\"/g')
  details=$(printf '%s' "$details" | sed 's/\\/\\\\/g; s/"/\\"/g')

  printf '{"ts":"%s","event":"%s","feature":"%s","details":"%s"}\n' \
    "$ts" "$event" "$feature" "$details" >> "$log_file"
}
