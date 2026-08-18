#!/bin/bash
# ABOUTME: Installer update path must thread CLI flags into do_update so re-exec
# ABOUTME: keeps --no-emoji / --no-color. prompt_update and interactive_update_check
# ABOUTME: receive "$@" from main; those functions pass "$@" into do_update.
# ABOUTME: Run with: bash tests/test_install_update.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$SCRIPT_DIR/install.sh"
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

# Count exact call-site patterns so empty "$@" in helpers cannot regress.
count_pattern() {
    grep -cF "$1" "$INSTALL"
}

assert_eq "do_update invoked with \"\$@\" at all call sites" "3" "$(count_pattern 'do_update "$@"')"
assert_eq "main calls prompt_update with \"\$@\"" "2" "$(count_pattern 'prompt_update "$@"')"
assert_eq "main calls interactive_update_check with \"\$@\"" "1" "$(count_pattern 'interactive_update_check "$@"')"
assert_eq "do_update re-execs installer with \"\$@\"" "2" "$(count_pattern 'exec "$SCRIPT_DIR/install.sh" "$@"')"

# Bare calls without args would drop --no-emoji / --no-color on re-exec.
if grep -nE '^\s+(prompt_update|interactive_update_check|do_update)\s*$' "$INSTALL"; then
    echo "  FAIL: found update helper invoked with no arguments"
    FAIL=$((FAIL + 1))
else
    echo "  PASS: no bare prompt_update / interactive_update_check / do_update calls"
    PASS=$((PASS + 1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
