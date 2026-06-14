#!/bin/bash
# ABOUTME: Tests for the shared utils.sh helpers (status, percentage, progress bar, number/time
# ABOUTME: formatting, safe int/divide, string truncation, icon + display-mode checks) used across modules
# ABOUTME: Run with: bash tests/test_utils.sh

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

# Load utils (the functions under test)
. "$SCRIPT_DIR/modules/utils.sh"

# -----------------------------------------------------------------------------
# get_status <value> <warning> <critical>
# 3-level threshold: value >= critical -> red, value >= warning -> yellow, else green.
# Uses >= at BOTH boundaries; prefixes a space unless DISPLAY_MODE=compact.
# -----------------------------------------------------------------------------
echo "=== get_status Tests ==="
# Isolate from any theme/global state so the :- defaults apply deterministically.
unset STATUS_GREEN STATUS_YELLOW STATUS_RED STATUS_ORANGE
USE_STATUS_INDICATORS="true"
DISPLAY_MODE="compact"      # prefix = "" so the output is exactly the indicator
STATUS_STYLE="ascii"        # [OK] / [WARN] / [CRIT] — deterministic, no emoji bytes

assert_eq "below warning is green"              "[OK]"   "$(get_status 50 60 80)"
assert_eq "exactly at warning is yellow (>=)"   "[WARN]" "$(get_status 60 60 80)"
assert_eq "between warning and critical is yellow" "[WARN]" "$(get_status 70 60 80)"
assert_eq "exactly at critical is red (>=)"     "[CRIT]" "$(get_status 80 60 80)"
assert_eq "above critical is red"               "[CRIT]" "$(get_status 85 60 80)"

# Default thresholds when omitted are warning=60, critical=80.
assert_eq "default thresholds: 50 -> green"  "[OK]"   "$(get_status 50)"
assert_eq "default thresholds: 65 -> yellow" "[WARN]" "$(get_status 65)"
assert_eq "default thresholds: 90 -> red"    "[CRIT]" "$(get_status 90)"

# Non-compact display modes prefix a single space before the indicator.
DISPLAY_MODE="normal"
assert_eq "normal mode prefixes a space" " [OK]" "$(get_status 50 60 80)"
DISPLAY_MODE="compact"

# Emoji is the default style; a mid-range value selects the yellow indicator.
STATUS_STYLE="emoji"
assert_eq "emoji style yields the yellow dot" "🟡" "$(get_status 70 60 80)"
STATUS_STYLE="ascii"

# Indicators can be disabled entirely.
USE_STATUS_INDICATORS="false"
assert_eq "disabled indicators yield empty string" "" "$(get_status 90 60 80)"
USE_STATUS_INDICATORS="true"

# -----------------------------------------------------------------------------
# safe_percent <value> <total> [default]
# value*100/total (integer), guarding divide-by-zero with the default.
# -----------------------------------------------------------------------------
echo "=== safe_percent Tests ==="
assert_eq "50 of 100 is 50"                      "50"  "$(safe_percent 50 100)"
assert_eq "divide-by-zero returns the default"   "99"  "$(safe_percent 10 0 99)"
assert_eq "integer division truncates (1/3)"     "33"  "$(safe_percent 1 3)"
assert_eq "non-numeric value coerces to 0"       "0"   "$(safe_percent abc 100)"
assert_eq "does not clamp above 100"             "200" "$(safe_percent 200 100)"

# -----------------------------------------------------------------------------
# progress_bar <percent> <width> [filled_char] [empty_char]
# filled = percent*width/100; clamps percent to [0,100]; width<=0 falls back to 8.
# (ASCII fill chars keep the assertions free of multi-byte glyph width issues.)
# -----------------------------------------------------------------------------
echo "=== progress_bar Tests ==="
assert_eq "0 percent is all empty"          "--------" "$(progress_bar 0 8 '#' '-')"
assert_eq "50 percent is half filled"       "####----" "$(progress_bar 50 8 '#' '-')"
assert_eq "100 percent is all filled"       "########" "$(progress_bar 100 8 '#' '-')"
assert_eq "over 100 clamps to full"         "########" "$(progress_bar 125 8 '#' '-')"
assert_eq "negative clamps to empty"        "--------" "$(progress_bar -5 8 '#' '-')"
assert_eq "width <= 0 falls back to 8"      "####----" "$(progress_bar 50 0 '#' '-')"
assert_eq "fill count truncates (33%->2)"   "##------" "$(progress_bar 33 8 '#' '-')"

# -----------------------------------------------------------------------------
# safe_int <value> [default]
# Strips a trailing ".xxx" decimal, then accepts only ^-?[0-9]+$; otherwise the
# default (which itself defaults to 0). Empty / "null" / "undefined" -> default.
# -----------------------------------------------------------------------------
echo "=== safe_int Tests ==="
assert_eq "plain integer passes through"       "100" "$(safe_int 100)"
assert_eq "decimal portion is stripped"        "100" "$(safe_int 100.7)"
assert_eq "empty value uses default 0"         "0"   "$(safe_int '')"
assert_eq "empty value uses supplied default"  "5"   "$(safe_int '' 5)"
assert_eq "literal null uses default"          "0"   "$(safe_int null)"
assert_eq "non-numeric uses supplied default"  "7"   "$(safe_int abc 7)"
assert_eq "negative integer is accepted"       "-42" "$(safe_int -42)"
assert_eq "trailing garbage is rejected"       "0"   "$(safe_int 12abc)"

# -----------------------------------------------------------------------------
# safe_divide <num> <denom> [default]
# Integer num/denom. denom defaults to 1 when empty (so an empty denom is NOT a
# zero-divide); a zero denom returns the default (default itself defaults to 0).
# -----------------------------------------------------------------------------
echo "=== safe_divide Tests ==="
assert_eq "even division"                       "25"  "$(safe_divide 100 4)"
assert_eq "integer division truncates"          "3"   "$(safe_divide 7 2)"
assert_eq "zero denom returns default 0"        "0"   "$(safe_divide 100 0)"
assert_eq "zero denom returns supplied default" "99"  "$(safe_divide 100 0 99)"
assert_eq "empty denom defaults to 1 not zero"  "100" "$(safe_divide 100 '')"
assert_eq "negative numerator"                  "-25" "$(safe_divide -100 4)"
assert_eq "zero numerator"                      "0"   "$(safe_divide 0 5)"

# -----------------------------------------------------------------------------
# truncate_string <string> <max_len>
# When ${#str} > max_len (and max_len > 0): first (max_len-3) chars + "...".
# Otherwise the string is returned unchanged. max_len <= 3 is pathological
# (it would index with a negative length) and intentionally untested -- real
# callers pass widths >= 4.
# -----------------------------------------------------------------------------
echo "=== truncate_string Tests ==="
assert_eq "shorter than max is unchanged"      "hello"    "$(truncate_string hello 10)"
assert_eq "equal to max is unchanged"          "hello"    "$(truncate_string hello 5)"
assert_eq "longer than max keeps max-3 + dots" "hello..." "$(truncate_string 'hello world' 8)"
assert_eq "max_len 4 keeps one char + dots"    "h..."     "$(truncate_string hello 4)"
assert_eq "ten chars to width 7"               "abcd..."  "$(truncate_string abcdefghij 7)"
assert_eq "max_len 0 disables truncation"      "hi"       "$(truncate_string hi 0)"

# -----------------------------------------------------------------------------
# format_time_remaining <seconds>
# <=0 -> "now"; days>0 -> "Nd Nh"; else hours>0 -> "Nh Nm"; else "Nm".
# Sub-minute values render as "0m" (there is no seconds unit).
# -----------------------------------------------------------------------------
echo "=== format_time_remaining Tests ==="
assert_eq "zero is now"               "now"   "$(format_time_remaining 0)"
assert_eq "negative is now"           "now"   "$(format_time_remaining -10)"
assert_eq "sub-minute is 0m"          "0m"    "$(format_time_remaining 30)"
assert_eq "exactly one minute"        "1m"    "$(format_time_remaining 60)"
assert_eq "minutes only"              "9m"    "$(format_time_remaining 599)"
assert_eq "exactly one hour shows 0m" "1h 0m" "$(format_time_remaining 3600)"
assert_eq "hours and minutes"         "2h 2m" "$(format_time_remaining 7320)"
assert_eq "exactly one day shows 0h"  "1d 0h" "$(format_time_remaining 86400)"
assert_eq "days and hours"            "1d 1h" "$(format_time_remaining 90061)"

# -----------------------------------------------------------------------------
# format_number <num>
# >=1,000,000 -> "<n>M"; >=1,000 -> "<n>k"; else the number. Integer division
# truncates (no rounding); the suffixes are lowercase k / uppercase M.
# -----------------------------------------------------------------------------
echo "=== format_number Tests ==="
assert_eq "below 1k is unchanged"   "999"  "$(format_number 999)"
assert_eq "exactly 1000 is 1k"      "1k"   "$(format_number 1000)"
assert_eq "thousands truncate"      "1k"   "$(format_number 1999)"
assert_eq "tens of thousands"       "12k"  "$(format_number 12345)"
assert_eq "just under a million"    "999k" "$(format_number 999999)"
assert_eq "exactly a million is 1M" "1M"   "$(format_number 1000000)"
assert_eq "millions truncate"       "2M"   "$(format_number 2500000)"
assert_eq "zero is unchanged"       "0"    "$(format_number 0)"

# -----------------------------------------------------------------------------
# get_icon <icon> [fallback]
# Echoes the icon when USE_ICONS != "false" (default true), else the fallback
# (which itself defaults to empty).
# -----------------------------------------------------------------------------
echo "=== get_icon Tests ==="
USE_ICONS="true"
assert_eq "icons on returns the icon"     "ICON" "$(get_icon ICON FB)"
USE_ICONS="false"
assert_eq "icons off returns fallback"    "FB"   "$(get_icon ICON FB)"
assert_eq "icons off, no fallback, empty" ""     "$(get_icon ICON)"
unset USE_ICONS
assert_eq "icons default on returns icon" "ICON" "$(get_icon ICON FB)"
USE_ICONS="true"

# -----------------------------------------------------------------------------
# is_compact [module_flag] / is_verbose -- return-code helpers keyed on
# DISPLAY_MODE. is_compact is additionally true when its module-flag arg == "true".
# -----------------------------------------------------------------------------
echo "=== is_compact / is_verbose Tests ==="
DISPLAY_MODE="normal"
assert_eq "normal mode is not compact" "no"  "$(is_compact && echo yes || echo no)"
assert_eq "module flag forces compact" "yes" "$(is_compact true && echo yes || echo no)"
DISPLAY_MODE="compact"
assert_eq "compact mode is compact"    "yes" "$(is_compact && echo yes || echo no)"
DISPLAY_MODE="verbose"
assert_eq "verbose mode is verbose"    "yes" "$(is_verbose && echo yes || echo no)"
DISPLAY_MODE="normal"
assert_eq "normal mode is not verbose" "no"  "$(is_verbose && echo yes || echo no)"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
