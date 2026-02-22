# 0001 Threat Model

## Primary Concerns

- Unintended file read/write/delete outside project boundary
- Prompt-injection-driven exfiltration of secrets or source code
- Over-broad tool execution during implement phase
- Credential leakage via git commits or logs

## Assets

- Source code
- Credentials/secrets (.env, SSH keys, API tokens)
- Pipeline state and spec documents
- Domain knowledge packs

## Baseline Objective

- Least privilege file access per pipeline stage
- Explicit export path for all artifacts
- No network access during code generation (sandbox)
- Human approval gates between major phases
