#!/bin/bash
# ABOUTME: Tests for modules/update.sh _version_gt -- the semver comparator behind the update
# ABOUTME: prompt (update.sh:76 fires only when remote_version > local_version). It must compare
# ABOUTME: major/minor/patch NUMERICALLY (so 1.10.0 > 1.9.0, not a lexical string compare) with
# ABOUTME: major-then-minor-then-patch precedence, and treat equal versions as NOT greater.
# ABOUTME: Run with: bash tests/test_update.sh

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

# Load the module under test. _version_gt is pure (cut + arithmetic, no I/O).
. "$SCRIPT_DIR/modules/update.sh"

# _version_gt <v1> <v2> -> rc 0 when v1 > v2, rc 1 otherwise.
assert_gt() {
    local desc="$1" v1="$2" v2="$3" expected_rc="$4"
    _version_gt "$v1" "$v2"
    assert_eq "$desc" "$expected_rc" "$?"
}

# Major precedence
assert_gt "major: 2.0.0 > 1.9.9"                 "2.0.0"  "1.9.9"  "0"
assert_gt "major: 1.0.0 is not > 2.0.0"          "1.0.0"  "2.0.0"  "1"
# Minor compared NUMERICALLY (a string compare would rank 1.10.0 below 1.9.0 and fail these)
assert_gt "minor numeric: 1.10.0 > 1.9.0"        "1.10.0" "1.9.0"  "0"
assert_gt "minor numeric: 1.9.0 is not > 1.10.0" "1.9.0"  "1.10.0" "1"
# Patch precedence, also numeric
assert_gt "patch: 1.7.1 > 1.7.0"                 "1.7.1"  "1.7.0"  "0"
assert_gt "patch numeric: 1.0.10 > 1.0.9"        "1.0.10" "1.0.9"  "0"
assert_gt "patch: 1.7.0 is not > 1.7.1"          "1.7.0"  "1.7.1"  "1"
# Equal versions are NOT greater (so the update prompt does not fire on an equal remote)
assert_gt "equal is not greater: 1.7.0 vs 1.7.0" "1.7.0"  "1.7.0"  "1"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
