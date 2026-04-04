# shellcheck shell=bash
# =============================================================================
# Battery Module - Shows battery percentage (macOS only)
# =============================================================================
# Configuration options:
#   BATTERY_ICON              - Icon for battery (default: 🔋)
#   BATTERY_SHOW_CHARGING     - Show charging indicator (default: true)
#   BATTERY_CHARGING_ICON     - Icon when charging (default: ⚡)
#   BATTERY_LOW_ICON          - Icon when low (default: 🪫)
#   BATTERY_CRITICAL_ICON     - Icon when critical (default: 🔴)
#   BATTERY_LOW_THRESHOLD     - Low battery threshold (default: 20)
#   BATTERY_CRITICAL_THRESHOLD - Critical threshold (default: 10)
#   BATTERY_SHOW_PERCENTAGE   - Show percentage number (default: true)
# =============================================================================

module_battery() {
    local icon="${BATTERY_ICON:-🔋}"
    local show_charging="${BATTERY_SHOW_CHARGING:-true}"
    local charging_icon="${BATTERY_CHARGING_ICON:-⚡}"
    local low_icon="${BATTERY_LOW_ICON:-🪫}"
    local critical_icon="${BATTERY_CRITICAL_ICON:-🔴}"
    local low_thresh="${BATTERY_LOW_THRESHOLD:-20}"
    local crit_thresh="${BATTERY_CRITICAL_THRESHOLD:-10}"
    local show_pct="${BATTERY_SHOW_PERCENTAGE:-true}"

    # Get battery info
    local batt_info=$(pmset -g batt 2>/dev/null)
    if [ -z "$batt_info" ]; then
        return
    fi

    local battery=$(echo "$batt_info" | grep -o '[0-9]*%' | head -1)
    if [ -z "$battery" ]; then
        return
    fi

    # Extract percentage number
    local pct_num=$(echo "$battery" | tr -d '%')

    # Determine icon based on level
    local display_icon="$icon"
    if [ "$pct_num" -le "$crit_thresh" ] 2>/dev/null; then
        display_icon=$(get_icon "$critical_icon" "CRIT:")
    elif [ "$pct_num" -le "$low_thresh" ] 2>/dev/null; then
        display_icon=$(get_icon "$low_icon" "LOW:")
    else
        display_icon=$(get_icon "$icon" "BAT:")
    fi

    # Check if charging
    local charging=""
    if [ "$show_charging" = "true" ]; then
        if echo "$batt_info" | grep -q "AC Power\|charging"; then
            charging=" $charging_icon"
        fi
    fi

    # Build output
    if [ "$show_pct" = "true" ]; then
        echo "$display_icon $battery$charging"
    else
        echo "$display_icon$charging"
    fi
}
