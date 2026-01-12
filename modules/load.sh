# =============================================================================
# Load Average Module - Shows system load average
# =============================================================================
# Configuration options:
#   LOAD_ICON              - Icon for load (default: 📊)
#   LOAD_SHOW_ALL          - Show 1, 5, 15 min averages (default: false)
#   LOAD_WARNING_THRESHOLD - Yellow at load (default: num_cpus)
#   LOAD_CRITICAL_THRESHOLD - Red at load (default: num_cpus * 2)
#   LOAD_SHOW_STATUS       - Show status indicator (default: true)
# =============================================================================

module_load() {
    local icon=$(get_icon "${LOAD_ICON:-📊}" "LOAD:")
    local show_all="${LOAD_SHOW_ALL:-false}"
    local show_status="${LOAD_SHOW_STATUS:-true}"

    # Get number of CPUs for threshold calculation
    local num_cpus
    if [ "$(uname)" = "Darwin" ]; then
        num_cpus=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
    else
        num_cpus=$(nproc 2>/dev/null || echo 4)
    fi

    local warn_thresh="${LOAD_WARNING_THRESHOLD:-$num_cpus}"
    local crit_thresh="${LOAD_CRITICAL_THRESHOLD:-$((num_cpus * 2))}"

    # Get load averages
    local load_output=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}')

    if [ -z "$load_output" ]; then
        return
    fi

    local load1=$(echo "$load_output" | awk '{print $1}' | tr -d ',')
    local load5=$(echo "$load_output" | awk '{print $2}' | tr -d ',')
    local load15=$(echo "$load_output" | awk '{print $3}' | tr -d ',')

    local result="$icon"

    if [ "$show_all" = "true" ]; then
        result="$result $load1 $load5 $load15"
    else
        result="$result $load1"
    fi

    if [ "$show_status" = "true" ]; then
        # Convert load to percentage relative to num_cpus for status
        local load_pct=$(echo "scale=0; $load1 * 100 / $num_cpus" | bc -l 2>/dev/null || echo "0")
        local warn_pct=$(echo "scale=0; $warn_thresh * 100 / $num_cpus" | bc -l 2>/dev/null || echo "100")
        local crit_pct=$(echo "scale=0; $crit_thresh * 100 / $num_cpus" | bc -l 2>/dev/null || echo "200")
        local status_ind=$(get_status "$load_pct" "$warn_pct" "$crit_pct")
        result="$result${status_ind}"
    fi

    echo "$result"
}
