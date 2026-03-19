# oh-my-agents

Claude Code skills, agents, and hooks implementing OpenAI's **Harness Engineering** —
the discipline of designing environments, constraints, and feedback loops that make AI
coding agents work reliably at scale.

Based on OpenAI's experiment: 3 engineers shipped ~1M lines of production code via
~1,500 PRs in 5 months with zero hand-written code, using 88 nested AGENTS.md files
across their codebase.

## The Four Pillars

| Pillar | What It Means | This Plugin |
|--------|---------------|-------------|
| **Architecture as Guardrails** | Mechanical layer enforcement + Providers pattern | `arch-guard`, `taste-encoder`, hooks |
| **Documentation as System of Record** | Everything agents need lives in the repo | `harness-init`, `legibility-score`, `spec-to-task` |
| **Observability & Legibility** | Agents and humans can see what happened and verify work | `verify`, `harness-dashboard`, `harness-metrics`, session metrics |
| **Entropy Management** | Continuous resistance to codebase degradation | `entropy-sweep`, `harness-review`, `encode-mistake` |

## Project Structure

```
.claude-plugin/
├── plugin.json                    # Plugin manifest (name, version, paths)
├── marketplace.json               # Marketplace definition for distribution
skills/                            # User-invocable slash commands
├── harness-init/SKILL.md          # Initialize: CLAUDE.md, docs/, bootstrap, entry points
├── legibility-score/SKILL.md      # 10-metric Agent Legibility Score (0-30)
├── spec-to-task/SKILL.md          # Convert specs into agent-ready tasks with execution plans
├── verify/SKILL.md                # Post-execution check: build, test, lint, arch guard
├── encode-mistake/SKILL.md        # Convert agent mistakes into permanent lint/hook rules
├── arch-guard/SKILL.md            # Set up layer enforcement + Providers pattern
├── taste-encoder/SKILL.md         # Encode expertise into lint rules & structural tests
├── entropy-sweep/SKILL.md         # Scan for slop, doc drift, dead code, violations
├── harness-review/SKILL.md        # Code review with "Say No to Slop"
├── harness-dashboard/SKILL.md     # Session metrics, plan progress, harness health
└── harness-metrics/SKILL.md       # Deep-dive metric queries and analysis
agents/                            # Read-only background subagents (with memory: project)
├── arch-guard-agent.md            # Architectural compliance checker
├── entropy-sweep-agent.md         # Entropy scanner
├── harness-reviewer.md            # Code review agent
└── session-observer-agent.md      # Session tracking and shift-handoff (Haiku)
hooks/                             # Event hook scripts
├── hooks.json                     # Hook event bindings (uses ${CLAUDE_PLUGIN_ROOT})
├── arch-check.sh                  # Block Edit/Write on layer violations or Providers bypass
├── safety-check.sh                # Block Edit/Write on hardcoded secrets
├── bash-safety-check.sh           # Block Bash commands with credential leaks
├── session-metrics.sh             # Record tool usage to .claude/metrics/ (JSONL)
└── doc-drift-check.sh             # Warn about documentation drift after session ends
docs/                              # Template documentation for target projects
├── ARCHITECTURE.md                # Layer model, module boundaries, design decisions
├── CONVENTIONS.md                 # Naming, file size, error handling, logging patterns
├── TESTING.md                     # Test strategy, structural tests, coverage rules
├── LINTING.md                     # Custom lint rules registry (TASTE-NNN)
├── DECISIONS.md                   # Architecture Decision Records (ADRs)
├── PROVIDERS.md                   # Cross-cutting: auth, telemetry, feature flags interface
├── OBSERVABILITY.md               # Logging, metrics, tracing, monitoring strategy
└── WORKFLOW.md                    # Full dev lifecycle (oh-my-agents + gstack integration)
templates/                         # Configuration templates for target projects
├── harness-config.json            # .claude/harness.json starter template
├── execution-plan.json            # docs/exec-plans/ execution plan template
└── github-actions-harness.yml     # CI/CD workflow: lint + type-check + arch-guard + tests
```

## Installation

### Via Claude Code Plugin System (Recommended)

```bash
# Add the marketplace
/plugin marketplace add caishize/oh-my-agents

# Install the plugin
/plugin install oh-my-agents
```

After installation, all skills are available with the `oh-my-agents:` namespace:

```
/oh-my-agents:harness-init
/oh-my-agents:legibility-score
/oh-my-agents:verify
...
```

### Manual Installation (copy to .claude/)

```bash
git clone https://github.com/caishize/oh-my-agents.git

# Copy all skills
cp -r oh-my-agents/skills/ /path/to/your-project/.claude/skills/

# Copy all agents
mkdir -p /path/to/your-project/.claude/agents
for f in oh-my-agents/agents/*.md; do
  name=$(basename "$f" .md)
  mkdir -p /path/to/your-project/.claude/agents/"$name"
  cp "$f" /path/to/your-project/.claude/agents/"$name"/AGENT.md
done

# Copy hooks
cp -r oh-my-agents/hooks/ /path/to/your-project/.claude/hooks/
```

## Skills

### `/harness-init` — Initialize the Harness

Set up the full harness environment in 9 steps: root CLAUDE.md as table of contents
(~100 lines), nested CLAUDE.md for every module with 5+ files, structured docs/ directory,
machine-readable `.claude/harness.json`, bootstrap script, pre-commit enforcement, and
architecture test skeleton.

### `/legibility-score` — Agent Legibility Score

Assess the **10-metric readiness score** (0-30) across four pillars:

| # | Metric | Pillar |
|---|--------|--------|
| 1 | Bootstrap self-sufficiency | Architecture |
| 2 | Task entry points (build/test/lint/run) | Architecture |
| 3 | Validation harness | Architecture |
| 4 | Linting & formatting | Architecture |
| 5 | Codebase map (CLAUDE.md) | Documentation |
| 6 | Documentation structure (docs/) | Documentation |
| 7 | Decision records (ADRs) | Documentation |
| 8 | App bootstrap | Observability |
| 9 | Runtime logs | Observability |
| 10 | Nested CLAUDE.md coverage | Observability |

Score interpretation: 0-10 (not ready), 11-20 (struggling), 21-25 (agent-ready), 26-30 (excellent).

### `/spec-to-task` — Planning Before Execution

Decompose specs into agent-executable tasks with **tests first**, layer-aware
decomposition (Types → Config → Repo → Service → Runtime → UI), explicit context arrays,
and acceptance criteria. Produces a JSON execution plan for shift-handoff and a Markdown
companion for humans.

### `/verify` — Post-Execution Verification

Implements the **Verify** phase of OpenAI's Research → Plan → Execute → Verify cycle.
Runs lint → build → test → architecture guard in order, reports structured pass/fail
results, maps to plan acceptance criteria, and recommends `/encode-mistake` for recurring
failures.

```
=== Verify Report ===
  LINT     PASS     0 errors, 2 warnings
  BUILD    PASS     Compiled in 4.2s
  TEST     FAIL     47 passed, 3 failed
  ARCH     PASS     No violations
Overall: RED (1 check failed)
```

### `/encode-mistake` — Mistake → Permanent Guardrail

> "Every agent mistake is an encoding opportunity." — Mitchell Hashimoto

Converts incidents into permanent TASTE rules: lint rules, structural tests, hook
patterns, or improved error messages. Complements `/taste-encoder` (proactive taste
encoding) with reactive learning from actual failures.

**Difference:**
- `/taste-encoder` — "I dislike this pattern; encode it" (proactive)
- `/encode-mistake` — "This just broke; ensure it never happens again" (reactive)

### `/taste-encoder` — Encode Your Taste (Proactive)

Turn team expertise into custom lint rules, structural tests, or pre-commit hooks.
Each expert's knowledge becomes a multiplier for the entire agent fleet.

Real example from OpenAI: Codex kept creating duplicate concurrency helpers, but only
one version had OpenTelemetry. Fix: a custom ESLint rule banning that function outside
the approved location.

### `/arch-guard` — Architectural Constraints

Set up the rigid layered architecture: Types → Config → Repo → Service → Runtime → UI.
Plus the Providers pattern for cross-cutting concerns (auth, telemetry, feature flags).
Creates custom linters with **remediation instructions in error messages** (error
messages double as agent context).

### `/entropy-sweep` — Garbage Collection

Evolved from OpenAI's manual Friday "slop cleanup" to automated agent scanning. Detects:
- **Slop**: duplicates, pattern drift, copy-paste artifacts, security slop
- **Doc drift**: commands that don't work, dead file references
- **Violations**: layer crossings, Providers bypass
- **Dead weight**: unused exports, deps, orphaned files, stale TODOs
- **Missing enforcement**: rules in docs/ without lint/test backing
- **Stale plans**: execution plans with no updates in 7+ days

### `/harness-review` — Say No to Slop

Code review based on OpenAI's top principle: **"Maintain strict review standards.
Lowering the bar creates compounding technical debt."** Bad patterns multiply via every
future agent-generated PR. Checks slop first, then safety, then architecture, then
plan alignment.

### `/harness-dashboard` + `/harness-metrics` — Observability

Dashboard aggregates session metrics, enforcement activity, and plan progress.
Metrics allows deep-dive queries: layer balance, violation trends, plan velocity.

## Agents (Background, Read-Only)

All agents have Write/Edit disabled — they report but never modify code.

| Agent | Model | Dispatched when... |
|-------|-------|--------------------|
| `arch-guard-agent` | Sonnet | Code changes might violate layers or boundaries |
| `entropy-sweep-agent` | Sonnet | Periodic scan or pre-release check requested |
| `harness-reviewer` | Sonnet | PR or staged changes need review |
| `session-observer-agent` | Haiku | Session ends — writes shift-handoff summary to memory |

## Hooks (Automatic Enforcement)

| Hook | Trigger | Behavior |
|------|---------|----------|
| `arch-check.sh` | Before Edit/Write | **Blocks** layer violations and Providers bypass |
| `safety-check.sh` | Before Edit/Write | **Blocks** hardcoded secrets and credentials |
| `bash-safety-check.sh` | Before Bash | **Blocks** credential leaks in bash commands |
| `session-metrics.sh` | After Edit/Write/Bash | Records tool usage to JSONL (30-day rotation) |
| `doc-drift-check.sh` | Session end | **Warns** if source changes may need doc updates |

## Workflow

Full lifecycle details: [docs/WORKFLOW.md](docs/WORKFLOW.md)

### One-Time Setup

```
/harness-init          # CLAUDE.md, docs/, bootstrap, harness.json, pre-commit
/legibility-score      # Assess readiness (0-30) — find gaps
/arch-guard            # Layer enforcement + Providers pattern
```

### Full Lifecycle (with [gstack](https://github.com/garrytan/gstack) installed)

oh-my-agents detects gstack during `/harness-init` and generates a complete workflow in
`docs/WORKFLOW.md`. The two plugins are complementary — gstack covers ideation, planning,
QA, and shipping; oh-my-agents covers architectural enforcement, entropy management, and
rule encoding. All skills work sequentially in the same Claude Code session without any
modification — the conversation context bridges data flow between them.

```
/office-hours          # Brainstorm & design doc (gstack)
/plan-eng-review       # Architecture & eng review (gstack)
/spec-to-task          # Layer-aware execution plan (oh-my-agents)
# ... develop with automatic hook enforcement ...
/verify                # Build + test + lint + arch (oh-my-agents)
/review                # PR structural review — SQL, LLM safety (gstack)
/harness-review        # Four-pillar harness review (oh-my-agents)
/ship                  # Version, changelog, PR (gstack)
```

### Daily Development Cycle (oh-my-agents only)

```
/spec-to-task <feature-spec>    # Decompose: tests first, layer-aware, explicit context
# ... agent implements tasks ...
/verify                          # Build + test + lint + arch — structured results
/harness-review                  # Say No to Slop — final check before merge
```

### When Agents Make Mistakes

```
/encode-mistake "agent imported from wrong layer again"
# → permanent hook pattern or lint rule (TASTE-NNN)
# → documented in docs/LINTING.md
# → never happens again
```

### Weekly / Pre-Release

```
/entropy-sweep          # Full scan: slop, drift, violations, dead code, stale plans
/retro                  # Engineering velocity retrospective (gstack, if installed)
/harness-dashboard      # Harness health overview
```

### Team Knowledge Encoding (Ongoing)

```
/taste-encoder "no direct DB queries outside repo layer"
/taste-encoder "all API responses use ResponseEnvelope<T>"
/taste-encoder "max 300 lines per file"
```

Each team member's expertise becomes a lint rule or structural test that all agents
inherit. Designate an **Agent Captain** per team (OpenAI's recommendation) to manage
the encoding process.

## CI/CD Integration

Copy `templates/github-actions-harness.yml` to `.github/workflows/harness.yml` in your
project for three-tier enforcement on every PR:
1. Lint & format (fastest — style violations)
2. Type check (type errors)
3. Architecture guard (TASTE/ARCH structural tests)
4. Tests (full suite)

## Key Principles from OpenAI

- **"Agents have no tacit knowledge; until it is made explicit, it doesn't exist"**
- **"If you can articulate what code you dislike, write that down"** — as a lint rule
- **"Say No to Slop"** — never lower review standards, even to ship faster
- **"When the agent struggles, treat it as an environment design problem"**
- **"Every agent mistake is an encoding opportunity"** — Mitchell Hashimoto
- **Progressive disclosure** — CLAUDE.md is the TOC, docs/ is the encyclopedia
- **Structured formats > prose** — agents comply better with JSON/YAML rules
- **Error messages are context** — lint errors must include WHAT, WHERE, HOW, REF
- **JSON > Markdown for tracking** — agents less frequently overwrite structured data
- **Speed increases communication need** — faster AI output requires more human check-ins

## References

- [OpenAI: Harness Engineering](https://openai.com/index/harness-engineering/)
- [Martin Fowler: Harness Engineering](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)
- [The Emerging Harness Engineering Playbook](https://www.ignorance.ai/p/the-emerging-harness-engineering)
