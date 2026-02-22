#!/usr/bin/env bash
# next-step.sh — PostToolUse[Skill] hook
# Suggests the next pipeline step after current skill completes
# Also sends Telegram/Discord notification on stage transitions
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/notify.sh"

INPUT=$(cat)

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')

# Only act on Skill completions
if [[ "$TOOL_NAME" != "Skill" ]]; then
  printf '{"hookSpecificOutput":{}}\n'
  exit 0
fi

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
STATE_FILE="${CWD}/.dev/state.json"

# No state → nothing to suggest
if [[ ! -f "$STATE_FILE" ]]; then
  printf '{"hookSpecificOutput":{}}\n'
  exit 0
fi

STAGE=$(jq -r '.stage // empty' "$STATE_FILE" 2>/dev/null)
FEATURE=$(jq -r '.feature // empty' "$STATE_FILE" 2>/dev/null)

if [[ -z "$STAGE" || -z "$FEATURE" ]]; then
  printf '{"hookSpecificOutput":{}}\n'
  exit 0
fi

# Map current stage → next stage
case "$STAGE" in
  brainstorm)
    NEXT="/specify ${FEATURE}"
    MSG="Brainstorm complete. Next: /specify ${FEATURE}"
    ;;
  specify)
    NEXT="/plan ${FEATURE}"
    MSG="Spec complete. Next: /plan ${FEATURE}"
    ;;
  plan)
    NEXT="/review-plan ${FEATURE}"
    MSG="Plan complete. Next: /review-plan ${FEATURE}"
    ;;
  review-plan)
    NEXT="/implement ${FEATURE}"
    MSG="Plan review complete. Next: /implement ${FEATURE}"
    ;;
  implement)
    NEXT="/review-code ${FEATURE}"
    MSG="Implementation complete. Next: /review-code ${FEATURE}"
    ;;
  review-code)
    NEXT="/learn ${FEATURE}"
    MSG="Code review complete. Next: /learn ${FEATURE}"
    ;;
  learn)
    MSG="Pipeline complete for [${FEATURE}]. All stages finished."
    NEXT=""
    ;;
  *)
    printf '{"hookSpecificOutput":{}}\n'
    exit 0
    ;;
esac

# Send notification on stage transition
notify "taco" "$MSG" &

printf '{"hookSpecificOutput":{"additionalContext":"[Pipeline] %s"}}\n' "$MSG"
