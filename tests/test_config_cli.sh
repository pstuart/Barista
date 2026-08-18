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

# --set must not accept process-critical names or injectable values
rc=0
"$BARISTA" config --set PATH=/tmp/evil >/dev/null 2>&1 || rc=$?
assert_eq "set rejects PATH" "2" "$rc"

rc=0
"$BARISTA" config --set COLOR_THEME='default" && echo PWNED #' >/dev/null 2>&1 || rc=$?
assert_eq "set rejects quote/amp value" "2" "$rc"
if grep -q 'PWNED' "$CLAUDE_CONFIG_DIR/barista.conf" 2>/dev/null; then
    echo "  FAIL: injected payload written to config"
    FAIL=$((FAIL + 1))
else
    echo "  PASS: injected payload not written"
    PASS=$((PASS + 1))
fi

# Preserve unmanaged keys + custom MODULE_ORDER on --set
printf '%s\n' \
    'RATE_SHOW_PROGRESS_BAR="true"' \
    'MODULE_GIT="true"' \
    'MODULE_DIRECTORY="true"' \
    'MODULE_ORDER="git,directory"' \
    > "$CLAUDE_CONFIG_DIR/barista.conf"
"$BARISTA" config --set COLOR_THEME=minimal >/dev/null 2>&1
assert_file_contains "set preserves RATE_*" 'RATE_SHOW_PROGRESS_BAR="true"' "$CLAUDE_CONFIG_DIR/barista.conf"
assert_file_contains "set preserves custom MODULE_ORDER" 'MODULE_ORDER="git,directory"' "$CLAUDE_CONFIG_DIR/barista.conf"
assert_file_contains "set still writes theme" 'COLOR_THEME="minimal"' "$CLAUDE_CONFIG_DIR/barista.conf"

# --toggle appends/removes one name; does not rebuild catalog order
"$BARISTA" config --toggle weather >/dev/null 2>&1
assert_file_contains "toggle appends module to order" 'MODULE_ORDER="git,directory,weather"' "$CLAUDE_CONFIG_DIR/barista.conf"
assert_file_contains "toggle still preserves RATE_*" 'RATE_SHOW_PROGRESS_BAR="true"' "$CLAUDE_CONFIG_DIR/barista.conf"

# Project .barista.conf must not be sourced (644 is typical for a cloned repo)
PROJ_PWN="$PROJ"
printf '%s\n' 'touch "$CLAUDE_CONFIG_DIR/pwned"' 'MODULE_CPU="true"' > "$PROJ_PWN/.barista.conf"
chmod 644 "$PROJ_PWN/.barista.conf"
(
  cd "$PROJ_PWN" || exit 1
  "$BARISTA" config --project --show >/dev/null 2>&1
)
if [ -e "$CLAUDE_CONFIG_DIR/pwned" ]; then
    echo "  FAIL: project .barista.conf was sourced (pwned marker exists)"
    FAIL=$((FAIL + 1))
else
    echo "  PASS: project .barista.conf is not sourced"
    PASS=$((PASS + 1))
fi
# Safe parser should still honor KEY=VALUE
show_proj=$(cd "$PROJ_PWN" && "$BARISTA" config --project --show 2>&1)
assert_contains "project --show still works" "Modules:" "$show_proj"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
