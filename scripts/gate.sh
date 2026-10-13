#!/usr/bin/env bash
# Explicit release gate for Codex hosts where hooks are unavailable or untrusted.
set -euo pipefail
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PLUGIN_DIR/hooks/lib/common.sh"
ROOT="${1:-$(git rev-parse --show-toplevel)}"
command -v jq >/dev/null
verification_complete "$ROOT"
signal_fresh "$ROOT" verify-latest.json GREEN --advance
signal_fresh "$ROOT" review-latest.json APPROVE --advance
echo 'Harness gate passed: fresh GREEN and APPROVE, with verified tree freshness.'
