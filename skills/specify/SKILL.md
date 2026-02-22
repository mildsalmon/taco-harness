---
name: specify
description: "Transform brainstorm ideas into structured specifications via interview-driven refinement"
allowed_tools:
  - Read
  - Grep
  - Glob
  - Task
  - Write
  - AskUserQuestion
validate_prompt: "spec.md exists with all 5 sections: Overview, User Scenarios, Core Requirements, Technical Details, Testing Plan"
---

# /specify — Specification Writing

## Usage
```
/specify <feature-name>
```

## Pipeline Stage: 2 of 7
**Prerequisite**: `/brainstorm <feature-name>` completed (idea.md exists)

## Process

### Phase 1: Load Context
Read `.dev/specs/{feature-name}/idea.md` to understand the brainstorm output.
Check for open questions that need resolution.

### Phase 2: Clarification Interview
Use **AskUserQuestion** to resolve open questions from brainstorm:
- Scope boundaries (what's in, what's out)
- Technical constraints (performance, compatibility)
- Testing expectations (what constitutes "done")
- Priority of features (must-have vs nice-to-have)

### Phase 3: Codebase Analysis
Spawn an **explorer** agent to analyze:
- Existing code that will be modified
- API contracts and interfaces
- Test patterns in use
- Data models affected

### Phase 4: Draft Specification
Using the template at `templates/SPEC_TEMPLATE.md`, create `.dev/specs/{feature-name}/spec.md` with:

1. **Overview**: 1-2 sentence summary
2. **User Scenarios**: Concrete usage scenarios
3. **Core Requirements**: Functional and non-functional requirements
4. **Technical Details**: Architecture, API changes, data model changes
5. **Testing Plan**: Unit tests, integration tests, edge cases

### Phase 5: User Confirmation
Present the draft spec to the user for review.
Ask if anything needs adjustment before planning.

## Rules
- Do NOT write any code or implementation files
- Only write to `.dev/specs/{feature-name}/`
- Every requirement must be testable
- Avoid ambiguous language ("should", "might") — use "MUST" / "MUST NOT"
