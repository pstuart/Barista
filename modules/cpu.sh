# =============================================================================
# CPU Module - Shows CPU usage percentage
# =============================================================================
# Configuration options:
#   CPU_ICON            - Icon for CPU (default: 💻)
#   CPU_SHOW_PERCENTAGE - Show percentage (default: true)
#   CPU_WARNING_THRESHOLD - Yellow at % (default: 60)
#   CPU_CRITICAL_THRESHOLD - Red at % (default: 80)
#   CPU_SHOW_STATUS     - Show status indicator (default: true)
# =============================================================================

module_cpu() {
    local icon=$(get_icon "${CPU_ICON:-💻}" "CPU:")
    local show_pct="${CPU_SHOW_PERCENTAGE:-true}"
    local warn_thresh="${CPU_WARNING_THRESHOLD:-60}"
    local crit_thresh="${CPU_CRITICAL_THRESHOLD:-80}"
    local show_status="${CPU_SHOW_STATUS:-true}"

    # Get CPU usage (macOS specific)
    local cpu_usage
    if [ "$(uname)" = "Darwin" ]; then
        # macOS: use top to get CPU usage
        cpu_usage=$(top -l 1 -n 0 2>/dev/null | grep "CPU usage" | awk '{print $3}' | tr -d '%')
    else
        # Linux: use /proc/stat
        cpu_usage=$(grep 'cpu ' /proc/stat 2>/dev/null | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.0f", usage}')
    fi

    if [ -z "$cpu_usage" ]; then
        return
    fi

    # Round to integer
    local cpu_int=$(printf "%.0f" "$cpu_usage" 2>/dev/null || echo "0")

    local result="$icon"

    if [ "$show_pct" = "true" ]; then
        result="$result ${cpu_int}%"
    fi

    if [ "$show_status" = "true" ]; then
        local status_ind=$(get_status "$cpu_int" "$warn_thresh" "$crit_thresh")
        result="$result${status_ind}"
    fi

    echo "$result"
}
