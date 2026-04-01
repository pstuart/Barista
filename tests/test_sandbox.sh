#!/bin/bash
# ABOUTME: Tests for the sandbox module - verifies lock icon display based on APP_SANDBOX_CONTAINER_ID
# ABOUTME: Run with: bash tests/test_sandbox.sh

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

assert_empty() {
    local desc="$1" actual="$2"
    if [ -z "$actual" ]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        echo "    expected empty, got: '$actual'"
        FAIL=$((FAIL + 1))
    fi
}

# Load utils and sandbox module
. "$SCRIPT_DIR/modules/utils.sh"
. "$SCRIPT_DIR/modules/sandbox.sh"

echo "=== Sandbox Module Tests ==="

# Test 1: No output when APP_SANDBOX_CONTAINER_ID is not set
echo "Test: no output when not in sandbox"
unset APP_SANDBOX_CONTAINER_ID
USE_ICONS="true"
result=$(module_sandbox)
assert_empty "no output when APP_SANDBOX_CONTAINER_ID is unset" "$result"

# Test 2: Shows lock icon when APP_SANDBOX_CONTAINER_ID is set
echo "Test: shows lock icon when in sandbox"
APP_SANDBOX_CONTAINER_ID="com.apple.security.sandbox.test"
USE_ICONS="true"
SANDBOX_ICON="🔒"
result=$(module_sandbox)
assert_eq "shows lock icon when sandboxed" "🔒" "$result"

# Test 3: Respects custom icon
echo "Test: respects custom SANDBOX_ICON"
APP_SANDBOX_CONTAINER_ID="something"
SANDBOX_ICON="🔐"
USE_ICONS="true"
result=$(module_sandbox)
assert_eq "uses custom icon" "🔐" "$result"

# Test 4: Works with icons disabled
echo "Test: works with icons disabled"
APP_SANDBOX_CONTAINER_ID="something"
USE_ICONS="false"
SANDBOX_ICON="🔒"
result=$(module_sandbox)
assert_eq "shows fallback text when icons disabled" "SANDBOX" "$result"

unset APP_SANDBOX_CONTAINER_ID

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
