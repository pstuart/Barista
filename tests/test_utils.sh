#!/bin/bash
# ABOUTME: Tests for the shared utils.sh status/percentage/progress-bar helpers used across modules
# ABOUTME: Run with: bash tests/test_utils.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        echo "    expected: '$expected'"
        echo "    actual:   '$actual'"
        FAIL=$((FAIL + 1))
    fi
}

# Load utils (the functions under test)
. "$SCRIPT_DIR/modules/utils.sh"

# -----------------------------------------------------------------------------
# get_status <value> <warning> <critical>
# 3-level threshold: value >= critical -> red, value >= warning -> yellow, else green.
# Uses >= at BOTH boundaries; prefixes a space unless DISPLAY_MODE=compact.
# -----------------------------------------------------------------------------
echo "=== get_status Tests ==="
# Isolate from any theme/global state so the :- defaults apply deterministically.
unset STATUS_GREEN STATUS_YELLOW STATUS_RED STATUS_ORANGE
USE_STATUS_INDICATORS="true"
DISPLAY_MODE="compact"      # prefix = "" so the output is exactly the indicator
STATUS_STYLE="ascii"        # [OK] / [WARN] / [CRIT] — deterministic, no emoji bytes

assert_eq "below warning is green"              "[OK]"   "$(get_status 50 60 80)"
assert_eq "exactly at warning is yellow (>=)"   "[WARN]" "$(get_status 60 60 80)"
assert_eq "between warning and critical is yellow" "[WARN]" "$(get_status 70 60 80)"
assert_eq "exactly at critical is red (>=)"     "[CRIT]" "$(get_status 80 60 80)"
assert_eq "above critical is red"               "[CRIT]" "$(get_status 85 60 80)"

# Default thresholds when omitted are warning=60, critical=80.
assert_eq "default thresholds: 50 -> green"  "[OK]"   "$(get_status 50)"
assert_eq "default thresholds: 65 -> yellow" "[WARN]" "$(get_status 65)"
assert_eq "default thresholds: 90 -> red"    "[CRIT]" "$(get_status 90)"

# Non-compact display modes prefix a single space before the indicator.
DISPLAY_MODE="normal"
assert_eq "normal mode prefixes a space" " [OK]" "$(get_status 50 60 80)"
DISPLAY_MODE="compact"

# Emoji is the default style; a mid-range value selects the yellow indicator.
STATUS_STYLE="emoji"
assert_eq "emoji style yields the yellow dot" "🟡" "$(get_status 70 60 80)"
STATUS_STYLE="ascii"

# Indicators can be disabled entirely.
USE_STATUS_INDICATORS="false"
assert_eq "disabled indicators yield empty string" "" "$(get_status 90 60 80)"
USE_STATUS_INDICATORS="true"

# -----------------------------------------------------------------------------
# safe_percent <value> <total> [default]
# value*100/total (integer), guarding divide-by-zero with the default.
# -----------------------------------------------------------------------------
echo "=== safe_percent Tests ==="
assert_eq "50 of 100 is 50"                      "50"  "$(safe_percent 50 100)"
assert_eq "divide-by-zero returns the default"   "99"  "$(safe_percent 10 0 99)"
assert_eq "integer division truncates (1/3)"     "33"  "$(safe_percent 1 3)"
assert_eq "non-numeric value coerces to 0"       "0"   "$(safe_percent abc 100)"
assert_eq "does not clamp above 100"             "200" "$(safe_percent 200 100)"

# -----------------------------------------------------------------------------
# progress_bar <percent> <width> [filled_char] [empty_char]
# filled = percent*width/100; clamps percent to [0,100]; width<=0 falls back to 8.
# (ASCII fill chars keep the assertions free of multi-byte glyph width issues.)
# -----------------------------------------------------------------------------
echo "=== progress_bar Tests ==="
assert_eq "0 percent is all empty"          "--------" "$(progress_bar 0 8 '#' '-')"
assert_eq "50 percent is half filled"       "####----" "$(progress_bar 50 8 '#' '-')"
assert_eq "100 percent is all filled"       "########" "$(progress_bar 100 8 '#' '-')"
assert_eq "over 100 clamps to full"         "########" "$(progress_bar 125 8 '#' '-')"
assert_eq "negative clamps to empty"        "--------" "$(progress_bar -5 8 '#' '-')"
assert_eq "width <= 0 falls back to 8"      "####----" "$(progress_bar 50 0 '#' '-')"
assert_eq "fill count truncates (33%->2)"   "##------" "$(progress_bar 33 8 '#' '-')"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
