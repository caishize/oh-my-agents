# Oh-My-Agents — Harness Engineering Plugin for Claude Code

**v3.11.0** — Mechanical quality constraints + entropy management for AI-driven dev.
**Composition-based** integration with [gstack](https://github.com/garrytan/gstack.git)
(v1.46+ floor, v1.84.1.0 current, source-verified 2026-09-11); we own *architecture /
entropy / observability* and **never orchestrate delivery**. Coordination is native
(Agent Teams + Dynamic Workflows); our durable anchor is the read-only audit + the
versioned decision-signal **Gate API** ([docs/SIGNALS.md](docs/SIGNALS.md)).

## Differentiation anchor

| oh-my-agents owns | gstack owns | Don't reinvent |
|---|---|---|
| hooks, arch-guard, TASTE rules, entropy-sweep | ideate / plan / ship / deploy / canary / retro | Managed Agents / Agents SDK runtime |
| verify + review **decision signals**, gate ladder, legibility scoring | `/codex` `/cso` `/design-review` `/investigate` `/qa` `/review` | native `/code-review` `/security-review` (delegate to them) |
| two-layer model: observation → mechanical enforcement | observation layer (GBrain memory) | auto-generated rules (ETH Zurich 2026) |

## Surface

11 user-invocable skills (details: [docs/WORKFLOW.md](docs/WORKFLOW.md)): `harness-init`,
`legibility-score`, `spec-to-task`, `verify`, `encode-mistake`, `arch-guard`,
`entropy-sweep`, `harness-review`, `harness-dashboard`, `gstack-sync`, `lifecycle`
(`harness-init` + `gstack-sync` are human-typed: `disable-model-invocation`). 6 hooks
(canonical: `hooks/hooks.json`, timeouts in SECONDS; advisory `additionalContext` on
PreToolUse/PostToolUse/SessionStart; Stop is `systemMessage` only — never a continuation).
0 agents. 1 workflow at the plugin root: `/oh-my-agents:harness-audit`. CI: `.github/workflows/ci.yml`.

## Workflow (TL;DR)

- One-time: `/harness-init --quick` + `/gstack-sync --setup`
- Daily: `/lifecycle next` (router-only; NAMES the next skill — never invokes); the gate
  ladder (SessionStart → model, Stop → human) names the next gate off a FRESH signal
- Mistake → guardrail: `/investigate` (gstack) → `/encode-mistake --from-gbrain` (here)
- Weekly: `/entropy-sweep` → `/harness-dashboard`; `/skill-doctor` before any retirement

Bridge manifest: [docs/INTEGRATION.md](docs/INTEGRATION.md) · Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
· Decision record: [docs/TEAM-DISCUSSION-2026-09-11.md](docs/TEAM-DISCUSSION-2026-09-11.md).

## gstack integration — what's wired (v1.84.1, verified against source)

- **Identity**: slug = `owner-repo` (gstack-slug `SLUG=` line / origin URL); `$GSTACK_HOME`
  honored; `{SLUG}`-templated bridges; gbrain = `~/.gstack-brain-worktree` + `learnings.jsonl`.
- **Gate API**: `/verify` + `/harness-review` write commit-stamped signals (+ optional gstack
  `wtree`); freshness = ONE predicate `signal_fresh` (commit==HEAD, clean tree at ADVANCE
  points, or wtree match); stale ⇒ default-deny. The ladder's APPROVE rung IS the pre-ship
  check; `/ship` reads none of it (VERIFIED) — the bilateral surface is gstack's verify-gate
  reading the `<!-- gstack:verify: cmd -->` line `/harness-init` exports.
- **Hand-offs**: `/spec` archive (`projects/<slug>/specs/*.md`, by `spec_branch`) → `/spec-to-task`;
  `failures[]` / `findings[]` typed history → next turn; gstack verdict + typed findings
  reconciled read-only (agree→pass, diverge→`NEEDS_HUMAN:judgment-slop`); never writes gstack.
- **Sensors**: `timeline.jsonl`, `.gstack/*-reports/*.md`; `GSTACK_SESSION_KIND=spawned` silences us.

## Anti-bloat (hard rules — cite by kebab-case NAME, never by number)

`no-new-skills` · `skill-line-cap` (SKILL.md ≤ 400, root CLAUDE.md ≤ 60 — CI-enforced) ·
`glob-over-exact-path` · `read-only-bridge` · `no-orchestration` (hooks nudge, never invoke)
· `human-gated-encoding` · `single-workflow` (read-only, RETURNS a signal; SIGNAL vs
DEPLOYED ARTIFACT bright line) · `hook-latency-budget` (seconds) · `declared-artifact` (every
written `.claude/*` file names its reader or CI fails) · `ablate-per-model`.
Full list + rationale: [Anti-Bloat Constraints](docs/INTEGRATION.md#anti-bloat-constraints).
