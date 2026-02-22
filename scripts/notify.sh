#!/usr/bin/env bash
# notify.sh — Universal notification utility
# Source this file from other scripts: source "$(dirname "$0")/notify.sh"
set -euo pipefail

NOTIFY_CONFIG="${HOME}/.taco-claude/notify-config.json"

# Send a notification
# Usage: notify "Title" "Message"
notify() {
  local title="$1"
  local message="$2"

  # Skip silently if no config
  if [[ ! -f "$NOTIFY_CONFIG" ]]; then
    return 0
  fi

  # Require jq
  if ! command -v jq >/dev/null 2>&1; then
    return 0
  fi

  local platform
  platform=$(jq -r '.platform // empty' "$NOTIFY_CONFIG" 2>/dev/null) || return 0

  case "$platform" in
    telegram)
      _notify_telegram "$title" "$message"
      ;;
    discord)
      _notify_discord "$title" "$message"
      ;;
    *)
      return 0
      ;;
  esac
}

_notify_telegram() {
  local title="$1"
  local message="$2"
  local token chat_id
  token=$(jq -r '.token // empty' "$NOTIFY_CONFIG") || return 0
  chat_id=$(jq -r '.chat_id // empty' "$NOTIFY_CONFIG") || return 0

  if [[ -z "$token" || -z "$chat_id" ]]; then
    return 0
  fi

  local text="*${title}*
${message}"

  curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    -d chat_id="$chat_id" \
    -d text="$text" \
    -d parse_mode="Markdown" \
    >/dev/null 2>&1 || true
}

_notify_discord() {
  local title="$1"
  local message="$2"
  local webhook_url
  webhook_url=$(jq -r '.webhook_url // empty' "$NOTIFY_CONFIG") || return 0

  if [[ -z "$webhook_url" ]]; then
    return 0
  fi

  local payload
  payload=$(jq -n --arg title "$title" --arg msg "$message" \
    '{embeds: [{title: $title, description: $msg}]}')

  curl -s -X POST "$webhook_url" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    >/dev/null 2>&1 || true
}
