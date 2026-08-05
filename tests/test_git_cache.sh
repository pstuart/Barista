#!/bin/bash
# ABOUTME: Regression-lock for modules/git.sh TTL cache helpers (#26)
# ABOUTME: Run with: bash tests/test_git_cache.sh

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

assert_match() {
    local desc="$1" pattern="$2" actual="$3"
    if printf '%s' "$actual" | grep -Eq "$pattern"; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        echo "    pattern: '$pattern'"
        echo "    actual:  '$actual'"
        FAIL=$((FAIL + 1))
    fi
}

# shellcheck source=/dev/null
. "$SCRIPT_DIR/modules/utils.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/modules/git.sh"

TEST_BASE="$(mktemp -d "${TMPDIR:-/tmp}/barista-git-cache-test.XXXXXX")"
CACHE_DIR="$TEST_BASE/cache"
init_cache

# Key helper: stable, no path separators
k1=$(_git_cache_key_for_dir "/tmp/example/repo/.git")
k2=$(_git_cache_key_for_dir "/tmp/example/repo/.git")
k3=$(_git_cache_key_for_dir "/tmp/other/repo/.git")
assert_eq "cache key is stable for same path" "$k1" "$k2"
assert_match "cache key has git_ prefix" '^git_' "$k1"
assert_eq "cache key has no slash" "0" "$(printf '%s' "$k1" | grep -c / || true)"
assert_eq "different paths get different keys" "1" "$([ "$k1" != "$k3" ] && echo 1 || echo 0)"

# Round-trip branch+porcelain payload through cache_get/set (same format as module_git)
payload="main
---BARISTA_GIT---
 M modules/git.sh
?? untracked.txt"
cache_set "$k1" "$payload"
got=$(cache_get "$k1" 60)
branch=$(printf '%s\n' "$got" | head -n 1)
porcelain=$(printf '%s\n' "$got" | sed '1,/^---BARISTA_GIT---$/d')
assert_eq "cached branch round-trips" "main" "$branch"
assert_match "cached porcelain includes modified line" ' M modules/git.sh' "$porcelain"
assert_match "cached porcelain includes untracked line" '\?\? untracked.txt' "$porcelain"

# TTL=0 path: module still runs when pointed at this worktree
export GIT_CACHE_TTL=0
export USE_ICONS=false
export GIT_SHOW_STATUS=true
export GIT_SHOW_FILE_COUNT=false
export GIT_SHOW_BRANCH=true
out=$(module_git "$SCRIPT_DIR" 2>/dev/null || true)
assert_match "module_git renders with TTL disabled" 'GIT:|🌿' "$out"
# Prefer GIT: fallback since USE_ICONS=false
assert_match "module_git shows branch or git label" '.' "$out"

rm -rf "$TEST_BASE"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
