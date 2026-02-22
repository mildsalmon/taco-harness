#!/usr/bin/env bash
# state-manager.sh — UserPromptSubmit hook
# Detects pipeline skill invocations and manages .dev/state.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/event-log.sh"
source "$SCRIPT_DIR/gate.sh"

INPUT=$(cat)

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty')

# Pipeline stages in order
STAGES="brainstorm specify plan review-plan implement review-code learn"

# Detect skill invocation from prompt
detect_stage() {
  local prompt="$1"
  for stage in $STAGES; do
    if printf '%s' "$prompt" | grep -qiE "^/${stage}( |$)"; then
      printf '%s' "$stage"
      return 0
    fi
  done
  return 1
}

# Extract feature name from prompt (word after /command)
extract_feature() {
  local prompt="$1"
  printf '%s' "$prompt" | sed -E 's|^/[a-z-]+ +||' | sed 's/ /-/g' | tr '[:upper:]' '[:lower:]' | head -c 64
}

# Clean stale sessions (>24h)
clean_stale() {
  local state_file="$1"
  if [[ ! -f "$state_file" ]]; then
    return 0
  fi
  local updated_at
  updated_at=$(jq -r '.updated_at // empty' "$state_file" 2>/dev/null) || return 0
  if [[ -z "$updated_at" ]]; then
    return 0
  fi
  local now updated_epoch
  now=$(date +%s)
  updated_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${updated_at%%.*}" +%s 2>/dev/null) || \
  updated_epoch=$(date -d "${updated_at}" +%s 2>/dev/null) || return 0
  local age=$(( now - updated_epoch ))
  if (( age > 86400 )); then
    rm -f "$state_file"
  fi
}

# Main
STAGE=$(detect_stage "$PROMPT") || {
  # Not a pipeline command — pass through
  printf '{"hookSpecificOutput":{}}\n'
  exit 0
}

FEATURE=$(extract_feature "$PROMPT")
if [[ -z "$FEATURE" ]]; then
  printf '{"hookSpecificOutput":{"additionalContext":"Error: feature name required. Usage: /%s <feature-name>"}}\n' "$STAGE"
  exit 0
fi

STATE_DIR="${CWD}/.dev"
STATE_FILE="${STATE_DIR}/state.json"
SPEC_DIR="${STATE_DIR}/specs/${FEATURE}"

# Create directories
mkdir -p "$SPEC_DIR/reviews"

# Clean stale sessions
clean_stale "$STATE_FILE"

# Check idempotency — if same session+stage+feature, skip
if [[ -f "$STATE_FILE" ]]; then
  EXISTING_SESSION=$(jq -r '.session_id // empty' "$STATE_FILE" 2>/dev/null)
  EXISTING_STAGE=$(jq -r '.stage // empty' "$STATE_FILE" 2>/dev/null)
  EXISTING_FEATURE=$(jq -r '.feature // empty' "$STATE_FILE" 2>/dev/null)
  if [[ "$EXISTING_SESSION" == "$SESSION_ID" && "$EXISTING_STAGE" == "$STAGE" && "$EXISTING_FEATURE" == "$FEATURE" ]]; then
    printf '{"hookSpecificOutput":{"additionalContext":"Pipeline state: already at /%s for %s"}}\n' "$STAGE" "$FEATURE"
    exit 0
  fi
fi

# Gate checks — verify prerequisites before entering certain stages
GATE_MSG=""
case "$STAGE" in
  plan)
    if ! gate_check "G1" "$CWD" "$FEATURE" >/dev/null 2>&1; then
      GATE_MSG="WARNING: G1 not passed — spec.md may be incomplete. Run /specify first."
    fi
    ;;
  implement)
    if ! gate_check "G2" "$CWD" "$FEATURE" >/dev/null 2>&1; then
      GATE_MSG="WARNING: G2 not passed — plan not approved. Run /review-plan first."
    fi
    ;;
  learn)
    if ! gate_check "G3" "$CWD" "$FEATURE" >/dev/null 2>&1; then
      GATE_MSG="WARNING: G3 not passed — code review not complete. Run /review-code first."
    fi
    ;;
esac

# Write state atomically
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TMPFILE="${STATE_FILE}.tmp.$$"
jq -n \
  --arg stage "$STAGE" \
  --arg feature "$FEATURE" \
  --arg session_id "$SESSION_ID" \
  --arg updated_at "$NOW" \
  --arg spec_dir "$SPEC_DIR" \
  '{
    stage: $stage,
    feature: $feature,
    session_id: $session_id,
    updated_at: $updated_at,
    spec_dir: $spec_dir
  }' > "$TMPFILE"
mv "$TMPFILE" "$STATE_FILE"

# Log event
log_event "$CWD" "stage_enter" "$FEATURE" "entering $STAGE"

CONTEXT="Pipeline state: entering /$STAGE for feature [$FEATURE]. Spec dir: $SPEC_DIR"
if [[ -n "$GATE_MSG" ]]; then
  CONTEXT="${CONTEXT}. ${GATE_MSG}"
fi
printf '{"hookSpecificOutput":{"additionalContext":"%s"}}\n' "$CONTEXT"
