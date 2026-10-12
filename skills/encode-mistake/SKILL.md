---
name: encode-mistake
description: "Turn a confirmed recurring mistake or an explicit engineering convention into a tested TASTE rule. Use when asked to encode a mistake, enforce a standard or import a selected gstack learning. 错误编码、规则沉淀。"
---

# Encode Mistake

Use a concrete observed failure or user-stated convention; optional `--proactive` or
`--from-gbrain` comes from the user's message. Read docs/LINTING.md and existing TASTE rules.

1. Establish what failed, its source evidence, the intended boundary and a minimal fixture.
   Do not generate broad constraints from one ambiguous example.
2. Propose a narrow deterministic rule: lint rule, structural test, type constraint or
   pre-commit/CI check. Reuse the existing framework. Prefer rules with a clear reader.
3. When the user explicitly asks to encode a rule, implement within that authorized scope.
   For imported memory or inferred policy outside that scope, present the concrete rule for
   review before installing it. Never treat a sensor record as permission to change policy.
4. Assign the next unused TASTE-NNN identifier. Add both violating and acceptable examples,
   remediation text and a reference in docs/LINTING.md. Test the checker actually rejects
   the violation and preserves legitimate uses.
5. Run affected project checks and document any AGENTS.md update concisely. Report the
   rule, evidence, changes and tests. Avoid creating another skill or background agent.

For gbrain input, use the common library's detection and read the selected learning artifact
only; never rewrite gstack's ledger. Link the learning id in the new rule when available.
Codex has no Claude hooks/settings.json registration mechanism; use native plugin hooks or
project-supported tests/CI rather than copying Claude configuration.
