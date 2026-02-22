#!/usr/bin/env bash
# call-model.sh — Universal external model invocation utility
# Source this file from other scripts: source "$(dirname "$0")/call-model.sh"
set -euo pipefail

CALL_MODEL_TIMEOUT="${CALL_MODEL_TIMEOUT:-120}"
CALL_MODEL_TIMEOUT_CMD=""

# Check if a CLI tool is available
# Usage: _model_available "codex"
_model_available() {
  command -v "$1" >/dev/null 2>&1
}

# Resolve timeout command:
# - GNU timeout (Linux, some macOS setups)
# - gtimeout (Homebrew coreutils on macOS)
# - fallback watchdog (pure bash)
_detect_timeout_cmd() {
  if [[ -n "$CALL_MODEL_TIMEOUT_CMD" ]]; then
    return 0
  fi

  if _model_available "timeout"; then
    CALL_MODEL_TIMEOUT_CMD="timeout"
  elif _model_available "gtimeout"; then
    CALL_MODEL_TIMEOUT_CMD="gtimeout"
  else
    CALL_MODEL_TIMEOUT_CMD="__fallback__"
  fi
}

# Run command with timeout and return command stdout.
# Returns non-zero on timeout or command failure.
_run_with_timeout() {
  _detect_timeout_cmd

  if [[ "$CALL_MODEL_TIMEOUT_CMD" != "__fallback__" ]]; then
    "$CALL_MODEL_TIMEOUT_CMD" "${CALL_MODEL_TIMEOUT}" "$@" 2>/dev/null
    return $?
  fi

  local tmp_out tmp_err timeout_flag pid watcher rc
  tmp_out=$(mktemp "${TMPDIR:-/tmp}/taco-call-model-out.XXXXXX")
  tmp_err=$(mktemp "${TMPDIR:-/tmp}/taco-call-model-err.XXXXXX")
  timeout_flag=$(mktemp "${TMPDIR:-/tmp}/taco-call-model-timeout.XXXXXX")
  rm -f "$timeout_flag"

  "$@" >"$tmp_out" 2>"$tmp_err" &
  pid=$!

  (
    sleep "${CALL_MODEL_TIMEOUT}"
    if kill -0 "$pid" 2>/dev/null; then
      : >"$timeout_flag"
      kill -TERM "$pid" 2>/dev/null || true
      sleep 1
      kill -KILL "$pid" 2>/dev/null || true
    fi
  ) &
  watcher=$!

  set +e
  wait "$pid" 2>/dev/null
  rc=$?
  set -e

  kill "$watcher" 2>/dev/null || true
  wait "$watcher" 2>/dev/null || true

  if [[ -f "$timeout_flag" ]]; then
    rc=124
  fi

  if [[ $rc -eq 0 ]]; then
    cat "$tmp_out"
  fi

  rm -f "$tmp_out" "$tmp_err" "$timeout_flag"
  return "$rc"
}

# Call Codex CLI
# Usage: result=$(call_codex "$prompt")
# Returns: stdout = model output, stderr = status (AVAILABLE|SKIPPED|DEGRADED)
call_codex() {
  local prompt="$1"
  if ! _model_available "codex"; then
    echo "SKIPPED" >&2
    return 0
  fi
  local output
  if output=$(_run_with_timeout codex exec "$prompt"); then
    echo "AVAILABLE" >&2
    printf '%s' "$output"
  else
    echo "DEGRADED" >&2
    return 0
  fi
}

# Call Gemini CLI
# Usage: result=$(call_gemini "$prompt")
# Returns: stdout = model output, stderr = status (AVAILABLE|SKIPPED|DEGRADED)
call_gemini() {
  local prompt="$1"
  if ! _model_available "gemini"; then
    echo "SKIPPED" >&2
    return 0
  fi
  local output
  if output=$(_run_with_timeout gemini -p "$prompt"); then
    echo "AVAILABLE" >&2
    printf '%s' "$output"
  else
    echo "DEGRADED" >&2
    return 0
  fi
}

# Check availability of all models
# Usage: check_models → prints JSON status
check_models() {
  local codex_status="SKIPPED" gemini_status="SKIPPED"
  _model_available "codex" && codex_status="AVAILABLE"
  _model_available "gemini" && gemini_status="AVAILABLE"
  printf '{"codex":"%s","gemini":"%s"}\n' "$codex_status" "$gemini_status"
}
