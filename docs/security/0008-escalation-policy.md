# 0008 Escalation Policy

## When to Escalate

- Guard denies a write that seems necessary → review stage assignment, not bypass guard
- Gate check fails unexpectedly → review prerequisites, not force-pass
- Sandbox execution fails → check Docker setup, not run on host
- 3-model review disagrees (split verdict) → human decides, not majority vote
- Sensitive file detected in diff → human review before commit

## Escalation Path

1. Pipeline skill reports the issue with context
2. notify.sh sends alert (if configured)
3. Human reviews and decides
4. Decision logged in events.jsonl

## Never Do

- Never bypass guard.sh with direct file writes
- Never skip gate checks
- Never run implement outside sandbox/worktree without explicit user approval
- Never auto-merge without G3 pass
- Never commit files matching sensitive patterns
