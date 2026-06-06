# Oh-My-Agents — Harness Engineering Plugin for Claude Code

**v3.7.0** — Mechanical quality constraints + entropy management for AI-driven dev.
**Composition-based** integration with [gstack](https://github.com/garrytan/gstack.git)
(v1.46+ floor, v1.56 current); we own *architecture / entropy / observability* and **never
orchestrate delivery**. Coordination ceded to native **Agent Teams** + **Dynamic Workflows**;
our durable anchor is the read-only audit + the versioned decision-signal **Gate API**
([docs/SIGNALS.md](docs/SIGNALS.md)) every executor gates on.

## Differentiation anchor

| oh-my-agents owns | gstack owns | Don't reinvent |
|---|---|---|
| hooks, arch-guard, TASTE rules, entropy-sweep | ideate / plan / ship / deploy / canary / retro | Managed Agents / Agents SDK runtime |
| verify + review **decision signals**, legibility scoring | `/codex` `/cso` `/design-review` `/investigate` `/qa` | gstack lifecycle orchestration |
| two-layer model: observation → mechanical enforcement | observation layer (GBrain memory ingest) | auto-generated rules (ETH Zurich 2026) |

## Surface

11 user-invocable skills (full details in [docs/WORKFLOW.md](docs/WORKFLOW.md)):
`harness-init`, `legibility-score`, `spec-to-task`, `verify`, `encode-mistake`,
`arch-guard`, `entropy-sweep`, `harness-review`, `harness-dashboard`, `gstack-sync`,
`lifecycle`. 1 read-only background agent in `agents/` (`session-observer`). 6 enforcement
hooks (`arch-check`, `safety-check`, `bash-safety-check`, `self-verify-check`,
`session-metrics`, `doc-drift-check`).

## Workflow (TL;DR)

- One-time: `/harness-init --quick` + `/gstack-sync --setup`
- Daily: `/lifecycle next` (router-only; NAMES the next gstack/harness skill + reads its
  decision signal — never invokes it)
- Mistake → guardrail: `/investigate` (gstack) → `/encode-mistake --from-gbrain` (here)
- Weekly: `/entropy-sweep` → `/harness-dashboard` → `/gstack-sync --metrics`

Full lifecycle: [docs/WORKFLOW.md](docs/WORKFLOW.md).
Bridge manifest: [docs/INTEGRATION.md](docs/INTEGRATION.md).
Architecture (incl. Anthropic 3-agent mapping): [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## gstack integration — what's wired (v1.46+ floor, v1.56 current)

- **Legacy sunset FIRED (v3.6.0)**: `min_supported` rose to 1.46 > the v1.27 rename floor,
  so `gstack-brain*` legacy paths are dropped; we probe `gstack-artifacts*` only.
- **`/spec` (gstack v1.47) → `/spec-to-task`**: clean intent→spec→layer-aware-plan handoff.
- **`/encode-mistake --from-gbrain {learning|eureka|retro|all}`** — observation →
  TASTE rule, always human-gated.
- **Decision-signal Gate API** ([docs/SIGNALS.md](docs/SIGNALS.md)): `/verify` +
  `/harness-review` write versioned signals → `/lifecycle` projects next phase (or halts
  on `NEEDS_HUMAN`, auto-recovers `composition-skipped`); gstack `/ship` gates on them too.
- **Sensors**: `/landing-report` → grounded DORA proxy in `/harness-dashboard`; Confusion
  Protocol → `.claude/metrics/confusion.jsonl` (legibility input).
- **Worktree-aware** — `.gstack-worktrees/` + `~/conductor/workspaces/` honored; never cross-fire.

## Anti-bloat (hard rules)

1. No new skills for integration; modify existing only.
2. SKILL.md ≤ 400 lines; root CLAUDE.md ≤ ~60 lines (Osmani 2026).
3. Glob over exact path; single-path probes (dual-value only transiently across a rename, then sunset).
4. Read-only across all gstack paths.
5. No orchestration of delivery — `/lifecycle` NAMES the next skill, never invokes it.
6. No auto-generated rules — human-gated TASTE encoding only.
7. Workflows ≤ 1, read-only (Explore agents), audit-only, **returns** a decision signal
   (accountable invoker persists it — never a relay write). Bright line: artifact ends in a
   **SIGNAL** (ours) or a **DEPLOYED ARTIFACT** (gstack's). Shipped: `.claude/workflows/harness-audit.js`.

Full constraints + rationale: [docs/INTEGRATION.md#anti-bloat-constraints](docs/INTEGRATION.md).
Latest decision record: [docs/TEAM-DISCUSSION-2026-06-06.md](docs/TEAM-DISCUSSION-2026-06-06.md).
