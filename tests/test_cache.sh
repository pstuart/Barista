#!/bin/bash
# ABOUTME: Tests for the file-cache helpers (init_cache/cache_set/cache_get/cache_clear) in modules/utils.sh
# ABOUTME: Run with: bash tests/test_cache.sh

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

# shellcheck source=/dev/null
. "$SCRIPT_DIR/modules/utils.sh"

# Sandbox: override CACHE_DIR so the suite never touches the real ~/.claude/barista-cache.
TEST_BASE="$(mktemp -d "${TMPDIR:-/tmp}/barista-cache-test.XXXXXX")"
CACHE_DIR="$TEST_BASE/cache"

# init_cache creates an owner-only directory -- cache keys (weather, wan_ip, update_check…)
# must not leak config state to other local users under a permissive umask.
init_cache
assert_eq "init_cache creates the cache dir"           "1"          "$([ -d "$CACHE_DIR" ] && echo 1 || echo 0)"
assert_eq "init_cache restricts the dir to the owner"  "drwx------" "$(ls -ld "$CACHE_DIR" | cut -c1-10)"

# cache_set / cache_get round-trip a value
cache_set "weather" "sunny"
assert_eq "cache_set/cache_get round-trips a value"    "sunny"      "$(cache_get weather)"
assert_eq "a fresh entry is returned within max_age"   "sunny"      "$(cache_get weather 60)"

# an entry older than max_age is a miss (backdate the file well past any TTL)
cache_set "wan_ip" "1.2.3.4"
touch -t 200001010000 "$CACHE_DIR/wan_ip"
assert_eq "an expired entry reads as empty"            ""           "$(cache_get wan_ip 60)"
cache_get wan_ip 60 >/dev/null 2>&1
assert_eq "an expired entry returns non-zero"          "1"          "$?"

# a missing key is a miss
assert_eq "a missing key reads as empty"               ""           "$(cache_get nope)"
cache_get nope >/dev/null 2>&1
assert_eq "a missing key returns non-zero"             "1"          "$?"

# path-traversal keys are rejected -- and must write nothing outside the cache dir
cache_set "../escape" "pwned"
assert_eq "cache_set rejects a traversal key"          "1"          "$?"
assert_eq "cache_set writes no file outside the cache" "1"          "$([ ! -e "$CACHE_DIR/../escape" ] && echo 1 || echo 0)"
cache_get "../escape" >/dev/null 2>&1
assert_eq "cache_get rejects a '..' key"               "1"          "$?"
cache_get "sub/key" >/dev/null 2>&1
assert_eq "cache_get rejects a '/' key"                "1"          "$?"

# cache_clear removes a single named key
cache_set "update_check" "v1"
cache_clear "update_check"
assert_eq "cache_clear removes the named key"          ""           "$(cache_get update_check 999)"

# cache_clear refuses to operate on an empty CACHE_DIR (never rm an unset path)
( CACHE_DIR=""; cache_clear )
assert_eq "cache_clear refuses an empty CACHE_DIR"     "1"          "$?"

rm -rf "$TEST_BASE"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
