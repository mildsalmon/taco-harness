---
title: "{Feature Name}"
version: 1
status: draft
feature: "{feature-name}"
date: "{YYYY-MM-DD}"
---

## Overview

{1-2 sentence summary of what this feature does and why it matters.}

## User Scenarios

### Scenario 1: {Primary Use Case}
**As a** {user type},
**I want to** {action},
**So that** {benefit}.

**Steps**:
1. {step}
2. {step}
3. {step}

### Scenario 2: {Secondary Use Case}
{...}

## Core Requirements

### Functional
- [ ] FR-1: {requirement — MUST/MUST NOT language}
- [ ] FR-2: {requirement}
- [ ] FR-3: {requirement}

### Non-Functional
- [ ] NFR-1: {performance/security/reliability requirement}
- [ ] NFR-2: {requirement}

## Technical Details

### Architecture
{How this fits into the existing system. Diagrams if helpful.}

**Hexagonal Boundaries** (refer to `docs/coding-principles.md`):
- Define which Port interfaces this feature introduces or modifies (Driving/Driven)
- Identify Adapter implementations needed (REST, DB, external API, etc.)
- Confirm the domain model has no direct external dependencies

### API Changes
{New or modified endpoints/interfaces. "None" if no API changes.}

### Data Model
{New or modified data structures. "None" if no data changes.}

### Dependencies
{External libraries or services needed. "None" if self-contained.}

## Testing Plan

### Unit Tests
- [ ] {test case description}
- [ ] {test case description}

### Integration Tests
- [ ] {test case description}

### Edge Cases
- [ ] {edge case and expected behavior}
- [ ] {edge case and expected behavior}
