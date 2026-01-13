# =============================================================================
# Rate Limits Module - Shows 5-hour and 7-day usage with projections
# Requires macOS Keychain with Claude Code OAuth token
# =============================================================================
# Configuration options:
#   RATE_SHOW_5H            - Show 5-hour rate limit (default: true)
#   RATE_SHOW_7D            - Show 7-day rate limit (default: true)
#   RATE_SHOW_TIME_REMAINING - Show time until reset (default: true)
#   RATE_SHOW_PROJECTION    - Show projection status (default: true)
#   RATE_SHOW_USAGE_STATUS  - Show usage level indicator (default: true)
#   RATE_LOW_THRESHOLD      - Green/yellow boundary (default: 50)
#   RATE_MEDIUM_THRESHOLD   - Yellow/orange boundary (default: 75)
#   RATE_HIGH_THRESHOLD     - Orange/red boundary (default: 95)
#   RATE_WARNING_THRESHOLD  - Yellow warning at % for projections (default: 80)
#   RATE_CRITICAL_THRESHOLD - Red warning at % for projections (default: 100)
#   RATE_COMPACT            - Compact mode (default: false)
#   RATE_5H_LABEL           - Label for 5-hour (default: 5h)
#   RATE_7D_LABEL           - Label for 7-day (default: 7d)
# =============================================================================

# Fetch usage from Anthropic API
_get_claude_usage() {
    local token
    token=$(security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)

    if [ -n "$token" ]; then
        curl -s --max-time 2 "https://api.anthropic.com/api/oauth/usage" \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "Accept: application/json" 2>/dev/null
    fi
}

# Get projection status indicator
_get_projection_status() {
    local projected=$1
    local warn_thresh="${RATE_WARNING_THRESHOLD:-80}"
    local crit_thresh="${RATE_CRITICAL_THRESHOLD:-100}"

    if [ "${RATE_SHOW_PROJECTION:-true}" != "true" ]; then
        echo ""
        return
    fi

    get_status "$projected" "$warn_thresh" "$crit_thresh"
}

module_rate_limits() {
    local show_5h="${RATE_SHOW_5H:-true}"
    local show_7d="${RATE_SHOW_7D:-true}"
    local show_time="${RATE_SHOW_TIME_REMAINING:-true}"
    local show_usage_status="${RATE_SHOW_USAGE_STATUS:-true}"
    local compact="${RATE_COMPACT:-false}"
    local label_5h="${RATE_5H_LABEL:-5h}"
    local label_7d="${RATE_7D_LABEL:-7d}"

    # 4-level usage thresholds: green -> yellow -> orange -> red
    local low_thresh="${RATE_LOW_THRESHOLD:-50}"
    local medium_thresh="${RATE_MEDIUM_THRESHOLD:-75}"
    local high_thresh="${RATE_HIGH_THRESHOLD:-95}"

    local cache_file="/tmp/.claude_usage_cache"
    local history_file="$HOME/.claude/.usage_history"
    local usage_data=""
    local fresh_fetch=false

    # Read from cache if fresh
    if [ -f "$cache_file" ]; then
        local cache_age=$(($(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || echo 0)))
        if [ "$cache_age" -lt "${CACHE_MAX_AGE:-60}" ]; then
            usage_data=$(cat "$cache_file")
        fi
    fi

    # Fetch fresh data if needed
    if [ -z "$usage_data" ]; then
        usage_data=$(_get_claude_usage)
        if [ -n "$usage_data" ]; then
            echo "$usage_data" > "$cache_file" 2>/dev/null
            fresh_fetch=true
        fi
    fi

    if [ -z "$usage_data" ]; then
        local result=""
        [ "$show_5h" = "true" ] && result="${label_5h}:--"
        [ "$show_7d" = "true" ] && result="${result:+$result }${label_7d}:--"
        echo "$result"
        return
    fi

    local five_hour_obj=$(echo "$usage_data" | jq -r '.five_hour // .five_hour_opus // .five_hour_sonnet // "null"' 2>/dev/null)
    local seven_day_obj=$(echo "$usage_data" | jq -r '.seven_day // .seven_day_opus // .seven_day_sonnet // "null"' 2>/dev/null)

    if [ "$five_hour_obj" = "null" ] || [ "$seven_day_obj" = "null" ]; then
        local result=""
        [ "$show_5h" = "true" ] && result="${label_5h}:--"
        [ "$show_7d" = "true" ] && result="${result:+$result }${label_7d}:--"
        echo "$result"
        return
    fi

    local five_hour=$(echo "$five_hour_obj" | jq -r '.utilization // 0' 2>/dev/null)
    local seven_day=$(echo "$seven_day_obj" | jq -r '.utilization // 0' 2>/dev/null)
    local five_hour_reset=$(echo "$five_hour_obj" | jq -r '.resets_at // empty' 2>/dev/null)
    local seven_day_reset=$(echo "$seven_day_obj" | jq -r '.resets_at // empty' 2>/dev/null)

    local now=$(date +%s)

    # Only record data point when fresh data was fetched (not from cache)
    # This prevents unbounded file growth from frequent statusline invocations
    if [ "$fresh_fetch" = "true" ]; then
        # Cap history file size at 50KB to prevent memory issues
        local max_history_size=51200
        local current_size=0
        if [ -f "$history_file" ]; then
            current_size=$(stat -f %z "$history_file" 2>/dev/null || echo 0)
        fi

        # Cleanup first if file is too large
        if [ "$current_size" -gt "$max_history_size" ]; then
            local cutoff=$((now - 86400))
            tail -50 "$history_file" | awk -F',' -v cutoff="$cutoff" '$1 >= cutoff' > "${history_file}.tmp" 2>/dev/null && \
                mv "${history_file}.tmp" "$history_file" 2>/dev/null
        fi

        # Record the data point
        echo "$now,$five_hour,$seven_day,$five_hour_reset,$seven_day_reset" >> "$history_file" 2>/dev/null

        # Routine cleanup - keep last 100 entries within 24 hours
        if [ -f "$history_file" ]; then
            local cutoff=$((now - 86400))
            tail -100 "$history_file" | awk -F',' -v cutoff="$cutoff" '$1 >= cutoff' > "${history_file}.tmp" 2>/dev/null && \
                mv "${history_file}.tmp" "$history_file" 2>/dev/null
        fi
    fi

    local five_hour_status=""
    local seven_day_status=""
    local five_hour_remaining=0
    local seven_day_remaining=0

    # Parse 5-hour reset time and calculate projection
    if [ -n "$five_hour_reset" ]; then
        local five_hour_reset_epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%S" "${five_hour_reset%%.*}" +%s 2>/dev/null || echo 0)
        five_hour_remaining=$((five_hour_reset_epoch - now))
        if [ "$five_hour_remaining" -gt 18000 ]; then
            five_hour_remaining=18000
        fi

        # 5-hour projection
        if [ -f "$history_file" ] && [ "$five_hour_remaining" -gt 0 ]; then
            local current_window_data=$(grep "$five_hour_reset" "$history_file" 2>/dev/null | tail -10)
            if [ -n "$current_window_data" ]; then
                local first_entry=$(echo "$current_window_data" | head -1)
                local last_entry=$(echo "$current_window_data" | tail -1)
                local first_ts=$(echo "$first_entry" | cut -d',' -f1)
                local first_util=$(echo "$first_entry" | cut -d',' -f2)
                local last_util=$(echo "$last_entry" | cut -d',' -f2)
                local elapsed=$((now - first_ts))

                if [ "$elapsed" -gt 60 ]; then
                    local usage_delta=$(echo "$last_util - $first_util" | bc -l 2>/dev/null || echo "0")
                    local rate=$(echo "scale=10; $usage_delta / $elapsed" | bc -l 2>/dev/null || echo "0")
                    local projected_additional=$(echo "scale=2; $rate * $five_hour_remaining" | bc -l 2>/dev/null || echo "0")
                    local projected_total=$(echo "scale=2; $five_hour + $projected_additional" | bc -l 2>/dev/null || echo "$five_hour")
                    local projected_int=$(printf "%.0f" "$projected_total" 2>/dev/null || echo "0")

                    five_hour_status=$(_get_projection_status "$projected_int")
                fi
            fi
        fi
    fi

    # Parse 7-day reset time and calculate projection
    if [ -n "$seven_day_reset" ]; then
        local seven_day_reset_epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%S" "${seven_day_reset%%.*}" +%s 2>/dev/null || echo 0)
        seven_day_remaining=$((seven_day_reset_epoch - now))
        if [ "$seven_day_remaining" -gt 604800 ]; then
            seven_day_remaining=604800
        fi

        # 7-day projection (needs 12h of data)
        if [ -f "$history_file" ] && [ "$seven_day_remaining" -gt 0 ]; then
            local current_window_data=$(grep "$seven_day_reset" "$history_file" 2>/dev/null | tail -50)
            if [ -n "$current_window_data" ]; then
                local first_entry=$(echo "$current_window_data" | head -1)
                local last_entry=$(echo "$current_window_data" | tail -1)
                local first_ts=$(echo "$first_entry" | cut -d',' -f1)
                local first_util=$(echo "$first_entry" | cut -d',' -f3)
                local last_util=$(echo "$last_entry" | cut -d',' -f3)
                local elapsed=$((now - first_ts))
                local min_elapsed=$((12 * 3600))

                if [ "$elapsed" -gt "$min_elapsed" ]; then
                    local usage_delta=$(echo "$last_util - $first_util" | bc -l 2>/dev/null || echo "0")
                    local rate=$(echo "scale=10; $usage_delta / $elapsed" | bc -l 2>/dev/null || echo "0")
                    local projected_additional=$(echo "scale=2; $rate * $seven_day_remaining" | bc -l 2>/dev/null || echo "0")
                    local projected_total=$(echo "scale=2; $seven_day + $projected_additional" | bc -l 2>/dev/null || echo "$seven_day")
                    local projected_int=$(printf "%.0f" "$projected_total" 2>/dev/null || echo "0")

                    seven_day_status=$(_get_projection_status "$projected_int")
                fi
            fi
        fi
    fi

    local five_hour_int=$(printf "%.0f" "$five_hour" 2>/dev/null || echo "0")
    local seven_day_int=$(printf "%.0f" "$seven_day" 2>/dev/null || echo "0")

    # Get usage level indicators (4-level: green/yellow/orange/red)
    local five_hour_usage_ind=""
    local seven_day_usage_ind=""
    if [ "$show_usage_status" = "true" ]; then
        five_hour_usage_ind=$(get_status_4level "$five_hour_int" "$low_thresh" "$medium_thresh" "$high_thresh")
        seven_day_usage_ind=$(get_status_4level "$seven_day_int" "$low_thresh" "$medium_thresh" "$high_thresh")
    fi

    # Build output
    local result=""

    if [ "$show_5h" = "true" ]; then
        result="${label_5h}:${five_hour_int}%${five_hour_usage_ind}${five_hour_status}"
        if [ "$show_time" = "true" ] && [ "$five_hour_remaining" -gt 0 ] 2>/dev/null && ! is_compact "$compact"; then
            result="${result}($(format_time_remaining $five_hour_remaining))"
        fi
    fi

    if [ "$show_7d" = "true" ]; then
        local seven_day_part="${label_7d}:${seven_day_int}%${seven_day_usage_ind}${seven_day_status}"
        if [ "$show_time" = "true" ] && [ "$seven_day_remaining" -gt 0 ] 2>/dev/null && ! is_compact "$compact"; then
            seven_day_part="${seven_day_part}($(format_time_remaining $seven_day_remaining))"
        fi
        result="${result:+$result }${seven_day_part}"
    fi

    echo "$result"
}
