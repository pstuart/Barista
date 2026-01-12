# =============================================================================
# Docker Module - Shows Docker container status
# =============================================================================
# Configuration options:
#   DOCKER_ICON            - Icon for Docker (default: 🐳)
#   DOCKER_SHOW_RUNNING    - Show running count (default: true)
#   DOCKER_SHOW_TOTAL      - Show total count (default: false)
#   DOCKER_SHOW_STATUS     - Show status indicator (default: true)
#   DOCKER_COMPACT         - Compact mode (default: false)
# =============================================================================

module_docker() {
    local icon=$(get_icon "${DOCKER_ICON:-🐳}" "DOCKER:")
    local show_running="${DOCKER_SHOW_RUNNING:-true}"
    local show_total="${DOCKER_SHOW_TOTAL:-false}"
    local show_status="${DOCKER_SHOW_STATUS:-true}"
    local compact="${DOCKER_COMPACT:-false}"

    # Check if docker is available
    if ! command -v docker >/dev/null 2>&1; then
        return
    fi

    # Check if docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        if [ "$show_status" = "true" ]; then
            echo "$icon --"
        fi
        return
    fi

    local running=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
    local total=$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ')

    local result="$icon"

    if [ "$show_running" = "true" ] && [ "$show_total" = "true" ]; then
        if is_compact "$compact"; then
            result="$result ${running}/${total}"
        else
            result="$result ${running} running / ${total} total"
        fi
    elif [ "$show_running" = "true" ]; then
        if is_compact "$compact"; then
            result="$result $running"
        else
            result="$result $running running"
        fi
    elif [ "$show_total" = "true" ]; then
        result="$result $total"
    fi

    if [ "$show_status" = "true" ]; then
        if [ "$running" -gt 0 ]; then
            result="$result $(get_icon '🟢' '[OK]')"
        else
            result="$result $(get_icon '⚪' '[-]')"
        fi
    fi

    echo "$result"
}
