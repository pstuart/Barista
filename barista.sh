#!/bin/bash

# =============================================================================
# Barista - Serving up fresh stats for Claude Code
# =============================================================================
# A feature-rich, modular statusline for Claude Code CLI
#
# Configuration: Edit barista.conf to enable/disable modules
# Modules: Add/remove files in the modules/ directory
# Per-directory: Create .barista.conf in any project for overrides
#
# Author: Patrick D. Stuart (https://github.com/pstuart)
# License: MIT
# Requires: jq
# =============================================================================

# Determine script directory (handles symlinks)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
CONFIG_FILE="$SCRIPT_DIR/barista.conf"

# Determine Claude config directory (respects CLAUDE_CONFIG_DIR env var)
CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# =============================================================================
# DEFAULT CONFIGURATION
# =============================================================================

# Core module defaults
MODULE_DIRECTORY="true"
MODULE_CONTEXT="true"
MODULE_GIT="true"
MODULE_PROJECT="true"
MODULE_MODEL="true"
MODULE_COST="true"
MODULE_RATE_LIMITS="true"
MODULE_TIME="true"
MODULE_BATTERY="true"

# System monitoring module defaults (disabled by default)
MODULE_CPU="false"
MODULE_MEMORY="false"
MODULE_DISK="false"
MODULE_NETWORK="false"
MODULE_UPTIME="false"
MODULE_LOAD="false"
MODULE_TEMPERATURE="false"
MODULE_BRIGHTNESS="false"
MODULE_DOCKER="false"
MODULE_NODE="false"
MODULE_PROCESSES="false"
MODULE_WEATHER="false"
MODULE_TIMEZONE="false"

# Display defaults
SEPARATOR=" | "
PROGRESS_BAR_WIDTH=8
PROGRESS_BAR_FILLED="█"
PROGRESS_BAR_EMPTY="░"
USE_ICONS="true"
USE_STATUS_INDICATORS="true"
STATUS_STYLE="emoji"
DISPLAY_MODE="normal"

# Advanced defaults
CACHE_MAX_AGE=60
DEBUG_MODE="false"

# Terminal layout defaults
# Layout mode: "smart", "wrap", "truncate", "newline", or "none"
#   smart    - (default) Join with separator, wrap to new line at separator boundaries
#   newline  - Add newline at end, Claude's right-side appears on next line
#   wrap     - Pad output to line boundary (requires accurate terminal width)
#   truncate - Cut output with "..." to fit on same line as Claude's right-side
#   none     - No adjustments, natural terminal behavior
LAYOUT_MODE="smart"
TERMINAL_WIDTH=""            # Manual terminal width override (empty = auto-detect)
RIGHT_SIDE_RESERVE=20        # Space reserved on right side of terminal (used by smart/truncate modes)

# =============================================================================
# CONFIGURATION LOADING
# =============================================================================

# Load main config file
load_config() {
    local config_path="$1"
    if [ -f "$config_path" ]; then
        # shellcheck source=/dev/null
        . "$config_path"
        return 0
    fi
    return 1
}

# Load configuration in order of precedence:
# 1. Built-in defaults (above)
# 2. Script directory config (barista.conf)
# 3. User config ($CLAUDE_CONFIG_DIR/barista.conf)
# 4. Per-directory config (.barista.conf in current_dir)

load_config "$CONFIG_FILE"

USER_CONFIG="$CLAUDE_CONFIG_DIR/barista.conf"
load_config "$USER_CONFIG"

# =============================================================================
# LOAD MODULES
# =============================================================================

# Load utility functions first (required by all other modules)
if [ -f "$MODULES_DIR/utils.sh" ]; then
    # shellcheck source=/dev/null
    . "$MODULES_DIR/utils.sh"
else
    # Minimal fallback if utils.sh is missing
    get_icon() { echo "$1"; }
    get_status() { echo ""; }
    progress_bar() { echo ""; }
    format_number() { echo "$1"; }
    safe_int() { echo "${1:-0}"; }
    safe_percent() { echo "0"; }
    json_get() { echo "${3:-}"; }
    json_get_int() { echo "${3:-0}"; }
    log_debug() { :; }
fi

# Load all other module files
for module_file in "$MODULES_DIR"/*.sh; do
    if [ -f "$module_file" ]; then
        basename_file=$(basename "$module_file")
        if [ "$basename_file" != "utils.sh" ]; then
            # shellcheck source=/dev/null
            . "$module_file"
        fi
    fi
done

# =============================================================================
# MODULE REGISTRY
# =============================================================================
# Maps module names to their functions (compatible with Bash 3.2+)

get_module_function() {
    local module_name="$1"
    case "$module_name" in
        directory)    echo "module_directory" ;;
        context)      echo "module_context" ;;
        git)          echo "module_git" ;;
        project)      echo "module_project" ;;
        model)        echo "module_model" ;;
        cost)         echo "module_cost" ;;
        rate-limits)  echo "module_rate_limits" ;;
        time)         echo "module_time" ;;
        battery)      echo "module_battery" ;;
        cpu)          echo "module_cpu" ;;
        memory)       echo "module_memory" ;;
        disk)         echo "module_disk" ;;
        network)      echo "module_network" ;;
        uptime)       echo "module_uptime" ;;
        load)         echo "module_load" ;;
        temperature)  echo "module_temperature" ;;
        brightness)   echo "module_brightness" ;;
        docker)       echo "module_docker" ;;
        node)         echo "module_node" ;;
        processes)    echo "module_processes" ;;
        weather)      echo "module_weather" ;;
        timezone)     echo "module_timezone" ;;
        *)            echo "" ;;
    esac
}

# =============================================================================
# MODULE EXECUTION
# =============================================================================

run_module() {
    local module_name="$1"
    local current_dir="$2"
    local input_json="$3"

    # Get function name from registry
    local func_name
    func_name=$(get_module_function "$module_name")

    if [ -z "$func_name" ]; then
        log_debug "Unknown module: $module_name"
        return
    fi

    # Check if function exists
    if ! type "$func_name" >/dev/null 2>&1; then
        log_debug "Module function not found: $func_name"
        return
    fi

    # Call the appropriate module function with correct arguments
    case "$module_name" in
        directory)
            "$func_name" "$current_dir"
            ;;
        context|model|cost)
            "$func_name" "$input_json"
            ;;
        git|project)
            "$func_name" "$current_dir"
            ;;
        *)
            # Modules that take no arguments or handle their own
            "$func_name"
            ;;
    esac
}

# Check if a module is enabled
is_module_enabled() {
    local module_name="$1"

    # Convert module name to config variable name
    # e.g., "rate-limits" -> "MODULE_RATE_LIMITS"
    local var_name="MODULE_$(echo "$module_name" | tr '[:lower:]-' '[:upper:]_')"

    # Get value using indirect reference
    local enabled
    eval "enabled=\${$var_name:-false}"

    [ "$enabled" = "true" ]
}

# =============================================================================
# CONFIGURATION VALIDATION
# =============================================================================

validate_module_order() {
    local order="$1"

    if [ -z "$order" ]; then
        return 0
    fi

    local old_ifs="$IFS"
    IFS=','
    for module in $order; do
        module=$(echo "$module" | tr -d ' ')
        local func_name
        func_name=$(get_module_function "$module")
        if [ -z "$func_name" ]; then
            log_debug "Warning: Unknown module in MODULE_ORDER: $module"
        fi
    done
    IFS="$old_ifs"
}

# =============================================================================
# SMART LINE WRAPPING
# =============================================================================
# Joins modules with separator, wrapping to new lines at separator boundaries
# when content would exceed available terminal width

wrap_at_separators() {
    local sections="$1"
    local separator="$2"
    local right_reserve="${3:-20}"

    # Get terminal width
    local term_width
    if [ -n "${TERMINAL_WIDTH:-}" ]; then
        term_width="$TERMINAL_WIDTH"
    else
        term_width=$(tput cols 2>/dev/null || echo "${COLUMNS:-200}")
        term_width=${term_width:-200}
    fi

    local max_line_width=$((term_width - right_reserve))

    local output=""
    local current_line=""

    # Calculate visible separator length (strip ANSI codes)
    local sep_visible
    sep_visible=$(echo "$separator" | sed $'s/\033\[[0-9;]*m//g')
    local sep_len=${#sep_visible}

    # Process each section (newline-separated input)
    while IFS= read -r section || [ -n "$section" ]; do
        [ -z "$section" ] && continue

        # Calculate visible length (strip ANSI codes)
        local section_visible
        section_visible=$(echo "$section" | sed $'s/\033\[[0-9;]*m//g')
        local section_len=${#section_visible}

        if [ -z "$current_line" ]; then
            # First section on this line
            current_line="$section"
        else
            # Calculate what line would look like with this section added
            local current_visible
            current_visible=$(echo "$current_line" | sed $'s/\033\[[0-9;]*m//g')
            local current_len=${#current_visible}
            local projected_len=$((current_len + sep_len + section_len))

            if [ "$projected_len" -le "$max_line_width" ]; then
                # Fits on current line - add with separator
                current_line="${current_line}${separator}${section}"
            else
                # Doesn't fit - output current line and start new one
                if [ -n "$output" ]; then
                    output="${output}"$'\n'"${current_line}"
                else
                    output="$current_line"
                fi
                current_line="$section"
            fi
        fi
    done <<< "$sections"

    # Output the last line
    if [ -n "$current_line" ]; then
        if [ -n "$output" ]; then
            output="${output}"$'\n'"${current_line}"
        else
            output="$current_line"
        fi
    fi

    echo "$output"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Read input JSON from Claude Code
    local input
    input=$(cat)

    # Extract current directory
    local current_dir
    current_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."' 2>/dev/null)

    # Load per-directory config if it exists
    # This allows project-specific statusline customization
    if [ -n "$current_dir" ] && [ -d "$current_dir" ]; then
        local dir_config="$current_dir/.barista.conf"
        if [ -f "$dir_config" ]; then
            log_debug "Loading per-directory config: $dir_config"
            load_config "$dir_config"
        fi
    fi

    # Apply color theme settings (must be after all config loading)
    if type apply_theme >/dev/null 2>&1; then
        apply_theme
    fi

    # Adjust separator based on display mode
    # Normal/verbose modes get padded separators, compact mode gets no padding
    if [ "${DISPLAY_MODE:-normal}" = "compact" ]; then
        # Strip whitespace from separator for compact mode
        SEPARATOR=$(echo "$SEPARATOR" | tr -d ' ')
    fi

    # Default module order if not specified
    local DEFAULT_ORDER="directory,context,git,project,model,cost,rate-limits,time,battery"

    # Use custom order if specified, otherwise use default
    local module_order="${MODULE_ORDER:-$DEFAULT_ORDER}"

    # Validate module order
    validate_module_order "$module_order"

    # Build status line sections
    local sections=""

    # Process modules in specified order
    local old_ifs="$IFS"
    IFS=','
    for module in $module_order; do
        # Trim whitespace
        module=$(echo "$module" | tr -d ' ')

        # Skip empty entries
        [ -z "$module" ] && continue

        # Check if module is enabled
        if is_module_enabled "$module"; then
            local output
            output=$(run_module "$module" "$current_dir" "$input")

            if [ -n "$output" ]; then
                if [ -n "$sections" ]; then
                    sections="${sections}"$'\n'"${output}"
                else
                    sections="$output"
                fi
            fi
        fi
    done
    IFS="$old_ifs"

    # =============================================================================
    # TERMINAL-WIDTH-AWARE OUTPUT
    # =============================================================================

    local layout_mode="${LAYOUT_MODE:-smart}"
    local right_reserve="${RIGHT_SIDE_RESERVE:-20}"
    local output=""

    case "$layout_mode" in
        smart)
            # Smart mode (default): join with separator, wrap at separator boundaries
            # when content would exceed terminal width minus reserve
            output=$(wrap_at_separators "$sections" "$SEPARATOR" "$right_reserve")
            ;;
        newline)
            # Newline mode: join all with separator, add newline at end
            # Forces Claude's right-side to next line
            local first=true
            while IFS= read -r section || [ -n "$section" ]; do
                [ -z "$section" ] && continue
                if [ "$first" = true ]; then
                    output="$section"
                    first=false
                else
                    output="${output}${SEPARATOR}${section}"
                fi
            done <<< "$sections"
            output="${output}"$'\n'
            ;;
        wrap)
            # Wrap mode: join all with separator, pad to next line boundary
            local first=true
            while IFS= read -r section || [ -n "$section" ]; do
                [ -z "$section" ] && continue
                if [ "$first" = true ]; then
                    output="$section"
                    first=false
                else
                    output="${output}${SEPARATOR}${section}"
                fi
            done <<< "$sections"
            local term_width
            if [ -n "${TERMINAL_WIDTH:-}" ]; then
                term_width="$TERMINAL_WIDTH"
            else
                term_width=$(tput cols 2>/dev/null || echo "${COLUMNS:-200}")
                term_width=${term_width:-200}
            fi
            local visible_output
            visible_output=$(echo "$output" | sed $'s/\033\[[0-9;]*m//g')
            local output_len=${#visible_output}
            local remainder=$((output_len % term_width))
            if [ "$remainder" -ne 0 ]; then
                local padding_needed=$((term_width - remainder))
                local padding
                padding=$(printf "%${padding_needed}s" "")
                output="${output}${padding}"
            fi
            ;;
        truncate)
            # Truncate mode: join all with separator, cut to fit with Claude's right-side
            local first=true
            while IFS= read -r section || [ -n "$section" ]; do
                [ -z "$section" ] && continue
                if [ "$first" = true ]; then
                    output="$section"
                    first=false
                else
                    output="${output}${SEPARATOR}${section}"
                fi
            done <<< "$sections"
            local term_width
            if [ -n "${TERMINAL_WIDTH:-}" ]; then
                term_width="$TERMINAL_WIDTH"
            else
                term_width=$(tput cols 2>/dev/null || echo "${COLUMNS:-200}")
                term_width=${term_width:-200}
            fi
            local available_width=$((term_width - right_reserve))
            local visible_output
            visible_output=$(echo "$output" | sed $'s/\033\[[0-9;]*m//g')
            local output_len=${#visible_output}
            if [ "$output_len" -gt "$available_width" ]; then
                local truncate_at=$((available_width - 3))  # Room for "..."
                if [ "$truncate_at" -gt 0 ]; then
                    output="${output:0:$truncate_at}..."
                fi
            fi
            ;;
        none)
            # No layout adjustments - just join with separator
            local first=true
            while IFS= read -r section || [ -n "$section" ]; do
                [ -z "$section" ] && continue
                if [ "$first" = true ]; then
                    output="$section"
                    first=false
                else
                    output="${output}${SEPARATOR}${section}"
                fi
            done <<< "$sections"
            ;;
    esac

    echo "$output"
}

# Run main function
main
