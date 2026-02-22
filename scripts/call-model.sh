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
  if output=$(_run_with_timeout codex exec -m gpt-5.3-codex -c model_reasoning_effort=xhigh "$prompt"); then
    echo "AVAILABLE" >&2
    printf '%s' "$output"
  else
    echo "DEGRADED" >&2
    return 0
  fi
}

# Gemini oneshot wrapper — closes stdin so CLI exits after responding
_gemini_oneshot() {
  gemini --model gemini-2.5-pro -p "$1" < /dev/null
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
  if output=$(_run_with_timeout _gemini_oneshot "$prompt"); then
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
  printf '{"codex":{"status":"%s","model":"gpt-5.3-codex","effort":"xhigh"},"gemini":{"status":"%s","model":"gemini-2.5-pro"}}\n' \
    "$codex_status" "$gemini_status"
}

# Millisecond timestamp (portable: macOS lacks %N)
_ms_now() {
  if command -v gdate >/dev/null 2>&1; then
    gdate +%s%3N
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import time; print(int(time.time()*1000))'
  else
    echo "$(date +%s)000"
  fi
}

# JSON-escape a string (minimal: backslash, double-quote, newlines)
_json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ' | head -c 200
}

# -------------------------------------------------------------------
# Probe functions — send a test prompt and verify response
# -------------------------------------------------------------------

TACO_PROBE_PROMPT="Respond with exactly: TACO_OK"
TACO_PROBE_TIMEOUT="${TACO_PROBE_TIMEOUT:-60}"

# Probe Codex CLI
# Usage: probe_codex → prints JSON result to stdout
probe_codex() {
  if ! _model_available "codex"; then
    printf '{"status":"unavailable","model":"gpt-5.3-codex","latency_ms":0,"response":""}\n'
    return 0
  fi

  local start end latency_ms output status response_escaped
  start=$(_ms_now)

  local saved_timeout="$CALL_MODEL_TIMEOUT"
  CALL_MODEL_TIMEOUT="$TACO_PROBE_TIMEOUT"
  if output=$(_run_with_timeout codex exec -m gpt-5.3-codex -c model_reasoning_effort=low "$TACO_PROBE_PROMPT" 2>/dev/null); then
    end=$(_ms_now)
    latency_ms=$(( end - start ))
    response_escaped=$(_json_escape "$output")

    if printf '%s' "$output" | grep -qi "TACO_OK"; then
      status="healthy"
    else
      status="degraded"
    fi
  else
    end=$(_ms_now)
    latency_ms=$(( end - start ))
    status="degraded"
    response_escaped=""
  fi

  CALL_MODEL_TIMEOUT="$saved_timeout"
  printf '{"status":"%s","model":"gpt-5.3-codex","effort":"low","latency_ms":%d,"response":"%s"}\n' \
    "$status" "$latency_ms" "$response_escaped"
}

# Probe Gemini CLI
# Usage: probe_gemini → prints JSON result to stdout
probe_gemini() {
  if ! _model_available "gemini"; then
    printf '{"status":"unavailable","model":"gemini-2.5-pro","latency_ms":0,"response":""}\n'
    return 0
  fi

  local start end latency_ms output status response_escaped
  start=$(_ms_now)

  local saved_timeout="$CALL_MODEL_TIMEOUT"
  CALL_MODEL_TIMEOUT="$TACO_PROBE_TIMEOUT"
  if output=$(_run_with_timeout _gemini_oneshot "$TACO_PROBE_PROMPT" 2>/dev/null); then
    end=$(_ms_now)
    latency_ms=$(( end - start ))
    response_escaped=$(_json_escape "$output")

    if printf '%s' "$output" | grep -qi "TACO_OK"; then
      status="healthy"
    else
      status="degraded"
    fi
  else
    end=$(_ms_now)
    latency_ms=$(( end - start ))
    status="degraded"
    response_escaped=""
  fi

  CALL_MODEL_TIMEOUT="$saved_timeout"
  printf '{"status":"%s","model":"gemini-2.5-pro","latency_ms":%d,"response":"%s"}\n' \
    "$status" "$latency_ms" "$response_escaped"
}

# -------------------------------------------------------------------
# Logged wrappers — call model + append invocation metadata to JSONL
# -------------------------------------------------------------------

TACO_MODEL_LOG="${TACO_MODEL_LOG:-/tmp/taco-model-calls.jsonl}"

# Call Codex with JSONL logging
# Usage: result=$(call_codex_logged "$prompt")
# Same interface as call_codex (stdout=output, stderr=status)
call_codex_logged() {
  local prompt="$1"
  local start end latency_ms output status prompt_len response_len
  prompt_len=${#prompt}
  start=$(_ms_now)

  output=$(call_codex "$prompt" 2>/tmp/taco-codex-status.tmp)
  status=$(cat /tmp/taco-codex-status.tmp 2>/dev/null || echo "UNKNOWN")
  rm -f /tmp/taco-codex-status.tmp

  end=$(_ms_now)
  latency_ms=$(( end - start ))
  response_len=${#output}

  # Append to log
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  printf '{"ts":"%s","model":"gpt-5.3-codex","status":"%s","latency_ms":%d,"prompt_len":%d,"response_len":%d}\n' \
    "$ts" "$status" "$latency_ms" "$prompt_len" "$response_len" >> "$TACO_MODEL_LOG"

  echo "$status" >&2
  printf '%s' "$output"
}

# Call Gemini with JSONL logging
# Usage: result=$(call_gemini_logged "$prompt")
# Same interface as call_gemini (stdout=output, stderr=status)
call_gemini_logged() {
  local prompt="$1"
  local start end latency_ms output status prompt_len response_len
  prompt_len=${#prompt}
  start=$(_ms_now)

  output=$(call_gemini "$prompt" 2>/tmp/taco-gemini-status.tmp)
  status=$(cat /tmp/taco-gemini-status.tmp 2>/dev/null || echo "UNKNOWN")
  rm -f /tmp/taco-gemini-status.tmp

  end=$(_ms_now)
  latency_ms=$(( end - start ))
  response_len=${#output}

  # Append to log
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  printf '{"ts":"%s","model":"gemini-2.5-pro","status":"%s","latency_ms":%d,"prompt_len":%d,"response_len":%d}\n' \
    "$ts" "$status" "$latency_ms" "$prompt_len" "$response_len" >> "$TACO_MODEL_LOG"

  echo "$status" >&2
  printf '%s' "$output"
}
