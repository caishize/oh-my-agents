---
name: gstack-sync
description: "Detect gstack installation, set up artifact bridges, sync metrics bidirectionally. The integration hub for oh-my-agents + gstack combined workflows. Aliases: gstack同步, 插件同步, gstack集成"
user-invocable: true
argument-hint: "[--status] [--setup] [--metrics]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# gstack-sync — Plugin Integration Hub

Detect, configure, and maintain the bridge between oh-my-agents (quality enforcement)
and gstack (delivery acceleration).

## Task

`$ARGUMENTS`: `--status` (default), `--setup`, or `--metrics`

### Step 0: Detect gstack

```bash
GSTACK_PATH=""
for p in "$HOME/.claude/skills/gstack" ".claude/skills/gstack"; do
  [ -d "$p" ] && GSTACK_PATH="$p" && break
done
[ -z "$GSTACK_PATH" ] && echo "NOT_FOUND" && exit 0
GSTACK_VERSION=$(cat "$GSTACK_PATH/VERSION" 2>/dev/null || echo "unknown")
SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
echo "GSTACK_PATH: $GSTACK_PATH"
echo "GSTACK_VERSION: $GSTACK_VERSION"
echo "PROJECT_SLUG: $SLUG"
```

If not found, suggest installation and list benefits. Then stop.

### Step 1: Status Report (default)

Report integration health: plugin versions, artifact bridges (design docs, review logs,
exec plans, metrics), workflow coverage (which phases have both systems), and
recent activity (7-day skill usage, hook fires, violations blocked).

### Step 2: Setup (--setup)

1. Create `.claude/integration.json` with detected paths and bridge config
2. Update CLAUDE.md workflow section to include full lifecycle table
3. Add `.gstack/` to `.gitignore`

### Step 3: Metrics Sync (--metrics)

Read metrics from both systems and generate `.claude/metrics/integrated-report.json`:
- gstack: skills used, reviews, design docs, QA sessions, ships
- harness: hooks fired, violations blocked, entropy sweeps, plans
- combined: lifecycle completeness, dual review rate, investigate-to-encode rate

## Rules

- Never modify gstack files or `~/.gstack/` state
- Read-only bridge — oh-my-agents reads gstack artifacts, never writes
- Graceful degradation when gstack is absent
- No duplicate metrics — merge and reference originals
