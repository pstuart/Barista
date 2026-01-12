# =============================================================================
# Temperature Module - Shows CPU/system temperature (macOS)
# =============================================================================
# Configuration options:
#   TEMP_ICON              - Icon for temp (default: 🌡️)
#   TEMP_UNITS             - Units: "C" or "F" (default: C)
#   TEMP_WARNING_THRESHOLD - Yellow at temp (default: 70)
#   TEMP_CRITICAL_THRESHOLD - Red at temp (default: 85)
#   TEMP_SHOW_STATUS       - Show status indicator (default: true)
# =============================================================================

# Note: On macOS, this requires either:
# - osx-cpu-temp (brew install osx-cpu-temp)
# - istats (gem install iStats)
# - powermetrics (requires sudo)

module_temperature() {
    local icon=$(get_icon "${TEMP_ICON:-🌡️}" "TEMP:")
    local units="${TEMP_UNITS:-C}"
    local warn_thresh="${TEMP_WARNING_THRESHOLD:-70}"
    local crit_thresh="${TEMP_CRITICAL_THRESHOLD:-85}"
    local show_status="${TEMP_SHOW_STATUS:-true}"

    local temp=""

    if [ "$(uname)" = "Darwin" ]; then
        # Try osx-cpu-temp first (most common)
        if command -v osx-cpu-temp >/dev/null 2>&1; then
            temp=$(osx-cpu-temp 2>/dev/null | grep -o '[0-9.]*' | head -1)
        # Try istats
        elif command -v istats >/dev/null 2>&1; then
            temp=$(istats cpu temp 2>/dev/null | grep -o '[0-9.]*' | head -1)
        # Try smctemp
        elif command -v smctemp >/dev/null 2>&1; then
            temp=$(smctemp -c 2>/dev/null | head -1)
        fi
    else
        # Linux: read from thermal zones
        if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
            local millideg=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
            if [ -n "$millideg" ]; then
                temp=$((millideg / 1000))
            fi
        # Try sensors command
        elif command -v sensors >/dev/null 2>&1; then
            temp=$(sensors 2>/dev/null | grep -i 'core 0' | grep -o '[0-9.]*' | head -1)
        fi
    fi

    if [ -z "$temp" ]; then
        return
    fi

    # Convert to integer for comparison
    local temp_int=$(printf "%.0f" "$temp" 2>/dev/null || echo "0")

    # Convert to Fahrenheit if requested
    local display_temp="$temp_int"
    if [ "$units" = "F" ]; then
        display_temp=$(echo "scale=0; ($temp_int * 9/5) + 32" | bc -l 2>/dev/null || echo "$temp_int")
        # Adjust thresholds for Fahrenheit
        warn_thresh=$(echo "scale=0; ($warn_thresh * 9/5) + 32" | bc -l 2>/dev/null || echo "158")
        crit_thresh=$(echo "scale=0; ($crit_thresh * 9/5) + 32" | bc -l 2>/dev/null || echo "185")
    fi

    local result="$icon ${display_temp}°${units}"

    if [ "$show_status" = "true" ]; then
        local status_ind=$(get_status "$temp_int" "${TEMP_WARNING_THRESHOLD:-70}" "${TEMP_CRITICAL_THRESHOLD:-85}")
        result="$result${status_ind}"
    fi

    echo "$result"
}
