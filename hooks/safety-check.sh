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

# --- Fast exit for binary/asset files (no secrets possible) ---
case "$FILE_PATH" in
    *.png|*.jpg|*.gif|*.ico|*.svg|*.woff|*.woff2|*.ttf|*.eot|*.mp3|*.mp4|*.webm|*.lock|*.map)
        exit 0
        ;;
esac

# --- Skip fixtures and mocks (but still scan test files for real secrets) ---
case "$FILE_PATH" in
    */fixtures/*|*/__fixtures__/*|*/__mocks__/*)
        exit 0
        ;;
esac

# Flag for test files: only check token-format patterns, skip generic password= patterns
IS_TEST_FILE=false
case "$FILE_PATH" in
    */test/*|*/tests/*|*/__tests__/*|*.test.*|*.spec.*)
        IS_TEST_FILE=true
        ;;
esac

CONTENT=$(get_content)

if [ -z "$CONTENT" ]; then
    exit 0
fi

# --- Strip comments to reduce false positives ---
# Step 1: Remove full-line comments (lines starting with //, #, ;, *, <!--, /*)
# Step 2: Remove inline trailing comments (// ... or # ... after code)
# Step 3: Remove block comment close lines
CONTENT_NO_COMMENTS=$(echo "$CONTENT" \
    | grep -vE '^\s*(//|#|;|\*|<!--|/\*)' \
    | grep -vE '^\s*\*/' \
    | sed -E 's/\s+\/\/.*$//' \
    | sed -E 's/\s+#[^"'"'"']*$//' \
    || true)

VIOLATIONS=""

# --- Helper: build violation message ---
add_violation() {
    local risk_type="$1"
    local file="$2"
    local pattern="${3:-}"
    local fix="$4"
    local ref="${5:-docs/CONVENTIONS.md#cross-cutting-concerns (secrets via env/secret manager)}"
    VIOLATIONS="${VIOLATIONS}Security risk: ${risk_type}\n"
    VIOLATIONS="${VIOLATIONS}  File: ${file}\n"
    if [ -n "$pattern" ]; then
        VIOLATIONS="${VIOLATIONS}  Pattern: ${pattern}\n"
    fi
    VIOLATIONS="${VIOLATIONS}  Fix: ${fix}\n"
    VIOLATIONS="${VIOLATIONS}  Ref: ${ref}\n\n"
}

# --- 1. Hardcoded secrets detection (uses comment-stripped content) ---

# --- Generic credential patterns (skip in test files to reduce false positives) ---
if [ "$IS_TEST_FILE" = "false" ]; then

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

fi  # end IS_TEST_FILE guard

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

# --- Modern API token patterns (scanned even in test files — real tokens should never appear) ---

# Stripe keys (sk_live_, sk_test_, pk_live_, pk_test_)
if echo "$CONTENT_NO_COMMENTS" | grep -Eq '(sk|pk)_(live|test)_[A-Za-z0-9]{20,}'; then
    MATCH=$(echo "$CONTENT_NO_COMMENTS" | grep -oE '(sk|pk)_(live|test)_[A-Za-z0-9]{20,}' | head -1)
    add_violation "Stripe API key detected." "$FILE_PATH" "$MATCH" \
        "Use STRIPE_SECRET_KEY / STRIPE_PUBLISHABLE_KEY env var."
fi

# Anthropic API keys (sk-ant-)
if echo "$CONTENT_NO_COMMENTS" | grep -Eq 'sk-ant-[A-Za-z0-9_-]{20,}'; then
    MATCH=$(echo "$CONTENT_NO_COMMENTS" | grep -oE 'sk-ant-[A-Za-z0-9_-]{20,}' | head -1)
    add_violation "Anthropic API key detected." "$FILE_PATH" "$MATCH" \
        "Use ANTHROPIC_API_KEY env var."
fi

# OpenAI API keys (sk-proj-, sk-...)
if echo "$CONTENT_NO_COMMENTS" | grep -Eq 'sk-proj-[A-Za-z0-9_-]{20,}'; then
    MATCH=$(echo "$CONTENT_NO_COMMENTS" | grep -oE 'sk-proj-[A-Za-z0-9_-]{20,}' | head -1)
    add_violation "OpenAI API key detected." "$FILE_PATH" "$MATCH" \
        "Use OPENAI_API_KEY env var."
fi

# npm tokens (npm_)
if echo "$CONTENT_NO_COMMENTS" | grep -Eq 'npm_[A-Za-z0-9]{36,}'; then
    MATCH=$(echo "$CONTENT_NO_COMMENTS" | grep -oE 'npm_[A-Za-z0-9]{36,}' | head -1)
    add_violation "npm token detected." "$FILE_PATH" "$MATCH" \
        "Use NPM_TOKEN env var."
fi

# --- 2. .env file modification with secrets ---
# Improved: exclude common non-secret patterns (URLs, paths, base64-padded config)
case "$FILE_PATH" in
    *.env|*.env.*|*secrets.env)
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
