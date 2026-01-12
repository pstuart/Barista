# =============================================================================
# Memory Module - Shows RAM usage
# =============================================================================
# Configuration options:
#   MEMORY_ICON              - Icon for memory (default: 🧠)
#   MEMORY_SHOW_PERCENTAGE   - Show percentage (default: true)
#   MEMORY_SHOW_USED         - Show used/total (default: false)
#   MEMORY_WARNING_THRESHOLD - Yellow at % (default: 70)
#   MEMORY_CRITICAL_THRESHOLD - Red at % (default: 85)
#   MEMORY_SHOW_STATUS       - Show status indicator (default: true)
# =============================================================================

module_memory() {
    local icon=$(get_icon "${MEMORY_ICON:-🧠}" "MEM:")
    local show_pct="${MEMORY_SHOW_PERCENTAGE:-true}"
    local show_used="${MEMORY_SHOW_USED:-false}"
    local warn_thresh="${MEMORY_WARNING_THRESHOLD:-70}"
    local crit_thresh="${MEMORY_CRITICAL_THRESHOLD:-85}"
    local show_status="${MEMORY_SHOW_STATUS:-true}"

    local mem_pct=""
    local mem_used=""
    local mem_total=""

    if [ "$(uname)" = "Darwin" ]; then
        # macOS: use vm_stat
        local pages_free=$(vm_stat 2>/dev/null | grep "Pages free" | awk '{print $3}' | tr -d '.')
        local pages_active=$(vm_stat 2>/dev/null | grep "Pages active" | awk '{print $3}' | tr -d '.')
        local pages_inactive=$(vm_stat 2>/dev/null | grep "Pages inactive" | awk '{print $3}' | tr -d '.')
        local pages_speculative=$(vm_stat 2>/dev/null | grep "Pages speculative" | awk '{print $3}' | tr -d '.')
        local pages_wired=$(vm_stat 2>/dev/null | grep "Pages wired down" | awk '{print $4}' | tr -d '.')

        if [ -n "$pages_free" ] && [ -n "$pages_active" ]; then
            local page_size=4096
            local total_mem=$(sysctl -n hw.memsize 2>/dev/null)
            local used_pages=$((pages_active + pages_wired))
            local used_bytes=$((used_pages * page_size))
            local total_gb=$((total_mem / 1073741824))
            local used_gb=$((used_bytes / 1073741824))

            mem_pct=$((used_bytes * 100 / total_mem))
            mem_used="${used_gb}G"
            mem_total="${total_gb}G"
        fi
    else
        # Linux: use /proc/meminfo
        local total=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
        local avail=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}')

        if [ -n "$total" ] && [ -n "$avail" ]; then
            local used=$((total - avail))
            mem_pct=$((used * 100 / total))
            mem_used="$((used / 1048576))G"
            mem_total="$((total / 1048576))G"
        fi
    fi

    if [ -z "$mem_pct" ]; then
        return
    fi

    local result="$icon"

    if [ "$show_used" = "true" ]; then
        result="$result ${mem_used}/${mem_total}"
    elif [ "$show_pct" = "true" ]; then
        result="$result ${mem_pct}%"
    fi

    if [ "$show_status" = "true" ]; then
        local status_ind=$(get_status "$mem_pct" "$warn_thresh" "$crit_thresh")
        result="$result${status_ind}"
    fi

    echo "$result"
}
