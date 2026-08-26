#!/bin/bash
# ABOUTME: Tests that non-numeric cache-TTL config values (from an untrusted
# ABOUTME: .barista.conf) are sanitized before arithmetic. Covers the guards in
# ABOUTME: modules/weather.sh (WEATHER_CACHE_TTL) and modules/rate-limits.sh
# ABOUTME: (RATE_CACHE_TTL), plus the underlying cache_get behaviour when
# ABOUTME: max_age is non-numeric.
# ABOUTME: Run with: bash tests/test_ttl_validation.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

TEST_BASE="$(mktemp -d "${TMPDIR:-/tmp}/barista-ttl-test.XXXXXX")"
trap 'rm -rf "$TEST_BASE"' EXIT
export CLAUDE_CONFIG_DIR="$TEST_BASE/claude"
mkdir -p "$CLAUDE_CONFIG_DIR"

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

# Load utils only after establishing the isolated config root so its cache
# location can never resolve to the user's real ~/.claude directory.
. "$SCRIPT_DIR/modules/utils.sh"

# Sandbox CACHE_DIR
CACHE_DIR="$CLAUDE_CONFIG_DIR/barista-cache"
mkdir -p "$CACHE_DIR"

# -----------------------------------------------------------------------------
# cache_get with a non-numeric max_age must not crash, must not print to
# stderr, and must treat the cache as a MISS: the age comparison would
# otherwise silently fail and return a stale entry no matter how old it is.
# -----------------------------------------------------------------------------
echo "=== cache_get with non-numeric max_age ==="

# Write a fresh cache entry
echo "cached-value" > "$CACHE_DIR/test_ttl_key"

# Non-numeric max_age: no stderr, and a miss (exit 1, empty value)
stderr=$(cache_get "test_ttl_key" "abc" 2>&1 1>/dev/null)
assert_eq "cache_get non-numeric max_age produces no stderr" "" "$stderr"
out=$(cache_get "test_ttl_key" "abc")
assert_eq "cache_get non-numeric max_age treats cache as a miss" "" "$out"

# Negative max_age: same treatment
stderr=$(cache_get "test_ttl_key" "-5" 2>&1 1>/dev/null)
assert_eq "cache_get negative max_age produces no stderr" "" "$stderr"

# Numeric max_age still works: fresh entry returned within max_age
out=$(cache_get "test_ttl_key" 60)
assert_eq "cache_get numeric max_age still returns the value" "cached-value" "$out"

# An old entry with a numeric max_age is a miss (backdate well past any TTL;
# keep the portability fallback used in tests/test_cache.sh)
touch -t 200001010000 "$CACHE_DIR/test_ttl_key" 2>/dev/null || touch -d "2000-01-01" "$CACHE_DIR/test_ttl_key"
out=$(cache_get "test_ttl_key" 60)
assert_eq "cache_get old entry with numeric max_age is a miss" "" "$out"

# -----------------------------------------------------------------------------
# weather.sh: WEATHER_CACHE_TTL is coerced to a safe default when non-numeric.
# We verify by calling module_weather with a bad TTL and a valid location that
# will hit the "no curl / no network" path (cache miss -> curl fails -> empty).
# The key assertion: the module must not emit a bash arithmetic error.
# -----------------------------------------------------------------------------
echo "=== weather.sh WEATHER_CACHE_TTL validation ==="

# Load the weather module
# shellcheck source=/dev/null
. "$SCRIPT_DIR/modules/weather.sh"

# Create a fake cache file so we exercise the mtime comparison path
WEATHER_CACHE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/barista-cache"
mkdir -p "$WEATHER_CACHE_DIR" 2>/dev/null
printf '☀️+72°F' > "$WEATHER_CACHE_DIR/weather"

# Non-numeric TTL should not produce stderr (the case guard resets it to 1800)
stderr=$(WEATHER_CACHE_TTL="abc" WEATHER_LOCATION="" module_weather 2>&1 1>/dev/null)
assert_eq "weather module with non-numeric TTL produces no stderr" "" "$stderr"

# Empty TTL same treatment
stderr=$(WEATHER_CACHE_TTL="" WEATHER_LOCATION="" module_weather 2>&1 1>/dev/null)
assert_eq "weather module with empty TTL produces no stderr" "" "$stderr"

# Valid numeric TTL still works normally (cache hit -> returns weather data)
out=$(WEATHER_CACHE_TTL="99999" WEATHER_LOCATION="" module_weather)
assert_eq "weather module with valid TTL returns cached data" "☀️ 72°F" "$out"

# -----------------------------------------------------------------------------
# rate-limits.sh: RATE_CACHE_TTL is coerced before being passed to cache_get.
# We test that module_rate_limits doesn't crash when RATE_CACHE_TTL is garbage.
# The module will try to call _get_claude_usage which needs credentials; we
# just verify no arithmetic error leaks to stderr.
# -----------------------------------------------------------------------------
echo "=== rate-limits.sh RATE_CACHE_TTL validation ==="

# shellcheck source=/dev/null
. "$SCRIPT_DIR/modules/rate-limits.sh"

# Stub: make _get_claude_usage a no-op so we isolate the TTL path
# (The real function would need an OAuth token; we don't test that here.)
_get_claude_usage() { echo ""; }

# Non-numeric RATE_CACHE_TTL: no stderr, no crash
stderr=$(RATE_CACHE_TTL="not-a-number" module_rate_limits 2>&1 1>/dev/null)
assert_eq "rate-limits with non-numeric TTL produces no stderr" "" "$stderr"

# Negative RATE_CACHE_TTL: no stderr
stderr=$(RATE_CACHE_TTL="-1" module_rate_limits 2>&1 1>/dev/null)
assert_eq "rate-limits with negative TTL produces no stderr" "" "$stderr"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
