#!/bin/bash
# ABOUTME: Tests for barista.sh config subcommand (CLI path, show, set, toggle, write)
# ABOUTME: Run with: bash tests/test_config_cli.sh

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

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    case "$haystack" in
        *"$needle"*) echo "  PASS: $desc"; PASS=$((PASS + 1)) ;;
        *) echo "  FAIL: $desc (missing '$needle')"; echo "    in: $haystack"; FAIL=$((FAIL + 1)) ;;
    esac
}

assert_file_contains() {
    local desc="$1" needle="$2" file="$3"
    if grep -qF "$needle" "$file" 2>/dev/null; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (missing '$needle' in $file)"
        FAIL=$((FAIL + 1))
    fi
}

TMPHOME=$(mktemp -d "${TMPDIR:-/tmp}/barista-cfg-test.XXXXXX")
export CLAUDE_CONFIG_DIR="$TMPHOME/claude"
mkdir -p "$CLAUDE_CONFIG_DIR"
trap 'rm -rf "$TMPHOME"' EXIT

BARISTA="$SCRIPT_DIR/barista.sh"

echo "=== config CLI tests ==="

ver=$("$BARISTA" version 2>/dev/null | tr -d '[:space:]')
assert_eq "version prints VERSION file" "1.8.0" "$ver"

help_out=$("$BARISTA" help 2>&1)
assert_contains "help mentions config" "config" "$help_out"

path_out=$("$BARISTA" config --path 2>&1)
assert_eq "config --path uses CLAUDE_CONFIG_DIR" "$CLAUDE_CONFIG_DIR/barista.conf" "$path_out"

show_out=$("$BARISTA" config --show 2>&1)
assert_contains "show lists modules" "Modules:" "$show_out"
assert_contains "show default git on" "[on ] git" "$show_out" || assert_contains "show git line" "git" "$show_out"

# set + write
"$BARISTA" config --set COLOR_THEME=minimal >/dev/null 2>&1
assert_file_contains "set writes COLOR_THEME" 'COLOR_THEME="minimal"' "$CLAUDE_CONFIG_DIR/barista.conf"

"$BARISTA" config --toggle weather >/dev/null 2>&1
assert_file_contains "toggle weather on" 'MODULE_WEATHER="true"' "$CLAUDE_CONFIG_DIR/barista.conf"

"$BARISTA" config --toggle weather >/dev/null 2>&1
assert_file_contains "toggle weather off" 'MODULE_WEATHER="false"' "$CLAUDE_CONFIG_DIR/barista.conf"

# project scope
PROJ="$TMPHOME/proj"
mkdir -p "$PROJ"
(
  cd "$PROJ" || exit 1
  "$BARISTA" config --project --set MODULE_CPU=true >/dev/null 2>&1
)
assert_file_contains "project conf written" 'MODULE_CPU="true"' "$PROJ/.barista.conf"

# statusline path still works with empty-ish JSON (no args)
json='{"cwd":"/tmp","model":{"display_name":"Test"},"context_window":{"used_percentage":10}}'
# Must not treat missing args as config
out=$(echo "$json" | "$BARISTA" 2>/dev/null | head -c 200)
# Just ensure it produced some output or empty without error
rc=0
echo "$json" | "$BARISTA" >/dev/null 2>&1 || rc=$?
assert_eq "statusline main still exits 0" "0" "$rc"

# unknown module
rc=0
"$BARISTA" config --toggle not-a-module >/dev/null 2>&1 || rc=$?
assert_eq "unknown module fails" "2" "$rc"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
