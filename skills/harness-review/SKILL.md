---
name: harness-review
description: "Independently review changes against architecture, documentation, observability and entropy rules, saving typed findings and a decision signal. Use for review or governance audit; supports --audit. 审查、代码评审、四支柱审计。"
---

# Harness Review

Read `docs/SIGNALS.md` and `docs/LINTING.md`. Arguments select a diff/file/PR and optional
`--plan <id>`, `--audit`, `--no-gstack` or `--ux`. Local changes are the default.
Resolve the project root once. Resolve `PLUGIN_DIR` from this installed skill's path.

## Independent evaluator

Use a fresh Codex review agent when the host exposes agent tools, or an authenticated
`codex review` process when the user authorizes that route. Agent availability and read-only
permissions vary by host: request read-only inspection, and use enforced read-only tools or
sandbox where available. Skill metadata cannot restrict tools. Do not pass credentials.
Give the evaluator only the diff, relevant files, plan acceptance, project rubric, and fresh
verification evidence. Do not pass the implementer's reasoning or desired decision.
The evaluator returns findings and unresolved questions; it never writes the signal.

If no independent evaluator is available, finish useful inspection and report
NEEDS_HUMAN with `needs_human_kind: judgment-slop` and a precise reason. A self-review cannot
produce an independent APPROVE. Never invent an Explore role or use Claude Agent APIs.

## Rubric

Inspect correctness first, then these four dimensions:
- Architecture: actual imports/layers, Providers boundaries, structural enforcement.
- Documentation: AGENTS.md, runnable commands, schemas, links and drift from code.
- Observability: actionable failures, evidence source, metrics readers, decision freshness.
- Entropy: duplicate logic, overengineering, dead code, inconsistent patterns and slop.

Each finding has `fingerprint` (file:line:rule), `severity` P0/P1/P2, `tag`, and actionable
`fix`; include source evidence and confidence in the detailed report. Reject speculative
findings. Deduplicate by fingerprint and escalate severity when confirmed sources disagree.
Read optional gstack artifacts only when present; use `$oh-my-agents:gstack-sync` for capability detection.
Do not invoke gstack's Claude skills or a second Codex model merely to label it cross-model.
For `--ux`, inspect a representative user interaction if possible; report untested behavior.

## Governance audit (`--audit`)

This replaces the Claude Dynamic Workflow. Audit the entire selected scope, one pass per
pillar plus cross-cutting contracts. With native agent support, independent auditors may
work on separate dimensions; otherwise inspect sequentially and retain the independence
requirement for the final decision. An independent skeptical pass tries to refute each
candidate against actual source. Unconfirmed candidates are not reported as defects.
The final accountable reviewer derives and writes the signal. No delivery orchestration,
source mutations, commits or PR creation occur during an audit.

## Decision and persistence

Compute from confirmed findings: any P0/P1 gives REQUEST_CHANGES; unresolved architecture
or evaluation ambiguity gives NEEDS_HUMAN; otherwise APPROVE. Reconcile an optional fresh
gstack verdict read-only: opposite conclusions give NEEDS_HUMAN (judgment-slop), never
silently overrule either evaluator. Missing gstack is optional, not a blocker by itself.

Stamp the decision with the current HEAD and contract freshness evidence; if source changes
during review, invalidate or rerun it. Write `.codex/signals/review-latest.json` and append
`.codex/metrics/reviews.jsonl` using `append_history_record` from the common library.
The record includes typed `findings[]`; the compact signal follows the contract byte limit.
Report the decision, findings, independent evaluation method, limitations and next skill.
