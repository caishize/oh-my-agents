---
name: legibility-score
description: "Assess how well repository instructions, commands, architecture and evidence support Codex development. Use for project readiness assessment or harness health scoring. 可读性评分、项目就绪评估。"
---

# Legibility Score

Read-only assessment. Score ten dimensions from actual repository evidence, each 0–3:
0 missing/broken; 1 documented but incomplete; 2 usable with known gaps; 3 verified.

1. Root AGENTS.md: concise, current commands and links.
2. Scoped instructions: nested AGENTS.md only where needed, with consistent precedence.
3. Bootstrap: reproducible tools, lockfile-respecting install, documented prerequisites.
4. Architecture: explicit boundaries and real directory mapping.
5. Structural enforcement: checks fail on representative violations.
6. Tests: meaningful executed checks and visible skipped/unrun outcomes.
7. Error legibility: file, rule, fix and documentation reference.
8. Documentation: accurate system of record, no broken links or invented decisions.
9. Observability: evidence and metrics have named consumers and source provenance.
10. Entropy resistance: tested TASTE rules, periodic inspection, no unconsumed artifacts.

For each score cite a concrete path or executed check. Do not award 3 for an unrun command;
explain limited test scope. Total is /30, not an authorization or release gate. Report top
three improvements with their evidence. Do not create instructions merely to raise a score.
Append a timestamped assessment to `.codex/metrics/legibility.jsonl` only when requested;
its consumer is `$oh-my-agents:harness-dashboard`, and paths must be anchored to the project root.
