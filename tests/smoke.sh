#!/usr/bin/env bash
# smoke.sh — Automated smoke test for taco-claude scripts
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TACO="$ROOT/scripts/taco.sh"
TMP_DIR=$(mktemp -d)

fail() {
  echo "[FAIL] $1" >&2
  rm -rf "$TMP_DIR"
  exit 1
}

pass() {
  echo "[PASS] $1"
}

trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

# --- Test 1: Scripts are executable ---
for script in "$ROOT"/scripts/*.sh; do
  [[ -x "$script" ]] || fail "$(basename "$script") is not executable"
done
pass "all scripts executable"

# --- Test 2: JSON files are valid ---
for json_file in "$ROOT/.claude-plugin/plugin.json" "$ROOT/hooks/hooks.json"; do
  python3 -c "import json; json.load(open('$json_file'))" 2>/dev/null || fail "$(basename "$json_file") invalid JSON"
done
pass "JSON files valid"

# --- Test 3: taco.sh init ---
"$TACO" init "$TMP_DIR" >/dev/null 2>&1
[[ -f "$TMP_DIR/.dev/state.json" ]] || fail "state.json not created"
[[ -f "$TMP_DIR/.dev/events.jsonl" ]] || fail "events.jsonl not created"
pass "taco.sh init"

# --- Test 4: taco.sh feature new ---
"$TACO" feature new "$TMP_DIR" "test-feature" >/dev/null 2>&1
[[ -d "$TMP_DIR/.dev/specs/test-feature" ]] || fail "feature dir not created"
[[ -f "$TMP_DIR/.dev/specs/test-feature/idea.md" ]] || fail "idea.md not created"
[[ -f "$TMP_DIR/.dev/specs/test-feature/spec.md" ]] || fail "spec.md not created"
[[ -f "$TMP_DIR/.dev/specs/test-feature/plan.md" ]] || fail "plan.md not created"
[[ -f "$TMP_DIR/.dev/specs/test-feature/tasks.md" ]] || fail "tasks.md not created"
[[ -f "$TMP_DIR/.dev/specs/test-feature/reviews/verify-report.md" ]] || fail "verify-report.md not created"
pass "taco.sh feature new"

# --- Test 5: Duplicate feature should fail ---
if "$TACO" feature new "$TMP_DIR" "test-feature" >/dev/null 2>&1; then
  fail "duplicate feature should fail"
fi
pass "duplicate feature rejected"

# --- Test 6: Gate G1 should fail (spec incomplete) ---
if "$TACO" gate check G1 "$TMP_DIR" "test-feature" >/dev/null 2>&1; then
  fail "G1 should fail on incomplete spec"
fi
pass "gate G1 fails on incomplete spec"

# --- Test 7: Event log has entries ---
events=$(wc -l < "$TMP_DIR/.dev/events.jsonl")
[[ "$events" -ge 2 ]] || fail "expected at least 2 events, got $events"
pass "event log has entries ($events)"

# --- Test 8: state-manager.sh pipeline detection ---
result=$(echo '{"cwd":"'"$TMP_DIR"'","session_id":"smoke-test","prompt":"/brainstorm test-feature"}' | "$ROOT/scripts/state-manager.sh")
echo "$result" | grep -q "entering /brainstorm" || fail "state-manager did not detect /brainstorm"
pass "state-manager.sh pipeline detection"

# --- Test 8b: skill-state-update.sh PreToolUse[Skill] detection ---
result=$(echo '{"cwd":"'"$TMP_DIR"'","session_id":"smoke-skill","tool_name":"Skill","tool_input":{"skill":"taco:specify","args":"test-feature"}}' | "$ROOT/scripts/skill-state-update.sh")
echo "$result" | grep -q "entering /specify" || fail "skill-state-update did not detect taco:specify"
# Verify state.json was updated
state_stage=$(jq -r '.stage' "$TMP_DIR/.dev/state.json")
[[ "$state_stage" == "specify" ]] || fail "state.json not updated to specify (got $state_stage)"
pass "skill-state-update.sh PreToolUse[Skill] detection"

# --- Test 8c: skill-state-update.sh idempotency ---
result=$(echo '{"cwd":"'"$TMP_DIR"'","session_id":"smoke-skill","tool_name":"Skill","tool_input":{"skill":"taco:specify","args":"test-feature"}}' | "$ROOT/scripts/skill-state-update.sh")
echo "$result" | grep -q "entering /specify" && fail "skill-state-update should be idempotent"
pass "skill-state-update.sh idempotency"

# --- Test 8d: skill-state-update.sh ignores non-pipeline skills ---
result=$(echo '{"cwd":"'"$TMP_DIR"'","session_id":"smoke-skill","tool_name":"Skill","tool_input":{"skill":"taco:setup-notify","args":""}}' | "$ROOT/scripts/skill-state-update.sh")
echo "$result" | grep -q "entering" && fail "skill-state-update should ignore non-pipeline skills"
pass "skill-state-update.sh ignores non-pipeline skills"

# --- Test 8e: skill-state-update.sh without taco: prefix ---
result=$(echo '{"cwd":"'"$TMP_DIR"'","session_id":"smoke-prefix","tool_name":"Skill","tool_input":{"skill":"plan","args":"test-feature"}}' | "$ROOT/scripts/skill-state-update.sh")
echo "$result" | grep -q "entering /plan" || fail "skill-state-update should handle skills without prefix"
pass "skill-state-update.sh handles no-prefix skill names"

# Reset state for subsequent tests
echo '{"cwd":"'"$TMP_DIR"'","session_id":"smoke-test","prompt":"/brainstorm test-feature"}' | "$ROOT/scripts/state-manager.sh" >/dev/null

# --- Test 9: guard.sh stage enforcement ---
# brainstorm: .dev/ write allowed
result=$(echo '{"cwd":"'"$TMP_DIR"'","tool_name":"Write","tool_input":{"file_path":"'"$TMP_DIR"'/.dev/specs/test/idea.md"}}' | "$ROOT/scripts/guard.sh")
echo "$result" | grep -q "deny" && fail "guard should allow .dev/ write in brainstorm"
pass "guard.sh allows .dev/ in brainstorm"

# brainstorm: src/ write denied
result=$(echo '{"cwd":"'"$TMP_DIR"'","tool_name":"Write","tool_input":{"file_path":"'"$TMP_DIR"'/src/main.ts"}}' | "$ROOT/scripts/guard.sh")
echo "$result" | grep -q "deny" || fail "guard should deny src/ write in brainstorm"
pass "guard.sh denies src/ in brainstorm"

# sensitive file always denied
result=$(echo '{"cwd":"'"$TMP_DIR"'","tool_name":"Write","tool_input":{"file_path":"'"$TMP_DIR"'/.env"}}' | "$ROOT/scripts/guard.sh")
echo "$result" | grep -q "deny" || fail "guard should deny .env write"
pass "guard.sh denies .env"

# --- Test 10: Agent/skill frontmatter ---
for agent in "$ROOT"/agents/*.md; do
  awk '/^---$/{c++} c==2{found=1; exit} END{if(!found) exit 1}' "$agent" || fail "$(basename "$agent") missing frontmatter"
done
pass "all agents have valid frontmatter"

for skill in "$ROOT"/skills/*/SKILL.md; do
  awk '/^---$/{c++} c==2{found=1; exit} END{if(!found) exit 1}' "$skill" || fail "$(basename "$(dirname "$skill")") skill missing frontmatter"
  awk '/^---$/{f++; next} f==1 && /^validate_prompt:/{found=1} f>=2{exit} END{if(!found) exit 1}' "$skill" || fail "$(basename "$(dirname "$skill")") skill missing validate_prompt"
done
pass "all skills have valid frontmatter + validate_prompt"

# --- Test 11: call-model.sh loads ---
(source "$ROOT/scripts/call-model.sh" && check_models >/dev/null) || fail "call-model.sh failed to load"
pass "call-model.sh loads"

# --- Test 11b: check_models returns valid JSON with model info ---
models_json=$(source "$ROOT/scripts/call-model.sh" && check_models)
echo "$models_json" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'codex' in d and 'gemini' in d" 2>/dev/null || fail "check_models JSON structure invalid"
pass "check_models returns valid JSON"

# --- Test 11c: model doctor runs without error (short timeout to avoid hanging) ---
CALL_MODEL_TIMEOUT=5 "$TACO" model doctor >/dev/null 2>&1 || fail "model doctor command failed"
pass "model doctor runs"

# --- Test 11d: probe functions (live, skippable) ---
if [[ "${TACO_SKIP_MODEL_PROBE:-0}" != "1" ]]; then
  source "$ROOT/scripts/call-model.sh"

  # Probe Codex (if CLI available)
  if _model_available "codex"; then
    codex_probe=$(probe_codex)
    codex_probe_status=$(printf '%s' "$codex_probe" | jq -r '.status' 2>/dev/null || echo "error")
    if [[ "$codex_probe_status" == "healthy" ]]; then
      pass "probe_codex: healthy"
    elif [[ "$codex_probe_status" == "degraded" ]]; then
      echo "[WARN] probe_codex: degraded (model responded but TACO_OK not found)"
    else
      echo "[WARN] probe_codex: $codex_probe_status"
    fi
  else
    echo "[SKIP] probe_codex: CLI not installed"
  fi

  # Probe Gemini (if CLI available)
  if _model_available "gemini"; then
    gemini_probe=$(probe_gemini)
    gemini_probe_status=$(printf '%s' "$gemini_probe" | jq -r '.status' 2>/dev/null || echo "error")
    if [[ "$gemini_probe_status" == "healthy" ]]; then
      pass "probe_gemini: healthy"
    elif [[ "$gemini_probe_status" == "degraded" ]]; then
      echo "[WARN] probe_gemini: degraded (model responded but TACO_OK not found)"
    else
      echo "[WARN] probe_gemini: $gemini_probe_status"
    fi
  else
    echo "[SKIP] probe_gemini: CLI not installed"
  fi
else
  echo "[SKIP] model probes (TACO_SKIP_MODEL_PROBE=1)"
fi

# --- Test 12: synthesize-reviews.sh ---
echo "Claude ok" > "$TMP_DIR/c.txt"
echo "Codex ok" > "$TMP_DIR/x.txt"
echo "Gemini ok" > "$TMP_DIR/g.txt"
"$ROOT/scripts/synthesize-reviews.sh" "$TMP_DIR/c.txt" "$TMP_DIR/x.txt" "$TMP_DIR/g.txt" "$TMP_DIR/synth.md" >/dev/null
[[ -f "$TMP_DIR/synth.md" ]] || fail "synthesize-reviews.sh did not create output"
grep -q "3-model" "$TMP_DIR/synth.md" || fail "synthesize output missing 3-model consensus"
pass "synthesize-reviews.sh"

# --- Done ---
echo ""
echo "========================================="
echo "  ALL TESTS PASSED"
echo "========================================="
