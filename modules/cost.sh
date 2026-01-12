# =============================================================================
# Cost Module - Shows session cost, burn rate, and TPM
# =============================================================================
# Configuration options:
#   COST_ICON           - Icon before cost (default: 💰)
#   COST_SHOW_BURN_RATE - Show burn rate $/hour (default: true)
#   COST_SHOW_TPM       - Show tokens per minute (default: true)
#   COST_TPM_ICON       - Icon for TPM (default: ⚡)
#   COST_DECIMAL_PLACES - Decimal places for cost (default: 2)
#   COST_COMPACT        - Compact mode (default: false)
#   COST_MINIMUM_DISPLAY - Hide if below this amount (default: 0.01)
# =============================================================================

module_cost() {
    local input="$1"
    local icon=$(get_icon "${COST_ICON:-💰}" "COST:")
    local show_burn="${COST_SHOW_BURN_RATE:-true}"
    local show_tpm="${COST_SHOW_TPM:-true}"
    local tpm_icon="${COST_TPM_ICON:-⚡}"
    local decimals="${COST_DECIMAL_PLACES:-2}"
    local compact="${COST_COMPACT:-false}"
    local min_display="${COST_MINIMUM_DISPLAY:-0.01}"

    local result=""

    local session_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
    local session_duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

    # Check minimum display threshold
    if [ "$session_cost" != "0" ] && [ "$session_cost" != "null" ]; then
        local above_min=$(echo "$session_cost >= $min_display" | bc -l 2>/dev/null || echo "1")
        if [ "$above_min" != "1" ]; then
            return
        fi

        # Format cost with configurable decimal places
        local cost_fmt=$(printf "%.${decimals}f" "$session_cost")
        result="$icon \$${cost_fmt}"

        # Burn rate (skip in compact mode)
        if [ "$show_burn" = "true" ] && ! is_compact "$compact"; then
            if [ "$session_duration_ms" != "0" ] && [ "$session_duration_ms" != "null" ]; then
                local burn_rate_value=$(echo "scale=2; $session_cost * 3600000 / $session_duration_ms" | bc -l 2>/dev/null)
                if [ -n "$burn_rate_value" ] && [ "$burn_rate_value" != "0" ]; then
                    result="$result @\$${burn_rate_value}/h"
                fi
            fi
        fi
    fi

    # TPM (skip in compact mode)
    if [ "$show_tpm" = "true" ] && ! is_compact "$compact"; then
        if [ "$session_duration_ms" != "0" ] && [ "$session_duration_ms" != "null" ]; then
            local total_input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
            local total_output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
            local total_tokens=$((total_input_tokens + total_output_tokens))

            if [ "$total_tokens" -gt 0 ] 2>/dev/null; then
                local tpm_value=$(echo "scale=0; $total_tokens * 60000 / $session_duration_ms" | bc 2>/dev/null)
                if [ -n "$tpm_value" ] && [ "$tpm_value" != "0" ]; then
                    local tpm_fmt=$(format_number "$tpm_value")
                    if [ -n "$result" ]; then
                        result="$result ${tpm_icon}${tpm_fmt}tpm"
                    else
                        result="${tpm_icon}${tpm_fmt}tpm"
                    fi
                fi
            fi
        fi
    fi

    echo "$result"
}
