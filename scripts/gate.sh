#!/usr/bin/env bash
# gate.sh — Pipeline gate checking
# Can be sourced or called directly:
#   ./gate.sh check <G1|G2|G3> <project-root> <feature-name>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./event-log.sh
source "$SCRIPT_DIR/event-log.sh"

# Check a gate
# Usage: gate_check "G1" "/path/to/project" "feature-name"
# Returns: 0 = PASS, 1 = FAIL
gate_check() {
  local gate="$1"
  local root="$2"
  local feature="$3"

  local spec_dir="${root}/.dev/specs/${feature}"

  case "$gate" in
    G1)
      # SPEC approved — spec.md exists and has required sections
      local spec_file="${spec_dir}/spec.md"
      if [[ ! -f "$spec_file" ]]; then
        log_event "$root" "gate_fail" "$feature" "G1: spec.md not found"
        printf 'G1 FAIL: spec.md not found\n'
        return 1
      fi
      # Check for all 5 required sections
      local missing=""
      for section in "## Overview" "## User Scenarios" "## Core Requirements" "## Technical Details" "## Testing Plan"; do
        if ! grep -q "$section" "$spec_file"; then
          missing="${missing}${section}, "
        fi
      done
      if [[ -n "$missing" ]]; then
        log_event "$root" "gate_fail" "$feature" "G1: missing sections: ${missing%,*}"
        printf 'G1 FAIL: missing sections: %s\n' "${missing%, }"
        return 1
      fi
      log_event "$root" "gate_pass" "$feature" "G1"
      printf 'G1 PASS\n'
      return 0
      ;;

    G2)
      # PLAN approved — plan.md exists, has Tasks, and plan-review.md has SHIP
      local plan_file="${spec_dir}/plan.md"
      local review_file="${spec_dir}/reviews/plan-review.md"

      if [[ ! -f "$plan_file" ]]; then
        log_event "$root" "gate_fail" "$feature" "G2: plan.md not found"
        printf 'G2 FAIL: plan.md not found\n'
        return 1
      fi
      if ! grep -q "## Tasks" "$plan_file"; then
        log_event "$root" "gate_fail" "$feature" "G2: plan.md missing Tasks section"
        printf 'G2 FAIL: plan.md missing Tasks section\n'
        return 1
      fi
      if [[ ! -f "$review_file" ]]; then
        log_event "$root" "gate_fail" "$feature" "G2: plan-review.md not found"
        printf 'G2 FAIL: plan-review.md not found (run /review-plan first)\n'
        return 1
      fi
      if ! grep -qi "SHIP" "$review_file"; then
        log_event "$root" "gate_fail" "$feature" "G2: plan review verdict is not SHIP"
        printf 'G2 FAIL: plan review verdict is not SHIP\n'
        return 1
      fi
      log_event "$root" "gate_pass" "$feature" "G2"
      printf 'G2 PASS\n'
      return 0
      ;;

    G3)
      # VERIFY passed — code-review.md exists with SHIP + verify-report.md has pass
      local code_review="${spec_dir}/reviews/code-review.md"
      local verify_report="${spec_dir}/reviews/verify-report.md"

      # Check code review first
      if [[ ! -f "$code_review" ]]; then
        log_event "$root" "gate_fail" "$feature" "G3: code-review.md not found"
        printf 'G3 FAIL: code-review.md not found (run /review-code first)\n'
        return 1
      fi
      if ! grep -qi "SHIP" "$code_review"; then
        log_event "$root" "gate_fail" "$feature" "G3: code review verdict is not SHIP"
        printf 'G3 FAIL: code review verdict is not SHIP\n'
        return 1
      fi
      # Verify report is optional but checked if exists
      if [[ -f "$verify_report" ]] && grep -qi "Result: fail" "$verify_report"; then
        log_event "$root" "gate_fail" "$feature" "G3: verify report has failures"
        printf 'G3 FAIL: verify report has failures\n'
        return 1
      fi
      log_event "$root" "gate_pass" "$feature" "G3"
      printf 'G3 PASS\n'
      return 0
      ;;

    *)
      printf 'Unknown gate: %s (expected G1, G2, or G3)\n' "$gate" >&2
      return 1
      ;;
  esac
}

# CLI mode
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -lt 3 || "$1" != "check" ]]; then
    echo "Usage: $0 check <G1|G2|G3> <project-root> <feature-name>" >&2
    exit 1
  fi
  gate_check "$2" "$3" "$4"
fi
