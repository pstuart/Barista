# =============================================================================
# Utils Module - Shared utility functions
# =============================================================================

# Get status indicator based on value and thresholds
# Usage: get_status <value> <warning_threshold> <critical_threshold>
get_status() {
    local value=$1
    local warning=${2:-60}
    local critical=${3:-80}

    if [ "${USE_STATUS_INDICATORS:-true}" != "true" ]; then
        echo ""
        return
    fi

    local green="${STATUS_GREEN:-🟢}"
    local yellow="${STATUS_YELLOW:-🟡}"
    local red="${STATUS_RED:-🔴}"

    case "${STATUS_STYLE:-emoji}" in
        ascii)
            green="[OK]"
            yellow="[WARN]"
            red="[CRIT]"
            ;;
        dots)
            green="●"
            yellow="●"
            red="●"
            ;;
    esac

    if [ "$value" -ge "$critical" ] 2>/dev/null; then
        echo "$red"
    elif [ "$value" -ge "$warning" ] 2>/dev/null; then
        echo "$yellow"
    else
        echo "$green"
    fi
}

# Get icon based on USE_ICONS setting
# Usage: get_icon <icon> <fallback_text>
get_icon() {
    local icon="$1"
    local fallback="${2:-}"

    if [ "${USE_ICONS:-true}" = "true" ]; then
        echo "$icon"
    else
        echo "$fallback"
    fi
}

# Truncate string to max length
# Usage: truncate_string <string> <max_length>
truncate_string() {
    local str="$1"
    local max_len=${2:-0}

    if [ "$max_len" -gt 0 ] 2>/dev/null && [ ${#str} -gt "$max_len" ]; then
        local truncated=$(echo "$str" | cut -c1-$((max_len-3)))
        echo "${truncated}..."
    else
        echo "$str"
    fi
}

# Check if in compact mode (global or module-specific)
# Usage: is_compact <module_compact_var>
is_compact() {
    local module_compact="${1:-false}"

    if [ "${DISPLAY_MODE:-normal}" = "compact" ] || [ "$module_compact" = "true" ]; then
        return 0  # true
    fi
    return 1  # false
}

# Check if in verbose mode
is_verbose() {
    if [ "${DISPLAY_MODE:-normal}" = "verbose" ]; then
        return 0  # true
    fi
    return 1  # false
}

# Generate a progress bar
# Usage: progress_bar <percentage> [width] [filled_char] [empty_char]
progress_bar() {
    local percent=$1
    local width=${2:-${PROGRESS_BAR_WIDTH:-8}}
    local filled_char=${3:-${PROGRESS_BAR_FILLED:-█}}
    local empty_char=${4:-${PROGRESS_BAR_EMPTY:-░}}

    # Clamp percentage to 0-100
    if [ "$percent" -lt 0 ] 2>/dev/null; then percent=0; fi
    if [ "$percent" -gt 100 ] 2>/dev/null; then percent=100; fi

    local filled=$((percent * width / 100))
    local empty=$((width - filled))

    local bar=""
    local i=0
    while [ $i -lt $filled ]; do
        bar="${bar}${filled_char}"
        i=$((i + 1))
    done
    i=0
    while [ $i -lt $empty ]; do
        bar="${bar}${empty_char}"
        i=$((i + 1))
    done

    echo "$bar"
}

# Format seconds into human-readable time (e.g., "2h 15m" or "3d 5h")
format_time_remaining() {
    local seconds=$1
    if [ "$seconds" -le 0 ] 2>/dev/null; then
        echo "now"
        return
    fi

    local days=$((seconds / 86400))
    local hours=$(((seconds % 86400) / 3600))
    local minutes=$(((seconds % 3600) / 60))

    if [ "$days" -gt 0 ]; then
        echo "${days}d ${hours}h"
    elif [ "$hours" -gt 0 ]; then
        echo "${hours}h ${minutes}m"
    else
        echo "${minutes}m"
    fi
}

# Format large numbers with k/M suffix
format_number() {
    local num=$1
    if [ "$num" -ge 1000000 ] 2>/dev/null; then
        echo "$((num / 1000000))M"
    elif [ "$num" -ge 1000 ] 2>/dev/null; then
        echo "$((num / 1000))k"
    else
        echo "$num"
    fi
}

# Debug logging
log_debug() {
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "[$(date '+%H:%M:%S')] $1" >> "$HOME/.claude/statusline.log"
    fi
}
