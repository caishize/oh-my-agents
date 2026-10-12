# Architecture

The plugin owns repository constraints and evidence, not delivery orchestration.
The four pillars are architecture, documentation, observability and entropy management.

## Components

| Path | Responsibility |
|---|---|
| .codex-plugin/plugin.json | Native package and skills/hooks paths |
| .agents/plugins/marketplace.json | Distribution from this checkout |
| skills/ | 11 procedures with Codex metadata |
| hooks/codex-adapter.py | Native apply_patch normalization, no source writes |
| hooks/*.sh | Layer, secret, plan, metrics and drift checks |
| hooks/lib/common.sh | Root resolution, detection, signal freshness, locked history |
| scripts/gate.sh | Explicit release gate for any compatible host |
| templates/ | Target project config and real-check scaffolding |
| docs/ | Contracts and implementation references |
| tests/ | Behavior tests and real CLI package installation |

The target architecture order defaults to types → config → repo → service → runtime → ui.
Target `.codex/harness.json` maps those canonical names to actual directories; explicit
sibling exceptions are supported. This plugin's own components are not application layers.

## Data flow

Native apply_patch hook → reconstruct affected files → layer/secret/plan checks → Codex
executes the patch → layer metrics. Hook parse errors cannot silently pass an edit.
`$oh-my-agents:verify` executes checks and derives its signal; an independent reviewer derives review
findings and the accountable `$oh-my-agents:harness-review` invocation computes/persists its signal.
The hook ladder, `$oh-my-agents:lifecycle`, dashboard and explicit release gate read those records.

Root resolution uses an explicit HARNESS_PROJECT_DIR, Git root from hook cwd, then file
markers. Build directories are separate from the project root. Subdirectory commands must
never fork `.codex/signals` or metrics. Real Git roots outrank harness markers.

## Three review moments

| Trigger | Procedure | Result |
|---|---|---|
| Change/PR | `$oh-my-agents:harness-review` | Independent decision and actionable findings |
| Periodic maintenance | `$oh-my-agents:entropy-sweep` | Read-only prioritized health findings |
| Governance/release | `$oh-my-agents:harness-review --audit` | Four-pillar passes plus skeptical confirmation |

Use one appropriate review for the context. Unsupported Claude workflow globals and
built-in Explore roles are removed. Native independent agents are optional host features;
absence never becomes an independent APPROVE. gstack artifacts are optional read-only
inputs. See [compatibility](CODEX.md) and [signal contract](SIGNALS.md).

## Maintenance constraints

Keep skill entry points focused (≤400 lines), shared contracts in docs, and deterministic
behavior covered by tests. Add artifacts only with a reader. Preserve user config and
external ledgers. New orchestration, untested automatic rules and unsupported runtime APIs
require a separate design decision.
