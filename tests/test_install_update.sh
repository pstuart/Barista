#!/bin/bash
# ABOUTME: Behavioral tests for installer update flag forwarding, parse_args,
# ABOUTME: version_lt, and Homebrew-prefix refusal. Grep counts are not enough.
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

# Load installer functions without running main.
# shellcheck source=../install.sh
. "$INSTALL"

assert_rc() {
    local desc="$1" expected="$2"
    shift 2
    "$@"
    assert_eq "$desc" "$expected" "$?"
}

# --- parse_args ---
USE_EMOJI="true"
USE_COLOR="true"
INSTALL_MODE="interactive"
SKIP_UPDATE_CHECK="false"
parse_args --update --no-emoji --no-color --skip-update-check
assert_eq "parse_args INSTALL_MODE=update" "update" "$INSTALL_MODE"
assert_eq "parse_args USE_EMOJI=false" "false" "$USE_EMOJI"
assert_eq "parse_args USE_COLOR=false" "false" "$USE_COLOR"
assert_eq "parse_args SKIP_UPDATE_CHECK=true" "true" "$SKIP_UPDATE_CHECK"

INSTALL_MODE="interactive"
parse_args --check-update
assert_eq "parse_args --check-update" "check-update" "$INSTALL_MODE"

# --- version_lt (numeric + prerelease sanitizing) ---
assert_rc "version_lt 1.9.0 < 1.10.0" 0 version_lt "1.9.0" "1.10.0"
assert_rc "version_lt 1.10.0 not < 1.9.0" 1 version_lt "1.10.0" "1.9.0"
assert_rc "version_lt equal is not less" 1 version_lt "1.8.0" "1.8.0"
assert_rc "version_lt 1.7.9 < 1.8.0-rc1 (numeric)" 0 version_lt "1.7.9" "1.8.0-rc1"
assert_rc "version_lt 1.8.0-rc1 not < 1.8.0" 1 version_lt "1.8.0-rc1" "1.8.0"
assert_rc "version_lt 2.0.0 not < 1.9.9" 1 version_lt "2.0.0" "1.9.9"
assert_rc "version_lt 1.0.9 < 1.0.10" 0 version_lt "1.0.9" "1.0.10"

# --- brew prefix detection ---
assert_rc "Cellar path is Homebrew" 0 _is_homebrew_prefix "/opt/homebrew/Cellar/barista/1.8.0/libexec"
assert_rc "opt/barista is Homebrew" 0 _is_homebrew_prefix "/opt/homebrew/opt/barista"
assert_rc "opt/barista/libexec is Homebrew" 0 _is_homebrew_prefix "/usr/local/opt/barista/libexec"
assert_rc "git clone is not Homebrew" 1 _is_homebrew_prefix "/Users/me/src/Barista"

# --- do_update refuses Homebrew and does not re-exec ---
REEXEC_LOG=""
_reexec_installer() {
    REEXEC_LOG="called:$*"
}

USE_COLOR="false"
setup_colors
SCRIPT_DIR="/opt/homebrew/opt/barista/libexec"
REMOTE_VERSION="1.9.0"
assert_rc "do_update refuses Homebrew prefix" 1 do_update --update --no-emoji
assert_eq "do_update brew path does not re-exec" "" "$REEXEC_LOG"

# --- do_update git path forwards original argv through _reexec_installer ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAKE_ROOT=$(mktemp -d)
mkdir -p "$FAKE_ROOT/.git"
SCRIPT_DIR="$FAKE_ROOT"
REMOTE_VERSION="9.9.9"
REEXEC_ARGS=""
_reexec_installer() {
    REEXEC_ARGS=$(printf '%s\n' "$@")
}
_barista_git() {
    return 0
}
do_update --update --no-emoji --no-color
assert_eq "do_update re-exec first arg --update" "--update" "$(printf '%s\n' "$REEXEC_ARGS" | sed -n '1p')"
assert_eq "do_update re-exec keeps --no-emoji" "--no-emoji" "$(printf '%s\n' "$REEXEC_ARGS" | sed -n '2p')"
assert_eq "do_update re-exec keeps --no-color" "--no-color" "$(printf '%s\n' "$REEXEC_ARGS" | sed -n '3p')"

# Dropping "$@" at the do_update call site must fail this test.
REEXEC_ARGS=""
do_update
assert_eq "bare do_update re-exec has empty argv" "" "$REEXEC_ARGS"

rm -f "$FAKE_ROOT/.git" 2>/dev/null
rmdir "$FAKE_ROOT/.git" 2>/dev/null
rmdir "$FAKE_ROOT" 2>/dev/null

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
