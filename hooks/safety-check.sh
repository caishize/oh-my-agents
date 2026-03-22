#!/usr/bin/env bash
#
# Safety check hook — PreToolUse for Edit/Write
# Detects hardcoded secrets and risk patterns.
#
# Exit codes:
#   0 - no risks found (allow)
#   2 - risk detected (block with remediation on stderr)

set -euo pipefail

# --- Load shared utilities ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

read_input

FILE_PATH=$(get_file_path)

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

CONTENT=$(get_content)

if [ -z "$CONTENT" ]; then
    exit 0
fi

# --- Skip test files, fixtures, and mocks ---
case "$FILE_PATH" in
    */test/*|*/tests/*|*/__tests__/*|*/fixtures/*|*/__fixtures__/*|*/__mocks__/*|*.test.*|*.spec.*)
        exit 0
        ;;
esac

# --- Strip comment lines to reduce false positives ---
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

# Detect SECRET variable with literal value
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

# --- Additional credential patterns ---

# GitHub Personal Access Token (ghp_ prefix)
if echo "$CONTENT_NO_COMMENTS" | grep -Eq 'ghp_[A-Za-z0-9_]{36,}'; then
    MATCH=$(echo "$CONTENT_NO_COMMENTS" | grep -oE 'ghp_[A-Za-z0-9_]{36,}' | head -1)
    add_violation "GitHub Personal Access Token detected." "$FILE_PATH" "$MATCH" \
        "Use GITHUB_TOKEN env var or GitHub App credentials. Rotate immediately if committed."
fi

# Slack tokens (xoxb- / xoxp- prefix)
if echo "$CONTENT_NO_COMMENTS" | grep -Eq 'xox[bp]-[0-9]{10,}-[A-Za-z0-9-]+'; then
    MATCH=$(echo "$CONTENT_NO_COMMENTS" | grep -oE 'xox[bp]-[0-9]{10,}-[A-Za-z0-9-]+' | head -1)
    add_violation "Slack token detected." "$FILE_PATH" "$MATCH" \
        "Use SLACK_TOKEN env var."
fi

# Private keys (PEM format)
if echo "$CONTENT_NO_COMMENTS" | grep -Eq 'BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY'; then
    add_violation "Private key detected in source code." "$FILE_PATH" "" \
        "Store keys in a secrets manager or .pem file excluded via .gitignore."
fi

# Google API key (AIzaSy prefix)
if echo "$CONTENT_NO_COMMENTS" | grep -Eq 'AIzaSy[A-Za-z0-9_-]{33}'; then
    MATCH=$(echo "$CONTENT_NO_COMMENTS" | grep -oE 'AIzaSy[A-Za-z0-9_-]{33}' | head -1)
    add_violation "Google API key detected." "$FILE_PATH" "$MATCH" \
        "Use GOOGLE_API_KEY env var."
fi

# --- 2. .env file modification with secrets ---
# Improved: exclude common non-secret patterns (URLs, paths, base64-padded config)
case "$FILE_PATH" in
    *.env|*.env.local|*.env.production|*.env.staging)
        # Only flag values that look like secrets: high-entropy, no URL scheme, no path separators
        if echo "$CONTENT" | grep -Eq '=\s*["\x27]?[A-Za-z0-9+/=_-]{16,}["\x27]?\s*$' &&
           ! echo "$CONTENT" | grep -Eq '=\s*["\x27]?(https?://|postgresql://|mongodb://|redis://|mysql://|sqlite:)'; then
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
