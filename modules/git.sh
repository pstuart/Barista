# =============================================================================
# Git Module - Shows branch, status, and file count
# =============================================================================
# Configuration options:
#   GIT_ICON              - Icon before branch name (default: 🌿)
#   GIT_SHOW_BRANCH       - Show branch name (default: true)
#   GIT_SHOW_STATUS       - Show status symbols (default: true)
#   GIT_SHOW_FILE_COUNT   - Show modified file count (default: true)
#   GIT_SYMBOL_MODIFIED   - Symbol for modified files (default: ●)
#   GIT_SYMBOL_UNTRACKED  - Symbol for untracked files (default: +)
#   GIT_SYMBOL_STAGED     - Symbol for staged files (default: ✓)
#   GIT_FILE_ICON         - Icon before file count (default: 📝)
#   GIT_COMPACT           - Compact mode (default: false)
# =============================================================================

module_git() {
    local current_dir="$1"
    local icon=$(get_icon "${GIT_ICON:-🌿}" "GIT:")
    local show_branch="${GIT_SHOW_BRANCH:-true}"
    local show_status="${GIT_SHOW_STATUS:-true}"
    local show_count="${GIT_SHOW_FILE_COUNT:-true}"
    local sym_modified="${GIT_SYMBOL_MODIFIED:-●}"
    local sym_untracked="${GIT_SYMBOL_UNTRACKED:-+}"
    local sym_staged="${GIT_SYMBOL_STAGED:-✓}"
    local file_icon=$(get_icon "${GIT_FILE_ICON:-📝}" "")
    local compact="${GIT_COMPACT:-false}"

    # Safety check: ensure directory exists and is accessible
    if [ -z "$current_dir" ] || [ ! -d "$current_dir" ]; then
        return
    fi

    # Save current directory and change to target
    local orig_dir="$PWD"
    cd "$current_dir" 2>/dev/null || return

    # Quick check: are we in a git repo?
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        cd "$orig_dir" 2>/dev/null
        return
    fi

    # Get branch name (handles detached HEAD)
    local git_branch
    git_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    if [ -z "$git_branch" ]; then
        # Detached HEAD - show short SHA
        git_branch=$(git rev-parse --short HEAD 2>/dev/null)
        if [ -z "$git_branch" ]; then
            cd "$orig_dir" 2>/dev/null
            return
        fi
        git_branch="($git_branch)"  # Indicate detached state
    fi

    local result="$icon"

    # Branch name
    if [ "$show_branch" = "true" ]; then
        result="$result $git_branch"
    fi

    # PERFORMANCE OPTIMIZATION: Use single git status --porcelain call
    # This replaces 4 separate git commands with 1
    if [ "$show_status" = "true" ] || [ "$show_count" = "true" ]; then
        local git_porcelain
        git_porcelain=$(git status --porcelain 2>/dev/null)

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
            if [ -n "$git_porcelain" ]; then
                modified_count=$(echo "$git_porcelain" | grep -c '^' 2>/dev/null || echo "0")
            fi

            if [ "$modified_count" -gt 0 ] 2>/dev/null; then
                if [ -n "$file_icon" ]; then
                    result="$result $file_icon $modified_count"
                else
                    result="$result $modified_count files"
                fi
            fi
        fi
    fi

    # Return to original directory
    cd "$orig_dir" 2>/dev/null

    echo "$result"
}
