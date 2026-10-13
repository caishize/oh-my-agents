---
name: lifecycle
description: "Read execution plans and fresh verification/review decisions, then name the next Codex skill or remediation. Use to decide the next development step; never invokes delivery automatically. 下一步、恢复、开发流程。"
---

# Lifecycle

Read-only router. Arguments are `next` (default), `status` or `recover` in the user's message.
Resolve project and plugin roots; source the common library. Read `docs/SIGNALS.md` for
freshness, default denial and release gating. Do not invoke named skills automatically.

1. Read active plans and latest verify/review signals plus history failures/findings.
2. Missing/malformed/unknown/stale evidence: name `$oh-my-agents:verify` or `$oh-my-agents:harness-review` as appropriate.
3. REQUEST_CHANGES: name the first concrete fixes in `findings[]`, then `$oh-my-agents:verify` and review.
4. NEEDS_HUMAN: explain the specific architecture or evaluation decision; recover optional
   composition skips by rerunning review without making gstack a required dependency.
5. RED: identify first failures and mapped task ids. After three identical RED reasons,
   name investigation or `$oh-my-agents:encode-mistake` when a recurring mistake is confirmed.
6. YELLOW: name unconfirmed acceptance/warnings and the check needed to resolve them.
7. Full GREEN without fresh independent APPROVE: name `$oh-my-agents:harness-review`.
8. Full GREEN + APPROVE with tree freshness: run `bash "$PLUGIN_DIR/scripts/gate.sh" "$ROOT"`
   if an explicit release-gate result is requested, then report readiness for the user's
   delivery process. Never automatically commit, push, merge, deploy or invoke gstack ship.
9. An active plan with remaining work names the relevant task; no spec/plan names
   `$oh-my-agents:spec-to-task`. If multiple plans exist, report candidates without silently choosing one.

Skills-only/cloud hosts use this explicit router because command hooks are not guaranteed.
An advisory message or a score never substitutes for actual executed tests and review.
