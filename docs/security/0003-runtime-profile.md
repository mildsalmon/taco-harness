# 0003 Runtime Profile

## Pipeline Stages

| Stage | File Write | Network | Bash | Task (sub-agents) |
|-------|-----------|---------|------|-------------------|
| brainstorm | .dev/ only | allowed | no | explorer, critic, researcher |
| specify | .dev/ only | allowed | no | explorer |
| plan | .dev/ only | allowed | no | explorer, critic |
| review-plan | none | allowed | yes (git, gh) | reviewer |
| implement | worktree only | sandbox: none | yes | worker |
| review-code | none | allowed | yes (git, gh) | reviewer |
| learn | docs/, CLAUDE.md | no | no | none |

## Sandbox Profile (implement stage)

- Docker: `read_only: true`, `cap_drop: ALL`, `network_mode: none`
- Non-root user (uid 10001)
- tmpfs for /tmp and /run
- No new privileges
