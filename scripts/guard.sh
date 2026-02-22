#!/usr/bin/env bash
# guard.sh — PreToolUse[Edit|Write] hook
# Stage-based file access control
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/event-log.sh"

INPUT=$(cat)

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

STATE_FILE="${CWD}/.dev/state.json"

# No state file → guard inactive, allow everything
if [[ ! -f "$STATE_FILE" ]]; then
  printf '{"hookSpecificOutput":{}}\n'
  exit 0
fi

STAGE=$(jq -r '.stage // empty' "$STATE_FILE" 2>/dev/null)
FEATURE=$(jq -r '.feature // empty' "$STATE_FILE" 2>/dev/null)
SPEC_DIR=$(jq -r '.spec_dir // empty' "$STATE_FILE" 2>/dev/null)

# No stage → allow
if [[ -z "$STAGE" ]]; then
  printf '{"hookSpecificOutput":{}}\n'
  exit 0
fi

# Resolve file path to absolute
if [[ "$FILE_PATH" != /* ]]; then
  FILE_PATH="${CWD}/${FILE_PATH}"
fi

# Always block sensitive files regardless of stage
BLOCKED_PATTERNS=(
  ".env"
  ".ssh"
  "credentials"
  "secret"
  ".aws/credentials"
  "id_rsa"
  "id_ed25519"
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if printf '%s' "$FILE_PATH" | grep -qi "$pattern"; then
    log_event "$CWD" "guard_deny" "$FEATURE" "sensitive file: $FILE_PATH matches $pattern"
    printf '{"hookSpecificOutput":{"permissionDecision":"deny","reason":"Blocked: writing to sensitive file matching [%s]"}}\n' "$pattern"
    exit 0
  fi
done

# Stage-specific rules
case "$STAGE" in
  brainstorm|specify|plan)
    # Only allow writing inside .dev/
    if [[ "$FILE_PATH" == "${CWD}/.dev/"* ]]; then
      printf '{"hookSpecificOutput":{}}\n'
    else
      printf '{"hookSpecificOutput":{"permissionDecision":"deny","reason":"Stage [%s]: only .dev/ writes allowed. Attempted: %s"}}\n' "$STAGE" "$FILE_PATH"
    fi
    ;;

  review-plan|review-code)
    # Read-only stages — deny all writes
    printf '{"hookSpecificOutput":{"permissionDecision":"deny","reason":"Stage [%s]: read-only, no writes allowed"}}\n' "$STAGE"
    ;;

  implement)
    # Allow writes in worktree only (detected by checking if CWD is in a worktree)
    # Fallback: allow writes outside .dev/ and outside sensitive paths
    if [[ "$FILE_PATH" == "${CWD}/.dev/"* ]]; then
      # Allow state updates in .dev
      printf '{"hookSpecificOutput":{}}\n'
    elif [[ "$FILE_PATH" == "${CWD}/"* ]]; then
      printf '{"hookSpecificOutput":{}}\n'
    else
      printf '{"hookSpecificOutput":{"permissionDecision":"deny","reason":"Stage [implement]: writes only allowed within project directory"}}\n'
    fi
    ;;

  learn)
    # Allow: docs/learnings/, CLAUDE.md, templates/
    if [[ "$FILE_PATH" == "${CWD}/docs/learnings/"* ]] || \
       [[ "$FILE_PATH" == "${CWD}/CLAUDE.md" ]] || \
       [[ "$FILE_PATH" == "${CWD}/templates/"* ]] || \
       [[ "$FILE_PATH" == "${CWD}/.dev/"* ]]; then
      printf '{"hookSpecificOutput":{}}\n'
    else
      printf '{"hookSpecificOutput":{"permissionDecision":"deny","reason":"Stage [learn]: only docs/learnings/, CLAUDE.md, templates/ writes allowed"}}\n'
    fi
    ;;

  *)
    # Unknown stage → allow
    printf '{"hookSpecificOutput":{}}\n'
    ;;
esac
