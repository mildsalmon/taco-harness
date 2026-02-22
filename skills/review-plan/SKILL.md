---
name: review-plan
description: "3-model plan review (Claude + Codex + Gemini) with synthesized verdict and Draft PR creation"
allowed_tools:
  - Read
  - Grep
  - Glob
  - Task
  - Bash
  - Write
validate_prompt: "plan-review.md saved and Draft PR URL present (or reason for skip)"
---

# /review-plan — 3-Model Plan Review

## Usage
```
/review-plan <feature-name>
```

## Pipeline Stage: 4 of 7
**Prerequisite**: `/plan <feature-name>` completed (plan.md exists)

## Process

### Phase 1: Load Artifacts
Read all specs:
- `.dev/specs/{feature-name}/idea.md`
- `.dev/specs/{feature-name}/spec.md`
- `.dev/specs/{feature-name}/plan.md`

### Phase 2: 3-Model Parallel Review
Execute reviews from all available models:

**Claude** (always available):
- Spawn **reviewer** agent with plan.md + spec.md
- Focus: logical consistency, completeness, feasibility

**Codex** (if available):
- Use `scripts/call-model.sh` → `call_codex` with review prompt
- Focus: implementation feasibility, code architecture

**Gemini** (if available):
- Use `scripts/call-model.sh` → `call_gemini` with review prompt
- Focus: alternative approaches, edge cases

### Phase 3: Synthesize
Use `scripts/synthesize-reviews.sh` to merge results:
- Identify consensus items
- Flag divergent opinions
- Deduplicate findings into CR-xxx format
- Determine verdict: **SHIP** or **NEEDS_FIXES**

Save to `.dev/specs/{feature-name}/reviews/plan-review.md`

### Phase 4: Act on Verdict

**If NEEDS_FIXES**:
- Present findings to user
- Suggest returning to `/plan` to address issues
- Do NOT create PR

**If SHIP**:
1. Create git worktree for the feature branch:
   ```bash
   git worktree add ../{feature-name}-wt -b feat/{feature-name}
   ```
2. Create Draft PR:
   ```bash
   gh pr create --draft --title "feat: {feature-name}" --body "{plan summary}"
   ```
3. Send notification via `scripts/notify.sh`

## Rules
- This is a READ-ONLY review stage — do not modify plan.md
- Reviews must produce CR-xxx numbered findings
- Graceful degradation: if Codex/Gemini unavailable, proceed with Claude-only
