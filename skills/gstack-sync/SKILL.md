---
name: gstack-sync
description: "Detect gstack installation, configure read-only artifact bridges, report integration health with a mechanical contract-drift nudge. The integration hub for oh-my-agents + gstack combined workflows (never writes gstack paths). Aliases: gstack同步, 插件同步, gstack集成"
user-invocable: true
argument-hint: "[--status] [--setup] [--contract-check]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# gstack-sync — Plugin Integration Hub

Detect, configure, and maintain the bridge between oh-my-agents (quality enforcement)
and gstack (delivery acceleration).

**Composition principle**: this skill never wraps gstack commands. It only **discovers
artifacts** (glob), **emits readiness signals**, and **reports integration health**.
gstack version drift is expected (daily releases) — match versions loosely, degrade gracefully.

## Task

`$ARGUMENTS`: `--status` (default), `--setup`, or `--contract-check`
(`--metrics` / `integrated-report.json` were deleted in v3.10.0 — one producer, zero
consumers, triple-dead upstream inputs; everything wanted lives in `/harness-dashboard`)

### Step 0: Detect gstack (loose match)

```bash
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/common.sh" && gstack_detect || true
[ -z "$GSTACK_PATH" ] && echo "NOT_FOUND" && exit 0
GSTACK_VERSION=$(cat "$GSTACK_PATH/VERSION" 2>/dev/null || echo "unknown")
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
ROOT=$(harness_root)                       # project root — never the shell cwd
GSTACK_HOME_DIR=$(gstack_home)             # honors $GSTACK_HOME like gstack's own bin/gstack-paths
PROJ_DIR="$GSTACK_PROJECTS"                # from gstack_detect (slug = owner-repo, {SLUG}-templated)
ANALYTICS_DIR="$GSTACK_ANALYTICS"
# gbrain: GBRAIN_WT / GBRAIN_LEARNINGS / GBRAIN_CLI / GBRAIN_REMOTE / GSTACK_ARTIFACTS_REMOTE /
# GSTACK_TIMELINE are all set by gstack_detect (ONE implementation — hooks/lib/common.sh).
# Worktree = ~/.gstack-brain-worktree (env GSTACK_BRAIN_WORKTREE); learnings = ONE file
# under projects/<slug>/. Absent = graceful degrade.

# Capability probes (presence > version)
# llms.txt: GLOB, not exact paths — carved skills (v1.56+ skeleton+sections/) and rendered
# layouts move it around. Also check the project-local gstack-rendered enclave.
LLMS_TXT=$(find "$GSTACK_PATH" .claude/gstack-rendered -name 'llms.txt' 2>/dev/null | head -1)  # v1.28+
INGEST_BIN=""
[ -x "$GSTACK_PATH/bin/gstack-memory-ingest" ] && INGEST_BIN="$GSTACK_PATH/bin/gstack-memory-ingest"  # v1.26+
ARTIFACTS_REMOTE="$GSTACK_ARTIFACTS_REMOTE"   # sync/distribution remote
BRAIN_REMOTE="$GBRAIN_REMOTE"                 # DISTINCT remote — gbrain memory; never infer "gbrain absent" from artifacts-only
GBRAIN_DOCTOR=$( { command -v gbrain >/dev/null 2>&1 && gbrain doctor >/dev/null 2>&1; } && echo "ok" || echo "")  # v1.26+ MCP/health

# gstack decision/verdict layer (v1.57.5+): event-sourced decisions + active snapshot + review verdict.
# Read-only — feeds /harness-review reconciliation (docs/SIGNALS.md), never written here.
DECISIONS_LOG=$([ -f "$PROJ_DIR/decisions.jsonl" ] && echo 1 || echo 0)              # v1.57.5+
DECISIONS_ACTIVE=$([ -f "$PROJ_DIR/decisions.active.json" ] && echo 1 || echo 0)     # v1.57.5+
REVIEW_VERDICT=$(ls -t $PROJ_DIR/*-reviews.jsonl 2>/dev/null | head -1 | xargs -I{} tail -1 {} 2>/dev/null \
  | python3 -c "import sys,json; raw=sys.stdin.read().strip(); print(json.loads(raw).get('status','verdict-unparsed') if raw else '')" 2>/dev/null || echo "verdict-unparsed")  # gstack-review-log; LOUD degrade, never silent ""
HEALTH_HISTORY=$([ -f "$PROJ_DIR/health-history.jsonl" ] && echo 1 || echo 0)        # v1.x /health

# Core artifacts (legacy, pre-v1)
CAP_DESIGN=$(ls $PROJ_DIR/*-design-*.md 2>/dev/null | wc -l)
CAP_TEST_PLAN=$(ls $PROJ_DIR/*-test-plan-*.md 2>/dev/null | wc -l)
CAP_REVIEW=$(ls $PROJ_DIR/*-reviews.jsonl 2>/dev/null | wc -l)
CAP_QA=$(ls $PROJ_DIR/*-test-outcome-*.md 2>/dev/null | wc -l)
CAP_CODEX=$(ls $PROJ_DIR/*-codex-*.md 2>/dev/null | wc -l)
CAP_CSO=$(ls $PROJ_DIR/*-cso-*.md 2>/dev/null | wc -l)
CAP_DESIGN_REVIEW=$(ls $PROJ_DIR/*-design-review-*.md 2>/dev/null | wc -l)  # was /ux-audit pre-v1.x
CAP_CANARY=$(ls "$ROOT"/.gstack/canary-reports/*.md 2>/dev/null | wc -l)   # gstack writes {date}-canary.md (never .json); rooted, never cwd-relative
CAP_DEPLOY=$(ls "$ROOT"/.gstack/deploy-reports/*.md 2>/dev/null | wc -l)   # {date}-pr{n}-deploy.md
CAP_CONDUCTOR=$([ -f "conductor.json" ] && echo 1 || echo 0)
CAP_WORKTREES=$([ -d ".gstack-worktrees" ] && ls -1 .gstack-worktrees | wc -l || echo 0)
CAP_SKILL_USAGE=$([ -f "$ANALYTICS_DIR/skill-usage.jsonl" ] && echo 1 || echo 0)
CAP_EUREKA=$([ -f "$ANALYTICS_DIR/eureka.jsonl" ] && echo 1 || echo 0)

# Post-v0.18 additions (v1.x era). `.gstack/landing-reports/` NEVER existed (verified v1.79) — no probe.
CAP_LANDING_PROJ=$(ls $PROJ_DIR/*-landing-*.md 2>/dev/null | wc -l)              # v1.11+
CAP_TIMELINE=$([ -f "$GSTACK_TIMELINE" ] && wc -l < "$GSTACK_TIMELINE" || echo 0) # ALWAYS-ON usage log (skill-usage.jsonl is telemetry-gated, default off)
CAP_GBRAIN_WT=$([ -n "$GBRAIN_WT" ] && echo 1 || echo 0)                         # ~/.gstack-brain-worktree
CAP_GBRAIN_LEARNINGS=$(cat $GBRAIN_LEARNINGS 2>/dev/null | wc -l)                # projects/<slug>/learnings.jsonl entries
CAP_GBRAIN_TIMELINE=$([ -n "$GBRAIN_WT" ] && ls $GBRAIN_WT/timeline-*.jsonl 2>/dev/null | wc -l || echo 0)
CAP_GBRAIN_REVIEWS=$([ -n "$GBRAIN_WT" ] && ls $GBRAIN_WT/review-*.jsonl 2>/dev/null | wc -l || echo 0)
CAP_GBRAIN_PROFILE=$([ -n "$GBRAIN_WT" ] && ls $GBRAIN_WT/developer-profile-*.json 2>/dev/null | wc -l || echo 0)
CAP_GBRAIN_POLICY=$([ -f "$GSTACK_HOME_DIR/gbrain-repo-policy.json" ] && echo 1 || echo 0)  # v1.12+
# Conductor workspaces (v1.11+); presence only — never write
CAP_CONDUCTOR_WS=$([ -d "$HOME/conductor/workspaces" ] && echo 1 || echo 0)
```

**llms.txt preference (v1.28+)**: when `$LLMS_TXT` is non-empty, prefer it over
hand-rolled skill enumeration. It is gstack's authoritative index of skills/commands
(47 skills, 75 commands compressed to ~11KB) — saves tokens and stays current.

**Lightweight contract drift check** (auto-run on every `--status`):

```bash
# Compare detected version to integration.json's min_supported
ROOT=$(source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/common.sh" && harness_root)
MIN_SUPPORTED=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]+"/.claude/integration.json"))["gstack"]["min_supported"])' "$ROOT" 2>/dev/null)
ver_lt() { [ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -1)" = "$1" ] && [ "$1" != "$2" ]; }
[ -n "$MIN_SUPPORTED" ] && ver_lt "$GSTACK_VERSION" "$MIN_SUPPORTED" && \
  echo "DRIFT: gstack v$GSTACK_VERSION below min_supported v$MIN_SUPPORTED" || true
# Contract-check overdue nudge (v3.10): the recorded quarter is BOTH trigger and receipt.
# Current quarter computed from the clock (never a hard-coded string). Silent when current.
REC_Q=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]+"/.claude/integration.json"))["policies"].get("review_contract_quarter",""))' "$ROOT" 2>/dev/null)
NOW_Q=$(date -u +%Y)-Q$(( ($(date -u +%-m) - 1) / 3 + 1 ))
[ -n "$REC_Q" ] && [ "$REC_Q" \< "$NOW_Q" ] && \
  echo "CONTRACT-CHECK OVERDUE: last recorded $REC_Q, now $NOW_Q — next: /gstack-sync --contract-check" || true
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
- deploy reports: {count}         - landing reports (project): {count}
- timeline entries: {count}       (gstack always-on usage log — lifecycle coverage source)
- conductor.json: {present}       - .gstack-worktrees/: {N parallel}
- conductor workspaces (v1.11+): {present|absent}

### GBrain (v1.12+ memory subsystem, read-only; v1.26+ ingest; v1.27 rename — legacy sunset v3.6.0)
- worktree present       : {none | present (gstack-artifacts)}
- worktree path          : {resolved $GBRAIN_WT or "—"}
- learnings entries      : {N from projects/<slug>/learnings.jsonl}
- timeline entries       : {N}
- review log entries     : {N}
- developer profile      : {present|absent}
- repo policy (schema v2): {present|absent}              (~/.gstack/gbrain-repo-policy.json)
- gbrain CLI             : {path | "not on PATH"}        (v1.26+ memory ingest)
- memory-ingest binary   : {path | "absent"}             (v1.26+)
- llms.txt index         : {path | "absent"}             (v1.28+; preferred for skill discovery)
- artifacts remote       : {present|absent}              (sync/distribution remote)
- brain remote           : {present|absent}              (DISTINCT remote — gbrain memory; not a rename)
- gbrain doctor          : {ok | "n/a"}                  (v1.26+ MCP/health probe)

### Decision/verdict layer (gstack v1.57.5+, read-only — feeds /harness-review reconciliation)
- decisions.jsonl        : {present|absent}              (event-sourced decision memory)
- decisions.active.json  : {present|absent}              (presence only — a rebuildable cache, never counted)
- review verdict         : {clean | issues_found | verdict-unparsed | "—"}  (gstack-review-log status; currency by `wtree` in /harness-review)
- health-history.jsonl   : {present|absent}
- reconciliation         : {our review-latest.json + gstack verdict → agree=pass / diverge=NEEDS_HUMAN:judgment-slop}

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
- learnings unencoded: count of learnings entries with no matching TASTE-NNN

### Ship gate (our-side convention — honest labeling)
- gate_status: {VERIFIED | ASSERTED}   ← from the --contract-check probe; ASSERTED means
  our-side convention (docs/SIGNALS.md pre-ship check), unconfirmed by gstack — a probe
  miss is NEVER reported as "gstack ignores signals"

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

1. Ensure `$ROOT/.claude/integration.json` exists. It is NOT created by `/harness-init`; when
   absent, copy the plugin's own manifest as the template —
   `cp "${CLAUDE_PLUGIN_ROOT}/.claude/integration.json" "$ROOT/.claude/integration.json"` —
   it carries `{SLUG}` placeholders (substituted at read time by `resolve_gstack_paths`,
   never baked) and `policies.review_contract_quarter`, which the overdue nudge needs. Set
   `project.slug` to `$SLUG`. If older, migrate.
2. Update CLAUDE.md workflow section if it lacks current gstack lifecycle commands.
3. Add to `.gitignore` if missing: `.gstack/`, `.gstack-worktrees/`, `conductor.json`,
   `.claude/signals/`, `.claude/metrics/`, `.claude/gstack-rendered/` (gstack-owned
   enclave, v1.57.9+ — gstack writes rendered docs there; we never track or flag it).
4. Create the signals directory at the **project root** for verify + review decision
   signals (`verify-latest.json`, `review-latest.json`):
   `ROOT=$(source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/common.sh" && harness_root); mkdir -p "$ROOT/.claude/signals"`.
5. Print summary; do not modify gstack files.

### Step 4: Contract Check (--contract-check)

Quarterly governance gate — run before/after each quarter:

1. List integration contract assumptions (from this file + integration.json).
2. For each, probe whether gstack still satisfies it (artifact presence, path stability).
3. **Reconcile command bindings against the capability oracle — ORDERED succession**
   (`integration.json policies.capability_oracle`): (a) local `$GSTACK_PATH/VERSION`
   file first; (b) `llms.txt` via glob (carved/rendered layouts); (c) generated skill
   index; (d) raw-fetch VERSION+CHANGELOG from GitHub — network LAST, the quarterly
   check must never acquire a hard network dependency (gstack's Releases page is empty;
   VERSION/CHANGELOG raw-fetch is the only drift channel). When an oracle is present,
   diff every slash-command string in `integration.json.composition` against it. Any
   binding whose command no longer appears is **drift** (this is exactly how `/ux-audit`
   and `/health` went stale). Hand-maintained command lists are the drift source.
4. Surface drift: command bindings missing from the oracle, paths moved, artifact format
   changed, gstack version below `min_supported`, legacy paths past `legacy_sunset`.
5. **Ship-gate probe (read-only)** — does gstack actually reference our signals?
   Glob WIDE: `$GSTACK_PATH/**/*.md` PLUS the project's `.claude/gstack-rendered/**`
   (carved skills put content in `sections/`; a narrow skill-dir grep is a
   false-negative machine), grep for `.claude/signals` / `verify-latest`. Report
   `gate_status: VERIFIED` (reference found) or `ASSERTED` (our-side convention,
   unconfirmed). A grep miss MUST render as `ASSERTED` — never as "gstack ignores
   signals" (absence of a hit is not proof of absence). Verified against v1.79 source
   (2026-09-04): `/ship` reads nothing of ours — ASSERTED is the confirmed state. The one
   bilateral surface is `bin/gstack-verify-gate` reading `<!-- gstack:verify: … -->` from
   the PROJECT's CLAUDE.md (our `/harness-init` exports it, confirmed-command only).
6. **Confusion Protocol probe** — read-only grep of gstack's surface for Confusion
   Protocol references. The `confusion.jsonl` bridge is RESERVED/INACTIVE (no producer
   observed); hard-delete its bridge row only if this probe confirms upstream sunset at
   a quarterly check.
7. Output a remediation checklist; do NOT auto-modify integration.json (human decides).
8. **Record the check** by bumping `policies.review_contract_quarter` to the current
   quarter — a ONE-LINE HUMAN-CONFIRMED edit, never auto-written (the check must not mark
   itself done without running). That recorded quarter is the next `--status` run's trigger.

## Rules

- Never modify gstack files or `~/.gstack/` state
- Read-only bridge — oh-my-agents reads gstack artifacts, never writes
- Graceful degradation when gstack is absent or version differs
- No duplicate metrics — merge and reference originals
- **Glob over exact path** — gstack reorganizes frequently; use patterns
- **Loose version match** — accept `min_supported` and above; warn but don't fail on drift
- **Worktree-aware** — if `.gstack-worktrees/` present, scope reports to current worktree
- **No skill duplication** — never invoke gstack commands; only discover their outputs
- **gbrain paths (corrected v3.10.0)** — the memory worktree is `~/.gstack-brain-worktree`
  (env `GSTACK_BRAIN_WORKTREE`); `~/.gstack-artifacts-worktree` has zero hits in gstack
  v1.79 and is never probed. `~/.gstack-brain-remote.txt` and `~/.gstack-artifacts-remote.txt`
  are two DISTINCT remotes (memory vs sync); gbrain presence = CLI/`gbrain doctor` OR
  worktree OR brain-remote — never artifacts-only. ONE detection implementation:
  `gbrain_detect()` in hooks/lib/common.sh (a future rename is a 3-line edit there).
- **Prefer llms.txt over enumeration** (v1.28+) — when present, it is gstack's
  authoritative skill/command index; do not duplicate or stale-cache it locally
- **No orchestration** — this skill discovers and reports; never executes gstack workflow
- Quarterly contract check is nudged mechanically on every `--status`; its result is the
  recorded `review_contract_quarter` (human-bumped in integration.json)
