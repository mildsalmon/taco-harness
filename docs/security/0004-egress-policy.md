# 0004 Egress Policy

## Allowed Outbound

- brainstorm/specify: WebSearch, WebFetch (researcher agent)
- review-plan/review-code: GitHub API via `gh` CLI
- setup-notify: Telegram API, Discord webhook (user-configured)
- All stages: Codex CLI, Gemini CLI (local process calls)

## Blocked Outbound

- implement (sandbox): `network_mode: none` — zero network access
- learn: no network access needed

## Data Exfiltration Prevention

- guard.sh blocks writes to sensitive file patterns
- Sandbox has no network — generated code cannot phone home
- Review stages are read-only — cannot modify code to add exfiltration
- Notify only sends titles/messages, never code or secrets
