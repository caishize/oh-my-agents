---
name: spec-to-task
description: "Convert an explicit specification into an execution plan with runnable acceptance, context files and failing tests. Use for feature decomposition before implementation. 需求拆解、执行计划。"
---

# Spec to Task

Read the supplied spec and existing project AGENTS.md, architecture, tests and active plans.
Arguments may name a spec path or plan id. Follow `templates/execution-plan.json` exactly.

1. Extract user-visible behavior, constraints, dependencies and concrete acceptance criteria.
   Ask only for unknown requirements that prevent useful planning; continue independent work.
2. If no spec was supplied, optionally inspect the gstack spec archive for the current branch
   via the common detection library. Exactly one matching `spec_branch` permits selection;
   multiple matching specs require explicit selection. Absence is not an error.
3. Split work into small tasks following actual layer dependencies. Each task names context
   files, a test that initially fails, a runnable acceptance command, dependencies and status.
   Use `pending`, `in-progress`, `done`, `skipped` (hyphen spelling from the schema).
4. Do not mark a test as initially failing until it ran and failed for the intended reason.
   Record unexecuted tests honestly. Commands must be safe in the documented directory.
5. Write `docs/exec-plans/active/<id>.json` only when planning output is authorized. Validate
   JSON and schema constraints with existing tools. Never overwrite an existing active plan.
6. Present task order, acceptance, evidence and unresolved constraints. Execution and review
   belong to later tasks; do not create delivery orchestration, worktrees or external issues.

The plan is consumed by `$oh-my-agents:verify`, `$oh-my-agents:lifecycle` and the plan-validation hook. Completion is
confirmed by executed acceptance, not an implementer's claim. Move a completed plan to the
completed directory only after verification covers the accepted work.
