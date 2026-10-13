---
name: arch-guard
description: "Configure and verify architecture layers, sibling exceptions and Providers boundaries in an existing project. Use for dependency-direction enforcement and structural tests. 架构检查、分层约束。"
---

# Architecture Guard

1. Read applicable AGENTS.md, `.codex/harness.json`, manifests and actual imports. Resolve
   the project root and installed plugin root; inspect `templates/harness-config.json`.
2. Map canonical `types → config → repo → service → runtime → ui` layers to real directories.
   Dependencies may point left; document justified `sibling_layers` exceptions. Never invent
   layers for a project that uses a different architecture; surface that decision explicitly.
3. Confirm cross-cutting concerns have Providers interfaces. Adapt the reference tests in
   `skills/harness-init/` to the project's language/test runner with real assertions.
4. Encode boundaries in structural tests and existing CI. The Codex apply_patch hook checks
   additions/updates through the adapter; shell writes and unsupported hosts need these
   project tests too. Hook regexes are a fast guard, not complete language parsers.
5. Run both valid and deliberately invalid fixture imports to demonstrate enforcement.
   Verify the actual project with its test runner. Preserve existing configuration and tests.
6. Record the layer map and commands in docs/ARCHITECTURE.md and AGENTS.md. Report violations
   with file:line, rule, remedy and documentation reference; do not rewrite application
   architecture as an incidental setup step.
