# =============================================================================
# Time Module - Shows current date and time
# =============================================================================
# Configuration options:
#   TIME_DATE_ICON   - Icon for date (default: 📅)
#   TIME_CLOCK_ICON  - Icon for time (default: 🕐)
#   TIME_SHOW_DATE   - Show date (default: true)
#   TIME_SHOW_TIME   - Show time (default: true)
#   TIME_DATE_FORMAT - Date format using strftime (default: %m/%d)
#   TIME_TIME_FORMAT - Time format using strftime (default: %I:%M %p)
#   TIME_COMPACT     - Compact mode with single icon (default: false)
# =============================================================================

module_time() {
    local date_icon=$(get_icon "${TIME_DATE_ICON:-📅}" "DATE:")
    local clock_icon=$(get_icon "${TIME_CLOCK_ICON:-🕐}" "TIME:")
    local show_date="${TIME_SHOW_DATE:-true}"
    local show_time="${TIME_SHOW_TIME:-true}"
    local date_fmt="${TIME_DATE_FORMAT:-%m/%d}"
    local time_fmt="${TIME_TIME_FORMAT:-%I:%M %p}"
    local compact="${TIME_COMPACT:-false}"

    local result=""

    # Compact mode: single combined output
    if [ "$compact" = "true" ] || is_compact; then
        if [ "$show_date" = "true" ] && [ "$show_time" = "true" ]; then
            result="$clock_icon $(date "+$date_fmt $time_fmt")"
        elif [ "$show_date" = "true" ]; then
            result="$date_icon $(date "+$date_fmt")"
        elif [ "$show_time" = "true" ]; then
            result="$clock_icon $(date "+$time_fmt")"
        fi
    else
        # Normal mode: separate date and time
        if [ "$show_date" = "true" ]; then
            result="$date_icon $(date "+$date_fmt")"
        fi

        if [ "$show_time" = "true" ]; then
            if [ -n "$result" ]; then
                result="$result $clock_icon $(date "+$time_fmt")"
            else
                result="$clock_icon $(date "+$time_fmt")"
            fi
        fi
    fi

    echo "$result"
}
