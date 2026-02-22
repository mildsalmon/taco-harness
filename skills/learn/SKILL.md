---
name: learn
description: "Retrospective analysis: extract learnings, update knowledge base, and refine rules"
allowed_tools:
  - Read
  - Grep
  - Glob
  - Write
  - Edit
  - AskUserQuestion
validate_prompt: "Learning file created in docs/learnings/ and index.md updated"
---

# /learn — Retrospective & Knowledge Capture

## Usage
```
/learn <feature-name>
```

## Pipeline Stage: 7 of 7
**Prerequisite**: `/review-code <feature-name>` completed

## Process

### Phase 1: Load Full History
Read the complete pipeline history:
- `.dev/specs/{feature-name}/idea.md`
- `.dev/specs/{feature-name}/spec.md`
- `.dev/specs/{feature-name}/plan.md`
- `.dev/specs/{feature-name}/reviews/plan-review.md`
- `.dev/specs/{feature-name}/reviews/code-review.md`

### Phase 2: Retrospective Analysis
Analyze the pipeline execution:

**What went well?**
- Which phases flowed smoothly?
- What decisions proved correct?
- What patterns worked effectively?

**What didn't go well?**
- Where were there iterations/rework?
- What was missed in earlier phases?
- What surprised us during implementation?

**What to change?**
- Process improvements for next time
- New patterns to adopt
- Warnings for similar future work

### Phase 3: Create Learning Record
Generate `docs/learnings/{YYYY-MM-DD}-{feature-name}.md`:

```markdown
---
title: {Feature Name} — Learnings
tags: [{relevant tags}]
date: {YYYY-MM-DD}
feature: {feature-name}
---

## Summary
{1-2 sentence summary}

## What Went Well
{bullets}

## What Didn't Go Well
{bullets}

## Key Learnings
{numbered insights}

## Process Improvements
{suggestions for pipeline/template changes}
```

### Phase 4: Update Index
Run `scripts/update-index.sh` to add entry to `docs/learnings/index.md`.

### Phase 5: Rule Updates (with user approval)
If learnings suggest changes to:
- **CLAUDE.md**: Project rules
- **templates/**: Spec or plan templates
- **Skills**: Pipeline step improvements

Present proposed changes to user via **AskUserQuestion**.
Only apply changes with explicit approval.

## Rules
- Only write to `docs/learnings/`, `CLAUDE.md`, and `templates/`
- Never modify `.dev/specs/` retrospectively
- All rule changes require user approval
- Be honest about failures — they're the most valuable learnings
