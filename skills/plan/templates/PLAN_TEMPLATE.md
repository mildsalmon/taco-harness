---
title: "{Feature Name} — Technical Plan"
spec: ".dev/specs/{feature-name}/spec.md"
status: draft
feature: "{feature-name}"
date: "{YYYY-MM-DD}"
---

## Architecture

{High-level overview of the implementation approach.
How does it fit into the existing codebase? What patterns does it follow?}

**Layer Separation** (refer to `docs/coding-principles.md`):
- **Domain**: {domain models, services, and ports involved}
- **Port**: {interfaces introduced or modified — Driving and Driven}
- **Adapter**: {concrete implementations — REST, DB, external API, etc.}

## Tasks

### Task 1: {Title}
- **Files**: {list of files to modify/create}
- **MUST DO**:
  - {required behavior from spec}
  - {required behavior}
- **MUST NOT DO**:
  - {boundary — what to avoid}
  - {boundary}
  - Do not reference infrastructure directly from the domain layer
  - Review: could an if/else chain be replaced with polymorphism (Strategy)?
- **Acceptance Criteria**:
  - [ ] {verifiable criterion}
  - [ ] {verifiable criterion}

### Task 2: {Title}
- **Files**: {list}
- **MUST DO**:
  - {required behavior}
- **MUST NOT DO**:
  - {boundary}
- **Acceptance Criteria**:
  - [ ] {criterion}

{Continue for all tasks...}

## Dependencies

{Task dependency graph. Which tasks must complete before others can start?}

```
Task 1 → Task 2 → Task 4
Task 1 → Task 3 → Task 4
```

## Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| {risk description} | High/Medium/Low | High/Medium/Low | {mitigation strategy} |

## Verification

{How to verify the complete implementation:}
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Manual verification steps: {list}
- [ ] Performance benchmarks: {if applicable}
