# =============================================================================
# Context Module - Shows context window usage with progress bar
# =============================================================================
# Configuration options:
#   CONTEXT_ICON                - Icon before context info (default: 📊)
#   CONTEXT_SHOW_PROGRESS_BAR   - Show visual progress bar (default: true)
#   CONTEXT_SHOW_PERCENTAGE     - Show percentage (default: true)
#   CONTEXT_SHOW_STATUS         - Show status indicator (default: true)
#   CONTEXT_SHOW_TOKENS_REMAINING - Show tokens until compact (default: true)
#   CONTEXT_COMPACT_ICON        - Icon for compact indicator (default: ⚡)
#   CONTEXT_WARNING_THRESHOLD   - Yellow warning at % (default: 60)
#   CONTEXT_CRITICAL_THRESHOLD  - Red warning at % (default: 75)
#   CONTEXT_COMPACT_THRESHOLD   - Auto-compact at % (default: 80)
# =============================================================================

module_context() {
    local input="$1"
    local icon=$(get_icon "${CONTEXT_ICON:-📊}" "CTX:")
    local show_bar="${CONTEXT_SHOW_PROGRESS_BAR:-true}"
    local show_pct="${CONTEXT_SHOW_PERCENTAGE:-true}"
    local show_status="${CONTEXT_SHOW_STATUS:-true}"
    local show_tokens="${CONTEXT_SHOW_TOKENS_REMAINING:-true}"
    local compact_icon="${CONTEXT_COMPACT_ICON:-⚡}"
    local warn_thresh=$(safe_int "${CONTEXT_WARNING_THRESHOLD:-60}" 60)
    local crit_thresh=$(safe_int "${CONTEXT_CRITICAL_THRESHOLD:-75}" 75)
    local compact_thresh=$(safe_int "${CONTEXT_COMPACT_THRESHOLD:-80}" 80)

    # Safely extract context window size with proper default
    local context_size=$(json_get_int "$input" '.context_window.context_window_size' 1)

    # Ensure context_size is never zero to avoid division errors
    if [ "$context_size" -le 0 ] 2>/dev/null; then
        context_size=200000  # Default Claude context size
    fi

    # Get usage data
    local usage=$(echo "$input" | jq '.context_window.current_usage' 2>/dev/null)

    if [ -n "$usage" ] && [ "$usage" != "null" ]; then
        # Get all token types with safe defaults
        local input_tokens=$(json_get_int "$usage" '.input_tokens' 0)
        local cache_creation=$(json_get_int "$usage" '.cache_creation_input_tokens' 0)
        local cache_read=$(json_get_int "$usage" '.cache_read_input_tokens' 0)
        local output_tokens=$(json_get_int "$usage" '.output_tokens' 0)

        # Calculate total
        local current_tokens=$((input_tokens + cache_creation + cache_read + output_tokens))

        # Safe percentage calculation
        local context_percent=$(safe_percent "$current_tokens" "$context_size" 0)

        # Calculate tokens until compact (safe math)
        local compact_threshold=$((context_size * compact_thresh / 100))
        local tokens_until_compact=$((compact_threshold - current_tokens))
        if [ "$tokens_until_compact" -lt 0 ]; then
            tokens_until_compact=0
        fi

        # Build output
        local result="$icon"

        # Progress bar
        if [ "$show_bar" = "true" ]; then
            local context_bar=$(progress_bar "$context_percent")
            result="$result ${context_bar}"
        fi

        # Percentage
        if [ "$show_pct" = "true" ]; then
            result="$result ${context_percent}%"
        fi

        # Status indicator
        if [ "$show_status" = "true" ]; then
            local status_ind=$(get_status "$context_percent" "$warn_thresh" "$crit_thresh")
            result="$result${status_ind}"
        fi

        # Tokens remaining
        if [ "$show_tokens" = "true" ]; then
            local until_compact_fmt=$(format_number "$tokens_until_compact")
            result="$result (${until_compact_fmt}→${compact_icon})"
        fi

        echo "$result"
    else
        # No data - show minimal output with zeros
        local result="$icon"

        if [ "$show_bar" = "true" ]; then
            result="$result $(progress_bar 0)"
        fi

        if [ "$show_pct" = "true" ]; then
            result="$result 0%"
        fi

        if [ "$show_status" = "true" ]; then
            result="$result$(get_status 0 "$warn_thresh" "$crit_thresh")"
        fi

        echo "$result"
    fi
}
