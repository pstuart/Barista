# shellcheck shell=bash
# =============================================================================
# Model Module - Shows current Claude model and output style
# =============================================================================
# Configuration options:
#   MODEL_ICON              - Icon before model name (default: 🤖)
#   MODEL_SHOW_OUTPUT_STYLE - Show output style (default: true)
#   MODEL_COMPACT           - Use abbreviated model names (default: false)
#   MODEL_STYLE             - "model", "style", "both" (default: both)
#   MODEL_SHOW_THINKING     - Show thinking state / reasoning effort (default: false)
#   MODEL_THINKING_ICON     - Icon before thinking segment (default: ✦)
# =============================================================================

# Build the optional thinking segment from the statusline JSON.
# Prints "<icon> On · <effort>" (icon and either part omitted when absent);
# prints nothing when the feature is disabled or no thinking data exists.
model_thinking_segment() {
    local input="$1"

    if [ "${MODEL_SHOW_THINKING:-false}" != "true" ]; then
        return 0
    fi

    # Absent, null, or false thinking yields an empty state; effort must be a
    # non-empty string. try/catch guards scalar parents (e.g. .model as string).
    local thinking_state
    thinking_state=$(echo "$input" | jq -r '
        try (
            (if (.thinking | type) == "object"
                then (.thinking.enabled // .thinking.on)
                else (.thinking // .model.thinking) end) as $t
            | if ($t == true or $t == "true" or $t == "on" or $t == "enabled")
              then "On" else "" end
        ) catch ""
    ' 2>/dev/null)

    local effort
    effort=$(echo "$input" | jq -r '
        try (
            def effort_text:
              if type == "string" and length > 0 then .
              elif type == "object" then (.level // .name // "" | if type == "string" then . else "" end)
              else "" end;
            (
              (.effort | effort_text) as $top
              | (if (.thinking | type) == "object" then (.thinking.effort | effort_text) else "" end) as $nested
              | (if (.model | type) == "object" then (.model.effort | effort_text) else "" end) as $model
              | (if (.model | type) == "object" then (.model.reasoning_effort | effort_text) else "" end) as $reasoning
              | [$top, $nested, $model, $reasoning] | map(select(length > 0)) | first // ""
            )
        ) catch ""
    ' 2>/dev/null)

    local text=""
    if [ -n "$thinking_state" ] && [ -n "$effort" ]; then
        text="On · $effort"
    elif [ -n "$thinking_state" ]; then
        text="On"
    elif [ -n "$effort" ]; then
        text="$effort"
    else
        return 0
    fi

    local icon
    icon=$(get_icon "${MODEL_THINKING_ICON:-✦}" "")
    if [ -n "$icon" ]; then
        echo "$icon $text"
    else
        echo "$text"
    fi
}

module_model() {
    local input="$1"
    local icon=$(get_icon "${MODEL_ICON:-🤖}" "MODEL:")
    local show_style="${MODEL_SHOW_OUTPUT_STYLE:-true}"
    local compact="${MODEL_COMPACT:-false}"
    local style="${MODEL_STYLE:-both}"

    local model_name=$(echo "$input" | jq -r '.model.display_name // "Unknown"' 2>/dev/null)
    local output_style=$(echo "$input" | jq -r '.output_style.name // "default"' 2>/dev/null)

    # jq prints nothing when the input is not JSON or .model is not an object;
    # normalize to the documented fallbacks instead of rendering empty noise.
    if [ -z "$model_name" ]; then model_name="Unknown"; fi
    if [ -z "$output_style" ]; then output_style="default"; fi

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

    # Optional thinking segment (hidden unless MODEL_SHOW_THINKING=true and
    # the statusline JSON carries thinking/effort data)
    local thinking
    thinking=$(model_thinking_segment "$input")
    if [ -n "$thinking" ]; then
        result="$result $thinking"
    fi

    echo "$result"
}
