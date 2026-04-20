# shellcheck shell=bash
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
#   RATE_CACHE_TTL          - Cache TTL in seconds (default: 120)
#   RATE_BACKOFF_SECONDS    - Fallback backoff after 429 if no retry-after header (default: 300)
# =============================================================================

# Extract OAuth token from (in order):
#   1. ~/.claude/.credentials.json — used on Windows and some Linux setups
#   2. macOS Keychain via `security` — used on macOS
# Handles both plain JSON and hex-encoded formats (macOS 15+ / recent Claude Code)
_get_claude_token() {
    local creds_file="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json"
    if [ -f "$creds_file" ]; then
        local file_token
        file_token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
        if [ -n "$file_token" ]; then
            echo "$file_token"
            return
        fi
    fi

    command -v security >/dev/null 2>&1 || return

    local raw
    raw=$(security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null)
    [ -z "$raw" ] && return

    # Try parsing as plain JSON first (older format)
    local token
    token=$(echo "$raw" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)

    if [ -z "$token" ]; then
        # Try hex-decoding (newer macOS/Claude Code returns hex-encoded data)
        local decoded
        decoded=$(echo "$raw" | xxd -r -p 2>/dev/null)
        if [ -n "$decoded" ]; then
            # Try jq on decoded data
            token=$(echo "$decoded" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)

            if [ -z "$token" ]; then
                # Fall back to regex extraction (handles binary prefix bytes)
                token=$(echo "$decoded" | grep -o '"accessToken":"[^"]*"' | head -1 | sed 's/"accessToken":"//;s/"$//')
            fi
        fi
    fi

    echo "$token"
}

# Check if currently in backoff from a 429
# Returns 0 if in backoff (with remaining seconds on stdout), 1 if not
_check_backoff() {
    local backoff_file="$CACHE_DIR/rate_limits_backoff"
    local default_duration="${RATE_BACKOFF_SECONDS:-300}"

    if [ ! -f "$backoff_file" ]; then
        return 1
    fi

    # Read retry-after duration from file (first line), fall back to default
    local stored_duration
    stored_duration=$(head -1 "$backoff_file" 2>/dev/null)
    local duration="${stored_duration:-$default_duration}"

    local backoff_time
    backoff_time=$(_file_mtime "$backoff_file")

    local now
    now=$(date +%s)
    local backoff_age=$((now - backoff_time))

    if [ "$backoff_age" -lt "$duration" ]; then
        local remaining=$((duration - backoff_age))
        echo "$remaining"
        return 0
    else
        rm -f "$backoff_file" 2>/dev/null
        return 1
    fi
}

# Fetch usage from Anthropic API
_get_claude_usage() {
    local backoff_file="$CACHE_DIR/rate_limits_backoff"

    # Check if we're in backoff period from a previous 429
    local backoff_remaining
    backoff_remaining=$(_check_backoff)
    if [ $? -eq 0 ]; then
        log_debug "rate-limits: in backoff period (${backoff_remaining}s remaining), skipping API call"
        return 1
    fi

    local token
    token=$(_get_claude_token)

    if [ -z "$token" ]; then
        return 1
    fi

    # Capture both body and HTTP status code, plus headers for retry-after
    # Token is passed via a temporary config file (mode 0600) to keep it out of
    # the process table (`ps` output) and shell history.
    local tmp_file="$CACHE_DIR/rate_limits_response"
    local tmp_headers="$CACHE_DIR/rate_limits_headers"
    local tmp_curlcfg="$CACHE_DIR/rate_limits_curlcfg"
    init_cache
    printf 'header = "Authorization: Bearer %s"\n' "$token" > "$tmp_curlcfg"
    chmod 600 "$tmp_curlcfg" 2>/dev/null
    # On Git Bash / MSYS, some mingw curl builds (notably 8.8 shipped with
    # recent Git for Windows) hit libcurl error 43 on this endpoint due to a
    # schannel TLS-renegotiation bug. Windows' system curl.exe works fine.
    local curl_bin="curl"
    case "$(uname -s 2>/dev/null)" in
        MINGW*|MSYS*|CYGWIN*)
            local sys_curl=""
            if command -v cygpath >/dev/null 2>&1 && [ -n "$SYSTEMROOT" ]; then
                sys_curl="$(cygpath -u "$SYSTEMROOT" 2>/dev/null)/System32/curl.exe"
            fi
            [ -x "${sys_curl:-/c/Windows/System32/curl.exe}" ] && \
                curl_bin="${sys_curl:-/c/Windows/System32/curl.exe}"
            ;;
    esac

    local http_code
    http_code=$("$curl_bin" -s --max-time 5 -o "$tmp_file" -D "$tmp_headers" -w "%{http_code}" \
        --config "$tmp_curlcfg" \
        "https://api.anthropic.com/api/oauth/usage" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "Accept: application/json" 2>/dev/null)
    rm -f "$tmp_curlcfg" 2>/dev/null

    case "$http_code" in
        200)
            cat "$tmp_file" 2>/dev/null
            rm -f "$tmp_file" "$tmp_headers" 2>/dev/null
            return 0
            ;;
        429)
            # Parse retry-after header (seconds) from response
            local retry_after
            retry_after=$(grep -i '^retry-after:' "$tmp_headers" 2>/dev/null | tr -d '\r' | awk '{print $2}')
            local backoff_duration="${retry_after:-${RATE_BACKOFF_SECONDS:-300}}"
            log_debug "rate-limits: received 429, backing off for ${backoff_duration}s (retry-after: ${retry_after:-not set})"
            init_cache
            echo "$backoff_duration" > "$backoff_file" 2>/dev/null
            rm -f "$tmp_file" "$tmp_headers" 2>/dev/null
            return 1
            ;;
        *)
            log_debug "rate-limits: API returned HTTP $http_code"
            rm -f "$tmp_file" "$tmp_headers" 2>/dev/null
            return 1
            ;;
    esac
}

# Get projection status indicator (only shown at warning/critical levels)
_get_projection_status() {
    local projected=$1
    local warn_thresh="${RATE_WARNING_THRESHOLD:-80}"
    local crit_thresh="${RATE_CRITICAL_THRESHOLD:-100}"

    if [ "${RATE_SHOW_PROJECTION:-true}" != "true" ]; then
        echo ""
        return
    fi

    # Only show projection indicator when it's warning or critical
    if [ "$projected" -lt "$warn_thresh" ] 2>/dev/null; then
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

    local cache_key="rate_limits_usage"
    local cache_ttl="${RATE_CACHE_TTL:-120}"
    local history_file="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.usage_history"
    local usage_data=""
    local fresh_fetch=false
    local in_backoff=false
    local backoff_remaining=0

    # Check if we're in API backoff (429 cooldown)
    backoff_remaining=$(_check_backoff)
    if [ $? -eq 0 ]; then
        in_backoff=true
    fi

    # Read from shared cache if fresh
    usage_data=$(cache_get "$cache_key" "$cache_ttl")

    # Fetch fresh data if cache miss
    if [ -z "$usage_data" ]; then
        usage_data=$(_get_claude_usage)
        if [ -n "$usage_data" ]; then
            cache_set "$cache_key" "$usage_data"
            fresh_fetch=true
        else
            # API failed (429/error/timeout) — serve stale cache if available
            usage_data=$(cache_get "$cache_key" 86400)
        fi
    fi

    if [ -z "$usage_data" ]; then
        # No data at all - show backoff countdown if applicable
        if [ "$in_backoff" = "true" ]; then
            local cooldown_display
            if [ "$backoff_remaining" -ge 3600 ]; then
                cooldown_display="$((backoff_remaining / 3600))h$((backoff_remaining % 3600 / 60))m"
            elif [ "$backoff_remaining" -ge 60 ]; then
                cooldown_display="$((backoff_remaining / 60))m"
            else
                cooldown_display="${backoff_remaining}s"
            fi
            local pause_icon=$(get_icon "⏸" "WAIT:")
            echo "${pause_icon} API cooldown ${cooldown_display}"
        else
            local result=""
            [ "$show_5h" = "true" ] && result="${label_5h}:--"
            [ "$show_7d" = "true" ] && result="${result:+$result }${label_7d}:--"
            echo "$result"
        fi
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
            current_size=$(_file_size "$history_file")
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

    # Add stale/backoff indicator when showing cached data during API cooldown
    local stale_marker=""
    if [ "$in_backoff" = "true" ] && [ "$fresh_fetch" != "true" ]; then
        local cooldown_display
        if [ "$backoff_remaining" -ge 3600 ]; then
            cooldown_display="$((backoff_remaining / 3600))h$((backoff_remaining % 3600 / 60))m"
        elif [ "$backoff_remaining" -ge 60 ]; then
            cooldown_display="$((backoff_remaining / 60))m"
        else
            cooldown_display="${backoff_remaining}s"
        fi
        stale_marker=" $(get_icon '⏸' 'WAIT')${cooldown_display}"
    fi

    if [ "$show_5h" = "true" ]; then
        result="${label_5h}:${five_hour_int}% ${five_hour_usage_ind}${five_hour_status}"
        if [ "$show_time" = "true" ] && [ "$five_hour_remaining" -gt 0 ] 2>/dev/null && ! is_compact "$compact"; then
            result="${result} ($(format_time_remaining $five_hour_remaining))"
        fi
    fi

    if [ "$show_7d" = "true" ]; then
        local seven_day_part="${label_7d}:${seven_day_int}% ${seven_day_usage_ind}${seven_day_status}"
        if [ "$show_time" = "true" ] && [ "$seven_day_remaining" -gt 0 ] 2>/dev/null && ! is_compact "$compact"; then
            seven_day_part="${seven_day_part} ($(format_time_remaining $seven_day_remaining))"
        fi
        result="${result:+$result }${seven_day_part}"
    fi

    # Append backoff indicator at the end
    result="${result}${stale_marker}"

    echo "$result"
}
