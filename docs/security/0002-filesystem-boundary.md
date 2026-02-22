# 0002 Filesystem Boundary

- guard.sh enforces stage-based file access control
- brainstorm/specify/plan: only `.dev/` writes allowed
- review-plan/review-code: read-only, no writes
- implement: worktree directory only
- learn: `docs/learnings/`, `CLAUDE.md`, `templates/` only
- Always blocked: `.env`, `.ssh`, `credentials`, `secret`, `id_rsa`, `id_ed25519`
- Prefer isolated workspace in sandbox volume for implement stage
- Export only reviewed artifacts, not full workspace
