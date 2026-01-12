# =============================================================================
# Timezone Module - Shows time in different timezones
# =============================================================================
# Configuration options:
#   TIMEZONE_ZONES     - Comma-separated list of timezones (default: UTC)
#   TIMEZONE_FORMAT    - Time format (default: %H:%M)
#   TIMEZONE_SHOW_LABEL - Show timezone label (default: true)
#   TIMEZONE_LABELS    - Custom labels comma-separated (default: zone abbreviation)
#   TIMEZONE_COMPACT   - Compact mode (default: false)
# =============================================================================

module_timezone() {
    local zones="${TIMEZONE_ZONES:-UTC}"
    local format="${TIMEZONE_FORMAT:-%H:%M}"
    local show_label="${TIMEZONE_SHOW_LABEL:-true}"
    local labels="${TIMEZONE_LABELS:-}"
    local compact="${TIMEZONE_COMPACT:-false}"

    local result=""
    local i=0

    # Split zones by comma
    local old_ifs="$IFS"
    IFS=','
    for zone in $zones; do
        # Trim whitespace
        zone=$(echo "$zone" | sed 's/^ *//;s/ *$//')

        if [ -z "$zone" ]; then
            continue
        fi

        local time_str=""
        if [ "$(uname)" = "Darwin" ]; then
            time_str=$(TZ="$zone" date +"$format" 2>/dev/null)
        else
            time_str=$(TZ="$zone" date +"$format" 2>/dev/null)
        fi

        if [ -z "$time_str" ]; then
            continue
        fi

        local label=""
        if [ "$show_label" = "true" ]; then
            # Get custom label or derive from zone
            if [ -n "$labels" ]; then
                local j=0
                for l in $labels; do
                    if [ "$j" = "$i" ]; then
                        label=$(echo "$l" | sed 's/^ *//;s/ *$//')
                        break
                    fi
                    j=$((j + 1))
                done
            fi

            if [ -z "$label" ]; then
                # Derive label from zone name
                label=$(echo "$zone" | sed 's|.*/||' | cut -c1-3 | tr '[:lower:]' '[:upper:]')
            fi
        fi

        local part=""
        if [ -n "$label" ]; then
            if is_compact "$compact"; then
                part="${label}:${time_str}"
            else
                part="${label}: ${time_str}"
            fi
        else
            part="$time_str"
        fi

        if [ -n "$result" ]; then
            result="$result | $part"
        else
            result="$part"
        fi

        i=$((i + 1))
    done
    IFS="$old_ifs"

    echo "$result"
}
