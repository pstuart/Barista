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

    local result=""

    cd "$current_dir" 2>/dev/null || return

    # Get branch name
    local git_branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)

    if [ -z "$git_branch" ]; then
        return
    fi

    # Start with icon
    result="$icon"

    # Branch name
    if [ "$show_branch" = "true" ]; then
        result="$result $git_branch"
    fi

    # Check if in git repo
    if git rev-parse --git-dir >/dev/null 2>&1; then
        # Git status symbols
        if [ "$show_status" = "true" ]; then
            local git_status=""

            # Modified files
            if ! git diff-index --quiet HEAD -- 2>/dev/null; then
                git_status="${git_status}${sym_modified}"
            fi

            # Untracked files
            if [ -n "$(git ls-files --others --exclude-standard 2>/dev/null | head -1)" ]; then
                git_status="${git_status}${sym_untracked}"
            fi

            # Staged files
            if ! git diff-index --quiet --cached HEAD -- 2>/dev/null; then
                git_status="${git_status}${sym_staged}"
            fi

            if [ -n "$git_status" ]; then
                result="$result [$git_status]"
            fi
        fi

        # Modified files count (skip in compact mode)
        if [ "$show_count" = "true" ] && ! is_compact "$compact"; then
            local modified_count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
            if [ "$modified_count" -gt 0 ] 2>/dev/null; then
                if [ -n "$file_icon" ]; then
                    result="$result $file_icon ${modified_count} files"
                else
                    result="$result ${modified_count} files"
                fi
            fi
        fi
    fi

    echo "$result"
}
