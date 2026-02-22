# {Domain Name}

- Version: 0.1.0
- Scope: {brief description of domain coverage}
- Mode: iterative

## Injection Points

| Pipeline Stage | File | How It's Used |
|---------------|------|---------------|
| specify | SPEC_ADDON.md | Additional domain requirements injected into spec |
| plan | RISK_CHECKLIST.md | Domain risks added to plan risk assessment |
| review-code | VERIFY_SCENARIOS.md | Domain test scenarios added to review criteria |
| learn | LEARNINGS.md → KNOWLEDGE.md | Provisional learnings promoted to stable rules |

## Required Files

```
domains/{domain-name}/
├── MANIFEST.md          # This file — pack metadata + injection points
├── BOUNDARY.md          # In-scope and out-of-scope definitions
├── GLOSSARY.md          # Domain terminology dictionary
├── KNOWLEDGE.md         # Verified domain rules (promoted from LEARNINGS)
├── LEARNINGS.md         # Provisional domain learnings (not yet verified)
├── RISK_CHECKLIST.md    # Domain-specific risk checklist for design phase
├── SPEC_ADDON.md        # Additional requirements for specify phase
└── VERIFY_SCENARIOS.md  # Domain-specific test scenarios for verification
```

## Activation

Enable: add domain name to `.dev/state.json` enabled_packs array
Disable: remove from enabled_packs array
