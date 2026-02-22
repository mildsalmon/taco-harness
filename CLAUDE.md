# taco-harness — Personal Dev Harness

A Claude Code plugin implementing a structured development pipeline:
`/brainstorm → /specify → /plan → /review-plan → /implement → /review-code → /learn`

## Pipeline Overview

| Stage | Command | Model | Purpose | Gate |
|-------|---------|-------|---------|------|
| 1 | `/brainstorm <name>` | Claude | Explore ideas via Socratic Q&A | — |
| 2 | `/specify <name>` | Claude | Write structured specification | — |
| 3 | `/plan <name>` | Claude | Generate technical plan | G1 (spec complete) |
| 4 | `/review-plan <name>` | Claude+Codex+Gemini | 3-model plan review + Draft PR | — |
| 5 | `/implement <name>` | Codex+Claude | Orchestrator-Worker implementation | G2 (plan approved) |
| 6 | `/review-code <name>` | Claude+Codex+Gemini | 3-model code review + PR Ready | — |
| 7 | `/learn <name>` | Claude | Retrospective + knowledge capture | G3 (verify passed) |

**Utility**: `/setup-notify` — Configure Telegram/Discord notifications
**CLI**: `./scripts/taco.sh` — Pipeline management from terminal

## Gate System

Three explicit approval gates prevent skipping prerequisites:

| Gate | When | Checks | Required Before |
|------|------|--------|-----------------|
| G1 | After specify | spec.md has all 5 sections | /plan |
| G2 | After review-plan | plan.md has Tasks + plan-review SHIP | /implement |
| G3 | After review-code | code-review SHIP + verify-report pass | /learn |

Gate checks run automatically when entering gated stages.
Manual check: `./scripts/taco.sh gate check G1 <project-dir> <feature>`

## Directory Structure

### Plugin Files (this repo)
```
taco-harness/
├── .claude-plugin/plugin.json   # Plugin registration
├── hooks/hooks.json             # Hook definitions
├── scripts/                     # Bash hook + utility scripts
│   ├── state-manager.sh         # Pipeline state management (hook)
│   ├── guard.sh                 # File access control (hook)
│   ├── validate.sh              # Output validation (hook)
│   ├── next-step.sh             # Next stage suggestion (hook)
│   ├── gate.sh                  # Gate checking
│   ├── event-log.sh             # JSONL event logging
│   ├── call-model.sh            # External model invocation
│   ├── synthesize-reviews.sh    # 3-model review synthesis
│   ├── notify.sh                # Telegram/Discord notifications
│   ├── update-index.sh          # Learnings index management
│   ├── sandbox-run.sh           # Docker sandbox management
│   └── taco.sh                  # Unified CLI
├── agents/                      # 5 generic agents
├── skills/                      # Pipeline skills + templates
├── sandbox/                     # Docker sandbox files
│   ├── Dockerfile.runner        # Minimal Alpine container
│   └── docker-compose.yml       # Isolated runner service
├── templates/
│   ├── VERIFY_REPORT_TEMPLATE.md
│   ├── TASKS_TEMPLATE.md
│   └── domains/                 # Domain knowledge pack templates
├── docs/security/               # Security policy documents (8)
├── tests/smoke.sh               # Automated smoke tests
└── CLAUDE.md                    # This file
```

### Runtime Files (per project, git-ignored)
```
{project}/
├── .dev/
│   ├── state.json               # Current pipeline state
│   ├── events.jsonl             # Event audit trail
│   └── specs/{feature}/
│       ├── idea.md              # brainstorm output
│       ├── spec.md              # specify output
│       ├── plan.md              # plan output
│       ├── tasks.md             # Task tracker (backlog/done)
│       └── reviews/
│           ├── plan-review.md   # review-plan output
│           ├── code-review.md   # review-code output
│           └── verify-report.md # Verification evidence
└── docs/learnings/              # git-tracked knowledge base
    ├── index.md                 # Learning index
    └── {date}-{name}.md        # Individual learnings
```

## Event Log

All pipeline actions are recorded in `.dev/events.jsonl`:
```jsonl
{"ts":"2026-02-22T01:00:00Z","event":"stage_enter","feature":"login","details":"entering brainstorm"}
{"ts":"2026-02-22T01:05:00Z","event":"gate_pass","feature":"login","details":"G1"}
{"ts":"2026-02-22T01:06:00Z","event":"guard_deny","feature":"login","details":"sensitive file: .env"}
```

View events: `./scripts/taco.sh events <project-dir> [count]`

## Hook System

### UserPromptSubmit — `state-manager.sh`
- Detects `/brainstorm`, `/specify`, etc. in prompts
- Manages `.dev/state.json` (current stage, feature, session)
- **Checks gates** before entering gated stages (warns if prerequisites missing)
- Logs `stage_enter` events to events.jsonl
- Idempotent: skips if same session+stage+feature
- Auto-cleans stale sessions (>24h)

### PreToolUse[Edit|Write] — `guard.sh`
Stage-based file access control:

| Stage | Allowed Writes |
|-------|---------------|
| brainstorm, specify, plan | `.dev/` only |
| review-plan, review-code | NONE (read-only) |
| implement | Project directory (worktree) |
| learn | `docs/learnings/`, `CLAUDE.md`, `templates/` |
| (no state) | Everything (guard inactive) |

Always blocked: `.env`, `.ssh`, `credentials`, `secret`, `id_rsa`, `id_ed25519`
Denials are logged to events.jsonl.

### PostToolUse[Task|Skill] — `validate.sh` + `next-step.sh`
- `validate.sh`: Extracts `validate_prompt` from agent/skill frontmatter, outputs verification guidance
- `next-step.sh`: Suggests next pipeline stage after current skill completes

## Agents

| Agent | Model | Role | Tools |
|-------|-------|------|-------|
| explorer | sonnet | Codebase exploration, pattern discovery | Read-only |
| critic | opus | Devil's advocate, risk analysis | Read-only |
| reviewer | opus | Code/plan review, CR-xxx findings | Read + Bash |
| worker | sonnet | Focused implementation tasks | Read + Write + Edit + Bash |
| researcher | sonnet | External research, references | Read + Web |

## Model Distribution

- **Claude** (default): brainstorm, specify, plan, learn — thinking and documentation
- **Codex CLI** (`codex exec`): implement — code generation
- **3-Model** (Claude + Codex + Gemini): review-plan, review-code — diverse perspectives

Graceful degradation: if Codex/Gemini CLI unavailable, proceeds with Claude only.

## Sandbox (Docker Isolation)

The implement stage can use Docker for isolated code execution:
- **Network**: `none` (zero outbound access)
- **Filesystem**: `read_only: true` root, tmpfs for /tmp
- **User**: non-root (uid 10001)
- **Capabilities**: all dropped, no new privileges

```bash
./scripts/sandbox-run.sh up        # Start sandbox
./scripts/sandbox-run.sh seed src/ # Copy files in
./scripts/sandbox-run.sh run "make build"  # Execute
./scripts/sandbox-run.sh collect output.tar # Extract results
./scripts/sandbox-run.sh down      # Tear down
```

Fallback: if Docker unavailable, implement runs in git worktree with guard.sh file restrictions.

## CLI (taco.sh)

```bash
./scripts/taco.sh init <project-dir>                # Initialize .dev/
./scripts/taco.sh feature new <project-dir> <name>  # Create feature scaffold
./scripts/taco.sh feature list <project-dir>         # List features
./scripts/taco.sh gate check <G1|G2|G3> <dir> <feature>  # Check gate
./scripts/taco.sh state show <project-dir>           # Show pipeline state
./scripts/taco.sh events <project-dir> [n]           # Show last n events
```

## Domain Packs (Extensible)

Structured domain knowledge injected into pipeline stages:

```
domains/{domain-name}/
├── MANIFEST.md          # Pack metadata + injection points
├── BOUNDARY.md          # In-scope / out-of-scope
├── GLOSSARY.md          # Domain terminology
├── KNOWLEDGE.md         # Verified rules (promoted from learnings)
├── LEARNINGS.md         # Provisional learnings
├── RISK_CHECKLIST.md    # Design-phase risk checklist
├── SPEC_ADDON.md        # Additional specify requirements
└── VERIFY_SCENARIOS.md  # Domain test scenarios
```

Templates in `templates/domains/` (MANIFEST_TEMPLATE.md, BOUNDARY_TEMPLATE.md).

## Security

8 security policy documents in `docs/security/`:
- 0001-threat-model.md — Assets, threats, objectives
- 0002-filesystem-boundary.md — Stage-based access rules
- 0003-runtime-profile.md — Per-stage permission matrix
- 0004-egress-policy.md — Network access rules
- 0005-prompt-injection-policy.md — Untrusted input handling
- 0006-approval-gates.md — G1/G2/G3 gate definitions
- 0007-security-tests.md — Security test checklist
- 0008-escalation-policy.md — When and how to escalate

## Writing validate_prompt

Every agent and skill MUST have a `validate_prompt` in YAML frontmatter:
```yaml
---
validate_prompt: "Description of what must be true when this agent/skill completes"
---
```

Guidelines:
- Be specific and verifiable
- Reference concrete artifacts (files, sections, fields)
- Example: `"spec.md exists with all 5 sections: Overview, User Scenarios, Core Requirements, Technical Details, Testing Plan"`

## Writing New Agents

```yaml
---
model: sonnet | opus
allowed_tools:        # whitelist (optional)
  - Read
  - Grep
disallowed_tools:     # blacklist (optional)
  - Task              # workers should never sub-delegate
validate_prompt: "..."
---

# Agent Name

{Role description and guidelines}
```

## Git Worktree Usage

The `/review-plan` stage creates a worktree for implementation isolation:
```bash
git worktree add ../{feature}-wt -b feat/{feature}
```

After `/review-code` SHIP verdict, the worktree branch is pushed and PR marked ready.
Clean up worktrees after merge: `git worktree remove ../{feature}-wt`

## Learning System

The `/learn` stage creates searchable knowledge records:
- Stored in `docs/learnings/` (git-tracked)
- Indexed in `docs/learnings/index.md` with frontmatter metadata
- Can propose updates to CLAUDE.md, templates, or skills
- All rule changes require user approval

## Testing

Run automated smoke tests:
```bash
./tests/smoke.sh
```

Tests cover: script executability, JSON validity, init/feature/gate/state-manager/guard/agent/skill validation.

## External Dependencies

- **Required**: `jq` (JSON processing)
- **Optional**: `codex` CLI (Codex model), `gemini` CLI (Gemini model)
- **Optional**: `timeout` or `gtimeout` (if unavailable, built-in watchdog fallback is used)
- **Optional**: `gh` CLI (GitHub PR operations)
- **Optional**: `docker` (isolated implementation sandbox)
