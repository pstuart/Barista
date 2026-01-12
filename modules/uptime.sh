# =============================================================================
# Uptime Module - Shows system uptime
# =============================================================================
# Configuration options:
#   UPTIME_ICON       - Icon for uptime (default: ⏱️)
#   UPTIME_STYLE      - Display style: "short", "long", "days" (default: short)
#   UPTIME_SHOW_LOAD  - Show load average (default: false)
# =============================================================================

module_uptime() {
    local icon=$(get_icon "${UPTIME_ICON:-⏱️}" "UP:")
    local style="${UPTIME_STYLE:-short}"
    local show_load="${UPTIME_SHOW_LOAD:-false}"

    local uptime_str=""

    if [ "$(uname)" = "Darwin" ]; then
        # macOS: parse boot time
        local boot_time=$(sysctl -n kern.boottime 2>/dev/null | awk '{print $4}' | tr -d ',')
        if [ -n "$boot_time" ]; then
            local now=$(date +%s)
            local uptime_secs=$((now - boot_time))
            uptime_str=$(format_uptime "$uptime_secs" "$style")
        fi
    else
        # Linux: use /proc/uptime
        local uptime_secs=$(cut -d. -f1 /proc/uptime 2>/dev/null)
        if [ -n "$uptime_secs" ]; then
            uptime_str=$(format_uptime "$uptime_secs" "$style")
        fi
    fi

    if [ -z "$uptime_str" ]; then
        return
    fi

    local result="$icon $uptime_str"

    # Add load average if requested
    if [ "$show_load" = "true" ]; then
        local load=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
        if [ -n "$load" ]; then
            result="$result [$load]"
        fi
    fi

    echo "$result"
}

format_uptime() {
    local secs=$1
    local style=${2:-short}

    local days=$((secs / 86400))
    local hours=$(((secs % 86400) / 3600))
    local mins=$(((secs % 3600) / 60))

    case "$style" in
        days)
            if [ "$days" -gt 0 ]; then
                echo "${days}d"
            else
                echo "${hours}h"
            fi
            ;;
        long)
            if [ "$days" -gt 0 ]; then
                echo "${days} days, ${hours} hours"
            elif [ "$hours" -gt 0 ]; then
                echo "${hours} hours, ${mins} mins"
            else
                echo "${mins} mins"
            fi
            ;;
        short|*)
            if [ "$days" -gt 0 ]; then
                echo "${days}d ${hours}h"
            elif [ "$hours" -gt 0 ]; then
                echo "${hours}h ${mins}m"
            else
                echo "${mins}m"
            fi
            ;;
    esac
}
