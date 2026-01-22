# =============================================================================
# Weather Module - Shows current weather (uses wttr.in)
# =============================================================================
# Configuration options:
#   WEATHER_LOCATION   - Location (default: auto-detect)
#   WEATHER_UNITS      - Units: "m" (metric), "u" (US), "M" (metric wind) (default: u)
#   WEATHER_SHOW_TEMP  - Show temperature (default: true)
#   WEATHER_SHOW_COND  - Show condition icon (default: true)
#   WEATHER_COMPACT    - Compact mode (default: false)
#   WEATHER_CACHE_TTL  - Cache duration in seconds (default: 1800)
# =============================================================================

module_weather() {
    local location="${WEATHER_LOCATION:-}"
    local units="${WEATHER_UNITS:-u}"
    local show_temp="${WEATHER_SHOW_TEMP:-true}"
    local show_cond="${WEATHER_SHOW_COND:-true}"
    local compact="${WEATHER_COMPACT:-false}"
    local cache_ttl="${WEATHER_CACHE_TTL:-1800}"

    local cache_file="/tmp/.claude_weather_cache"
    local weather_data=""

    # Check cache
    if [ -f "$cache_file" ]; then
        local cache_age=$(($(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || echo 0)))
        if [ "$cache_age" -lt "$cache_ttl" ]; then
            weather_data=$(cat "$cache_file")
        fi
    fi

    # Fetch fresh data if needed
    if [ -z "$weather_data" ]; then
        local url="https://wttr.in/${location}?format=%c%t&${units}"
        weather_data=$(curl -s --max-time 3 "$url" 2>/dev/null)
        if [ -n "$weather_data" ] && [ "$weather_data" != "Unknown location" ]; then
            echo "$weather_data" > "$cache_file" 2>/dev/null
        else
            weather_data=""
        fi
    fi

    if [ -z "$weather_data" ]; then
        return
    fi

    # Parse weather data (format: icon+temp like "☀️+72°F")
    local cond_icon=$(echo "$weather_data" | sed 's/[+].*//')
    local temp=$(echo "$weather_data" | sed 's/.*[+]//')

    local result=""

    if [ "$show_cond" = "true" ] && [ -n "$cond_icon" ]; then
        result="$cond_icon"
    fi

    if [ "$show_temp" = "true" ] && [ -n "$temp" ]; then
        if [ -n "$result" ]; then
            result="${result} ${temp}"
        else
            result="${temp}"
        fi
    fi

    # Trim whitespace
    result=$(echo "$result" | sed 's/^ *//;s/ *$//')

    echo "$result"
}
