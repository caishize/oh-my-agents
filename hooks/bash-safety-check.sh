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

# Private key (PEM format) in command
if echo "$COMMAND" | grep -Eq 'BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY'; then
    VIOLATIONS="${VIOLATIONS}Security risk: Private key content in bash command.\n"
    VIOLATIONS="${VIOLATIONS}  Fix: Reference a key file or secrets manager instead.\n\n"
fi

# curl/wget with inline Authorization header (not referencing env var)
# Improved: exclude both $VAR and ${VAR} patterns
if echo "$COMMAND" | grep -iEq '(Authorization|Bearer)[: ]+[A-Za-z0-9_-]{20,}'; then
    if ! echo "$COMMAND" | grep -Eq '(Authorization|Bearer)[: ]+\$(\{?[A-Za-z_])'; then
        VIOLATIONS="${VIOLATIONS}Security risk: Possible inline auth token in bash command.\n"
        VIOLATIONS="${VIOLATIONS}  Fix: Use environment variable reference instead of hardcoded token.\n\n"
    fi
fi

# Stripe keys in commands
if echo "$COMMAND" | grep -Eq '(sk|pk)_(live|test)_[A-Za-z0-9]{20,}'; then
    VIOLATIONS="${VIOLATIONS}Security risk: Stripe API key in bash command.\n"
    VIOLATIONS="${VIOLATIONS}  Fix: Use STRIPE_SECRET_KEY env var.\n\n"
fi

# Anthropic keys in commands
if echo "$COMMAND" | grep -Eq 'sk-ant-[A-Za-z0-9_-]{20,}'; then
    VIOLATIONS="${VIOLATIONS}Security risk: Anthropic API key in bash command.\n"
    VIOLATIONS="${VIOLATIONS}  Fix: Use ANTHROPIC_API_KEY env var.\n\n"
fi

# OpenAI keys in commands
if echo "$COMMAND" | grep -Eq 'sk-proj-[A-Za-z0-9_-]{20,}'; then
    VIOLATIONS="${VIOLATIONS}Security risk: OpenAI API key in bash command.\n"
    VIOLATIONS="${VIOLATIONS}  Fix: Use OPENAI_API_KEY env var.\n\n"
fi

# curl -u user:password (not referencing env var)
if echo "$COMMAND" | grep -Eq 'curl\s.*-u\s+[^$][A-Za-z0-9_]+:[A-Za-z0-9_]+'; then
    VIOLATIONS="${VIOLATIONS}Security risk: curl -u with inline credentials.\n"
    VIOLATIONS="${VIOLATIONS}  Fix: Use -u \"\$USER:\$PASS\" with env vars.\n\n"
fi

# CLI --password= or -p with inline value (mysql, redis-cli, etc.)
if echo "$COMMAND" | grep -Eq '\-\-password=[^\$][^ ]+'; then
    VIOLATIONS="${VIOLATIONS}Security risk: Inline password in CLI flag.\n"
    VIOLATIONS="${VIOLATIONS}  Fix: Use --password=\$DB_PASSWORD with env var.\n\n"
fi

if [ -n "$VIOLATIONS" ]; then
    echo -e "$VIOLATIONS" >&2
    exit 2
fi

exit 0
