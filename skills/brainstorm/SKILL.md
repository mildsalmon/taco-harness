---
name: brainstorm
description: "Socratic brainstorming: explore ideas through questions, multi-model debate, and structured output"
allowed_tools:
  - Read
  - Grep
  - Glob
  - Task
  - Write
  - Edit
  - Bash
  - AskUserQuestion
validate_prompt: "idea.md exists with Problem, Solution, Debate Summary, Risks, and References sections; status is clarified"
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

### Phase 5: Multi-Model Debate
Gather diverse perspectives on the idea using 3 models in parallel.
Reuses `call-model.sh` (`call_codex` / `call_gemini`) and `synthesize-reviews.sh` patterns.

**Claude** (critic results): Reuse the risk analysis from Phase 3 as Claude's perspective.

**Codex** (`call_codex`): Implementation-focused prompt —
> "Given this idea: {Problem + Solution summary}. Evaluate: (1) implementation complexity, (2) technical feasibility, (3) alternative approaches. Be specific and concise."

**Gemini** (`call_gemini`): Broad-perspective prompt —
> "Given this idea: {Problem + Solution summary}. Provide: (1) similar solutions in other ecosystems, (2) perspectives or angles not yet considered, (3) potential blind spots. Be specific and concise."

**Synthesis**: Combine the 3 perspectives using `synthesize-reviews.sh` → save to `.dev/specs/{feature-name}/debate.md`

**Consensus detection**: Automatically determined by `synthesize-reviews.sh`:
- `3-model` — all three models contributed
- `2-model` — two models contributed
- `claude-only` — only Claude (Codex/Gemini unavailable)

**Graceful degradation**: If Codex or Gemini CLI is unavailable, proceed with available models. If only Claude is available, skip debate file and carry Phase 3 results directly into Synthesis.

### Phase 6: Synthesis
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

## Debate Summary
{3-model debate synthesis. Points of agreement, disagreement, and key insights}
- **Consensus**: {what models agreed on}
- **Divergent**: {where models disagreed}
- **Key Insight**: {most valuable finding from debate}

## References
{External resources found by researcher, if any}

## Open Questions
{Unresolved questions for specify phase}
```

If debate was claude-only (no debate.md), write "Single-model analysis (Codex/Gemini unavailable)" in Debate Summary and summarize key points from the critic analysis.

### Phase 7: Clarify
After idea.md is written, perform a final review before handing off to `/specify`:

1. **Open Questions check** — Are the Open Questions specific enough to be actionable in the specify phase?
2. **Problem ↔ Solution coherence** — Does the Solution logically address the Problem? Any gaps?
3. **Debate resolution** — Were Divergent points from the Debate Summary addressed or acknowledged?
4. **User confirmation** — Use **AskUserQuestion** to ask:
   - "This brainstorm is ready for /specify. How would you like to proceed?"
   - Options: "Proceed to /specify" / "Revise Solution" / "Redefine Problem" / (Other)
5. If the user requests revisions, update the relevant section(s) in idea.md and re-confirm.
6. Once confirmed, update idea.md frontmatter `status: brainstorm` → `status: clarified`.

## Rules
- Do NOT write any code or implementation files
- Only write to `.dev/specs/{feature-name}/`
- Focus on understanding, not solving
- It's OK to have open questions — that's what /specify is for
- Debate phase uses Bash to invoke `call-model.sh` / `synthesize-reviews.sh` — this is the only permitted Bash usage
