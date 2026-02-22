---
name: brainstorm
description: "Socratic brainstorming: explore ideas through questions, multi-perspective analysis, and structured output"
allowed_tools:
  - Read
  - Grep
  - Glob
  - Task
  - Write
  - AskUserQuestion
validate_prompt: "idea.md exists with Problem, Solution, Risks, and References sections"
---

# /brainstorm — Idea Exploration

## Usage
```
/brainstorm <feature-name>
```

## Pipeline Stage: 1 of 7

## Process

### Phase 1: Intent Discovery
Ask the user 3-5 Socratic questions to understand the core intent:
- What problem does this solve?
- Who benefits and how?
- What does success look like?
- What constraints exist?
- What have you already considered?

Use **AskUserQuestion** tool for this — present focused questions with concrete options where possible.

### Phase 2: Context Collection
Spawn an **explorer** agent to scan the codebase:
- Identify related existing code
- Find similar patterns already in use
- Map relevant dependencies
- Note architectural constraints

### Phase 3: Risk Analysis
Spawn a **critic** agent to challenge the idea:
- Surface hidden assumptions
- Identify technical risks
- Point out scope concerns
- Suggest edge cases

### Phase 4: External Research (if needed)
Spawn a **researcher** agent if the idea involves:
- Unfamiliar technology
- External APIs or services
- Industry best practices needed

### Phase 5: Synthesis
Combine all inputs into `.dev/specs/{feature-name}/idea.md`:

```markdown
---
title: {Feature Name}
date: {YYYY-MM-DD}
status: brainstorm
---

## Problem
{What problem this solves, for whom}

## Solution
{Proposed approach, key ideas}

## Context
{Relevant existing code, patterns, constraints discovered by explorer}

## Risks
{Risks and concerns identified by critic}

## References
{External resources found by researcher, if any}

## Open Questions
{Unresolved questions for specify phase}
```

## Rules
- Do NOT write any code or implementation files
- Only write to `.dev/specs/{feature-name}/`
- Focus on understanding, not solving
- It's OK to have open questions — that's what /specify is for
