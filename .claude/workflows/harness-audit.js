// harness-audit — the ONE sanctioned oh-my-agents Dynamic Workflow (anti-bloat rule 17).
//
// WHAT: a read-only, fan-out, four-pillar governance audit. Many Explore agents audit the
// repo in parallel, each finding is adversarially verified (skeptic tries to REFUTE it),
// and the workflow RETURNS a review-latest.json-shaped decision + the confirmed findings.
//
// RULE 17 INVARIANTS (mechanically honored here; do not weaken):
//   1. READ-ONLY, structurally: every audit/verify agent uses agentType:'Explore', which
//      CANNOT Write/Edit/NotebookEdit (a real mechanism, not a grep self-test).
//   2. TERMINATES IN A SIGNAL, not a deployed artifact (the SIGNAL-vs-ARTIFACT bright line).
//   3. ACCOUNTABLE-WRITER (proven by the 2026-06-07 spike): this workflow does NOT write
//      .claude/signals/ from a relay agent — the safety classifier correctly blocks an agent
//      from emitting a decision it didn't itself derive. The workflow RETURNS the signal; the
//      invoking skill/human (accountable for the verdict) persists it via /harness-review's
//      existing writer. Never advances a delivery phase, mutates source, commits, or opens a PR.
//
// USE: governance/release/quarterly audits where fan-out recall matters (the A/B spike found
// ZERO overlap between fan-out and a single sequential pass; fan-out caught 3x more real
// findings and adversarial verify filtered 16.7% false positives). For PR/hotfix validation,
// prefer the single-pass /harness-review — cheaper, sufficient.
//
// args (optional): { scope?: string }  — free-text scope hint passed to every auditor.

export const meta = {
  name: 'harness-audit',
  description: 'Read-only four-pillar governance audit: fan-out Explore agents + adversarial verification; returns a review-latest.json-shaped decision (never writes it). Rule-17 governed.',
  phases: [
    { title: 'Audit', detail: 'Read-only Explore agents, one per pillar/dimension' },
    { title: 'Verify', detail: 'Adversarially refute each finding (read-only)' },
    { title: 'Decide', detail: 'Compute the decision signal and RETURN it for the accountable writer' },
  ],
}

const SCOPE = (args && args.scope) ? `\nScope hint: ${args.scope}` : '';

const CTX = `You are auditing the repository in the current working directory (a codebase using
the oh-my-agents harness). Use Read/Glob/Grep and read-only Bash to inspect REAL files. Report
ONLY concrete, file-anchored findings — no speculation, nothing a linter would catch. When a
finding depends on an external fact (e.g. whether a gstack command still exists), VERIFY it
against the source of truth (gstack's llms.txt) before reporting. Severity: P0=blocks/
correctness/contract-break, P1=should-fix, P2=minor. Cap at your 6 highest-signal findings;
return zero if your dimension is clean.${SCOPE}`;

const AUDIT_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['dimension', 'findings'],
  properties: {
    dimension: { type: 'string' },
    findings: {
      type: 'array', maxItems: 6,
      items: {
        type: 'object', additionalProperties: false,
        required: ['id', 'severity', 'title', 'file', 'detail'],
        properties: {
          id: { type: 'string' },
          severity: { type: 'string', enum: ['P0', 'P1', 'P2'] },
          title: { type: 'string' },
          file: { type: 'string' },
          line: { type: 'string' },
          detail: { type: 'string' },
        },
      },
    },
  },
};

const VERDICT_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['real', 'confidence', 'reason'],
  properties: {
    real: { type: 'boolean' },
    confidence: { type: 'string', enum: ['low', 'med', 'high'] },
    reason: { type: 'string' },
  },
};

// Four pillars + the cross-cutting contract dimension. Each is blind to the others (multi-modal sweep).
const DIMENSIONS = [
  { key: 'slop',     prompt: 'Pillar: Entropy. SLOP/duplication — duplicate helpers/logic, copy-paste artifacts, pattern inconsistency, over-engineering, contradictory prose across docs/skills.' },
  { key: 'arch',     prompt: 'Pillar: Architecture. Layer/Providers violations; dependency-direction breaks; module boundary leaks; direct service instantiation.' },
  { key: 'docs',     prompt: 'Pillar: Documentation. Stale counts (skills/agents/hooks), dead file references, version-string mismatches, broken relative links, commands that no longer exist.' },
  { key: 'observ',   prompt: 'Pillar: Observability. Missing/ambiguous decision signals, metrics gaps, nested CLAUDE.md drift, unactionable error messages.' },
  { key: 'contract', prompt: 'Cross-cutting: CONTRACTS. integration.json bridges vs the skills that probe them; any skill globbing a removed legacy path; docs/SIGNALS.md schema vs what verify/harness-review actually emit; default-deny completeness in /lifecycle.' },
];

// ---------------------------------------------------------------------------
phase('Audit');
const audits = await parallel(DIMENSIONS.map((d) => () =>
  agent(`${CTX}\n\n${d.prompt}`, { agentType: 'Explore', schema: AUDIT_SCHEMA, label: `audit:${d.key}`, phase: 'Audit' })
)).then((r) => r.filter(Boolean));

const raw = audits.flatMap((a) => (a.findings || []).map((f) => ({ ...f, dimension: a.dimension })));

// ---------------------------------------------------------------------------
phase('Verify');
const verified = await parallel(raw.map((f) => () =>
  agent(
    `${CTX}\n\nROLE: adversarial skeptic. Try HARD to REFUTE this finding by checking the actual file(s) and any external source of truth. Default real=false if you cannot independently confirm it on disk. Finding:\n${JSON.stringify(f, null, 2)}`,
    { agentType: 'Explore', schema: VERDICT_SCHEMA, label: `verify:${f.dimension}:${f.id}`, phase: 'Verify' }
  ).then((v) => ({ ...f, verdict: v })).catch(() => null)
)).then((r) => r.filter(Boolean));

const confirmed = verified.filter((f) => f.verdict && f.verdict.real);
const refuted = verified.filter((f) => f.verdict && !f.verdict.real);

// ---------------------------------------------------------------------------
phase('Decide');
const p0 = confirmed.filter((f) => f.severity === 'P0').length;
const p1 = confirmed.filter((f) => f.severity === 'P1').length;
const p2 = confirmed.filter((f) => f.severity === 'P2').length;

// Deterministic decision (computed here, NOT by a model). Conservative by design.
const decision = p0 > 0 ? 'REQUEST_CHANGES' : (p1 > 0 ? 'NEEDS_HUMAN' : 'APPROVE');
const needs_human_kind = decision === 'NEEDS_HUMAN' ? 'judgment-slop' : null;

// review-latest.json shape (docs/SIGNALS.md). RETURNED, not written — see header invariant 3.
// The accountable invoker (a human, or /harness-review re-run) persists this; add `timestamp`
// (date -u +%Y-%m-%dT%H:%M:%SZ) at persist time. Strip the `_persistence` note before writing.
const signal = {
  schema_version: 1,
  decision,
  needs_human_kind,
  merge_recommendation: p0 > 0 ? 'COMPLEX' : (p1 > 0 ? 'STANDARD' : 'TRIVIAL'),
  p0_count: p0, p1_count: p1, p2_count: p2,
  tags_present: ['[HARNESS]'],
  gstack_composed: false,
  plan_id: null,
  reason: `harness-audit: ${p0} P0 / ${p1} P1 / ${p2} P2 confirmed (fan-out+verify)`.slice(0, 120),
  _persistence: 'RETURNED, not written. The accountable invoker persists to .claude/signals/review-latest.json (add timestamp, drop this field). A relay agent must NOT write it — the spike proved the safety classifier correctly blocks fabricated-verdict writes.',
};

log(`harness-audit: ${confirmed.length} confirmed (${p0} P0 / ${p1} P1 / ${p2} P2), ${refuted.length} refuted → decision ${decision}`);

return {
  signal,
  confirmed: confirmed.map((f) => ({ dimension: f.dimension, severity: f.severity, title: f.title, file: f.file, line: f.line || '', detail: f.detail, confidence: f.verdict.confidence })),
  refuted: refuted.map((f) => ({ title: f.title, why: f.verdict.reason })),
  stats: { dimensions: DIMENSIONS.length, raw: raw.length, confirmed: confirmed.length, refuted: refuted.length },
};
