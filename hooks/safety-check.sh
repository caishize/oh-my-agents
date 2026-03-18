#!/usr/bin/env bash
#
# Safety check hook — PreToolUse for Edit/Write
# Detects hardcoded secrets and risk patterns.
#
# Input: JSON on stdin from Claude Code
#   { "tool_name": "Edit", "tool_input": { "file_path": "...", "new_string": "..." } }
#
# Exit codes:
#   0 - no risks found (allow)
#   2 - risk detected (block with remediation on stderr)

set -euo pipefail

INPUT=$(cat)

# --- JSON parser: prefer jq, fallback to python3 ---
json_get() {
    local jq_expr="$1"
    local py_expr="$2"
    if command -v jq >/dev/null 2>&1; then
        echo "$INPUT" | jq -r "$jq_expr" 2>/dev/null || echo ""
    elif command -v python3 >/dev/null 2>&1; then
        echo "$INPUT" | python3 -c "$py_expr" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

FILE_PATH=$(json_get \
    '.tool_input.file_path // ""' \
    "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))")

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

CONTENT=$(json_get \
    '(.tool_input.content // "") + (.tool_input.new_string // "")' \
    "import sys,json; d=json.load(sys.stdin).get('tool_input',{}); print((d.get('content','') or '')+(d.get('new_string','') or ''))")

if [ -z "$CONTENT" ]; then
    exit 0
fi

VIOLATIONS=""

# --- 1. Hardcoded secrets detection ---

# password = 'value' or password = "value"
if echo "$CONTENT" | grep -iEq 'password\s*=\s*["\x27][^"\x27]+["\x27]'; then
    MATCH=$(echo "$CONTENT" | grep -iE 'password\s*=\s*["\x27][^"\x27]+["\x27]' | head -1 | sed 's/^[[:space:]]*//')
    VIOLATIONS="${VIOLATIONS}Security risk: Hardcoded password detected in source code.\n"
    VIOLATIONS="${VIOLATIONS}  File: ${FILE_PATH}\n"
    VIOLATIONS="${VIOLATIONS}  Pattern: ${MATCH}\n"
    VIOLATIONS="${VIOLATIONS}  Fix: Use environment variable: password: process.env.DB_PASSWORD\n"
    VIOLATIONS="${VIOLATIONS}  Add to .env.example: DB_PASSWORD=\n"
    VIOLATIONS="${VIOLATIONS}  Ref: docs/CONVENTIONS.md#secrets-management\n\n"
fi

# SECRET = 'value'
if echo "$CONTENT" | grep -Eq 'SECRET\s*=\s*["\x27][^"\x27]+["\x27]'; then
    MATCH=$(echo "$CONTENT" | grep -E 'SECRET\s*=\s*["\x27][^"\x27]+["\x27]' | head -1 | sed 's/^[[:space:]]*//')
    VIOLATIONS="${VIOLATIONS}Security risk: Hardcoded secret detected.\n"
    VIOLATIONS="${VIOLATIONS}  File: ${FILE_PATH}\n"
    VIOLATIONS="${VIOLATIONS}  Pattern: ${MATCH}\n"
    VIOLATIONS="${VIOLATIONS}  Fix: Use environment variable instead of inline secret.\n"
    VIOLATIONS="${VIOLATIONS}  Ref: docs/CONVENTIONS.md#secrets-management\n\n"
fi

# api_key = 'value' or apiKey = 'value' or api-key = 'value'
if echo "$CONTENT" | grep -iEq 'api[_-]?key\s*=\s*["\x27][^"\x27]+["\x27]'; then
    MATCH=$(echo "$CONTENT" | grep -iE 'api[_-]?key\s*=\s*["\x27][^"\x27]+["\x27]' | head -1 | sed 's/^[[:space:]]*//')
    VIOLATIONS="${VIOLATIONS}Security risk: Hardcoded API key detected.\n"
    VIOLATIONS="${VIOLATIONS}  File: ${FILE_PATH}\n"
    VIOLATIONS="${VIOLATIONS}  Pattern: ${MATCH}\n"
    VIOLATIONS="${VIOLATIONS}  Fix: Use environment variable: process.env.API_KEY\n"
    VIOLATIONS="${VIOLATIONS}  Ref: docs/CONVENTIONS.md#secrets-management\n\n"
fi

# AWS access key (AKIA...)
if echo "$CONTENT" | grep -Eq 'AKIA[0-9A-Z]{16}'; then
    MATCH=$(echo "$CONTENT" | grep -oE 'AKIA[0-9A-Z]{16}' | head -1)
    VIOLATIONS="${VIOLATIONS}Security risk: AWS Access Key ID detected.\n"
    VIOLATIONS="${VIOLATIONS}  File: ${FILE_PATH}\n"
    VIOLATIONS="${VIOLATIONS}  Pattern: ${MATCH}\n"
    VIOLATIONS="${VIOLATIONS}  Fix: Use AWS credential chain (env vars, IAM role, or ~/.aws/credentials).\n"
    VIOLATIONS="${VIOLATIONS}  Rotate this key immediately if it was ever committed.\n"
    VIOLATIONS="${VIOLATIONS}  Ref: docs/CONVENTIONS.md#secrets-management\n\n"
fi

# JWT tokens (eyJ...)
if echo "$CONTENT" | grep -Eq 'eyJ[A-Za-z0-9_-]{20,}\.eyJ[A-Za-z0-9_-]{20,}'; then
    VIOLATIONS="${VIOLATIONS}Security risk: JWT token detected in source code.\n"
    VIOLATIONS="${VIOLATIONS}  File: ${FILE_PATH}\n"
    VIOLATIONS="${VIOLATIONS}  Fix: Never embed tokens in source. Load from environment or secrets manager.\n"
    VIOLATIONS="${VIOLATIONS}  Ref: docs/CONVENTIONS.md#secrets-management\n\n"
fi

# --- 2. .env file modification with secrets ---
case "$FILE_PATH" in
    *.env|*.env.local|*.env.production|*.env.staging)
        if echo "$CONTENT" | grep -Eq '=\s*["\x27]?[A-Za-z0-9+/=_-]{16,}["\x27]?\s*$'; then
            VIOLATIONS="${VIOLATIONS}Security risk: Potential secret value in env file.\n"
            VIOLATIONS="${VIOLATIONS}  File: ${FILE_PATH}\n"
            VIOLATIONS="${VIOLATIONS}  Fix: Env files with secrets should be in .gitignore.\n"
            VIOLATIONS="${VIOLATIONS}  Use .env.example with empty values for documentation.\n"
            VIOLATIONS="${VIOLATIONS}  Ref: docs/CONVENTIONS.md#secrets-management\n\n"
        fi
        ;;
esac

# --- Output ---
if [ -n "$VIOLATIONS" ]; then
    echo -e "$VIOLATIONS" >&2
    exit 2
fi

exit 0
