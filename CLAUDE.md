# Oh-My-Agents — Harness Engineering Plugin for Claude Code

**v3.4.0** — Mechanical quality constraints + entropy management for AI-driven
development. **Composition-based** integration with
[gstack](https://github.com/garrytan/gstack.git) v1.28+; we own
*architecture / entropy / observability* and **never orchestrate workflows**
(gstack does that).

## Differentiation anchor

| oh-my-agents owns | gstack owns | Don't reinvent |
|---|---|---|
| hooks, arch-guard, TASTE rules, entropy-sweep | ideate / plan / ship / deploy / canary / retro | Managed Agents / Agents SDK runtime |
| review **decision signal**, legibility scoring | `/codex` `/cso` `/ux-audit` `/investigate` `/qa` | gstack lifecycle orchestration |
| two-layer model: observation → mechanical enforcement | observation layer (GBrain memory ingest) | auto-generated rules (ETH Zurich 2026) |

## Surface

11 user-invocable skills (full details in [docs/WORKFLOW.md](docs/WORKFLOW.md)):
`harness-init`, `legibility-score`, `spec-to-task`, `verify`, `encode-mistake`,
`arch-guard`, `entropy-sweep`, `harness-review`, `harness-dashboard`, `gstack-sync`,
`lifecycle`. 2 read-only background agents in `agents/`. 6 enforcement hooks
(`arch-check`, `safety-check`, `bash-safety-check`, `self-verify-check`,
`session-metrics`, `doc-drift-check`).

## Workflow (TL;DR)

- One-time: `/harness-init --quick` + `/gstack-sync --setup`
- Daily: `/lifecycle next` (router-only; chains gstack + harness skills, halts on
  `review-latest.json` decision)
- Mistake → guardrail: `/investigate` (gstack) → `/encode-mistake --from-gbrain` (here)
- Weekly: `/entropy-sweep` → `/harness-dashboard` → `/gstack-sync --metrics`

Full lifecycle: [docs/WORKFLOW.md](docs/WORKFLOW.md).
Bridge manifest: [docs/INTEGRATION.md](docs/INTEGRATION.md).
Architecture (incl. Anthropic 3-agent mapping): [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## gstack integration — what's wired (v1.28 baseline)

- **Bridge dual-value**: every gstack v1.27+ rename is probed at both legacy
  (`gstack-brain*`) and current (`gstack-artifacts*`) paths.
- **`/encode-mistake --from-gbrain {learning|eureka|retro|all}`** — observation →
  TASTE rule, always human-gated.
- **`/harness-review` decision signal** → `.claude/signals/review-latest.json` →
  `/lifecycle next` auto-advances or halts on `NEEDS_HUMAN`.
- **`/landing-report` grounded DORA proxy** in `/harness-dashboard`.
- **Confusion Protocol** signals → `.claude/metrics/confusion.jsonl` → legibility input.
- **Worktree-aware** — `.gstack-worktrees/` and `~/conductor/workspaces/` both honored;
  never cross-fire.

## Anti-bloat (hard rules)

1. No new skills for integration; modify existing only.
2. SKILL.md ≤ 400 lines; root CLAUDE.md ≤ ~60 lines (Osmani 2026).
3. Glob over exact path; bridges dual-value (legacy + current).
4. Read-only across all gstack paths.
5. No orchestration — `/lifecycle` is router, never executor.
6. No auto-generated rules — human-gated TASTE encoding only.

Full constraints + rationale: [docs/INTEGRATION.md#anti-bloat-constraints](docs/INTEGRATION.md).
Latest decision record: [docs/TEAM-DISCUSSION-2026-05-08.md](docs/TEAM-DISCUSSION-2026-05-08.md).
