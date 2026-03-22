#!/usr/bin/env bash
#
# Bash command credential leak check — PreToolUse for Bash
# Detects hardcoded secrets in command arguments.
#
# Exit codes:
#   0 - no risks (allow)
#   2 - risk detected (block with remediation on stderr)

set -euo pipefail

# --- Load shared utilities ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

read_input

COMMAND=$(get_command)

if [ -z "$COMMAND" ]; then
    exit 0
fi

VIOLATIONS=""

# AWS key in command
if echo "$COMMAND" | grep -Eq 'AKIA[0-9A-Z]{16}'; then
    VIOLATIONS="${VIOLATIONS}Security risk: AWS Access Key in bash command.\n"
    VIOLATIONS="${VIOLATIONS}  Fix: Use AWS credential chain instead of inline keys.\n\n"
fi

# GitHub token in command
if echo "$COMMAND" | grep -Eq 'ghp_[A-Za-z0-9_]{36,}'; then
    VIOLATIONS="${VIOLATIONS}Security risk: GitHub token in bash command.\n"
    VIOLATIONS="${VIOLATIONS}  Fix: Use GITHUB_TOKEN env var.\n\n"
fi

# Slack token in command
if echo "$COMMAND" | grep -Eq 'xox[bp]-[0-9]{10,}'; then
    VIOLATIONS="${VIOLATIONS}Security risk: Slack token in bash command.\n"
    VIOLATIONS="${VIOLATIONS}  Fix: Use SLACK_TOKEN env var.\n\n"
fi

# Google API key in command
if echo "$COMMAND" | grep -Eq 'AIzaSy[A-Za-z0-9_-]{33}'; then
    VIOLATIONS="${VIOLATIONS}Security risk: Google API key in bash command.\n"
    VIOLATIONS="${VIOLATIONS}  Fix: Use GOOGLE_API_KEY env var.\n\n"
fi

# JWT token in command
if echo "$COMMAND" | grep -Eq 'eyJ[A-Za-z0-9_-]{20,}\.eyJ[A-Za-z0-9_-]{20,}'; then
    VIOLATIONS="${VIOLATIONS}Security risk: JWT token in bash command.\n"
    VIOLATIONS="${VIOLATIONS}  Fix: Use env var reference instead of inline token.\n\n"
fi

# curl/wget with inline Authorization header (not referencing env var)
# Improved: exclude both $VAR and ${VAR} patterns
if echo "$COMMAND" | grep -iEq '(Authorization|Bearer)[: ]+[A-Za-z0-9_-]{20,}'; then
    if ! echo "$COMMAND" | grep -Eq '(Authorization|Bearer)[: ]+\$(\{?[A-Za-z_])'; then
        VIOLATIONS="${VIOLATIONS}Security risk: Possible inline auth token in bash command.\n"
        VIOLATIONS="${VIOLATIONS}  Fix: Use environment variable reference instead of hardcoded token.\n\n"
    fi
fi

if [ -n "$VIOLATIONS" ]; then
    echo -e "$VIOLATIONS" >&2
    exit 2
fi

exit 0
