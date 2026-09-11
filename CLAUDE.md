# Oh-My-Agents — Harness Engineering Plugin for Claude Code

**v3.10.0** — Mechanical quality constraints + entropy management for AI-driven dev.
**Composition-based** integration with [gstack](https://github.com/garrytan/gstack.git)
(v1.46+ floor, v1.79.0.0 current, source-verified 2026-09-04); we own *architecture /
entropy / observability* and **never orchestrate delivery**. Coordination is native
(Agent Teams + Dynamic Workflows); our durable anchor is the read-only audit + the
versioned decision-signal **Gate API** ([docs/SIGNALS.md](docs/SIGNALS.md)).

## Differentiation anchor

| oh-my-agents owns | gstack owns | Don't reinvent |
|---|---|---|
| hooks, arch-guard, TASTE rules, entropy-sweep | ideate / plan / ship / deploy / canary / retro | Managed Agents / Agents SDK runtime |
| verify + review **decision signals**, legibility scoring | `/codex` `/cso` `/design-review` `/investigate` `/qa` `/review` | native `/code-review` `/security-review` (delegate to them) |
| two-layer model: observation → mechanical enforcement | observation layer (GBrain memory) | auto-generated rules (ETH Zurich 2026) |

## Surface

11 user-invocable skills (details: [docs/WORKFLOW.md](docs/WORKFLOW.md)): `harness-init`,
`legibility-score`, `spec-to-task`, `verify`, `encode-mistake`, `arch-guard`,
`entropy-sweep`, `harness-review`, `harness-dashboard`, `gstack-sync`, `lifecycle`.
7 hooks (canonical: `hooks/hooks.json`; advisory ones emit JSON `additionalContext` so the
MODEL sees them; `doc-drift-check` also runs on SessionStart to inject gate state).
0 agents (session-observer retired v3.10.0). 1 project-local workflow (`harness-audit`).

## Workflow (TL;DR)

- One-time: `/harness-init --quick` + `/gstack-sync --setup`
- Daily: `/lifecycle next` (router-only; NAMES the next skill + reads its signal — never invokes)
- Mistake → guardrail: `/investigate` (gstack) → `/encode-mistake --from-gbrain` (here)
- Weekly: `/entropy-sweep` → `/harness-dashboard` (schedule with `/loop`; no plugin scheduler)

Bridge manifest: [docs/INTEGRATION.md](docs/INTEGRATION.md) · Architecture:
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) · Decision record:
[docs/TEAM-DISCUSSION-2026-09-04.md](docs/TEAM-DISCUSSION-2026-09-04.md).

## gstack integration — what's wired (v1.79, verified against source)

- **Identity**: slug = `owner-repo` (gstack-slug `SLUG=` line / origin URL); `$GSTACK_HOME`
  honored; `{SLUG}`-templated bridges. gbrain = `~/.gstack-brain-worktree` + one
  `learnings.jsonl` (the `artifacts-worktree` name never existed — CI-grepped out).
- **Gate API**: `/verify` + `/harness-review` write commit-stamped signals; freshness =
  `commit == HEAD` AND clean tree at ADVANCE points; stale ⇒ default-deny. `/ship` reads
  none of it (VERIFIED) — the pre-ship check is our convention; the bilateral surface is
  gstack's verify-gate reading the `<!-- gstack:verify: cmd -->` line `/harness-init` exports.
- **Reconciliation**: gstack's `<branch>-reviews.jsonl` verdict, currency by `wtree`;
  agree→pass, diverge→`NEEDS_HUMAN:judgment-slop`; never aggregates, never writes gstack.
- **Sensors**: always-on `timeline.jsonl` (lifecycle coverage), `.gstack/*-reports/*.md`;
  `GSTACK_SESSION_KIND=spawned` silences our nudges; `.claude/gstack-rendered/` is theirs.

## Anti-bloat (hard rules — cite by kebab-case NAME, never by number)

`no-new-skills` · `skill-line-cap` (SKILL.md ≤ 400, root CLAUDE.md ≤ 60 — CI-enforced) ·
`glob-over-exact-path` · `read-only-bridge` · `no-orchestration` (hooks nudge, never invoke)
· `human-gated-encoding` · `single-workflow` (read-only, RETURNS a signal; SIGNAL vs
DEPLOYED ARTIFACT bright line) · `hook-latency-budget` · `declared-artifact` (every written
`.claude/*` file names its reader or CI fails) · `ablate-per-model`.
Full list + rationale: [Anti-Bloat Constraints](docs/INTEGRATION.md#anti-bloat-constraints).
