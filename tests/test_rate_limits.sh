#!/bin/bash
# ABOUTME: Tests for _parse_reset_epoch in modules/rate-limits.sh -- the resets_at
# ABOUTME: ISO-8601 -> epoch parser added in #38 so time-remaining works on Linux/
# ABOUTME: Windows (GNU date) as well as macOS (BSD date).
# ABOUTME: Run with: bash tests/test_rate_limits.sh

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

# Load the module under test (_parse_reset_epoch only uses `date`, no other deps).
. "$SCRIPT_DIR/modules/rate-limits.sh"

# -----------------------------------------------------------------------------
# _parse_reset_epoch <iso-8601-utc-timestamp>
# Converts a UTC ISO-8601 timestamp (fractional seconds already stripped by the
# caller via ${reset%%.*}) to epoch seconds. It must work on BOTH BSD `date -j -f`
# (macOS) and GNU `date -d` (Linux / Git Bash on Windows) -- #38 added the GNU
# fallback so time-remaining stopped vanishing off macOS -- and emit 0 when the
# timestamp is unparseable. The expected epochs are UTC and identical on both date
# variants. (The caller guards empty input with `[ -n ... ]`; the empty-string case,
# which GNU `date -d ""` resolves to midnight-today rather than 0, is unreachable
# and intentionally not asserted here.)
# -----------------------------------------------------------------------------
echo "=== _parse_reset_epoch Tests ==="
assert_eq "parses a UTC midnight timestamp to epoch"   "1767225600" "$(_parse_reset_epoch '2026-01-01T00:00:00')"
assert_eq "parses a different year (not hardcoded)"    "1735689600" "$(_parse_reset_epoch '2025-01-01T00:00:00')"
assert_eq "parses the time-of-day, not just the date"  "1767270600" "$(_parse_reset_epoch '2026-01-01T12:30:00')"
assert_eq "unparseable input falls back to 0"          "0"          "$(_parse_reset_epoch 'not-a-date')"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
