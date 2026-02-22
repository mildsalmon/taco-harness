---
name: plan
description: "Generate a technical implementation plan from specification with tasks, dependencies, and risks"
allowed_tools:
  - Read
  - Grep
  - Glob
  - Task
  - Write
  - AskUserQuestion
validate_prompt: "plan.md exists with Tasks section where each Task has MUST DO and MUST NOT DO items"
---

# /plan — Technical Planning

## Usage
```
/plan <feature-name>
```

## Pipeline Stage: 3 of 7
**Prerequisite**: `/specify <feature-name>` completed (spec.md exists)

## Process

### Phase 1: Load Context
Read both:
- `.dev/specs/{feature-name}/idea.md` (original intent)
- `.dev/specs/{feature-name}/spec.md` (detailed spec)

### Phase 2: Architecture Analysis
Spawn an **explorer** agent to deep-dive into:
- Files that need modification (exact paths)
- Existing architecture patterns to follow
- Dependency graph of affected modules
- Test infrastructure available

### Phase 3: Task Decomposition
Break the spec into ordered, atomic tasks. Each task should be:
- Completable in a single focused session
- Independently testable
- Clear about what files to touch

### Phase 4: Risk Assessment
Spawn a **critic** agent to review the plan:
- Are tasks properly ordered?
- Are dependencies captured?
- Are there risky changes that need extra care?
- What could block progress?

### Phase 5: Generate Plan
Using `templates/PLAN_TEMPLATE.md`, create `.dev/specs/{feature-name}/plan.md`:

Each task MUST include:
- **Files**: Exact file paths to modify/create
- **MUST DO**: Required behaviors (from spec)
- **MUST NOT DO**: Boundaries (what to avoid)
- **Acceptance Criteria**: How to verify completion

### Phase 6: User Review
Present the plan summary. Ask if task ordering or scope needs adjustment.

## Rules
- Do NOT write any code or implementation files
- Only write to `.dev/specs/{feature-name}/`
- Tasks must be ordered by dependency (independent tasks first)
- Each task must reference specific spec requirements
