---
name: gstack-sync
description: "Detect gstack installation, set up artifact bridges, sync metrics bidirectionally. The integration hub for oh-my-agents + gstack combined workflows. Aliases: gstack同步, 插件同步, gstack集成"
user-invocable: true
argument-hint: "[--status] [--setup] [--metrics] [--contract-check]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# gstack-sync — Plugin Integration Hub

Detect, configure, and maintain the bridge between oh-my-agents (quality enforcement)
and gstack (delivery acceleration).

**Composition principle**: this skill never wraps gstack commands. It only **discovers
artifacts** (glob), **emits readiness signals**, and **reports integration health**.
gstack version drift is expected (daily releases) — match versions loosely, degrade gracefully.

## Task

`$ARGUMENTS`: `--status` (default), `--setup`, `--metrics`, or `--contract-check`

### Step 0: Detect gstack (loose match)

```bash
GSTACK_PATH=""
for p in "$HOME/.claude/skills/gstack" ".claude/skills/gstack"; do
  [ -d "$p" ] && GSTACK_PATH="$p" && break
done
[ -z "$GSTACK_PATH" ] && echo "NOT_FOUND" && exit 0
GSTACK_VERSION=$(cat "$GSTACK_PATH/VERSION" 2>/dev/null || echo "unknown")
SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
GSTACK_MAJOR_MINOR=$(echo "$GSTACK_VERSION" | cut -d. -f1-2)
echo "GSTACK_PATH: $GSTACK_PATH"
echo "GSTACK_VERSION: $GSTACK_VERSION (major.minor: $GSTACK_MAJOR_MINOR)"
echo "PROJECT_SLUG: $SLUG"
```

If not found, suggest installation, list benefits, then stop. Do NOT hard-fail.

### Step 1: Detect gstack capabilities (capability probe, not version probe)

Probe the artifact surface — NOT the command list (commands change too often).
gstack ships ~daily; rely on **artifact presence**, not version strings.

```bash
GSTACK_HOME="$HOME/.gstack"
PROJ_DIR="$GSTACK_HOME/projects/$SLUG"
ANALYTICS_DIR="$GSTACK_HOME/analytics"

# GBrain worktree — dual-value (v1.27.0.0 renamed gstack-brain → gstack-artifacts).
# Probe current first; fall back to legacy. First hit wins; both absent = degrade.
GBRAIN_WT=""
for d in "$HOME/.gstack-artifacts-worktree" "$HOME/.gstack-brain-worktree"; do
  [ -d "$d" ] && GBRAIN_WT="$d" && break
done

# Capability probes (presence > version)
GBRAIN_CLI=$(command -v gbrain 2>/dev/null || echo "")               # v1.26+ memory ingest CLI
LLMS_TXT=""
for f in "$GSTACK_PATH/llms.txt" "$HOME/.claude/skills/gstack/llms.txt"; do
  [ -f "$f" ] && LLMS_TXT="$f" && break
done                                                                  # v1.28+
INGEST_BIN=""
[ -x "$GSTACK_PATH/bin/gstack-memory-ingest" ] && INGEST_BIN="$GSTACK_PATH/bin/gstack-memory-ingest"  # v1.26+
ARTIFACTS_REMOTE=""
[ -f "$HOME/.gstack-artifacts-remote.txt" ] && ARTIFACTS_REMOTE="present"  # v1.27 Path 4 hint
[ -f "$HOME/.gstack-brain-remote.txt" ] && ARTIFACTS_REMOTE="legacy"

# Core artifacts (legacy, pre-v1)
CAP_DESIGN=$(ls $PROJ_DIR/*-design-*.md 2>/dev/null | wc -l)
CAP_TEST_PLAN=$(ls $PROJ_DIR/*-test-plan-*.md 2>/dev/null | wc -l)
CAP_REVIEW=$(ls $PROJ_DIR/*-reviews.jsonl 2>/dev/null | wc -l)
CAP_QA=$(ls $PROJ_DIR/*-test-outcome-*.md 2>/dev/null | wc -l)
CAP_CODEX=$(ls $PROJ_DIR/*-codex-*.md 2>/dev/null | wc -l)
CAP_CSO=$(ls $PROJ_DIR/*-cso-*.md 2>/dev/null | wc -l)
CAP_DESIGN_REVIEW=$(ls $PROJ_DIR/*-design-review-*.md 2>/dev/null | wc -l)  # was /ux-audit pre-v1.x
CAP_CANARY=$(ls .gstack/canary-reports/*.json 2>/dev/null | wc -l)
CAP_DEPLOY=$(ls .gstack/deploy-reports/*.json 2>/dev/null | wc -l)
CAP_CONDUCTOR=$([ -f "conductor.json" ] && echo 1 || echo 0)
CAP_WORKTREES=$([ -d ".gstack-worktrees" ] && ls -1 .gstack-worktrees | wc -l || echo 0)
CAP_SKILL_USAGE=$([ -f "$ANALYTICS_DIR/skill-usage.jsonl" ] && echo 1 || echo 0)
CAP_EUREKA=$([ -f "$ANALYTICS_DIR/eureka.jsonl" ] && echo 1 || echo 0)

# Post-v0.18 additions (v1.x era)
CAP_LANDING_LOCAL=$(ls .gstack/landing-reports/*.json 2>/dev/null | wc -l)       # v1.11+
CAP_LANDING_PROJ=$(ls $PROJ_DIR/*-landing-*.md 2>/dev/null | wc -l)              # v1.11+
CAP_GBRAIN_WT=$([ -n "$GBRAIN_WT" ] && echo 1 || echo 0)                         # v1.17+ / v1.27 renamed
CAP_GBRAIN_LEARNINGS=$([ -n "$GBRAIN_WT" ] && ls $GBRAIN_WT/learnings-*.jsonl 2>/dev/null | wc -l || echo 0)
CAP_GBRAIN_TIMELINE=$([ -n "$GBRAIN_WT" ] && ls $GBRAIN_WT/timeline-*.jsonl 2>/dev/null | wc -l || echo 0)
CAP_GBRAIN_REVIEWS=$([ -n "$GBRAIN_WT" ] && ls $GBRAIN_WT/review-*.jsonl 2>/dev/null | wc -l || echo 0)
CAP_GBRAIN_PROFILE=$([ -n "$GBRAIN_WT" ] && ls $GBRAIN_WT/developer-profile-*.json 2>/dev/null | wc -l || echo 0)
CAP_GBRAIN_POLICY=$([ -f "$GSTACK_HOME/gbrain-repo-policy.json" ] && echo 1 || echo 0)  # v1.12+
# Fallback path if user is pre-v1.17 (learnings still in projects/)
CAP_LEARNINGS_FB=$(ls $PROJ_DIR/*-learnings-*.jsonl 2>/dev/null | wc -l)
# Conductor workspaces (v1.11+); presence only — never write
CAP_CONDUCTOR_WS=$([ -d "$HOME/conductor/workspaces" ] && echo 1 || echo 0)
```

**llms.txt preference (v1.28+)**: when `$LLMS_TXT` is non-empty, prefer it over
hand-rolled skill enumeration. It is gstack's authoritative index of skills/commands
(47 skills, 75 commands compressed to ~11KB) — saves tokens and stays current.

**Lightweight contract drift check** (auto-run on every `--status`):

```bash
# Compare detected version to integration.json's min_supported
MIN_SUPPORTED=$(python3 -c 'import json;print(json.load(open(".claude/integration.json"))["gstack"]["min_supported"])' 2>/dev/null)
ver_lt() { [ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -1)" = "$1" ] && [ "$1" != "$2" ]; }
[ -n "$MIN_SUPPORTED" ] && ver_lt "$GSTACK_VERSION" "$MIN_SUPPORTED" && \
  echo "DRIFT: gstack v$GSTACK_VERSION below min_supported v$MIN_SUPPORTED" || true
```

### Step 2: Status Report (default)

Output this structure (Markdown):

```
## gstack ↔ oh-my-agents Integration Status

**Plugins**: oh-my-agents v{harness.version from integration.json}  ·  gstack v{version} ({loose-match: ok/warn})
**Project slug**: {slug}
**Worktree context**: {single | N parallel worktrees detected}

### Artifact bridges (presence)
- design docs: {count}            - test plans: {count}
- review logs: {count}            - QA outcomes: {count}
- codex reports: {count}          - cso reports: {count}
- design-review reports: {count}  - canary reports: {count}
- deploy reports: {count}         - landing reports: {local + project count}
- conductor.json: {present}       - .gstack-worktrees/: {N parallel}
- conductor workspaces (v1.11+): {present|absent}

### GBrain (v1.12+ memory subsystem, read-only; v1.26+ ingest, v1.27+ rename)
- worktree present       : {none | legacy(brain) | current(artifacts)}
- worktree path          : {resolved $GBRAIN_WT or "—"}
- learnings entries      : {N from worktree, or fallback projects/*-learnings-*.jsonl}
- timeline entries       : {N}
- review log entries     : {N}
- developer profile      : {present|absent}
- repo policy (schema v2): {present|absent}              (~/.gstack/gbrain-repo-policy.json)
- gbrain CLI             : {path | "not on PATH"}        (v1.26+ memory ingest)
- memory-ingest binary   : {path | "absent"}             (v1.26+)
- llms.txt index         : {path | "absent"}             (v1.28+; preferred for skill discovery)
- remote artifacts hint  : {none | legacy file | current file}  (v1.27 Path 4)

### Composition (who-owns-what)
- Slop deep-check         → gstack /codex                       (presence: {yes/no})
- Security audit          → gstack /cso                         (presence: {yes/no})
- UX / DX audit           → gstack /design-review + /devex-review (presence: {yes/no})
- Isolated bug repro      → gstack /investigate + /qa           (presence: {yes/no})
- Observation/learnings   → gstack GBrain + /learn (read)        (presence: {yes/no})
- Deploy metrics          → gstack /landing-report (presence: {yes/no})
- Architecture / layers   → harness arch-guard + hooks
- Entropy / TASTE rules   → harness entropy-sweep + encode-mistake
- Mechanical enforcement  → harness (TASTE rules in docs/LINTING.md)

### Recent activity (7d)
- gstack skill usage : top 5 from skill-usage.jsonl
- harness hooks fired: top 5 from session-*.jsonl
- violations blocked : count
- confusion signals  : count from confusion.jsonl
- learnings unencoded: count of learnings entries with no matching TASTE-NNN

### Integration contract
- Read-only bridge          : enforced (incl. GBrain — never write)
- Loose version match       : {current ok / DRIFT warning if < min_supported}
- min_supported             : {value}  ← bumps with major gstack milestones
- Lightweight drift check   : runs on every --status
- Deep contract check       : next due {policies.review_contract_quarter}

### Recommended next action
- {context-aware: if no design doc → /office-hours; if plan stalled → /lifecycle status; ...}
```

### Step 3: Setup (--setup)

1. Ensure `.claude/integration.json` exists (already shipped at v1.1+); if older, migrate.
2. Update CLAUDE.md workflow section if it lacks current gstack lifecycle commands.
3. Add to `.gitignore` if missing: `.gstack/`, `.gstack-worktrees/`, `conductor.json`,
   `.claude/signals/`, `.claude/metrics/`.
4. Create `.claude/signals/` directory for verify + review decision signals
   (`verify-latest.json`, `review-latest.json`).
5. Print summary; do not modify gstack files.

### Step 4: Metrics Sync (--metrics)

Generate `.claude/metrics/integrated-report.json`. Reference originals, do not copy:

```json
{
  "generated_at": "ISO8601",
  "harness": {
    "hooks_fired_7d": {...},
    "violations_blocked_7d": N,
    "verify_runs_7d": N,
    "verify_pass_rate": 0.0,
    "review_runs_7d": N,
    "encode_mistake_count_7d": N,
    "entropy_sweeps_7d": N
  },
  "gstack": {
    "source": "~/.gstack/analytics/skill-usage.jsonl",
    "skills_used_7d": {...},
    "ships_7d": N,
    "ships_with_verify_signal": N,
    "qa_runs_7d": N,
    "codex_reviews_7d": N,
    "cso_audits_7d": N,
    "ux_audits_7d": N,
    "investigates_7d": N
  },
  "combined": {
    "lifecycle_phase_coverage": {"ideate": N, "plan": N, ..., "improve": N},
    "dual_review_rate": 0.0,
    "investigate_to_encode_rate": 0.0,
    "ship_to_verify_signal_rate": 0.0,
    "confusion_signals_7d": N
  },
  "dora_proxy": {
    "deployment_frequency_per_week": 0.0,
    "lead_time_days_p50": 0.0,
    "change_failure_rate_proxy": 0.0,
    "mttr_hours_proxy": 0.0
  }
}
```

DORA proxies are best-effort estimates from available signals — flag as "proxy" in output.

### Step 5: Contract Check (--contract-check)

Quarterly governance gate — run before/after each quarter:

1. List integration contract assumptions (from this file + integration.json).
2. For each, probe whether gstack still satisfies it (artifact presence, path stability).
3. **Reconcile command bindings against the capability oracle.** When `$LLMS_TXT` is
   present, it is gstack's authoritative skill/command index — diff every slash-command
   string in `integration.json.composition` (`gstack_owns`, `*_audit`, `slop_deep_check`,
   …) against it. Any binding whose command no longer appears in `llms.txt` is **drift**
   (this is exactly how `/ux-audit` and `/health` went stale). Hand-maintained command
   lists are the drift source; `llms.txt` is the truth.
4. Surface drift: command bindings missing from `llms.txt`, paths moved, artifact format
   changed, gstack version below `min_supported`, legacy paths past `legacy_sunset`.
5. Output a remediation checklist; do NOT auto-modify integration.json (human decides).

## Rules

- Never modify gstack files or `~/.gstack/` state
- Read-only bridge — oh-my-agents reads gstack artifacts, never writes
- Graceful degradation when gstack is absent or version differs
- No duplicate metrics — merge and reference originals
- **Glob over exact path** — gstack reorganizes frequently; use patterns
- **Loose version match** — accept `min_supported` and above; warn but don't fail on drift
- **Worktree-aware** — if `.gstack-worktrees/` present, scope reports to current worktree
- **No skill duplication** — never invoke gstack commands; only discover their outputs
- **Bridge dual-value** — every gstack v1.27+ rename probes BOTH legacy (`gstack-brain*`)
  and current (`gstack-artifacts*`) paths; first hit wins; both absent = graceful degrade
- **Prefer llms.txt over enumeration** (v1.28+) — when present, it is gstack's
  authoritative skill/command index; do not duplicate or stale-cache it locally
- **No orchestration** — this skill discovers and reports; never executes gstack workflow
- Quarterly contract check is mandatory; record results in `.claude/metrics/integrated-report.json`
