#!/usr/bin/env bash
# validate.sh — PostToolUse[Task|Skill] hook
# Extracts validate_prompt from agent/skill frontmatter and outputs guidance
set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT=$(printf '%s' "$INPUT" | jq -r '.tool_input // empty')

# Determine the source file (agent or skill)
SOURCE_FILE=""
if [[ "$TOOL_NAME" == "Task" ]]; then
  # Try to extract agent type from tool input
  AGENT_TYPE=$(printf '%s' "$INPUT" | jq -r '.tool_input.subagent_type // empty')
  if [[ -n "$AGENT_TYPE" ]]; then
    PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
    CANDIDATE="${PLUGIN_ROOT}/agents/${AGENT_TYPE}.md"
    if [[ -f "$CANDIDATE" ]]; then
      SOURCE_FILE="$CANDIDATE"
    fi
  fi
elif [[ "$TOOL_NAME" == "Skill" ]]; then
  SKILL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // empty')
  if [[ -n "$SKILL_NAME" ]]; then
    PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
    CANDIDATE="${PLUGIN_ROOT}/skills/${SKILL_NAME}/SKILL.md"
    if [[ -f "$CANDIDATE" ]]; then
      SOURCE_FILE="$CANDIDATE"
    fi
  fi
fi

# No source file found → pass through
if [[ -z "$SOURCE_FILE" || ! -f "$SOURCE_FILE" ]]; then
  printf '{"hookSpecificOutput":{}}\n'
  exit 0
fi

# Extract validate_prompt from YAML frontmatter using awk
VALIDATE_PROMPT=$(awk '
  /^---$/ { front++; next }
  front == 1 && /^validate_prompt:/ {
    sub(/^validate_prompt:[[:space:]]*/, "")
    # Handle multi-line (indented continuation)
    prompt = $0
    while (getline > 0) {
      if (/^[[:space:]]/) {
        sub(/^[[:space:]]+/, " ")
        prompt = prompt $0
      } else {
        break
      }
    }
    print prompt
    exit
  }
  front >= 2 { exit }
' "$SOURCE_FILE")

# No validate_prompt → pass through
if [[ -z "$VALIDATE_PROMPT" ]]; then
  printf '{"hookSpecificOutput":{}}\n'
  exit 0
fi

# Output validation guidance
printf '{"hookSpecificOutput":{"additionalContext":"[Validation] Please verify: %s"}}\n' "$VALIDATE_PROMPT"
