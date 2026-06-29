#!/bin/bash
# ABOUTME: Tests for modules/uptime.sh format_uptime -- the pure seconds->string formatter behind
# ABOUTME: the uptime module. It cascades days->hours->mins and renders each style distinctly:
# ABOUTME: short shows the two coarsest non-zero units ("1d 1h" / "1h 1m" / "1m") and drops finer
# ABOUTME: units, long spells them out, and days collapses to "Nd" (or "Nh" when under a day).
# ABOUTME: Run with: bash tests/test_uptime.sh

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

# Load the module under test. format_uptime is pure (integer arithmetic + echo, no I/O).
. "$SCRIPT_DIR/modules/uptime.sh"

# 90061s = 1d 1h 1m 1s ; 3661s = 1h 1m 1s ; 61s = 1m 1s
# short (default): the two coarsest non-zero units, finer units dropped
assert_eq "short: 1d1h1m -> 1d 1h"      "1d 1h" "$(format_uptime 90061 short)"
assert_eq "short is the default style"  "1d 1h" "$(format_uptime 90061)"
assert_eq "short: 1h1m -> 1h 1m"        "1h 1m" "$(format_uptime 3661 short)"
assert_eq "short: under an hour -> 1m"  "1m"    "$(format_uptime 61 short)"

# long: units spelled out
assert_eq "long: days + hours"          "1 days, 1 hours" "$(format_uptime 90061 long)"
assert_eq "long: hours + mins"          "1 hours, 1 mins" "$(format_uptime 3661 long)"
assert_eq "long: mins only"             "1 mins"          "$(format_uptime 61 long)"

# days: collapses to whole days, or hours when under a day
assert_eq "days: >=1 day -> Nd"         "1d" "$(format_uptime 90061 days)"
assert_eq "days: <1 day falls to Nh"    "1h" "$(format_uptime 3661 days)"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
