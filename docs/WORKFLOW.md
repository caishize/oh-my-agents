# Codex workflow

Initialize explicitly with `$oh-my-agents:harness-init --quick`. Preserve the existing checkout and user
instructions. The ordinary loop is spec → tasks → implementation → verify → independent
review → the user's delivery process.

| Situation | Next action |
|---|---|
| New feature/spec | `$oh-my-agents:spec-to-task <spec-path>` |
| Completed implementation | `$oh-my-agents:verify all [--plan <id>]` |
| Full GREEN verification | `$oh-my-agents:harness-review` |
| Review requests changes | Fix named findings; verify and review again |
| Evaluation unavailable/ambiguous | Resolve the specific NEEDS_HUMAN requirement |
| Unsure what is next | `$oh-my-agents:lifecycle next` |
| Confirmed recurring mistake | `$oh-my-agents:encode-mistake <evidence>` |
| Periodic project health | `$oh-my-agents:entropy-sweep`, `$oh-my-agents:harness-dashboard` |
| Governance audit | `$oh-my-agents:harness-review --audit` |

Explicit release gating uses `scripts/gate.sh`; no skill silently ships, merges or deploys.
Partial checks, missing tools and unrun acceptance never satisfy the full gate. Optional
gstack artifacts may inform planning/review; Claude-only commands are not a Codex workflow.
