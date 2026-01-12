# =============================================================================
# Processes Module - Shows process count and info
# =============================================================================
# Configuration options:
#   PROC_ICON              - Icon for processes (default: 🔄)
#   PROC_SHOW_TOTAL        - Show total process count (default: true)
#   PROC_SHOW_RUNNING      - Show running process count (default: false)
#   PROC_WARNING_THRESHOLD - Yellow at count (default: 300)
#   PROC_CRITICAL_THRESHOLD - Red at count (default: 500)
#   PROC_SHOW_STATUS       - Show status indicator (default: false)
# =============================================================================

module_processes() {
    local icon=$(get_icon "${PROC_ICON:-🔄}" "PROC:")
    local show_total="${PROC_SHOW_TOTAL:-true}"
    local show_running="${PROC_SHOW_RUNNING:-false}"
    local warn_thresh="${PROC_WARNING_THRESHOLD:-300}"
    local crit_thresh="${PROC_CRITICAL_THRESHOLD:-500}"
    local show_status="${PROC_SHOW_STATUS:-false}"

    local total_procs=""
    local running_procs=""

    if [ "$(uname)" = "Darwin" ]; then
        # macOS
        total_procs=$(ps aux 2>/dev/null | wc -l | tr -d ' ')
        total_procs=$((total_procs - 1))  # Subtract header
        running_procs=$(ps aux 2>/dev/null | awk '$8 ~ /R/ {count++} END {print count+0}')
    else
        # Linux
        if [ -d /proc ]; then
            total_procs=$(ls -d /proc/[0-9]* 2>/dev/null | wc -l)
            running_procs=$(grep -l "^R" /proc/*/status 2>/dev/null | wc -l)
        else
            total_procs=$(ps aux 2>/dev/null | wc -l | tr -d ' ')
            total_procs=$((total_procs - 1))
        fi
    fi

    if [ -z "$total_procs" ]; then
        return
    fi

    local result="$icon"

    if [ "$show_total" = "true" ] && [ "$show_running" = "true" ]; then
        result="$result ${running_procs}/${total_procs}"
    elif [ "$show_running" = "true" ]; then
        result="$result $running_procs"
    elif [ "$show_total" = "true" ]; then
        result="$result $total_procs"
    fi

    if [ "$show_status" = "true" ]; then
        local status_ind=$(get_status "$total_procs" "$warn_thresh" "$crit_thresh")
        result="$result${status_ind}"
    fi

    echo "$result"
}
