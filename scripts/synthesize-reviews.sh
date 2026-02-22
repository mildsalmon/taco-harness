#!/usr/bin/env bash
# synthesize-reviews.sh — 3-model review synthesis utility
# Source this file or call directly:
#   ./synthesize-reviews.sh <claude_file> <codex_file> <gemini_file> <output_file>
set -euo pipefail

# Synthesize three model reviews into a unified report
# Usage: synthesize_reviews "$claude" "$codex" "$gemini" "$output_file" "$review_type"
synthesize_reviews() {
  local claude_text="$1"
  local codex_text="$2"
  local gemini_text="$3"
  local output_file="$4"
  local review_type="${5:-code}"

  # Determine consensus level
  local models_count=0
  local models_available=""
  [[ -n "$claude_text" ]] && models_count=$((models_count + 1)) && models_available="${models_available}Claude,"
  [[ -n "$codex_text" ]] && models_count=$((models_count + 1)) && models_available="${models_available}Codex,"
  [[ -n "$gemini_text" ]] && models_count=$((models_count + 1)) && models_available="${models_available}Gemini,"
  models_available="${models_available%,}"

  local consensus
  case "$models_count" in
    3) consensus="3-model" ;;
    2) consensus="2-model" ;;
    1) consensus="claude-only" ;;
    0)
      echo "ERROR: No review input provided" >&2
      return 1
      ;;
  esac

  # Build the synthesized review
  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local tmpfile="${output_file}.tmp.$$"
  {
    cat <<HEADER
---
type: ${review_type}-review
consensus: ${consensus}
models: [${models_available}]
date: ${now}
---

# $(echo "$review_type" | awk '{print toupper(substr($0,1,1)) substr($0,2)}') Review — Synthesized Report

**Consensus Level**: ${consensus}
**Models**: ${models_available}
**Date**: ${now}

HEADER

    if [[ -n "$claude_text" ]]; then
      cat <<SECTION
## Claude Review

${claude_text}

SECTION
    fi

    if [[ -n "$codex_text" ]]; then
      cat <<SECTION
## Codex Review

${codex_text}

SECTION
    fi

    if [[ -n "$gemini_text" ]]; then
      cat <<SECTION
## Gemini Review

${gemini_text}

SECTION
    fi

    cat <<FOOTER
## Synthesis

### Consensus Items
<!-- Items all available models agree on -->
_To be filled by the reviewing agent after analysis._

### Divergent Points
<!-- Items where models disagree -->
_To be filled by the reviewing agent after analysis._

### Verdict
<!-- SHIP or NEEDS_FIXES -->
**Verdict**: _PENDING_
FOOTER
  } > "$tmpfile"
  mv "$tmpfile" "$output_file"

  echo "$output_file"
}

# CLI mode: called directly with file args
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -lt 4 ]]; then
    echo "Usage: $0 <claude_file> <codex_file> <gemini_file> <output_file> [review_type]" >&2
    exit 1
  fi

  claude_input="" codex_input="" gemini_input=""
  [[ -f "$1" ]] && claude_input=$(cat "$1")
  [[ -f "$2" ]] && codex_input=$(cat "$2")
  [[ -f "$3" ]] && gemini_input=$(cat "$3")

  synthesize_reviews "$claude_input" "$codex_input" "$gemini_input" "$4" "${5:-code}"
fi
