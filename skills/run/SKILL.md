---
name: run
description: "Autopilot: run the full pipeline (brainstorm → learn) in one command with gate checkpoints"
allowed_tools:
  - Read
  - Grep
  - Glob
  - Task
  - Bash
  - Write
  - Edit
  - AskUserQuestion
  - Skill
validate_prompt: "Pipeline completed or stopped at a gate with clear status report"
---

# /run — Autopilot Pipeline Execution

## Usage
```
/run <feature-name>              # Interactive mode (checkpoint at gates)
/run <feature-name> --auto       # Full auto (stop only on gate failure)
/run <feature-name> --from plan  # Resume from a specific stage
```

## Pipeline Stages (in order)

```
brainstorm → specify → [G1] → plan → review-plan → [G2] → implement → review-code → [G3] → learn
```

## Process

### Step 0: Initialize
1. Parse arguments: feature name, mode (interactive/auto), starting stage
2. Check if `.dev/specs/{feature}/` exists — if yes, detect current stage and offer to resume
3. If new feature, start from brainstorm

### Step 1: Execute Stage
For each stage in sequence:

1. **Announce**: "Stage {N}/7: /{stage} {feature}"
2. **Invoke skill**: Use the Skill tool to call the corresponding pipeline skill
   - `/brainstorm {feature}`
   - `/specify {feature}`
   - `/plan {feature}`
   - `/review-plan {feature}`
   - `/implement {feature}`
   - `/review-code {feature}`
   - `/learn {feature}`
3. **Wait for completion**: The skill runs to completion

### Step 2: Gate Check (at G1, G2, G3 points)

**After specify (G1):**
- Run `scripts/gate.sh check G1 {project} {feature}`
- PASS → continue to /plan
- FAIL → report what's missing

**After review-plan (G2):**
- Run `scripts/gate.sh check G2 {project} {feature}`
- PASS → continue to /implement
- FAIL → report what's missing

**After review-code (G3):**
- Run `scripts/gate.sh check G3 {project} {feature}`
- PASS → continue to /learn
- FAIL → report what's missing

### Step 3: Checkpoint (interactive mode only)

At each gate, in interactive mode:
- Show gate result + stage summary
- Ask user via **AskUserQuestion**:
  - **Continue** — proceed to next stage
  - **Pause** — stop here, can resume later with `--from`
  - **Redo** — re-run the current stage

In auto mode: continue automatically if gate passes, stop if gate fails.

### Step 4: Completion Report

When all 7 stages complete (or pipeline stops):

```markdown
## Pipeline Report: {feature}

| Stage | Status | Duration |
|-------|--------|----------|
| brainstorm | DONE | — |
| specify | DONE | — |
| plan | DONE | — |
| review-plan | DONE (SHIP) | — |
| implement | DONE | — |
| review-code | DONE (SHIP) | — |
| learn | DONE | — |

Gates: G1 PASS | G2 PASS | G3 PASS
Result: PIPELINE COMPLETE
```

Send notification via `scripts/notify.sh` if configured.

## Resume Support

The `/run` command can resume from any stage:

```
/run my-feature --from implement
```

This checks:
1. Previous stages' artifacts exist
2. Relevant gates are passed
3. Starts from the specified stage

## State Tracking

During autopilot, update `.dev/state.json` with:
- `mode: "autopilot"` — indicates /run is driving
- `autopilot_stage: N` — current stage number (1-7)

## Error Handling

- **Skill failure**: Stop pipeline, report which stage failed and why
- **Gate failure**: Stop pipeline, report gate failure details
- **User interrupt**: Save current state, can resume with `--from`

## Rules
- Each stage uses its own skill — /run is an orchestrator, not a reimplementation
- Gate checks are mandatory — never skip gates even in auto mode
- Always show a completion report at the end
- Respect all guard.sh restrictions (they apply per-stage automatically)
