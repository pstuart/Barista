# shellcheck shell=bash
# =============================================================================
# Brightness Module - Shows screen brightness (macOS)
# =============================================================================
# Configuration options:
#   BRIGHTNESS_ICON         - Icon for brightness (default: ☀️)
#   BRIGHTNESS_SHOW_PERCENT - Show percentage (default: true)
#   BRIGHTNESS_SHOW_BAR     - Show progress bar (default: false)
#   BRIGHTNESS_BAR_WIDTH    - Width of progress bar (default: 5)
# =============================================================================

# macOS: prefer IODisplayParameters via ioreg (works without third-party tools).
# Optional accelerator: brew install brightness. Legacy appearance-preferences
# AppleScript and fixed 0–1024 AppleBacklightDisplay scale are dead on modern macOS.

module_brightness() {
    local icon
    icon=$(get_icon "${BRIGHTNESS_ICON:-☀️}" "BRT:")
    local show_pct="${BRIGHTNESS_SHOW_PERCENT:-true}"
    local show_bar="${BRIGHTNESS_SHOW_BAR:-false}"
    local bar_width="${BRIGHTNESS_BAR_WIDTH:-5}"

    local brightness=""

    if [ "$(uname)" = "Darwin" ]; then
        # Prefer brew brightness CLI when present (fast, direct)
        if command -v brightness >/dev/null 2>&1; then
            brightness=$(brightness -l 2>/dev/null | grep -o 'brightness [0-9.]*' | awk '{print $2}' | head -1)
            if [ -n "$brightness" ]; then
                brightness=$(echo "scale=0; $brightness * 100" | bc -l 2>/dev/null || echo "")
            fi
        fi

        # Primary fallback: IODisplayParameters "brightness"={min,max,value}
        # Live shape (Apple Silicon / modern macOS): max=65536, not 0–1024.
        if [ -z "$brightness" ]; then
            local dict max val
            # Isolate the brightness dict (not BrightnessMilliNits / rawBrightness)
            dict=$(ioreg -l 2>/dev/null | grep -o '"brightness"={"min"=[0-9]*,"max"=[0-9]*,"value"=[0-9]*}' | head -1)
            if [ -n "$dict" ]; then
                max=$(echo "$dict" | grep -o '"max"=[0-9]*' | cut -d= -f2)
                val=$(echo "$dict" | grep -o '"value"=[0-9]*' | cut -d= -f2)
                if [ -n "$max" ] && [ "$max" -gt 0 ] && [ -n "$val" ]; then
                    brightness=$((val * 100 / max))
                fi
            fi
        fi

        # Last resort: rawBrightness with its own max (often 2047 on Apple Silicon)
        if [ -z "$brightness" ]; then
            local dict max val
            dict=$(ioreg -l 2>/dev/null | grep -o '"rawBrightness"={"min"=[0-9]*,"max"=[0-9]*,"value"=[0-9]*}' | head -1)
            if [ -n "$dict" ]; then
                max=$(echo "$dict" | grep -o '"max"=[0-9]*' | cut -d= -f2)
                val=$(echo "$dict" | grep -o '"value"=[0-9]*' | cut -d= -f2)
                if [ -n "$max" ] && [ "$max" -gt 0 ] && [ -n "$val" ]; then
                    brightness=$((val * 100 / max))
                fi
            fi
        fi
    else
        # Linux: try various methods
        if ls /sys/class/backlight/*/brightness >/dev/null 2>&1; then
            local curr
            curr=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -1)
            local max
            max=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -1)
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

    local brightness_int
    brightness_int=$(printf "%.0f" "$brightness" 2>/dev/null || echo "0")

    local result="$icon"

    if [ "$show_pct" = "true" ]; then
        result="$result ${brightness_int}%"
    fi

    if [ "$show_bar" = "true" ]; then
        local bar
        bar=$(progress_bar "$brightness_int" "$bar_width")
        result="$result $bar"
    fi

    echo "$result"
}
