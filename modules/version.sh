# shellcheck shell=bash
# =============================================================================
# Version Module - Shows Barista version briefly on startup
# =============================================================================
# Displays the current version for the first 2 minutes after Claude Code starts,
# then automatically hides. Uses a session start marker file.
#
# Configuration options:
#   VERSION_SHOW_DURATION   - Seconds to show version after startup (default: 120)
#   VERSION_ICON            - Icon to display (default: coffee emoji)
# =============================================================================

module_version() {
    local show_duration="${VERSION_SHOW_DURATION:-120}"
    local session_file="$CACHE_DIR/barista_session_start"
    local now
    now=$(date +%s)

    init_cache

    # Create session marker on first invocation
    if [ ! -f "$session_file" ]; then
        echo "$now" > "$session_file" 2>/dev/null
    fi

    local session_start
    session_start=$(cat "$session_file" 2>/dev/null || echo "$now")

    local elapsed=$((now - session_start))

    # Only show version during startup window
    if [ "$elapsed" -ge "$show_duration" ]; then
        return
    fi

    local version=""
    local version_file="$SCRIPT_DIR/VERSION"
    if [ -f "$version_file" ]; then
        version=$(cat "$version_file" 2>/dev/null | tr -d '[:space:]')
    fi

    if [ -z "$version" ]; then
        return
    fi

    local icon
    icon=$(get_icon "${VERSION_ICON:-☕}" "Barista")
    echo "${icon} v${version}"
}
