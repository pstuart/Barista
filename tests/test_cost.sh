# =============================================================================
# Cost Module Regression Tests
# =============================================================================
# Standalone test for modules/cost.sh JSON extraction and output.
# Usage: bash tests/test_cost.sh
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
source "$PROJECT_ROOT/modules/cost.sh"

# Run module_cost with cost/cost-related config pinned to defaults.
run_cost() {
    (
        USE_ICONS="true"
        DISPLAY_MODE="normal"
        COST_SHOW_BURN_RATE="true"
        COST_SHOW_TPM="true"
        COST_DECIMAL_PLACES="2"
        COST_MINIMUM_DISPLAY="0.01"
        module_cost "$1"
    )
}

# --- Full status: cost + burn rate + TPM -------------------------------------

FULL='{"cost":{"total_cost_usd":0.5234,"total_duration_ms":12345},"context_window":{"total_input_tokens":150000,"total_output_tokens":25000}}'
assert_eq "full input renders cost, burn rate, tpm" \
    "$(get_icon "💰" "COST:") \$0.52 @\$152.63/h $(get_icon "⚡" "TPM:")850ktpm" \
    "$(run_cost "$FULL")"

# --- No cost data: empty string ---------------------------------------------

assert_eq "empty input yields empty result" "" "$(run_cost '')"

# --- No cost data: valid JSON with no cost fields -----------------------------

assert_eq "no cost fields yields empty result" "" \
    "$(run_cost '{"context_window":{"current_usage":{"input_tokens":5}}}')"

# --- Null cost values default to zero ----------------------------------------

assert_eq "null cost values yield empty result" "" \
    "$(run_cost '{"cost":{"total_cost_usd":null,"total_duration_ms":null}}')"

# --- Invalid JSON yields empty result ----------------------------------------

assert_eq "invalid json yields empty result" "" "$(run_cost 'not json')"

# --- Cost below minimum display threshold is hidden ---------------------------

assert_eq "cost below min display hidden" "" \
    "$(run_cost '{"cost":{"total_cost_usd":0.001,"total_duration_ms":100}}')"

# --- Cost without duration: no burn rate, no TPM ------------------------------

assert_eq "cost without duration shows cost only" \
    "$(get_icon "💰" "COST:") \$0.42" \
    "$(run_cost '{"cost":{"total_cost_usd":0.42,"total_duration_ms":0}}')"

# --- Non-numeric cost token values are coerced to zero -------------------------

assert_eq "string cost passes through, bad tokens forced to 0" \
    "$(get_icon "💰" "COST:") \$1.50" \
    "$(run_cost '{"cost":{"total_cost_usd":"1.5"},"context_window":{"total_input_tokens":"abc","total_output_tokens":1e3}}')"

# --- Decimal cost preserves precision through the minimum-display gate --------

assert_eq "decimal cost compared as decimal (0.5 passes 0.01 gate)" \
    "$(get_icon "💰" "COST:") \$0.50" \
    "$(run_cost '{"cost":{"total_cost_usd":0.5}}')"

# --- Negative duration: no burn rate, no TPM ---------------------------------
# A negative total_duration_ms is meaningless (elapsed time can't be negative);
# it must not produce a negative burn rate ($/h) or negative TPM.

assert_eq "negative duration suppresses burn rate and tpm" \
    "$(get_icon "💰" "COST:") \$0.42" \
    "$(run_cost '{"cost":{"total_cost_usd":0.42,"total_duration_ms":-500},"context_window":{"total_input_tokens":100,"total_output_tokens":50}}')"

# --- Negative duration with no cost: empty result -----------------------------

assert_eq "negative duration and zero cost yields empty result" \
    "" \
    "$(run_cost '{"cost":{"total_cost_usd":0,"total_duration_ms":-500},"context_window":{"total_input_tokens":100,"total_output_tokens":50}}')"

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
