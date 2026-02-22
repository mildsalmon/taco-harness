---
name: implement
description: "Orchestrator-Worker implementation using Codex CLI in isolated worktree with Docker support"
allowed_tools:
  - Read
  - Grep
  - Glob
  - Task
  - Bash
  - Write
  - Edit
validate_prompt: "All Tasks from plan.md have acceptance_criteria marked PASS"
---

# /implement — Code Implementation

## Usage
```
/implement <feature-name>
```

## Pipeline Stage: 5 of 7
**Prerequisites**:
- `/review-plan <feature-name>` completed with SHIP verdict
- Git worktree exists for feature branch
- plan-review.md exists

## Process

### Phase 1: Pre-flight Checks
Verify prerequisites:
1. `.dev/specs/{feature-name}/plan.md` exists
2. `.dev/specs/{feature-name}/reviews/plan-review.md` exists with SHIP verdict
3. Feature worktree exists (check `git worktree list`)

If worktree missing, create it:
```bash
git worktree add ../{feature-name}-wt -b feat/{feature-name}
```

### Phase 2: Parse Tasks
Extract ordered task list from plan.md.
Build execution sequence respecting dependencies.

Load `docs/coding-principles.md` — include its key rules as context when delegating to workers.

### Phase 3: Execute Tasks
For each task in order:

**Option A — Docker isolated (preferred)**:
```bash
docker run --rm --network none \
  -v "{worktree}:/workspace" \
  -w /workspace {base-image} \
  codex exec "{task-prompt}"
```

**Option B — Direct execution (fallback)**:
If Docker unavailable, execute in worktree directly:
- Spawn **worker** agent for each task
- Worker operates within worktree directory
- guard.sh restricts file access to worktree

### Phase 4: Per-Task Verification
After each task:
1. Run acceptance criteria checks
2. Commit changes in worktree:
   ```bash
   cd {worktree} && git add -A && git commit -m "feat({feature}): {task title}"
   ```
3. Log result to `.dev/state.json`

### Phase 5: Completion
After all tasks:
1. Push feature branch: `git push -u origin feat/{feature-name}`
2. Update `.dev/state.json` with completion status
3. Send notification via `scripts/notify.sh`

## Orchestrator Rules
- You are the **Orchestrator** — delegate to workers, don't implement directly
- Each worker gets ONE task — no multi-task workers
- Workers MUST NOT use Task tool (no sub-delegation)
- If a task fails, stop and report — don't skip ahead
- Commit after each successful task (atomic commits)
