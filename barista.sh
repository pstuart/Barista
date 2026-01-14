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
# 3. User config (~/.claude/barista.conf)
# 4. Per-directory config (.barista.conf in current_dir)

load_config "$CONFIG_FILE"

USER_CONFIG="$HOME/.claude/barista.conf"
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
                    sections="${sections}${SEPARATOR}${output}"
                else
                    sections="$output"
                fi
            fi
        fi
    done
    IFS="$old_ifs"

    # =============================================================================
    # OUTPUT
    # =============================================================================

    echo "$sections"
}

# Run main function
main
