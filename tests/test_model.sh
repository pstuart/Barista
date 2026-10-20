# =============================================================================
# Model Module Regression Tests
# =============================================================================
# Standalone test for modules/model.sh JSON extraction and output, including
# the optional thinking/effort segment (MODEL_SHOW_THINKING, issue #99).
# Usage: bash tests/test_model.sh
# =============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        pass "$desc"
    else
        fail "$desc — expected [$expected] got [$actual]"
    fi
}

# Load only the shared helpers and the module under test.
# shellcheck source=/dev/null
source "$PROJECT_ROOT/modules/utils.sh"
# shellcheck source=/dev/null
source "$PROJECT_ROOT/modules/model.sh"

# Invoke module_model with the documented barista.sh defaults pinned in a
# subshell; only the thinking flag and statusline JSON vary between calls.
# $1 = MODEL_SHOW_THINKING value, or "unset" to leave the flag at its default.
# $2 = statusline JSON payload.
run_model() {
    (
        USE_ICONS="true"
        DISPLAY_MODE="normal"
        MODEL_ICON="🤖"
        MODEL_SHOW_OUTPUT_STYLE="true"
        MODEL_COMPACT="false"
        MODEL_STYLE="both"
        if [ "$1" = "unset" ]; then
            unset MODEL_SHOW_THINKING
        else
            MODEL_SHOW_THINKING="$1"
        fi
        MODEL_THINKING_ICON="✦"
        module_model "$2"
    )
}

# Build a statusline payload by appending `,"key":value` fragments to the base
# model/object-style fixture; each argument is one `key:<json>` member joined
# with commas before the closing brace (keys unquoted — jq 1.6 tolerates it,
# but emit strict JSON instead so invalid-json assertions stay meaningful).
payload() {
    local base out fragment
    base='"model":{"display_name":"Claude Opus 4"},"output_style":{"name":"default"}'
    out="$base"
    for fragment in "$@"; do
        key="${fragment%%:*}"
        value="${fragment#*:}"
        out="$out,\"$key\":$value"
    done
    printf '{%s}' "$out"
}

# Expected output builder; `$1` is the model name (default: Claude Opus 4) and
# the remaining words form the optional trailing segment (thinking, style)
# appended with a space.
model_out() {
    local icon name suffix
    icon="$(get_icon "🤖" "MODEL:")"
    name="${1:-Claude Opus 4}"
    suffix="${2:-}"
    if [ -n "$suffix" ]; then
        printf '%s %s' "$icon $name" "$suffix"
    else
        printf '%s' "$icon $name"
    fi
}

MODEL_ONLY="$(model_out)"
THINK_ICON="$(get_icon "✦" "")"

# --- (1) Thinking enabled + effort renders "On · xhigh" ----------------------

assert_eq "thinking on + effort renders On · xhigh" \
    "$MODEL_ONLY $THINK_ICON On · xhigh" \
    "$(run_model true "$(payload 'thinking:{"enabled":true,"effort":"xhigh"}')")"

# Same shape with a top-level boolean + top-level effort
assert_eq "top-level thinking bool + effort renders On · high" \
    "$MODEL_ONLY $THINK_ICON On · high" \
    "$(run_model true "$(payload 'thinking:true' 'effort:"high"')")"

# --- (2) Thinking enabled, no effort renders "On" ----------------------------

assert_eq "thinking on without effort renders On" \
    "$MODEL_ONLY $THINK_ICON On" \
    "$(run_model true "$(payload 'thinking:{"enabled":true}')")"

# --- (3) Effort present, thinking off renders effort only --------------------

assert_eq "effort only (thinking absent) renders effort" \
    "$MODEL_ONLY $THINK_ICON medium" \
    "$(run_model true "$(payload 'thinking:{"effort":"medium"}')")"

assert_eq "effort only (thinking false) renders effort" \
    "$MODEL_ONLY $THINK_ICON low" \
    "$(run_model true "$(payload 'thinking:{"enabled":false,"effort":"low"}')")"

# --- (4) No thinking/effort fields: output unchanged --------------------------

assert_eq "no thinking fields leaves output unchanged" \
    "$MODEL_ONLY" \
    "$(run_model true "$(payload)")"

assert_eq "null thinking fields leave output unchanged" \
    "$MODEL_ONLY" \
    "$(run_model true "$(payload 'thinking:null' 'effort:null')")"

assert_eq "empty-string effort leaves output unchanged" \
    "$MODEL_ONLY" \
    "$(run_model true "$(payload 'thinking:{"effort":""}')")"

assert_eq "scalar thinking/model shape does not crash and falls back" \
    "$(model_out Unknown)" \
    "$(run_model true '{"model":"a-string","thinking":"a-string"}')"

# --- (5) Feature disabled (unset or false): no thinking segment ---------------

assert_eq "thinking flag unset hides segment even with data" \
    "$MODEL_ONLY" \
    "$(run_model unset "$(payload 'thinking:{"enabled":true,"effort":"xhigh"}')")"

assert_eq "thinking flag false hides segment even with data" \
    "$MODEL_ONLY" \
    "$(run_model false "$(payload 'thinking:{"enabled":true,"effort":"xhigh"}')")"

# --- Claude Code statusline: effort is an object with .level ------------------

assert_eq "thinking.enabled plus effort.level renders On · xhigh" \
    "$MODEL_ONLY $THINK_ICON On · xhigh" \
    "$(run_model true "$(payload 'thinking:{"enabled":true}' 'effort:{"level":"xhigh"}')")"

assert_eq "effort.level alone renders the level" \
    "$MODEL_ONLY $THINK_ICON max" \
    "$(run_model true "$(payload 'effort:{"level":"max"}')")"

# --- Extras: output style still combines, invalid JSON is safe -----------------

assert_eq "output style combines with thinking segment" \
    "$MODEL_ONLY (focus) $THINK_ICON On · high" \
    "$(run_model true "$(payload 'output_style:{"name":"focus"}' 'thinking:{"enabled":true,"effort":"high"}')")"

assert_eq "invalid json with flag on renders Unknown unchanged" \
    "$(model_out Unknown)" \
    "$(run_model true 'not json')"

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
