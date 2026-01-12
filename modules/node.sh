# =============================================================================
# Node Module - Shows Node.js version and npm info
# =============================================================================
# Configuration options:
#   NODE_ICON          - Icon for Node (default: ⬢)
#   NODE_SHOW_VERSION  - Show Node version (default: true)
#   NODE_SHOW_NPM      - Show npm version (default: false)
#   NODE_SHOW_NVM      - Show if using nvm (default: false)
#   NODE_COMPACT       - Compact mode (default: false)
# =============================================================================

module_node() {
    local icon=$(get_icon "${NODE_ICON:-⬢}" "NODE:")
    local show_version="${NODE_SHOW_VERSION:-true}"
    local show_npm="${NODE_SHOW_NPM:-false}"
    local show_nvm="${NODE_SHOW_NVM:-false}"
    local compact="${NODE_COMPACT:-false}"

    # Check if node is available
    if ! command -v node >/dev/null 2>&1; then
        return
    fi

    local result="$icon"
    local parts=""

    if [ "$show_version" = "true" ]; then
        local node_version=$(node --version 2>/dev/null | tr -d 'v')
        if [ -n "$node_version" ]; then
            if is_compact "$compact"; then
                # Just major.minor in compact
                parts=$(echo "$node_version" | cut -d. -f1-2)
            else
                parts="$node_version"
            fi
        fi
    fi

    if [ "$show_npm" = "true" ]; then
        local npm_version=$(npm --version 2>/dev/null)
        if [ -n "$npm_version" ]; then
            if is_compact "$compact"; then
                npm_version=$(echo "$npm_version" | cut -d. -f1-2)
            fi
            if [ -n "$parts" ]; then
                parts="$parts/npm:$npm_version"
            else
                parts="npm:$npm_version"
            fi
        fi
    fi

    if [ "$show_nvm" = "true" ]; then
        if [ -n "$NVM_DIR" ] && [ -d "$NVM_DIR" ]; then
            parts="${parts:+$parts }(nvm)"
        fi
    fi

    if [ -n "$parts" ]; then
        echo "$result $parts"
    fi
}
