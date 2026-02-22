---
name: review-code
description: "3-model code review (Claude + Codex + Gemini) with PR comments and Ready-for-Review transition"
allowed_tools:
  - Read
  - Grep
  - Glob
  - Task
  - Bash
  - Write
validate_prompt: "code-review.md saved with SHIP or NEEDS_FIXES verdict"
---

# /review-code — 3-Model Code Review

## Usage
```
/review-code <feature-name>
```

## Pipeline Stage: 6 of 7
**Prerequisite**: `/implement <feature-name>` completed

## Process

### Phase 1: Extract Diff
Get the full changeset from the feature branch:
```bash
cd {worktree} && git diff main...HEAD
```

Also gather:
- List of changed files
- spec.md and plan.md for context

### Phase 2: 3-Model Parallel Review
Same pattern as review-plan, but with code review criteria:

**Claude** (always available):
- Spawn **reviewer** agent with diff + spec context
- Focus: correctness, security, error handling, test coverage

**Codex** (if available):
- `call_codex` with code review prompt
- Focus: code quality, patterns, potential bugs

**Gemini** (if available):
- `call_gemini` with code review prompt
- Focus: performance, alternative approaches, edge cases

### Phase 3: Synthesize
Use `scripts/synthesize-reviews.sh` to merge:
- CR-xxx numbered findings
- Consensus level (3-model, 2-model, claude-only)
- Verdict: **SHIP** or **NEEDS_FIXES**

Save to `.dev/specs/{feature-name}/reviews/code-review.md`

### Phase 4: Act on Verdict

**If NEEDS_FIXES**:
- Present findings grouped by severity
- List specific files and lines to fix
- Suggest running `/implement` again after fixes
- Do NOT mark PR as ready

**If SHIP**:
1. Add review summary as PR comment:
   ```bash
   gh pr comment --body "{review summary}"
   ```
2. Mark PR as ready for review:
   ```bash
   gh pr ready
   ```
3. Send notification via `scripts/notify.sh`

## Rules
- This is a REVIEW stage — do not modify code directly
- All findings must be specific (file:line, not vague)
- Graceful degradation if Codex/Gemini unavailable
