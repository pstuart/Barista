# shellcheck shell=bash
# =============================================================================
# Git Module - Shows branch, status, and file count
# =============================================================================
# Configuration options:
#   GIT_ICON              - Icon before branch name (default: 🌿)
#   GIT_SHOW_BRANCH       - Show branch name (default: true)
#   GIT_SHOW_STATUS       - Show status symbols (default: true)
#   GIT_SHOW_FILE_COUNT    - Show modified file count (default: true)
#   GIT_SYMBOL_MODIFIED    - Symbol for modified files (default: ●)
#   GIT_SYMBOL_UNTRACKED  - Symbol for untracked files (default: +)
#   GIT_SYMBOL_STAGED      - Symbol for staged files (default: ✓)
#   GIT_FILE_ICON          - Icon before file count (default: 📝)
#   GIT_COMPACT            - Compact mode (default: false)
#   GIT_CACHE_TTL          - Seconds to TTL-cache git subprocess output (default: 2).
#                           Set 0 to disable. Cache busts early if .git/HEAD or
#                           .git/index is newer than the cache entry (issue #26).
# =============================================================================

# Hash a path into a cache-key-safe token (no / or ..). Prefer sha256, fall back.
_git_cache_key_for_dir() {
    local path="$1"
    local h=""
    if command -v shasum >/dev/null 2>&1; then
        h=$(printf '%s' "$path" | shasum -a 256 2>/dev/null | cut -c1-16)
    elif command -v sha256sum >/dev/null 2>&1; then
        h=$(printf '%s' "$path" | sha256sum 2>/dev/null | cut -c1-16)
    elif command -v md5 >/dev/null 2>&1; then
        h=$(printf '%s' "$path" | md5 -q 2>/dev/null | cut -c1-16)
    elif command -v md5sum >/dev/null 2>&1; then
        h=$(printf '%s' "$path" | md5sum 2>/dev/null | cut -c1-16)
    else
        # Portable last resort: cksum + length (collision-resistant enough for local TTL)
        h=$(printf '%s' "$path" | cksum 2>/dev/null | tr -d ' ')
    fi
    [ -n "$h" ] || h="default"
    echo "git_${h}"
}

module_git() {
    local current_dir="$1"
    local icon
    icon=$(get_icon "${GIT_ICON:-🌿}" "GIT:")
    local show_branch="${GIT_SHOW_BRANCH:-true}"
    local show_status="${GIT_SHOW_STATUS:-true}"
    local show_count="${GIT_SHOW_FILE_COUNT:-true}"
    local sym_modified="${GIT_SYMBOL_MODIFIED:-●}"
    local sym_untracked="${GIT_SYMBOL_UNTRACKED:-+}"
    local sym_staged="${GIT_SYMBOL_STAGED:-✓}"
    local file_icon
    file_icon=$(get_icon "${GIT_FILE_ICON:-📝}" "")
    local compact="${GIT_COMPACT:-false}"
    # TTL default 2s; 0 disables (scoping note #26 Phase 1)
    local git_ttl="${GIT_CACHE_TTL:-2}"

    # Safety check: ensure directory exists and is accessible
    if [ -z "$current_dir" ] || [ ! -d "$current_dir" ]; then
        return
    fi

    # Save current directory and change to target
    local orig_dir="$PWD"
    cd "$current_dir" 2>/dev/null || return

    # Quick check: are we in a git repo?
    local git_dir
    git_dir=$(git rev-parse --git-dir 2>/dev/null) || {
        cd "$orig_dir" 2>/dev/null || return
        return
    }

    # Resolve absolute git dir for stable cache keys + mtime targets
    local abs_git_dir
    if [ -d "$git_dir" ]; then
        abs_git_dir=$(cd "$git_dir" 2>/dev/null && pwd -P)
    fi
    [ -n "$abs_git_dir" ] || abs_git_dir="$git_dir"

    local head_file="$abs_git_dir/HEAD"
    local index_file="$abs_git_dir/index"
    local cache_key=""
    local use_cache=false
    local git_branch=""
    local git_porcelain=""
    local from_cache=false

    # Numeric TTL > 0 enables cache (non-numeric → treat as disabled)
    case "$git_ttl" in
        ''|*[!0-9]*) git_ttl=0 ;;
    esac
    if [ "$git_ttl" -gt 0 ] 2>/dev/null; then
        use_cache=true
        cache_key=$(_git_cache_key_for_dir "$abs_git_dir")
    fi

    if [ "$use_cache" = "true" ]; then
        local cached=""
        cached=$(cache_get "$cache_key" "$git_ttl" 2>/dev/null) || cached=""
        if [ -n "$cached" ]; then
            # Bust if HEAD or index changed after the cache write
            local cache_file="$CACHE_DIR/${cache_key}"
            local cache_mtime head_mtime index_mtime
            cache_mtime=$(_file_mtime "$cache_file")
            head_mtime=$(_file_mtime "$head_file")
            index_mtime=$(_file_mtime "$index_file")
            if [ "$head_mtime" -gt "$cache_mtime" ] 2>/dev/null \
                || [ "$index_mtime" -gt "$cache_mtime" ] 2>/dev/null; then
                cached=""
            fi
        fi
        if [ -n "$cached" ]; then
            # Format: first line = branch; remainder after sentinel = porcelain
            git_branch=$(printf '%s\n' "$cached" | head -n 1)
            git_porcelain=$(printf '%s\n' "$cached" | sed '1,/^---BARISTA_GIT---$/d')
            # Empty branch line means corrupt entry — recompute
            if [ -n "$git_branch" ]; then
                from_cache=true
            else
                git_porcelain=""
            fi
        fi
    fi

    if [ "$from_cache" != "true" ]; then
        # Get branch name (handles detached HEAD)
        git_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
        if [ -z "$git_branch" ]; then
            # Detached HEAD - show short SHA
            git_branch=$(git rev-parse --short HEAD 2>/dev/null)
            if [ -z "$git_branch" ]; then
                cd "$orig_dir" 2>/dev/null || return
                return
            fi
            git_branch="($git_branch)"  # Indicate detached state
        fi

        # PERFORMANCE: single git status --porcelain; MEMORY: cap monorepo output
        if [ "$show_status" = "true" ] || [ "$show_count" = "true" ]; then
            local max_lines=500
            git_porcelain=$(git status --porcelain 2>/dev/null | head -n "$max_lines")
        fi

        if [ "$use_cache" = "true" ]; then
            # Store branch + porcelain for next render within TTL
            cache_set "$cache_key" "${git_branch}
---BARISTA_GIT---
${git_porcelain}"
        fi
    fi

    local result="$icon"

    # Branch name
    if [ "$show_branch" = "true" ]; then
        result="$result $git_branch"
    fi

    # PERFORMANCE OPTIMIZATION: Use single git status --porcelain call
    # This replaces 4 separate git commands with 1
    # MEMORY OPTIMIZATION: Limit output to prevent OOM in large monorepos
    if [ "$show_status" = "true" ] || [ "$show_count" = "true" ]; then
        local max_lines=500  # Cap to prevent memory issues in monorepos

        if [ "$show_status" = "true" ]; then
            local has_modified=false
            local has_untracked=false
            local has_staged=false

            # Parse porcelain output efficiently
            # Format: XY filename
            # X = index status, Y = worktree status
            while IFS= read -r line; do
                [ -z "$line" ] && continue

                local index_status="${line:0:1}"
                local worktree_status="${line:1:1}"

                # Staged changes (index has changes)
                case "$index_status" in
                    [MADRC]) has_staged=true ;;
                esac

                # Modified in worktree
                case "$worktree_status" in
                    [MD]) has_modified=true ;;
                esac

                # Untracked files
                if [ "$index_status" = "?" ]; then
                    has_untracked=true
                fi

                # Early exit if we found all types
                if [ "$has_modified" = "true" ] && [ "$has_untracked" = "true" ] && [ "$has_staged" = "true" ]; then
                    break
                fi
            done <<< "$git_porcelain"

            # Build status string
            local git_status=""
            [ "$has_modified" = "true" ] && git_status="${git_status}${sym_modified}"
            [ "$has_untracked" = "true" ] && git_status="${git_status}${sym_untracked}"
            [ "$has_staged" = "true" ] && git_status="${git_status}${sym_staged}"

            if [ -n "$git_status" ]; then
                result="$result [$git_status]"
            fi
        fi

        # File count (skip in compact mode)
        if [ "$show_count" = "true" ] && ! is_compact "$compact"; then
            # Count non-empty lines from porcelain output
            local modified_count=0
            local count_display=""
            if [ -n "$git_porcelain" ]; then
                modified_count=$(echo "$git_porcelain" | grep -c '^' 2>/dev/null || echo "0")
                # If we hit the limit, get actual count efficiently with wc -l
                if [ "$modified_count" -ge "$max_lines" ]; then
                    # Only re-run full status when not serving from short TTL cache
                    # (cached path already capped; exact monorepo count is best-effort)
                    if [ "$from_cache" = "true" ]; then
                        count_display="${modified_count}+"
                    else
                        modified_count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
                        count_display="${modified_count}"
                    fi
                else
                    count_display="${modified_count}"
                fi
            fi

            if [ "$modified_count" -gt 0 ] 2>/dev/null; then
                if [ -n "$file_icon" ]; then
                    result="$result $file_icon $count_display"
                else
                    result="$result $count_display files"
                fi
            fi
        fi
    fi

    # Return to original directory (best-effort; the result must still print)
    cd "$orig_dir" 2>/dev/null || true

    echo "$result"
}
