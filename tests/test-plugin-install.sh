#!/usr/bin/env bash
# Real Codex package/discovery test; no user settings or authentication are touched.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v codex >/dev/null
python3 "$ROOT/tests/plugin_smoke.py"
