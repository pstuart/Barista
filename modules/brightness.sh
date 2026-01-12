# =============================================================================
# Brightness Module - Shows screen brightness (macOS)
# =============================================================================
# Configuration options:
#   BRIGHTNESS_ICON         - Icon for brightness (default: ☀️)
#   BRIGHTNESS_SHOW_PERCENT - Show percentage (default: true)
#   BRIGHTNESS_SHOW_BAR     - Show progress bar (default: false)
#   BRIGHTNESS_BAR_WIDTH    - Width of progress bar (default: 5)
# =============================================================================

# Note: Requires brightness command (brew install brightness) or
# uses AppleScript fallback on macOS

module_brightness() {
    local icon=$(get_icon "${BRIGHTNESS_ICON:-☀️}" "BRT:")
    local show_pct="${BRIGHTNESS_SHOW_PERCENT:-true}"
    local show_bar="${BRIGHTNESS_SHOW_BAR:-false}"
    local bar_width="${BRIGHTNESS_BAR_WIDTH:-5}"

    local brightness=""

    if [ "$(uname)" = "Darwin" ]; then
        # Try brightness command first
        if command -v brightness >/dev/null 2>&1; then
            brightness=$(brightness -l 2>/dev/null | grep -o 'brightness [0-9.]*' | awk '{print $2}' | head -1)
            if [ -n "$brightness" ]; then
                brightness=$(echo "scale=0; $brightness * 100" | bc -l 2>/dev/null || echo "")
            fi
        fi

        # Fallback to AppleScript
        if [ -z "$brightness" ]; then
            brightness=$(osascript -e 'tell application "System Events" to tell appearance preferences to get brightness' 2>/dev/null)
            if [ -n "$brightness" ]; then
                brightness=$(echo "scale=0; $brightness * 100" | bc -l 2>/dev/null || echo "")
            fi
        fi

        # Another fallback using ioreg
        if [ -z "$brightness" ]; then
            local raw=$(ioreg -c AppleBacklightDisplay 2>/dev/null | grep -i "brightness" | head -1 | grep -o '"brightness"=[0-9]*' | cut -d= -f2)
            if [ -n "$raw" ]; then
                # This is typically 0-1024, convert to percentage
                brightness=$((raw * 100 / 1024))
            fi
        fi
    else
        # Linux: try various methods
        if [ -f /sys/class/backlight/*/brightness ]; then
            local curr=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -1)
            local max=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -1)
            if [ -n "$curr" ] && [ -n "$max" ] && [ "$max" -gt 0 ]; then
                brightness=$((curr * 100 / max))
            fi
        # Try xbacklight
        elif command -v xbacklight >/dev/null 2>&1; then
            brightness=$(xbacklight -get 2>/dev/null | cut -d. -f1)
        fi
    fi

    if [ -z "$brightness" ]; then
        return
    fi

    local brightness_int=$(printf "%.0f" "$brightness" 2>/dev/null || echo "0")

    local result="$icon"

    if [ "$show_pct" = "true" ]; then
        result="$result ${brightness_int}%"
    fi

    if [ "$show_bar" = "true" ]; then
        local bar=$(render_progress_bar "$brightness_int" 100 "$bar_width")
        result="$result $bar"
    fi

    echo "$result"
}
