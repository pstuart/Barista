# shellcheck shell=bash
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

    # Get CPU usage
    local cpu_usage
    if [ "$(uname)" = "Darwin" ]; then
        # macOS: top sample (user + sys; #51)
        cpu_usage=$(top -l 1 -n 0 2>/dev/null | grep "CPU usage" | awk '{u=$3; s=$5; sub(/%/,"",u); sub(/%/,"",s); print u+s}')
    else
        # Linux: single-shot /proc/stat is lifetime average since boot — not
        # "current" CPU%. Diff against a previous sample cached under barista-cache
        # (statusline re-renders often → second+ ticks are accurate; first tick
        # seeds the cache and returns empty so we don't show a bogus % forever).
        local cur prev puser pnice psystem pidle cuser cnice csystem cidle
        local duser dnice dsystem didle dtotal
        cur=$(grep '^cpu ' /proc/stat 2>/dev/null)
        if [ -n "$cur" ]; then
            init_cache
            local stat_file="${CACHE_DIR}/cpu_stat"
            if [ -f "$stat_file" ]; then
                prev=$(cat "$stat_file" 2>/dev/null)
                # shellcheck disable=SC2086
                set -- $prev
                puser=${2:-0}; pnice=${3:-0}; psystem=${4:-0}; pidle=${5:-0}
                # shellcheck disable=SC2086
                set -- $cur
                cuser=${2:-0}; cnice=${3:-0}; csystem=${4:-0}; cidle=${5:-0}
                duser=$((cuser - puser))
                dnice=$((cnice - pnice))
                dsystem=$((csystem - psystem))
                didle=$((cidle - pidle))
                dtotal=$((duser + dnice + dsystem + didle))
                if [ "$dtotal" -gt 0 ]; then
                    cpu_usage=$(( (duser + dnice + dsystem) * 100 / dtotal ))
                fi
            fi
            printf '%s\n' "$cur" > "$stat_file" 2>/dev/null
            chmod 600 "$stat_file" 2>/dev/null
        fi
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
