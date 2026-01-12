# =============================================================================
# Model Module - Shows current Claude model and output style
# =============================================================================
# Configuration options:
#   MODEL_ICON              - Icon before model name (default: 🤖)
#   MODEL_SHOW_OUTPUT_STYLE - Show output style (default: true)
#   MODEL_COMPACT           - Use abbreviated model names (default: false)
#   MODEL_STYLE             - "model", "style", "both" (default: both)
# =============================================================================

module_model() {
    local input="$1"
    local icon=$(get_icon "${MODEL_ICON:-🤖}" "MODEL:")
    local show_style="${MODEL_SHOW_OUTPUT_STYLE:-true}"
    local compact="${MODEL_COMPACT:-false}"
    local style="${MODEL_STYLE:-both}"

    local model_name=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
    local output_style=$(echo "$input" | jq -r '.output_style.name // "default"')

    # Compact model names
    if [ "$compact" = "true" ] || is_compact; then
        model_name=$(echo "$model_name" | sed 's/Claude //')
    fi

    # Build output based on style
    local result="$icon"

    case "$style" in
        model)
            result="$result $model_name"
            ;;
        style)
            result="$result ($output_style)"
            ;;
        *)  # both (default)
            if [ "$show_style" = "true" ] && [ "$output_style" != "default" ]; then
                result="$result $model_name ($output_style)"
            else
                result="$result $model_name"
            fi
            ;;
    esac

    echo "$result"
}
