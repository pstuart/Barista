# =============================================================================
# Disk Module - Shows disk usage
# =============================================================================
# Configuration options:
#   DISK_ICON              - Icon for disk (default: 💾)
#   DISK_PATH              - Path to check (default: /)
#   DISK_SHOW_PERCENTAGE   - Show percentage (default: true)
#   DISK_SHOW_FREE         - Show free space instead of used (default: false)
#   DISK_WARNING_THRESHOLD - Yellow at % (default: 70)
#   DISK_CRITICAL_THRESHOLD - Red at % (default: 90)
#   DISK_SHOW_STATUS       - Show status indicator (default: true)
# =============================================================================

module_disk() {
    local icon=$(get_icon "${DISK_ICON:-💾}" "DISK:")
    local disk_path="${DISK_PATH:-/}"
    local show_pct="${DISK_SHOW_PERCENTAGE:-true}"
    local show_free="${DISK_SHOW_FREE:-false}"
    local warn_thresh="${DISK_WARNING_THRESHOLD:-70}"
    local crit_thresh="${DISK_CRITICAL_THRESHOLD:-90}"
    local show_status="${DISK_SHOW_STATUS:-true}"

    # Get disk usage
    local df_output=$(df -h "$disk_path" 2>/dev/null | tail -1)

    if [ -z "$df_output" ]; then
        return
    fi

    local used_pct=$(echo "$df_output" | awk '{print $5}' | tr -d '%')
    local free_space=$(echo "$df_output" | awk '{print $4}')
    local used_space=$(echo "$df_output" | awk '{print $3}')

    local result="$icon"

    if [ "$show_free" = "true" ]; then
        result="$result ${free_space} free"
    elif [ "$show_pct" = "true" ]; then
        result="$result ${used_pct}%"
    fi

    if [ "$show_status" = "true" ]; then
        local status_ind=$(get_status "$used_pct" "$warn_thresh" "$crit_thresh")
        result="$result${status_ind}"
    fi

    echo "$result"
}
