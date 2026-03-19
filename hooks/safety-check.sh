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

# --- Skip test files, fixtures, and mocks (P0 fix) ---
case "$FILE_PATH" in
    */test/*|*/tests/*|*/__tests__/*|*/fixtures/*|*/__fixtures__/*|*/__mocks__/*|*.test.*|*.spec.*)
        exit 0
        ;;
esac

# --- Strip comment lines to reduce false positives (P0 fix) ---
# Only strips lines where the first non-whitespace char is a comment marker.
# Inline comments after code are preserved (intentionally conservative).
CONTENT_NO_COMMENTS=$(echo "$CONTENT" | grep -vE '^\s*(//|#|;|\*|<!--|/\*)' | grep -vE '^\s*\*/' || true)

VIOLATIONS=""

# --- Helper: build violation message ---
add_violation() {
    local risk_type="$1"
    local file="$2"
    local pattern="${3:-}"
    local fix="$4"
    local ref="${5:-docs/CONVENTIONS.md#secrets-management}"
    VIOLATIONS="${VIOLATIONS}Security risk: ${risk_type}\n"
    VIOLATIONS="${VIOLATIONS}  File: ${file}\n"
    if [ -n "$pattern" ]; then
        VIOLATIONS="${VIOLATIONS}  Pattern: ${pattern}\n"
    fi
    VIOLATIONS="${VIOLATIONS}  Fix: ${fix}\n"
    VIOLATIONS="${VIOLATIONS}  Ref: ${ref}\n\n"
}

# --- 1. Hardcoded secrets detection (uses comment-stripped content) ---

# Detect credential assignments in quoted strings
if echo "$CONTENT_NO_COMMENTS" | grep -iEq 'password\s*=\s*["\x27][^"\x27]+["\x27]'; then
    MATCH=$(echo "$CONTENT_NO_COMMENTS" | grep -iE 'password\s*=\s*["\x27][^"\x27]+["\x27]' | head -1 | sed 's/^[[:space:]]*//')
    add_violation "Hardcoded credential detected in source code." "$FILE_PATH" "$MATCH" \
        "Use environment variable via process.env instead of inline value."
fi

# Detect SECRET variable with literal value (case-insensitive: secret, Secret, MY_SECRET, etc.)
if echo "$CONTENT_NO_COMMENTS" | grep -iEq '[A-Z_]*SECRET[A-Z_]*\s*=\s*["\x27][^"\x27]+["\x27]'; then
    MATCH=$(echo "$CONTENT_NO_COMMENTS" | grep -iE '[A-Z_]*SECRET[A-Z_]*\s*=\s*["\x27][^"\x27]+["\x27]' | head -1 | sed 's/^[[:space:]]*//')
    add_violation "Hardcoded secret detected." "$FILE_PATH" "$MATCH" \
        "Use environment variable instead of inline secret."
fi

# Detect api_key / apiKey / api-key with literal value
if echo "$CONTENT_NO_COMMENTS" | grep -iEq 'api[_-]?key\s*=\s*["\x27][^"\x27]+["\x27]'; then
    MATCH=$(echo "$CONTENT_NO_COMMENTS" | grep -iE 'api[_-]?key\s*=\s*["\x27][^"\x27]+["\x27]' | head -1 | sed 's/^[[:space:]]*//')
    add_violation "Hardcoded API key detected." "$FILE_PATH" "$MATCH" \
        "Use environment variable via process.env instead of inline key."
fi

# Detect AWS access key (AKIA prefix with 16 uppercase alphanumeric chars)
if echo "$CONTENT_NO_COMMENTS" | grep -Eq 'AKIA[0-9A-Z]{16}'; then
    MATCH=$(echo "$CONTENT_NO_COMMENTS" | grep -oE 'AKIA[0-9A-Z]{16}' | head -1)
    add_violation "AWS Access Key ID detected." "$FILE_PATH" "$MATCH" \
        "Use AWS credential chain (env vars, IAM role, or ~/.aws/credentials). Rotate immediately if committed."
fi

# Detect JWT tokens (eyJ... two-segment base64)
if echo "$CONTENT_NO_COMMENTS" | grep -Eq 'eyJ[A-Za-z0-9_-]{20,}\.eyJ[A-Za-z0-9_-]{20,}'; then
    add_violation "JWT token detected in source code." "$FILE_PATH" "" \
        "Never embed tokens in source. Load from environment or secrets manager."
fi

# --- Additional credential patterns (P2 fix) ---

# Detect GitHub Personal Access Token (ghp_ prefix)
if echo "$CONTENT_NO_COMMENTS" | grep -Eq 'ghp_[A-Za-z0-9_]{36,}'; then
    MATCH=$(echo "$CONTENT_NO_COMMENTS" | grep -oE 'ghp_[A-Za-z0-9_]{36,}' | head -1)
    add_violation "GitHub Personal Access Token detected." "$FILE_PATH" "$MATCH" \
        "Use GITHUB_TOKEN env var or GitHub App credentials. Rotate immediately if committed."
fi

# Detect Slack tokens (xoxb- / xoxp- prefix)
if echo "$CONTENT_NO_COMMENTS" | grep -Eq 'xox[bp]-[0-9]{10,}-[A-Za-z0-9-]+'; then
    MATCH=$(echo "$CONTENT_NO_COMMENTS" | grep -oE 'xox[bp]-[0-9]{10,}-[A-Za-z0-9-]+' | head -1)
    add_violation "Slack token detected." "$FILE_PATH" "$MATCH" \
        "Use SLACK_TOKEN env var."
fi

# Detect private keys (PEM format)
if echo "$CONTENT_NO_COMMENTS" | grep -Eq 'BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY'; then
    add_violation "Private key detected in source code." "$FILE_PATH" "" \
        "Store keys in a secrets manager or .pem file excluded via .gitignore."
fi

# Detect Google API key (AIzaSy prefix)
if echo "$CONTENT_NO_COMMENTS" | grep -Eq 'AIzaSy[A-Za-z0-9_-]{33}'; then
    MATCH=$(echo "$CONTENT_NO_COMMENTS" | grep -oE 'AIzaSy[A-Za-z0-9_-]{33}' | head -1)
    add_violation "Google API key detected." "$FILE_PATH" "$MATCH" \
        "Use GOOGLE_API_KEY env var."
fi

# --- 2. .env file modification with secrets ---
case "$FILE_PATH" in
    *.env|*.env.local|*.env.production|*.env.staging)
        if echo "$CONTENT" | grep -Eq '=\s*["\x27]?[A-Za-z0-9+/=_-]{16,}["\x27]?\s*$'; then
            add_violation "Potential secret value in env file." "$FILE_PATH" "" \
                "Env files with secrets should be in .gitignore. Use .env.example with empty values."
        fi
        ;;
esac

# --- Output ---
if [ -n "$VIOLATIONS" ]; then
    echo -e "$VIOLATIONS" >&2
    exit 2
fi

exit 0
