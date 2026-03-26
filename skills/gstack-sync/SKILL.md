---
name: gstack-sync
description: "Detect gstack installation, set up artifact bridges between oh-my-agents and gstack, synchronize metrics and review data bidirectionally. The integration hub for combined workflows. Aliases: gstack同步, 插件同步, 桥接配置, gstack集成"
user-invocable: true
argument-hint: "[--status] [--setup] [--metrics]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# gstack-sync — Plugin Integration Hub

Detect, configure, and maintain the bridge between oh-my-agents (harness engineering)
and gstack (development factory). This skill ensures both plugins share artifacts,
metrics, and workflow state seamlessly.

> "Two plugins, one workflow. oh-my-agents enforces quality; gstack accelerates delivery.
> Together they form the complete AI engineering stack."

## Task

Synchronize oh-my-agents with gstack based on `$ARGUMENTS`:

- `--status` (default if no args): Report integration health
- `--setup`: Full integration setup (first-time or repair)
- `--metrics`: Sync and merge metrics from both systems

## Step 0: Detect gstack Installation

```bash
GSTACK_PATH=""
GSTACK_VERSION=""
GSTACK_INSTALLED="no"

# Check common installation paths
for p in "$HOME/.claude/skills/gstack" ".claude/skills/gstack"; do
  if [ -d "$p" ]; then
    GSTACK_PATH="$p"
    GSTACK_INSTALLED="yes"
    break
  fi
done

# Check if symlink (dev mode)
GSTACK_DEV_MODE="no"
if [ "$GSTACK_INSTALLED" = "yes" ] && [ -L "$GSTACK_PATH" ]; then
  GSTACK_DEV_MODE="yes"
  GSTACK_REAL_PATH=$(readlink "$GSTACK_PATH")
fi

# Get version
if [ "$GSTACK_INSTALLED" = "yes" ] && [ -f "$GSTACK_PATH/VERSION" ]; then
  GSTACK_VERSION=$(cat "$GSTACK_PATH/VERSION")
fi

# Check oh-my-agents harness
HARNESS_JSON=""
for h in ".claude/harness.json" "../.claude/harness.json"; do
  if [ -f "$h" ]; then
    HARNESS_JSON="$h"
    break
  fi
done

echo "GSTACK_INSTALLED: $GSTACK_INSTALLED"
echo "GSTACK_PATH: $GSTACK_PATH"
echo "GSTACK_VERSION: $GSTACK_VERSION"
echo "GSTACK_DEV_MODE: $GSTACK_DEV_MODE"
echo "HARNESS_JSON: $HARNESS_JSON"

# Check gstack project slug
SLUG=""
if [ -n "$GSTACK_PATH" ] && [ -x "$GSTACK_PATH/bin/gstack-slug" ]; then
  SLUG=$("$GSTACK_PATH/bin/gstack-slug" 2>/dev/null || echo "")
fi
echo "PROJECT_SLUG: $SLUG"
```

If `GSTACK_INSTALLED` is `no`, report:
```
⚠ gstack not detected.
Install from: https://github.com/garrytan/gstack.git
oh-my-agents works standalone, but combined with gstack you get:
  - /office-hours → ideation & design thinking
  - /autoplan → automated multi-perspective review
  - /review → structural PR review (complements /harness-review)
  - /ship → automated versioning, changelog, PR creation
  - /qa → browser-based QA with automatic fixes
  - /retro → engineering velocity metrics
  - /investigate → systematic root-cause debugging
  - /canary → post-deploy monitoring
  - /benchmark → performance regression detection
```
Then stop.

## Step 1: Status Report (--status or default)

Generate a comprehensive integration health report:

```
═══════════════════════════════════════════
  gstack ↔ oh-my-agents Integration Status
═══════════════════════════════════════════

Plugins:
  gstack:       v{VERSION} at {PATH} {DEV_MODE ? "(dev symlink)" : ""}
  oh-my-agents: v{from plugin.json} at {plugin path}

Project:
  Slug:          {SLUG}
  Harness:       {HARNESS_JSON ? "✓ configured" : "✗ run /harness-init"}
  Layers:        {layer count from harness.json}

Artifact Bridges:
  Design docs:   {count files in ~/.gstack/projects/$SLUG/*-design-*.md}
  Review logs:   {count lines in ~/.gstack/projects/$SLUG/*-reviews.jsonl}
  Test plans:    {count files in ~/.gstack/projects/$SLUG/*-test-plan-*.md}
  QA reports:    {count files in .gstack/qa-reports/}
  Exec plans:    {count files in docs/exec-plans/active/}
  Harness metrics: {count lines in .claude/metrics/*.jsonl}

Workflow Coverage:
  Phase        gstack          oh-my-agents     Status
  ─────        ──────          ────────────     ──────
  Ideate       /office-hours   —                {installed ? "✓" : "—"}
  Plan         /autoplan       —                {installed ? "✓" : "—"}
  Decompose    —               /spec-to-task    ✓
  Execute      —               hooks            ✓
  Verify       —               /verify          ✓
  Review       /review         /harness-review  {both ? "✓✓ dual" : "✓"}
  Ship         /ship           —                {installed ? "✓" : "—"}
  Deploy       /land-and-deploy —               {installed ? "✓" : "—"}
  Monitor      /canary         —                {installed ? "✓" : "—"}
  Docs         /document-release —              {installed ? "✓" : "—"}
  Retro        /retro          /harness-dashboard ✓✓ dual
  Guard        /guard          /arch-guard      ✓✓ dual
  Debug        /investigate    /encode-mistake  ✓✓ complementary
  Security     /cso            safety hooks     ✓✓ dual
  QA           /qa             —                {installed ? "✓" : "—"}
  Design       /design-review  —                {installed ? "✓" : "—"}
  Perf         /benchmark      —                {installed ? "✓" : "—"}

Recent Activity (last 7 days):
  gstack skills used:    {parse ~/.gstack/analytics/skill-usage.jsonl}
  Harness hooks fired:   {parse .claude/metrics/*.jsonl}
  Violations blocked:    {count blocked_by events}
  Reviews completed:     {count review JSONL entries}

Recommendations:
  {Generate 1-3 actionable suggestions based on gaps detected}
═══════════════════════════════════════════
```

## Step 2: Setup Integration (--setup)

### 2a: Create Integration Config

Create or update `.claude/integration.json`:

```json
{
  "version": "1.0",
  "gstack": {
    "detected": true,
    "path": "{GSTACK_PATH}",
    "version": "{GSTACK_VERSION}",
    "dev_mode": false
  },
  "bridges": {
    "design_docs": "~/.gstack/projects/{SLUG}/",
    "review_logs": "~/.gstack/projects/{SLUG}/",
    "harness_metrics": ".claude/metrics/",
    "exec_plans": "docs/exec-plans/",
    "qa_reports": ".gstack/qa-reports/",
    "benchmark_reports": ".gstack/benchmark-reports/"
  },
  "workflow": {
    "auto_spec_from_design": true,
    "dual_review": true,
    "arch_gate_on_ship": true,
    "entropy_check_on_retro": true,
    "investigate_to_encode": true
  },
  "last_sync": "{ISO timestamp}"
}
```

### 2b: Update CLAUDE.md Workflow Section

If CLAUDE.md exists and has a Workflow section, update it to include the full
integrated lifecycle table (with both gstack and oh-my-agents commands).

### 2c: Generate docs/INTEGRATION.md

Create a comprehensive integration guide:

Generate `docs/INTEGRATION.md` using the plugin's own `docs/INTEGRATION.md` as a reference
template, adapting to the specific project's tech stack and directory structure discovered
in Step 0. The generated file should cover: philosophy, artifact flow map, bridge
configuration, setup instructions, and workflow modes.

Key sections to include:
- Philosophy (gstack accelerates delivery, oh-my-agents enforces quality)
- Artifact flow diagram (design doc → exec plan → verify → review → ship)
- Automated bridge table (source → consumer → trigger → data format)
- Configuration reference (`.claude/integration.json`)

Use the oh-my-agents plugin's `docs/INTEGRATION.md` as the content source — read it and
adapt the project-specific details (paths, slug, branch names) rather than hardcoding
a markdown template inline.

### 2d: Set up .gitignore entries

Ensure `.gstack/` directory is in `.gitignore` (gstack reports are local):

```bash
if [ -f .gitignore ]; then
  grep -q '\.gstack/' .gitignore || echo '.gstack/' >> .gitignore
fi
```

## Step 3: Metrics Sync (--metrics)

### 3a: Read gstack metrics

```bash
# Re-detect gstack path (bash blocks are independent)
GSTACK_PATH=""
for p in "$HOME/.claude/skills/gstack" ".claude/skills/gstack"; do
  [ -d "$p" ] && GSTACK_PATH="$p" && break
done

SLUG=""
if [ -n "$GSTACK_PATH" ] && [ -x "$GSTACK_PATH/bin/gstack-slug" ]; then
  SLUG=$("$GSTACK_PATH/bin/gstack-slug" 2>/dev/null || echo "")
fi
[ -z "$SLUG" ] && SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")

GSTACK_METRICS="$HOME/.gstack/projects/$SLUG"
GSTACK_ANALYTICS="$HOME/.gstack/analytics"

echo "=== gstack Metrics ==="
# Skill usage (last 7 days)
if [ -f "$GSTACK_ANALYTICS/skill-usage.jsonl" ]; then
  WEEK_AGO=$(date -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d 2>/dev/null || echo "")
  echo "Skill usage entries: $(wc -l < "$GSTACK_ANALYTICS/skill-usage.jsonl")"
fi

# Review logs
if [ -d "$GSTACK_METRICS" ]; then
  echo "Review log files: $(ls "$GSTACK_METRICS"/*-reviews.jsonl 2>/dev/null | wc -l)"
  echo "Design docs: $(ls "$GSTACK_METRICS"/*-design-*.md 2>/dev/null | wc -l)"
  echo "Test plans: $(ls "$GSTACK_METRICS"/*-test-plan-*.md 2>/dev/null | wc -l)"
fi
```

### 3b: Read oh-my-agents metrics

```bash
echo "=== oh-my-agents Metrics ==="
if [ -d ".claude/metrics" ]; then
  for f in .claude/metrics/*.jsonl; do
    [ -f "$f" ] && echo "$(basename "$f"): $(wc -l < "$f") entries"
  done
fi
```

### 3c: Generate merged report

Create `.claude/metrics/integrated-report.json` combining both metric sources:

```json
{
  "generated_at": "{ISO timestamp}",
  "window_days": 7,
  "gstack": {
    "skills_used": ["list of skills invoked"],
    "reviews_completed": 0,
    "design_docs_created": 0,
    "qa_sessions": 0,
    "ships": 0
  },
  "harness": {
    "hooks_fired": 0,
    "violations_blocked": 0,
    "entropy_sweeps": 0,
    "plans_active": 0,
    "plans_completed": 0
  },
  "combined": {
    "lifecycle_completeness": "percentage of phases used",
    "dual_review_rate": "percentage of reviews using both systems",
    "investigate_to_encode_rate": "percentage of investigations encoded as rules"
  }
}
```

## Step 4: Summary

Print a concise summary of what was done and next recommended action.

## Rules

- **Never modify gstack files** — gstack owns its own skill files, templates, and configs
- **Never modify ~/.gstack/ state** — gstack owns that directory tree
- **Read-only bridge** — oh-my-agents reads gstack artifacts but never writes to gstack paths
- **Graceful degradation** — all integration features must work when gstack is absent
- **Version tolerance** — detect but don't require specific gstack versions
- **No duplicate metrics** — merge, don't copy; reference original JSONL files
- **Integration config is project-scoped** — `.claude/integration.json` per project
