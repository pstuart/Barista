# =============================================================================
# Utils Module - Shared utility functions
# =============================================================================
# This module provides common functions used by all other modules.
# It must be loaded first before any other modules.
# =============================================================================

# =============================================================================
# CACHE SYSTEM
# =============================================================================
# Simple file-based caching for expensive operations (weather, network, etc.)

CACHE_DIR="${HOME}/.claude/barista-cache"

# Initialize cache directory
init_cache() {
    if [ ! -d "$CACHE_DIR" ]; then
        mkdir -p "$CACHE_DIR" 2>/dev/null
    fi
}

# Get cached value if not expired
# Usage: cache_get <key> [max_age_seconds]
# Returns: cached value or empty string if expired/missing
cache_get() {
    local key="$1"
    local max_age="${2:-${CACHE_MAX_AGE:-60}}"
    local cache_file="$CACHE_DIR/${key}"

    if [ ! -f "$cache_file" ]; then
        return 1
    fi

    # Check age
    local file_time
    if [[ "$OSTYPE" == "darwin"* ]]; then
        file_time=$(stat -f %m "$cache_file" 2>/dev/null)
    else
        file_time=$(stat -c %Y "$cache_file" 2>/dev/null)
    fi

    if [ -z "$file_time" ]; then
        return 1
    fi

    local current_time=$(date +%s)
    local age=$((current_time - file_time))

    if [ "$age" -gt "$max_age" ] 2>/dev/null; then
        # Cache expired
        return 1
    fi

    # Return cached value
    cat "$cache_file" 2>/dev/null
    return 0
}

# Set cache value
# Usage: cache_set <key> <value>
cache_set() {
    local key="$1"
    local value="$2"

    init_cache

    local cache_file="$CACHE_DIR/${key}"
    echo "$value" > "$cache_file" 2>/dev/null
}

# Clear specific cache key or all cache
# Usage: cache_clear [key]
cache_clear() {
    local key="$1"

    if [ -n "$key" ]; then
        rm -f "$CACHE_DIR/${key}" 2>/dev/null
    else
        rm -rf "$CACHE_DIR" 2>/dev/null
    fi
}

# =============================================================================
# SAFE NUMBER HANDLING
# =============================================================================
# Functions to handle null/empty/invalid numeric values safely

# Safely convert value to integer, with default
# Usage: safe_int <value> [default]
safe_int() {
    local val="$1"
    local default="${2:-0}"

    # Handle null, empty, or invalid
    if [ -z "$val" ] || [ "$val" = "null" ] || [ "$val" = "undefined" ]; then
        echo "$default"
        return
    fi

    # Remove any decimal portion
    val="${val%%.*}"

    # Check if it's a valid integer
    if echo "$val" | grep -qE '^-?[0-9]+$'; then
        echo "$val"
    else
        echo "$default"
    fi
}

# Safe division that avoids divide by zero
# Usage: safe_divide <numerator> <denominator> [default]
safe_divide() {
    local num=$(safe_int "$1" 0)
    local denom=$(safe_int "$2" 1)
    local default="${3:-0}"

    # Avoid divide by zero
    if [ "$denom" -eq 0 ] 2>/dev/null; then
        echo "$default"
        return
    fi

    echo $((num / denom))
}

# Safe percentage calculation
# Usage: safe_percent <value> <total> [default]
safe_percent() {
    local value=$(safe_int "$1" 0)
    local total=$(safe_int "$2" 1)
    local default="${3:-0}"

    # Avoid divide by zero
    if [ "$total" -eq 0 ] 2>/dev/null; then
        echo "$default"
        return
    fi

    echo $((value * 100 / total))
}

# =============================================================================
# COLOR THEME SYSTEM
# =============================================================================
# Themes define the visual style of status indicators and icons
# Call apply_theme() after loading config to set up theme-specific values

apply_theme() {
    local theme="${COLOR_THEME:-default}"

    case "$theme" in
        minimal)
            # Subtle, understated - simple geometric shapes
            STATUS_GREEN="${STATUS_GREEN:-◦}"
            STATUS_YELLOW="${STATUS_YELLOW:-◦}"
            STATUS_ORANGE="${STATUS_ORANGE:-◦}"
            STATUS_RED="${STATUS_RED:-●}"
            # Minimal icons - simple arrows and symbols
            DIRECTORY_ICON="${DIRECTORY_ICON:-→}"
            CONTEXT_ICON="${CONTEXT_ICON:-◐}"
            GIT_ICON="${GIT_ICON:-⎇}"
            MODEL_ICON="${MODEL_ICON:-◈}"
            COST_ICON="${COST_ICON:-$}"
            TIME_DATE_ICON="${TIME_DATE_ICON:-}"
            TIME_CLOCK_ICON="${TIME_CLOCK_ICON:-}"
            BATTERY_ICON="${BATTERY_ICON:-⚡}"
            CPU_ICON="${CPU_ICON:-▪}"
            MEMORY_ICON="${MEMORY_ICON:-▫}"
            NODE_ICON="${NODE_ICON:-⬡}"
            # Minimal progress bar
            PROGRESS_BAR_FILLED="${PROGRESS_BAR_FILLED:-▪}"
            PROGRESS_BAR_EMPTY="${PROGRESS_BAR_EMPTY:-·}"
            ;;

        vibrant)
            # Bold, expressive - colorful emoji with more impact
            STATUS_GREEN="${STATUS_GREEN:-💚}"
            STATUS_YELLOW="${STATUS_YELLOW:-💛}"
            STATUS_ORANGE="${STATUS_ORANGE:-🧡}"
            STATUS_RED="${STATUS_RED:-❤️}"
            # Vibrant icons - more expressive emoji
            DIRECTORY_ICON="${DIRECTORY_ICON:-📂}"
            CONTEXT_ICON="${CONTEXT_ICON:-🎯}"
            GIT_ICON="${GIT_ICON:-🔀}"
            MODEL_ICON="${MODEL_ICON:-🧠}"
            COST_ICON="${COST_ICON:-💸}"
            TIME_DATE_ICON="${TIME_DATE_ICON:-🗓️}"
            TIME_CLOCK_ICON="${TIME_CLOCK_ICON:-⏰}"
            BATTERY_ICON="${BATTERY_ICON:-🔌}"
            CPU_ICON="${CPU_ICON:-⚙️}"
            MEMORY_ICON="${MEMORY_ICON:-💾}"
            NODE_ICON="${NODE_ICON:-💎}"
            # Vibrant progress bar
            PROGRESS_BAR_FILLED="${PROGRESS_BAR_FILLED:-▓}"
            PROGRESS_BAR_EMPTY="${PROGRESS_BAR_EMPTY:-░}"
            ;;

        monochrome)
            # No color, pure ASCII - terminal friendly
            STATUS_GREEN="${STATUS_GREEN:-[OK]}"
            STATUS_YELLOW="${STATUS_YELLOW:-[~~]}"
            STATUS_ORANGE="${STATUS_ORANGE:-[!!]}"
            STATUS_RED="${STATUS_RED:-[XX]}"
            # ASCII text labels
            DIRECTORY_ICON="${DIRECTORY_ICON:-DIR:}"
            CONTEXT_ICON="${CONTEXT_ICON:-CTX:}"
            GIT_ICON="${GIT_ICON:-GIT:}"
            MODEL_ICON="${MODEL_ICON:-AI:}"
            COST_ICON="${COST_ICON:-\$:}"
            TIME_DATE_ICON="${TIME_DATE_ICON:-}"
            TIME_CLOCK_ICON="${TIME_CLOCK_ICON:-}"
            BATTERY_ICON="${BATTERY_ICON:-BAT:}"
            CPU_ICON="${CPU_ICON:-CPU:}"
            MEMORY_ICON="${MEMORY_ICON:-MEM:}"
            NODE_ICON="${NODE_ICON:-NODE:}"
            # ASCII progress bar
            PROGRESS_BAR_FILLED="${PROGRESS_BAR_FILLED:-#}"
            PROGRESS_BAR_EMPTY="${PROGRESS_BAR_EMPTY:--}"
            # Force ASCII status style
            STATUS_STYLE="ascii"
            USE_ICONS="false"
            ;;

        nerd)
            # Nerd Font icons - requires Nerd Font installed
            STATUS_GREEN="${STATUS_GREEN:-}"
            STATUS_YELLOW="${STATUS_YELLOW:-}"
            STATUS_ORANGE="${STATUS_ORANGE:-}"
            STATUS_RED="${STATUS_RED:-}"
            # Nerd Font icons
            DIRECTORY_ICON="${DIRECTORY_ICON:-}"
            CONTEXT_ICON="${CONTEXT_ICON:-}"
            GIT_ICON="${GIT_ICON:-}"
            MODEL_ICON="${MODEL_ICON:-}"
            COST_ICON="${COST_ICON:-}"
            TIME_DATE_ICON="${TIME_DATE_ICON:-}"
            TIME_CLOCK_ICON="${TIME_CLOCK_ICON:-}"
            BATTERY_ICON="${BATTERY_ICON:-}"
            CPU_ICON="${CPU_ICON:-}"
            MEMORY_ICON="${MEMORY_ICON:-}"
            NODE_ICON="${NODE_ICON:-}"
            # Nerd Font progress bar
            PROGRESS_BAR_FILLED="${PROGRESS_BAR_FILLED:-█}"
            PROGRESS_BAR_EMPTY="${PROGRESS_BAR_EMPTY:-░}"
            ;;

        *)
            # default - Standard emoji (no changes needed, uses config defaults)
            # Status indicators use standard colored circles
            STATUS_GREEN="${STATUS_GREEN:-🟢}"
            STATUS_YELLOW="${STATUS_YELLOW:-🟡}"
            STATUS_ORANGE="${STATUS_ORANGE:-🟠}"
            STATUS_RED="${STATUS_RED:-🔴}"
            ;;
    esac
}

# =============================================================================
# STATUS INDICATORS
# =============================================================================

# Get status indicator based on value and thresholds
# Usage: get_status <value> <warning_threshold> <critical_threshold>
get_status() {
    local value=$(safe_int "$1" 0)
    local warning=$(safe_int "$2" 60)
    local critical=$(safe_int "$3" 80)

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

    # Add spacing before indicator in normal/verbose mode, none in compact
    local prefix=""
    if [ "${DISPLAY_MODE:-normal}" != "compact" ]; then
        prefix=" "
    fi

    if [ "$value" -ge "$critical" ] 2>/dev/null; then
        echo "${prefix}${red}"
    elif [ "$value" -ge "$warning" ] 2>/dev/null; then
        echo "${prefix}${yellow}"
    else
        echo "${prefix}${green}"
    fi
}

# Get 4-level status indicator for rate limits
# Usage: get_status_4level <value> <low> <medium> <high> <critical>
# Returns: green (<low), yellow (low-medium), orange (medium-high), red (>=high)
get_status_4level() {
    local value=$(safe_int "$1" 0)
    local low=$(safe_int "$2" 50)
    local medium=$(safe_int "$3" 75)
    local high=$(safe_int "$4" 95)

    if [ "${USE_STATUS_INDICATORS:-true}" != "true" ]; then
        echo ""
        return
    fi

    local green="${STATUS_GREEN:-🟢}"
    local yellow="${STATUS_YELLOW:-🟡}"
    local orange="${STATUS_ORANGE:-🟠}"
    local red="${STATUS_RED:-🔴}"

    case "${STATUS_STYLE:-emoji}" in
        ascii)
            green="[OK]"
            yellow="[MED]"
            orange="[HIGH]"
            red="[CRIT]"
            ;;
        dots)
            green="●"
            yellow="●"
            orange="●"
            red="●"
            ;;
    esac

    # Add spacing before indicator in normal/verbose mode, none in compact
    local prefix=""
    if [ "${DISPLAY_MODE:-normal}" != "compact" ]; then
        prefix=" "
    fi

    if [ "$value" -ge "$high" ] 2>/dev/null; then
        echo "${prefix}${red}"
    elif [ "$value" -ge "$medium" ] 2>/dev/null; then
        echo "${prefix}${orange}"
    elif [ "$value" -ge "$low" ] 2>/dev/null; then
        echo "${prefix}${yellow}"
    else
        echo "${prefix}${green}"
    fi
}

# =============================================================================
# ICON HANDLING
# =============================================================================

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

# =============================================================================
# STRING UTILITIES
# =============================================================================

# Truncate string to max length
# Usage: truncate_string <string> <max_length>
truncate_string() {
    local str="$1"
    local max_len=$(safe_int "$2" 0)

    if [ "$max_len" -gt 0 ] && [ ${#str} -gt "$max_len" ]; then
        local truncated="${str:0:$((max_len-3))}"
        echo "${truncated}..."
    else
        echo "$str"
    fi
}

# =============================================================================
# DISPLAY MODE CHECKS
# =============================================================================

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

# =============================================================================
# PROGRESS BAR
# =============================================================================

# Generate a progress bar
# Usage: progress_bar <percentage> [width] [filled_char] [empty_char]
progress_bar() {
    local percent=$(safe_int "$1" 0)
    local width=$(safe_int "$2" "${PROGRESS_BAR_WIDTH:-8}")
    local filled_char="${3:-${PROGRESS_BAR_FILLED:-█}}"
    local empty_char="${4:-${PROGRESS_BAR_EMPTY:-░}}"

    # Clamp percentage to 0-100
    if [ "$percent" -lt 0 ]; then percent=0; fi
    if [ "$percent" -gt 100 ]; then percent=100; fi

    # Avoid division by zero with width
    if [ "$width" -le 0 ]; then width=8; fi

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

# =============================================================================
# TIME FORMATTING
# =============================================================================

# Format seconds into human-readable time (e.g., "2h 15m" or "3d 5h")
format_time_remaining() {
    local seconds=$(safe_int "$1" 0)

    if [ "$seconds" -le 0 ]; then
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

# =============================================================================
# NUMBER FORMATTING
# =============================================================================

# Format large numbers with k/M suffix
format_number() {
    local num=$(safe_int "$1" 0)

    if [ "$num" -ge 1000000 ]; then
        echo "$((num / 1000000))M"
    elif [ "$num" -ge 1000 ]; then
        echo "$((num / 1000))k"
    else
        echo "$num"
    fi
}

# =============================================================================
# LOGGING
# =============================================================================

# Debug logging
log_debug() {
    if [ "${DEBUG_MODE:-false}" = "true" ]; then
        local log_file="${HOME}/.claude/barista.log"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$log_file" 2>/dev/null
    fi
}

# Log error (always logs if DEBUG_MODE is on)
log_error() {
    log_debug "ERROR: $1"
}

# =============================================================================
# JSON PARSING HELPERS
# =============================================================================

# Safely extract JSON value with default
# Usage: json_get <json> <path> [default]
# Note: Requires jq
json_get() {
    local json="$1"
    local path="$2"
    local default="${3:-}"

    if [ -z "$json" ] || [ "$json" = "null" ]; then
        echo "$default"
        return
    fi

    local value
    value=$(echo "$json" | jq -r "$path // empty" 2>/dev/null)

    if [ -z "$value" ] || [ "$value" = "null" ]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Safely extract numeric JSON value
# Usage: json_get_int <json> <path> [default]
json_get_int() {
    local json="$1"
    local path="$2"
    local default="${3:-0}"

    local value
    value=$(json_get "$json" "$path" "$default")
    safe_int "$value" "$default"
}
