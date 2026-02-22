# 0007 Security Tests

## Guard Tests

- [ ] brainstorm stage: .dev/ write allowed
- [ ] brainstorm stage: src/ write denied
- [ ] review-plan stage: all writes denied
- [ ] implement stage: worktree write allowed
- [ ] learn stage: docs/learnings/ write allowed, src/ denied
- [ ] .env write always denied regardless of stage
- [ ] .ssh write always denied regardless of stage
- [ ] credentials file write always denied

## Gate Tests

- [ ] G1 fails when spec.md missing
- [ ] G1 fails when spec.md missing required sections
- [ ] G1 passes with complete spec.md
- [ ] G2 fails without plan-review.md
- [ ] G2 fails when verdict is not SHIP
- [ ] G3 fails without code-review.md

## Sandbox Tests

- [ ] Container runs as non-root (uid 10001)
- [ ] Network access blocked (network_mode: none)
- [ ] Root filesystem is read-only
- [ ] All capabilities dropped
