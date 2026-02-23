#!/usr/bin/env bash
# skill-state-update.sh — PreToolUse[Skill] hook
# Detects pipeline skill invocations from Skill tool input and updates .dev/state.json
# This is the primary state tracking mechanism — fires whenever the Skill tool is called,
# regardless of how the user phrased their prompt.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/event-log.sh"
source "$SCRIPT_DIR/gate.sh"

INPUT=$(cat)

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')

# Only act on Skill tool invocations
if [[ "$TOOL_NAME" != "Skill" ]]; then
  printf '{"hookSpecificOutput":{}}\n'
  exit 0
fi

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')

# Extract skill name from tool input (e.g., "taco:specify" or "specify")
SKILL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // empty')
# Extract args (feature name)
SKILL_ARGS=$(printf '%s' "$INPUT" | jq -r '.tool_input.args // empty')

# Strip plugin prefix (taco:specify → specify)
STAGE="${SKILL_NAME#*:}"

# Pipeline stages
STAGES="brainstorm specify plan review-plan implement review-code learn"

# Check if this skill is a pipeline stage
IS_PIPELINE=false
for s in $STAGES; do
  if [[ "$STAGE" == "$s" ]]; then
    IS_PIPELINE=true
    break
  fi
done

if [[ "$IS_PIPELINE" != "true" ]]; then
  printf '{"hookSpecificOutput":{}}\n'
  exit 0
fi

# Extract feature name from args
FEATURE=$(printf '%s' "$SKILL_ARGS" | sed 's/ /-/g' | tr '[:upper:]' '[:lower:]' | head -c 64)

# If no feature in args, fall back to current state
if [[ -z "$FEATURE" ]]; then
  STATE_FILE="${CWD}/.dev/state.json"
  if [[ -f "$STATE_FILE" ]]; then
    FEATURE=$(jq -r '.feature // empty' "$STATE_FILE" 2>/dev/null)
  fi
fi

if [[ -z "$FEATURE" ]]; then
  printf '{"hookSpecificOutput":{"additionalContext":"Error: feature name required for /%s"}}\n' "$STAGE"
  exit 0
fi

STATE_DIR="${CWD}/.dev"
STATE_FILE="${STATE_DIR}/state.json"
SPEC_DIR="${STATE_DIR}/specs/${FEATURE}"

# Create directories
mkdir -p "$SPEC_DIR/reviews"

# Check idempotency — if same session+stage+feature, skip
if [[ -f "$STATE_FILE" ]]; then
  EXISTING_SESSION=$(jq -r '.session_id // empty' "$STATE_FILE" 2>/dev/null)
  EXISTING_STAGE=$(jq -r '.stage // empty' "$STATE_FILE" 2>/dev/null)
  EXISTING_FEATURE=$(jq -r '.feature // empty' "$STATE_FILE" 2>/dev/null)
  if [[ "$EXISTING_SESSION" == "$SESSION_ID" && "$EXISTING_STAGE" == "$STAGE" && "$EXISTING_FEATURE" == "$FEATURE" ]]; then
    printf '{"hookSpecificOutput":{}}\n'
    exit 0
  fi
fi

# Gate checks
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

CONTEXT="Pipeline state updated: entering /$STAGE for feature [$FEATURE]."
if [[ -n "$GATE_MSG" ]]; then
  CONTEXT="${CONTEXT} ${GATE_MSG}"
fi
printf '{"hookSpecificOutput":{"additionalContext":"%s"}}\n' "$CONTEXT"
