# 0006 Approval Gates

Three explicit gates in the pipeline:

- **G1** (after specify): Spec approved — scope and assumptions are explicit
  - Checked by: `gate.sh check G1` — verifies spec.md has all 5 required sections
  - Must pass before: /plan

- **G2** (after review-plan): Plan approved — implementation plan is review-approved
  - Checked by: `gate.sh check G2` — verifies plan.md has Tasks + plan-review SHIP verdict
  - Must pass before: /implement

- **G3** (after review-code): Verification passed — implementation is verified
  - Checked by: `gate.sh check G3` — verifies code-review SHIP + verify-report pass
  - Must pass before: /learn + PR merge
