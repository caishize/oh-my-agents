# oh-my-agents `v3.1.0`

Lean Claude Code plugin implementing **Harness Engineering** — the discipline of
designing environments, constraints, and feedback loops that make AI coding agents
work reliably at scale. Deep integration with [gstack](https://github.com/garrytan/gstack.git)
for full-lifecycle coverage.

> **11 skills · 2 agents · 6 hooks** — optimized for minimal context window footprint
> via progressive disclosure.

## The Four Pillars

| Pillar | What It Means | This Plugin |
|--------|---------------|-------------|
| **Architecture as Guardrails** | Mechanical layer enforcement + Providers pattern | `arch-guard`, `encode-mistake`, hooks |
| **Documentation as System of Record** | Everything agents need lives in the repo | `harness-init`, `legibility-score`, `spec-to-task` |
| **Observability & Legibility** | Agents and humans can see what happened | `verify`, `harness-dashboard`, session metrics |
| **Entropy Management** | Continuous resistance to codebase degradation | `entropy-sweep`, `harness-review`, `encode-mistake` |

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

| Skill | Pillar | Purpose |
|-------|--------|---------|
| `/harness-init` | All | Initialize harness: CLAUDE.md, docs/, bootstrap, config |
| `/legibility-score` | All | 10-metric Agent Legibility Score (0-30) |
| `/spec-to-task` | Documentation | Convert specs to layer-aware execution plans |
| `/verify` | Architecture | Build + test + lint + arch check with structured results |
| `/encode-mistake` | Entropy | Mistakes or taste → permanent guardrails (TASTE-NNN) |
| `/arch-guard` | Architecture | Set up layer enforcement + Providers pattern |
| `/entropy-sweep` | Entropy | Scan for slop, drift, violations, dead code |
| `/harness-review` | Entropy | Four-pillar review with auto gstack dual-review |
| `/harness-dashboard` | Observability | Metrics overview + `--query` for deep-dive analysis |
| `/gstack-sync` | Integration | Detect gstack, configure bridges, sync metrics |
| `/lifecycle` | Integration | Full lifecycle orchestrator across all phases |

## Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `session-observer-agent` | Haiku | Session tracking and shift-handoff summaries |
| `doc-gardening-agent` | Haiku | Documentation gardening and drift repair |

Both agents are read-only (no Write/Edit) and use agent memory for cross-session learning.

## Hooks

| Hook | Event | Behavior |
|------|-------|----------|
| `arch-check.sh` | PreToolUse (Edit/Write) | Blocks layer violations, Providers bypass |
| `safety-check.sh` | PreToolUse (Edit/Write) | Blocks hardcoded secrets and risk patterns |
| `bash-safety-check.sh` | PreToolUse (Bash) | Blocks credential leaks in bash commands |
| `self-verify-check.sh` | PostToolUse (Edit/Write) | Warns on type/syntax errors after edit |
| `session-metrics.sh` | PostToolUse (Edit/Write/Bash) | Records tool usage and hook performance |
| `doc-drift-check.sh` | Stop | Warns about documentation drift |

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
- **gstack** accelerates delivery: ideation → planning → review → shipping → deployment → monitoring
- **oh-my-agents** enforces quality: architecture → entropy → observability → documentation

Key handoffs:
- Design docs from `/office-hours` → `/spec-to-task` (auto-imported)
- `/verify` readiness signal → `/ship` (machine-readable JSON)
- `/harness-review` auto-detects gstack for dual-review with deduplication
- `/investigate` → `/encode-mistake` closes the feedback loop permanently
- `/lifecycle` orchestrates the full cycle regardless of which plugins are installed

## Project Structure

```
.claude-plugin/plugin.json         # Plugin manifest (v3.1.0)
skills/                            # 11 user-invocable slash commands
├── harness-init/                  # Init (progressive disclosure refs)
│   ├── SKILL.md
│   ├── arch-test-python.md        # Python test skeleton
│   └── arch-test-typescript.md    # TypeScript test skeleton
├── harness-dashboard/
│   ├── SKILL.md
│   └── DEEP-DIVE.md              # Query format reference
├── <other-skills>/SKILL.md        # One dir per skill
agents/                            # 2 read-only background agents
hooks/                             # 6 event-driven shell scripts
├── hooks.json                     # Hook event bindings
├── lib/common.sh                  # Shared utilities
docs/                              # Progressive disclosure references
templates/                         # Config templates
tests/                             # Plugin self-tests
```

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

## License

MIT
