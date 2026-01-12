#!/bin/bash

# =============================================================================
# Barista - Serving up fresh stats for Claude Code ☕
# =============================================================================
# A feature-rich, modular statusline for Claude Code CLI
#
# Configuration: Edit barista.conf to enable/disable modules
# Modules: Add/remove files in the modules/ directory
#
# Author: Patrick D. Stuart (https://github.com/pstuart)
# License: MIT
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

# Advanced defaults
CACHE_MAX_AGE=60
DEBUG_MODE="false"

# =============================================================================
# LOAD CONFIGURATION
# =============================================================================

if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
fi

# Also check for user config in ~/.claude
USER_CONFIG="$HOME/.claude/barista.conf"
if [ -f "$USER_CONFIG" ]; then
    . "$USER_CONFIG"
fi

# =============================================================================
# LOAD MODULES
# =============================================================================

# Load utility functions first
if [ -f "$MODULES_DIR/utils.sh" ]; then
    . "$MODULES_DIR/utils.sh"
fi

# Load all module files
for module_file in "$MODULES_DIR"/*.sh; do
    if [ -f "$module_file" ]; then
        basename_file=$(basename "$module_file")
        if [ "$basename_file" != "utils.sh" ]; then
            . "$module_file"
        fi
    fi
done

# =============================================================================
# MODULE EXECUTION
# =============================================================================

run_module() {
    local module_name="$1"
    local current_dir="$2"
    local input_json="$3"

    case "$module_name" in
        directory)
            type module_directory >/dev/null 2>&1 && module_directory "$current_dir"
            ;;
        context)
            type module_context >/dev/null 2>&1 && module_context "$input_json"
            ;;
        git)
            type module_git >/dev/null 2>&1 && module_git "$current_dir"
            ;;
        project)
            type module_project >/dev/null 2>&1 && module_project "$current_dir"
            ;;
        model)
            type module_model >/dev/null 2>&1 && module_model "$input_json"
            ;;
        cost)
            type module_cost >/dev/null 2>&1 && module_cost "$input_json"
            ;;
        rate-limits)
            type module_rate_limits >/dev/null 2>&1 && module_rate_limits
            ;;
        time)
            type module_time >/dev/null 2>&1 && module_time
            ;;
        battery)
            type module_battery >/dev/null 2>&1 && module_battery
            ;;
        cpu)
            type module_cpu >/dev/null 2>&1 && module_cpu
            ;;
        memory)
            type module_memory >/dev/null 2>&1 && module_memory
            ;;
        disk)
            type module_disk >/dev/null 2>&1 && module_disk
            ;;
        network)
            type module_network >/dev/null 2>&1 && module_network
            ;;
        uptime)
            type module_uptime >/dev/null 2>&1 && module_uptime
            ;;
        load)
            type module_load >/dev/null 2>&1 && module_load
            ;;
        temperature)
            type module_temperature >/dev/null 2>&1 && module_temperature
            ;;
        brightness)
            type module_brightness >/dev/null 2>&1 && module_brightness
            ;;
        docker)
            type module_docker >/dev/null 2>&1 && module_docker
            ;;
        node)
            type module_node >/dev/null 2>&1 && module_node
            ;;
        processes)
            type module_processes >/dev/null 2>&1 && module_processes
            ;;
        weather)
            type module_weather >/dev/null 2>&1 && module_weather
            ;;
        timezone)
            type module_timezone >/dev/null 2>&1 && module_timezone
            ;;
    esac
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Read input JSON from Claude Code
input=$(cat)

# Extract common data
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."')

# Default module order if not specified
DEFAULT_ORDER="directory,context,git,project,model,cost,rate-limits,time,battery"

# Use custom order if specified, otherwise use default
if [ -n "$MODULE_ORDER" ]; then
    module_order="$MODULE_ORDER"
else
    module_order="$DEFAULT_ORDER"
fi

# Build status line sections
sections=""

# Process modules in specified order (bash 3.2 compatible)
old_ifs="$IFS"
IFS=','
for module in $module_order; do
    # Trim whitespace
    module=$(echo "$module" | tr -d ' ')

    # Convert module name to variable name (e.g., rate-limits -> MODULE_RATE_LIMITS)
    var_name="MODULE_$(echo "$module" | tr '[:lower:]-' '[:upper:]_')"

    # Check if module is enabled
    eval "enabled=\${$var_name:-false}"

    if [ "$enabled" = "true" ]; then
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
