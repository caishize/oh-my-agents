---
name: entropy-sweep
description: "Inspect a project for duplicated logic, dead code, documentation drift and unconsumed artifacts. Use for periodic code health checks; report evidence before proposing fixes. 熵扫描、代码清理、文档漂移。"
---

# Entropy Sweep

Perform a read-only inspection by default. Arguments may constrain the path or dimension.
Read AGENTS.md, docs/CONVENTIONS.md, docs/LINTING.md and `.codex/harness.json`.

- Compare documented commands, counts, file paths, schemas and decisions with actual code.
- Look for duplicated behavior, unnecessary abstractions, stale dependencies and dead code.
  Confirm usage with repository searches and exports; dynamic usage needs investigation.
- Scan actual architecture imports, Providers bypasses and file-size outliers.
- Find artifacts with writers but no readers; distinguish optional data from broken gates.
- Exclude dependencies, generated code, Git metadata, signal/metric ledgers and gstack's
  external `.claude/gstack-rendered/` enclave from source-quality findings.
- Separate deterministic violations from judgment calls. Cite file:line, evidence, severity,
  a narrow remedy and the existing rule. No speculative security or style claims.

Use existing tests/checkers for confirmation without writing source. Optional gstack
artifacts can provide observations, never policy. Return a prioritized list and health trend
only when comparable prior measurements exist. Do not manufacture precision from missing data.
Ask before edits beyond the user's authorized scope. A governance review uses
`$oh-my-agents:harness-review --audit`; a focused change review uses `$oh-my-agents:harness-review`.
