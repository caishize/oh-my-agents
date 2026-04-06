# oh-my-agents

Claude Code plugin implementing OpenAI's **Harness Engineering** — the discipline of
designing environments, constraints, and feedback loops that make AI coding agents work
reliably at scale. Deep integration with [gstack](https://github.com/garrytan/gstack.git).

## The Four Pillars

| Pillar | What It Means | This Plugin |
|--------|---------------|-------------|
| **Architecture as Guardrails** | Mechanical layer enforcement + Providers pattern | `arch-guard`, `encode-mistake`, hooks |
| **Documentation as System of Record** | Everything agents need lives in the repo | `harness-init`, `legibility-score`, `spec-to-task` |
| **Observability & Legibility** | Agents and humans can see what happened | `verify`, `harness-dashboard`, session metrics |
| **Entropy Management** | Continuous resistance to codebase degradation | `entropy-sweep`, `harness-review`, `encode-mistake` |

## Project Structure

```
.claude-plugin/
├── plugin.json                    # Plugin manifest
skills/                            # User-invocable slash commands (11 skills)
├── harness-init/                  # Initialize: CLAUDE.md, docs/, bootstrap
│   ├── SKILL.md
│   ├── arch-test-python.md        # Python test skeleton (progressive disclosure)
│   └── arch-test-typescript.md    # TypeScript test skeleton
├── legibility-score/SKILL.md      # 10-metric Agent Legibility Score (0-30)
├── spec-to-task/SKILL.md          # Convert specs into agent-ready tasks
├── verify/SKILL.md                # Post-execution check + gstack readiness
├── encode-mistake/SKILL.md        # Mistakes OR taste → permanent rules
├── arch-guard/SKILL.md            # Layer enforcement + Providers pattern
├── entropy-sweep/SKILL.md         # Scan for slop, drift, dead code
├── harness-review/SKILL.md        # Code review with auto gstack dual-review
├── harness-dashboard/             # Metrics overview + deep-dive queries
│   ├── SKILL.md
│   └── DEEP-DIVE.md              # Query format reference
├── gstack-sync/SKILL.md           # gstack integration hub
└── lifecycle/SKILL.md             # Full lifecycle orchestrator
agents/                            # Read-only background subagents (2 agents)
├── session-observer-agent.md      # Session tracking and shift-handoff
└── doc-gardening-agent.md         # Documentation gardening and drift repair
hooks/                             # Event hook scripts (6 hooks)
├── hooks.json                     # Hook event bindings
├── lib/common.sh                  # Shared utilities (JSON, layers, gstack detection)
├── arch-check.sh                  # Block layer violations
├── safety-check.sh                # Block hardcoded secrets
├── bash-safety-check.sh           # Block credential leaks in bash
├── self-verify-check.sh           # Warn on type/syntax errors after edit
├── session-metrics.sh             # Record metrics to JSONL
└── doc-drift-check.sh             # Warn about doc drift at session end
docs/                              # Template documentation
tests/                             # Plugin self-tests
templates/                         # Configuration templates
```

## Installation

```bash
# Via plugin system (recommended)
/plugin marketplace add caishize/oh-my-agents
/plugin install oh-my-agents

# Manual
git clone https://github.com/caishize/oh-my-agents.git ~/.claude/skills/oh-my-agents
```

## Quick Start

```
/harness-init --quick     # All-in-one: init + score + arch-guard
/gstack-sync --setup      # Configure gstack integration (if installed)
```

## Skills

| Skill | Purpose |
|-------|---------|
| `/harness-init` | Initialize harness: CLAUDE.md, docs/, bootstrap, config |
| `/legibility-score` | 10-metric Agent Legibility Score (0-30) |
| `/spec-to-task` | Convert specs to layer-aware execution plans |
| `/verify` | Build + test + lint + arch check with structured results |
| `/encode-mistake` | Mistakes or taste → permanent guardrails (TASTE-NNN) |
| `/arch-guard` | Set up layer enforcement + Providers pattern |
| `/entropy-sweep` | Scan for slop, drift, violations, dead code |
| `/harness-review` | Four-pillar review with auto gstack dual-review |
| `/harness-dashboard` | Metrics overview + deep-dive queries |
| `/gstack-sync` | Detect gstack, configure bridges, sync metrics |
| `/lifecycle` | Full lifecycle orchestrator across all phases |

## Workflow

### Full Lifecycle (with [gstack](https://github.com/garrytan/gstack))

```
/lifecycle next                   # Auto-guided (recommended)
# OR manually:
/office-hours → /autoplan → /spec-to-task → develop → /verify → /harness-review → /ship
```

### Daily (oh-my-agents only)

```
/spec-to-task <feature-spec>      # Plan with tests first
# ... agent implements tasks ...
/verify                            # Structured pass/fail
/harness-review                    # Say No to Slop
```

### When Agents Make Mistakes

```
/encode-mistake "agent imported from wrong layer again"
# → permanent hook or lint rule (TASTE-NNN), documented in docs/LINTING.md

/encode-mistake --proactive "all API responses must use ResponseEnvelope<T>"
# → encode expert taste without waiting for a failure
```

### Weekly

```
/entropy-sweep                     # Codebase garbage collection
/harness-dashboard                 # Health overview
/harness-dashboard --query trends  # Deep-dive metric analysis
```

## gstack Integration

oh-my-agents and gstack are complementary:
- **gstack** accelerates delivery: ideation → planning → review → shipping
- **oh-my-agents** enforces quality: architecture → entropy → observability

Key handoffs:
- Design docs from `/office-hours` → `/spec-to-task` (auto-imported)
- `/verify` readiness signal → `/ship` (machine-readable JSON)
- `/harness-review` auto-detects gstack for dual-review with deduplication
- `/investigate` → `/encode-mistake` closes the feedback loop permanently

## Configuration (`.claude/harness.json`)

| Field | Default | Description |
|-------|---------|-------------|
| `layers` | `["types","config","repo","service","runtime","ui"]` | Layer order |
| `layer_dirs` | `{...}` | Directory-to-layer mappings |
| `sibling_layers` | `[]` | Pairs that can import each other |
| `file_size_limit` | `300` | Max lines per source file |

## Key Principles

- **"Say No to Slop"** — never lower review standards
- **"Every agent mistake is an encoding opportunity"** — Mitchell Hashimoto
- **Progressive disclosure** — CLAUDE.md is the TOC, docs/ is the encyclopedia
- **Error messages are context** — must include WHAT, WHERE, HOW, REF

## References

- [OpenAI: Harness Engineering](https://openai.com/index/harness-engineering/)
- [gstack](https://github.com/garrytan/gstack) — complementary workflow plugin
- [Martin Fowler: Harness Engineering](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)
