#!/usr/bin/env bash
#
# Shared utilities for oh-my-agents hooks.
# Source this file from hook scripts:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/lib/common.sh"
#
# Provides:
#   read_input          — reads stdin into $INPUT
#   json_get <jq> <py>  — extract value from $INPUT using jq or python3 fallback
#   get_file_path       — extract .tool_input.file_path from $INPUT
#   get_content         — extract content + new_string from $INPUT
#   get_command         — extract .tool_input.command from $INPUT (for Bash hooks)
#   find_harness_json <start-dir> — walk up to find .claude/harness.json
#   load_harness_config <harness-file> — load providers_path and layer_dirs
#   resolve_layer <path> — return layer name for a file path (uses harness.json + fallback)
#   resolve_layer_index <path> — return numeric layer index (0-5, or -1)
#   layer_name_to_index <name> — convert layer name to index
#   add_violation <msg>  — append to $VIOLATIONS (caller must declare VIOLATIONS="")
#   get_project_dir [hint] — SETS PROJECT_DIR + PROJECT_DIR_SOURCE (never addresses off cwd)
#   find_project_root <path> — walk up to a VCS/.claude/build marker
#   find_build_root <path> — walk up to the nearest build manifest (monorepo package dir)
#   resolve_metrics_dir <root> <source> — SETS METRICS_DIR; creates only under env|git roots
#   harness_root        — project root for SKILL.md snippets (no hook stdin); echoes "." last

# --- Input ---

read_input() {
    # Limit stdin to 100KB to prevent hooks from stalling on large Write payloads
    INPUT=$(head -c 102400)
    # Ensure INPUT is never unset (set -u would kill downstream json_get calls)
    INPUT="${INPUT:-}"
}

# --- JSON parsing: prefer jq, fallback to python3 ---

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

# --- Common field extractors ---

get_file_path() {
    json_get \
        '.tool_input.file_path // ""' \
        "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))"
}

get_content() {
    json_get \
        '(.tool_input.content // "") + (.tool_input.new_string // "")' \
        "import sys,json; d=json.load(sys.stdin).get('tool_input',{}); print((d.get('content','') or '')+(d.get('new_string','') or ''))"
}

get_command() {
    json_get \
        '.tool_input.command // ""' \
        "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))"
}

get_tool_name() {
    json_get \
        '.tool_name // ""' \
        "import sys,json; print(json.load(sys.stdin).get('tool_name',''))"
}

get_cwd() {
    local result
    result=$(json_get \
        '.cwd // ""' \
        "import sys,json; print(json.load(sys.stdin).get('cwd',''))")
    # Return empty on bad input — callers must check and exit 0, not guess
    echo "$result"
}

# --- Project root resolution ---
#
# The hook input's `.cwd` is "wherever the last `cd` left the session" — Claude Code's Bash
# tool keeps cwd across calls by design, so one `cd backend && pytest` makes every later hook
# believe the project root is backend/. Addressing off it forks the metrics ledger and mixes
# path systems (repo-relative git output vs. cwd-relative paths) into comparisons that then
# never match. One fixed order instead, most authoritative first:
#
#   1. $CLAUDE_PROJECT_DIR       — the harness states the root; nothing beats it
#   2. git toplevel of `.cwd`    — a fact about the tree, not about where we stand
#   3. marker walk from a file   — VCS/.claude first, build manifests last
#   4. empty                     — callers exit 0 (see get_cwd's contract); never guess
#
# PROJECT_DIR_SOURCE records WHICH tier answered, because that decides what a caller may
# create. AUTHORITATIVE: `env` (tier 1) and `git` (tier 2, or a tier-3 walk that hit a real
# VCS root — the same fact, reached from the file instead of from cwd). DERIVED: `marker`
# (tier 3 landing on `.claude/` or a bare build manifest) — a build manifest marks a monorepo
# *package*, not a project. See resolve_metrics_dir: creating a ledger has to follow from
# KNOWING the root, never from where the process happens to stand.

PROJECT_DIR="${PROJECT_DIR:-}"
PROJECT_DIR_SOURCE="${PROJECT_DIR_SOURCE:-}"

# Resolve a directory to its physical path. Roots reached by different routes
# ($CLAUDE_PROJECT_DIR through a symlink vs. `git rev-parse` through the real path) must
# compare equal, or the same directory reads as two — which would make a hook report the
# project's own ledger as a stray copy. Always succeeds; echoes the input on failure.
_canonical_dir() {
    local d="${1:-}"
    if [ -z "$d" ]; then
        echo ""
        return 0
    fi
    ( cd "$d" 2>/dev/null && pwd -P ) || echo "${d%/}"
}

_set_project_dir() {
    PROJECT_DIR=$(_canonical_dir "$1")
    PROJECT_DIR_SOURCE="$2"
}

# Walk up from <path> (file or directory) to the nearest project-root marker.
# VCS and harness markers outrank build manifests: in a monorepo `backend/pyproject.toml`
# marks a package, not the project. Echoes the directory, or empty when nothing matches.
find_project_root() {
    local dir="${1:-}"
    if [ -z "$dir" ]; then
        echo ""
        return 1
    fi
    [ -d "$dir" ] || dir=$(dirname "$dir")
    local vcs="" harness="" build="" candidate=""
    while [ -n "$dir" ] && [ "$dir" != "/" ] && [ "$dir" != "." ]; do
        if [ -z "$vcs" ] && { [ -e "${dir}/.git" ] || [ -d "${dir}/.hg" ] || [ -d "${dir}/.svn" ]; }; then
            vcs="$dir"
        fi
        if [ -z "$harness" ] && [ -d "${dir}/.claude" ]; then
            harness="$dir"
        fi
        if [ -z "$build" ] && { [ -f "${dir}/package.json" ] || [ -f "${dir}/pyproject.toml" ] || \
                                [ -f "${dir}/Cargo.toml" ] || [ -f "${dir}/go.mod" ] || \
                                [ -f "${dir}/tsconfig.json" ]; }; then
            build="$dir"
        fi
        dir=$(dirname "$dir")
    done
    for candidate in "$vcs" "$harness" "$build"; do
        if [ -n "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done
    echo ""
    return 1
}

# Nearest ancestor of <path> carrying a build manifest — the directory a type-check or a
# compile has to run in. Deliberately NOT the project root: for `backend/src/x.py` in a
# monorepo this is `backend/`, which is exactly right for `tsc`/`cargo` and exactly wrong
# for the ledger. Echoes the directory, or empty.
find_build_root() {
    local dir="${1:-}"
    if [ -z "$dir" ]; then
        echo ""
        return 1
    fi
    [ -d "$dir" ] || dir=$(dirname "$dir")
    while [ -n "$dir" ] && [ "$dir" != "/" ] && [ "$dir" != "." ]; do
        if [ -f "${dir}/package.json" ] || [ -f "${dir}/tsconfig.json" ] || \
           [ -f "${dir}/pyproject.toml" ] || [ -f "${dir}/Cargo.toml" ]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    echo ""
    return 1
}

# Resolve the project root by the order documented above.
# SETS variables (like find_harness_json) rather than echoing, because the source matters
# as much as the path:
#   PROJECT_DIR         — the root, or "" when it cannot be established
#   PROJECT_DIR_SOURCE  — env | git | marker | "" (authoritative iff env or git)
# Optional $1: a file path to walk up from when tiers 1-2 miss (defaults to the input's
# .tool_input.file_path). Returns 0 when resolved, 1 when not — on 1 callers must exit 0
# and say so, not fall back to $(pwd).
get_project_dir() {
    PROJECT_DIR=""
    PROJECT_DIR_SOURCE=""

    if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR}" ]; then
        _set_project_dir "$CLAUDE_PROJECT_DIR" "env"
        return 0
    fi

    local cwd top
    cwd=$(get_cwd)
    if [ -n "$cwd" ] && [ -d "$cwd" ]; then
        top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "")
        if [ -n "$top" ] && [ -d "$top" ]; then
            _set_project_dir "$top" "git"
            return 0
        fi
    fi

    local hint="${1:-}"
    [ -z "$hint" ] && hint=$(get_file_path)
    if [ -n "$hint" ]; then
        top=$(find_project_root "$hint" || echo "")
        if [ -n "$top" ]; then
            # A VCS root found by the walk is the same fact `git rev-parse` reports, just
            # reached from the file instead of from cwd — authoritative. A bare build
            # manifest is not: in a monorepo it marks a package, so it stays DERIVED.
            if [ -e "${top}/.git" ] || [ -d "${top}/.hg" ] || [ -d "${top}/.svn" ]; then
                _set_project_dir "$top" "git"
            else
                _set_project_dir "$top" "marker"
            fi
            return 0
        fi
    fi

    return 1
}

# Resolve the metrics ledger directory under a project root.
# The ledger fork this guards against is self-reinforcing: once `backend/.claude/` exists,
# every later marker walk finds it first and routes that whole subtree into the copy. So:
#   - an existing ledger (or an existing `.claude/`) is always appended to
#   - a missing one is CREATED only under an authoritative root (env|git)
#   - a derived root with no `.claude/` gets nothing — no home is invented
# Sets: METRICS_DIR ("" when the ledger may not be created). Returns 0 on success.
resolve_metrics_dir() {
    local root="${1:-}"
    local source="${2:-}"
    METRICS_DIR=""
    [ -z "$root" ] && return 1
    local dir="${root%/}/.claude/metrics"
    if [ -d "$dir" ]; then
        METRICS_DIR="$dir"
        return 0
    fi
    case "$source" in
        env|git) : ;;
        *) [ -d "${root%/}/.claude" ] || return 1 ;;
    esac
    mkdir -p "$dir" 2>/dev/null || return 1
    METRICS_DIR="$dir"
    return 0
}

# The project root for callers that have no hook stdin — SKILL.md snippets, and the
# repo-local probes below (`.claude/skills`, `.claude/integration.json`). Same order as
# get_project_dir minus the hook-input tier: an already-resolved $PROJECT_DIR, then
# $CLAUDE_PROJECT_DIR, then the git toplevel of the process cwd, then ".". A bare relative
# `.claude/...` path would resolve against "wherever the last cd left us" — the same bug in
# miniature, and the reason every skill that writes into `.claude/` anchors on this.
harness_root() {
    if [ -n "${PROJECT_DIR:-}" ] && [ -d "${PROJECT_DIR}" ]; then
        echo "${PROJECT_DIR%/}"
        return 0
    fi
    if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR}" ]; then
        echo "${CLAUDE_PROJECT_DIR%/}"
        return 0
    fi
    local top
    top=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
    if [ -n "$top" ] && [ -d "$top" ]; then
        echo "${top%/}"
        return 0
    fi
    echo "."
}

# --- Harness config loading ---

# Initialize harness config variables with defaults
HARNESS_FILE=""
HARNESS_ROOT=""
PROVIDERS_PATH=""
HARNESS_LAYER_DIRS=""
SIBLING_LAYERS=""

# Walk up from a directory to find .claude/harness.json
# Sets: HARNESS_FILE, HARNESS_ROOT
find_harness_json() {
    local search_dir="$1"
    HARNESS_FILE=""
    HARNESS_ROOT=""
    while [ "$search_dir" != "/" ] && [ "$search_dir" != "." ]; do
        if [ -f "${search_dir}/.claude/harness.json" ]; then
            HARNESS_FILE="${search_dir}/.claude/harness.json"
            HARNESS_ROOT="$search_dir"
            return 0
        fi
        search_dir=$(dirname "$search_dir")
    done
    return 1
}

# Load config from harness.json
# Sets: PROVIDERS_PATH, HARNESS_LAYER_DIRS, SIBLING_LAYERS
load_harness_config() {
    local harness_file="$1"
    PROVIDERS_PATH=""
    HARNESS_LAYER_DIRS=""
    SIBLING_LAYERS=""
    if [ -z "$harness_file" ] || [ ! -f "$harness_file" ]; then
        return 1
    fi
    if command -v jq >/dev/null 2>&1; then
        PROVIDERS_PATH=$(jq -r '.providers_path // ""' "$harness_file" 2>/dev/null || echo "")
        HARNESS_LAYER_DIRS=$(jq -r '.layer_dirs // .target_layer_model.default_layer_dirs // empty' "$harness_file" 2>/dev/null || echo "")
        SIBLING_LAYERS=$(jq -r '(.sibling_layers // []) | .[]' "$harness_file" 2>/dev/null | tr '\n' ',' || echo "")
    elif command -v python3 >/dev/null 2>&1; then
        PROVIDERS_PATH=$(python3 -c "import json; print(json.load(open('${harness_file}')).get('providers_path',''))" 2>/dev/null || echo "")
        HARNESS_LAYER_DIRS=$(python3 -c "import json; c=json.load(open('${harness_file}')); d=c.get('layer_dirs') or c.get('target_layer_model',{}).get('default_layer_dirs',{}); print(json.dumps(d) if d else '')" 2>/dev/null || echo "")
        SIBLING_LAYERS=$(python3 -c "import json; print(','.join(json.load(open('${harness_file}')).get('sibling_layers',[])))" 2>/dev/null || echo "")
    fi
}

# Check if two layers are siblings (allowed to import from each other)
# sibling_layers format in harness.json: ["service:runtime", "ui:pages"]
# SIBLING_LAYERS is a comma-separated string: "service:runtime,ui:pages,"
are_sibling_layers() {
    local layer_a="$1"
    local layer_b="$2"
    if [ -z "${SIBLING_LAYERS:-}" ]; then
        return 1
    fi
    # Check both orderings: a:b and b:a
    if echo ",$SIBLING_LAYERS" | grep -qE ",${layer_a}:${layer_b},|,${layer_b}:${layer_a},"; then
        return 0
    fi
    return 1
}

# --- gstack integration utilities ---

# Detect gstack installation path (glob-based — gstack reorganizes; rule glob-over-exact-path).
# Probes common install roots; no version-era exact path is baked in here.
# Sets: GSTACK_PATH (empty if not found)
detect_gstack() {
    GSTACK_PATH=""
    local candidates=()
    local root
    local base
    base=$(harness_root)
    for root in "$HOME/.claude/skills" "${base}/.claude/skills" "$HOME/.claude/plugins" "${base}/.claude/plugins"; do
        [ -d "$root" ] || continue
        while IFS= read -r -d '' p; do
            candidates+=("$p")
        done < <(find "$root" -maxdepth 2 -type d -name 'gstack*' -print0 2>/dev/null || true)
    done
    if [ "${#candidates[@]}" -gt 0 ]; then
        GSTACK_PATH="${candidates[0]}"
        return 0
    fi
    return 1
}

# ONE-CALL gstack detection for skills and hooks (the single detection implementation —
# SKILL.md files source this via ${CLAUDE_PLUGIN_ROOT}/hooks/lib/common.sh and call it
# instead of restating their own probe snippets).
# Sets: GSTACK_PATH, SLUG (and PROJECT_SLUG), GSTACK_PROJECTS, GSTACK_ANALYTICS.
# Returns 0 when gstack is present, 1 when absent (graceful degrade — never an error).
gstack_detect() {
    detect_gstack || true
    resolve_project_slug
    SLUG="$PROJECT_SLUG"
    resolve_gstack_paths
    [ -n "$GSTACK_PATH" ]
}

# Resolve project slug for gstack artifact paths
# Tries gstack-slug binary first, falls back to basename of git root
# Sets: PROJECT_SLUG
resolve_project_slug() {
    PROJECT_SLUG=""
    if [ -n "${GSTACK_PATH:-}" ] && [ -x "$GSTACK_PATH/bin/gstack-slug" ]; then
        PROJECT_SLUG=$("$GSTACK_PATH/bin/gstack-slug" 2>/dev/null || echo "")
    fi
    if [ -z "$PROJECT_SLUG" ]; then
        PROJECT_SLUG=$(basename "$(git -C "$(harness_root)" rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
    fi
}

# Resolve gstack artifact paths, reading from integration.json if available, else defaults
# Requires: PROJECT_SLUG to be set
# Sets: GSTACK_PROJECTS, GSTACK_ANALYTICS
resolve_gstack_paths() {
    local integration_json
    integration_json="$(harness_root)/.claude/integration.json"
    GSTACK_PROJECTS=""
    GSTACK_ANALYTICS=""

    # Try integration.json first
    if [ -f "$integration_json" ] && command -v jq >/dev/null 2>&1; then
        GSTACK_PROJECTS=$(jq -r '.bridges.design_docs // ""' "$integration_json" 2>/dev/null | sed "s|{SLUG}|${PROJECT_SLUG:-unknown}|g; s|~|$HOME|g")
        # design_docs is a FILE glob — consumers need the project DIRECTORY
        case "$GSTACK_PROJECTS" in *\**) GSTACK_PROJECTS=$(dirname "$GSTACK_PROJECTS") ;; esac
        GSTACK_ANALYTICS=$(jq -r '.bridges.analytics // ""' "$integration_json" 2>/dev/null | sed "s|~|$HOME|g")
    fi

    # Fall back to defaults
    [ -z "$GSTACK_PROJECTS" ] && GSTACK_PROJECTS="$HOME/.gstack/projects/${PROJECT_SLUG:-unknown}"
    [ -z "$GSTACK_ANALYTICS" ] && GSTACK_ANALYTICS="$HOME/.gstack/analytics"
}

# --- Layer resolution ---

# Canonical layer order
LAYER_ORDER=(types config repo service runtime ui)

layer_name_to_index() {
    case "$1" in
        types)   echo 0 ;;
        config)  echo 1 ;;
        repo)    echo 2 ;;
        service) echo 3 ;;
        runtime) echo 4 ;;
        ui)      echo 5 ;;
        *)       echo -1 ;;
    esac
}

index_to_layer_name() {
    case "$1" in
        0) echo "types" ;;
        1) echo "config" ;;
        2) echo "repo" ;;
        3) echo "service" ;;
        4) echo "runtime" ;;
        5) echo "ui" ;;
        *) echo "unknown" ;;
    esac
}

# Resolve layer name from file path using harness.json layer_dirs
_resolve_layer_from_harness() {
    local path="$1"
    if [ -z "${HARNESS_LAYER_DIRS:-}" ]; then
        echo ""
        return
    fi
    if command -v jq >/dev/null 2>&1; then
        local layer_name
        for layer_name in types config repo service runtime ui; do
            local dirs
            dirs=$(echo "$HARNESS_LAYER_DIRS" | jq -r ".[\"$layer_name\"] // empty | if type == \"array\" then .[] else . end" 2>/dev/null || true)
            if [ -n "$dirs" ]; then
                while IFS= read -r pattern; do
                    local clean="${pattern//\*/}"
                    clean="${clean%/}"
                    clean="${clean#/}"
                    clean="${clean## }"
                    clean="${clean%% }"
                    if [ -n "$clean" ] && { [[ "$path" == *"/$clean/"* ]] || [[ "$path" == "$clean/"* ]]; }; then
                        echo "$layer_name"
                        return
                    fi
                done <<< "$dirs"
            fi
        done
        echo ""
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json, sys
layer_dirs = json.loads(sys.argv[1])
layer_order = ['types','config','repo','service','runtime','ui']
path = sys.argv[2]
for layer_name in layer_order:
    if layer_name in layer_dirs:
        dirs = layer_dirs[layer_name]
        if isinstance(dirs, str):
            dirs = [dirs]
        for pattern in dirs:
            clean = pattern.strip('*/ ')
            if clean and ('/' + clean + '/' in path or path.startswith(clean + '/')):
                print(layer_name)
                sys.exit(0)
print('')
" "$HARNESS_LAYER_DIRS" "$path" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Fallback layer detection from path patterns
_resolve_layer_fallback() {
    local path="$1"
    case "$path" in
        */types/*|*/models/*|*/interfaces/*)       echo "types" ;;
        */config/*|*/configuration/*)              echo "config" ;;
        */repo/*|*/repository/*|*/dal/*)           echo "repo" ;;
        */service/*|*/services/*)                  echo "service" ;;
        */runtime/*|*/server/*|*/api/*)            echo "runtime" ;;
        */ui/*|*/components/*|*/pages/*|*/views/*)  echo "ui" ;;
        *)                                         echo "" ;;
    esac
}

# Resolve layer name for a file path (harness.json first, then fallback)
# Returns: layer name string or empty
resolve_layer() {
    local path="$1"
    local result
    result=$(_resolve_layer_from_harness "$path" || echo "")
    if [ -n "$result" ]; then
        echo "$result"
        return
    fi
    _resolve_layer_fallback "$path"
}

# Resolve layer index for a file path (0-5, or -1 if unknown)
resolve_layer_index() {
    local name
    name=$(resolve_layer "$1")
    if [ -n "$name" ]; then
        layer_name_to_index "$name"
    else
        echo "-1"
    fi
}
