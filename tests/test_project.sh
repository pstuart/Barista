#!/bin/bash
# ABOUTME: Tests for modules/project.sh _get_project_icon and _format_project -- the two pure
# ABOUTME: helpers behind the project module. _get_project_icon maps a detected project type to
# ABOUTME: its icon, letting a per-type PROJECT_ICON_<TYPE> env var override the built-in default
# ABOUTME: (and falling back to the default for unknown types). _format_project renders "icon name"
# ABOUTME: per PROJECT_STYLE (icon/text/both), with USE_ICONS=false short-circuiting to name-only.
# ABOUTME: Run with: bash tests/test_project.sh

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

# Load the module under test. _get_project_icon and _format_project are pure (case + echo, no I/O).
# ASCII sentinels (DEF/OVR/ICON/NAME) keep assertions byte-clean instead of hinging on emoji bytes.
. "$SCRIPT_DIR/modules/project.sh"

# --- _get_project_icon <type> <default> ---------------------------------------
# A known type with no override echoes the caller's default icon.
assert_eq "known type, no override -> default" "DEF" "$(_get_project_icon nuxt DEF)"
# A per-type override wins over the default -- this override is the whole point of the helper.
assert_eq "override wins over default"         "OVR" "$(PROJECT_ICON_NUXT=OVR _get_project_icon nuxt DEF)"
# Each type reads its OWN env var (not one shared var): swift honors PROJECT_ICON_SWIFT.
assert_eq "swift reads PROJECT_ICON_SWIFT"     "S"   "$(PROJECT_ICON_SWIFT=S _get_project_icon swift DEF)"
# The last case in the ladder (bun) still resolves -- proves the whole case reaches the end.
assert_eq "bun (last case) -> default"         "DEF" "$(_get_project_icon bun DEF)"
# An unrecognized type falls through the '*' branch to the default.
assert_eq "unknown type -> default"            "DEF" "$(_get_project_icon cobol DEF)"
# The override is type-scoped: setting nuxt's icon must NOT bleed into a go lookup.
assert_eq "override does not leak across types" "DEF" "$(PROJECT_ICON_NUXT=OVR _get_project_icon go DEF)"

# --- _format_project <icon> <name> --------------------------------------------
# Default style (no PROJECT_STYLE) is "both": "icon name".
assert_eq "default style -> both"       "ICON NAME" "$(_format_project ICON NAME)"
assert_eq "style=both -> icon name"     "ICON NAME" "$(PROJECT_STYLE=both _format_project ICON NAME)"
assert_eq "style=icon -> icon only"     "ICON"      "$(PROJECT_STYLE=icon _format_project ICON NAME)"
assert_eq "style=text -> name only"     "NAME"      "$(PROJECT_STYLE=text _format_project ICON NAME)"
# An unknown style falls through '*' to both -- pins that garbage renders "icon name", not empty.
assert_eq "unknown style falls to both" "ICON NAME" "$(PROJECT_STYLE=bogus _format_project ICON NAME)"
# USE_ICONS=false short-circuits to name-only BEFORE the style case -- it wins even over style=icon.
assert_eq "USE_ICONS=false beats style=icon" "NAME" "$(USE_ICONS=false PROJECT_STYLE=icon _format_project ICON NAME)"
assert_eq "USE_ICONS=false, default style"   "NAME" "$(USE_ICONS=false _format_project ICON NAME)"

# --- dev-server pgrep pattern -------------------------------------------------
# module_project uses pgrep -f with an unescaped-pipe ERE pattern to detect
# running dev servers (npm/yarn/pnpm/bun run dev).  The pre-fix version had
# the pipes escaped (\|), which ERE pgrep treats as a literal `|`, so
# the alternation never matched and the 🚀 indicator was silently invisible
# on macOS.  These tests verify the corrected pattern matches and the old
# broken one does not.
#
# We spawn a real long-running process with a distinctive argv so pgrep -f
# can find it.  Cleanup is guaranteed via a subshell so a failing assert
# cannot leak the process.
(
  bash -c 'exec -a "yarn dev testproject" sleep 60' &
  _DEV_PID=$!
  sleep 0.4

  # Corrected pattern (unescaped pipes): must match the fake yarn dev process.
  pgrep -f "npm.*dev|yarn.*dev|pnpm.*dev|bun.*dev" >/dev/null 2>&1 \
    && echo "fixed_pattern_match" || echo "fixed_pattern_nomatch"

  # Legacy pattern (escaped pipes): must NOT match on this platform,
  # documenting that the bug was real and the fix was necessary.
  pgrep -f "npm.*dev\|yarn.*dev\|pnpm.*dev\|bun.*dev" >/dev/null 2>&1 \
    && echo "legacy_pattern_match" || echo "legacy_pattern_nomatch"

  kill "$_DEV_PID" 2>/dev/null
  wait "$_DEV_PID" 2>/dev/null
) > /tmp/_devpgrep_check.$$

_fixed=$(sed -n '1p' /tmp/_devpgrep_check.$$ 2>/dev/null)
_legacy=$(sed -n '2p' /tmp/_devpgrep_check.$$ 2>/dev/null)
rm -f /tmp/_devpgrep_check.$$

assert_eq "corrected dev-server pattern matches running process" "fixed_pattern_match"  "${_fixed:-}"
assert_eq "legacy escaped-pipe pattern does not match"           "legacy_pattern_nomatch" "${_legacy:-}"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
