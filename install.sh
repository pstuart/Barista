#!/bin/bash

# =============================================================================
# Barista Installer
# =============================================================================
# Installs Barista - the modular statusline for Claude Code CLI
#
# Usage:
#   ./install.sh                Install with interactive module selection
#   ./install.sh --uninstall    Uninstall and restore previous statusline
#   ./install.sh --force        Install with all defaults (no prompts)
#   ./install.sh --defaults     Install with core modules enabled
#   ./install.sh --no-emoji     Disable emojis in installer and config
#   ./install.sh --no-color     Disable colors in installer output
#   ./install.sh --minimal      Quick install with minimal modules
# =============================================================================

# Do NOT use set -e - we handle errors explicitly

# =============================================================================
# CONFIGURATION FLAGS (can be set via command line or interactively)
# =============================================================================
USE_EMOJI="true"
USE_COLOR="true"
INSTALL_MODE="interactive"
STATUS_STYLE="emoji"
PROGRESS_FILLED="█"
PROGRESS_EMPTY="░"

# =============================================================================
# COLOR DEFINITIONS
# =============================================================================
setup_colors() {
    if [ "$USE_COLOR" = "true" ] && [ -t 1 ]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        MAGENTA='\033[0;35m'
        BOLD='\033[1m'
        DIM='\033[2m'
        NC='\033[0m'
    else
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        CYAN=''
        MAGENTA=''
        BOLD=''
        DIM=''
        NC=''
    fi
}

# =============================================================================
# PATHS
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BARISTA_DIR="$CLAUDE_DIR/barista"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
BACKUP_DIR="$CLAUDE_DIR/.barista-backup"
BACKUP_MANIFEST="$BACKUP_DIR/manifest.json"

# =============================================================================
# MODULE DEFINITIONS
# =============================================================================
# Format: "module_name:default_enabled:category"
declare -a CORE_MODULES=(
    "directory:true:core"
    "context:true:core"
    "git:true:core"
    "project:true:core"
    "model:true:core"
    "cost:true:core"
    "rate-limits:true:core"
    "time:true:core"
    "battery:true:core"
)

declare -a SYSTEM_MODULES=(
    "cpu:false:system"
    "memory:false:system"
    "disk:false:system"
    "network:false:system"
    "uptime:false:system"
    "load:false:system"
    "temperature:false:system"
    "brightness:false:system"
    "processes:false:system"
)

declare -a DEV_MODULES=(
    "docker:false:dev"
    "node:false:dev"
)

declare -a EXTRA_MODULES=(
    "weather:false:extra"
    "timezone:false:extra"
)

# All modules combined
declare -a ALL_MODULES=("${CORE_MODULES[@]}" "${SYSTEM_MODULES[@]}" "${DEV_MODULES[@]}" "${EXTRA_MODULES[@]}")

# Selected modules (array of module names)
declare -a SELECTED_MODULES=()

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Get emoji or text fallback
emoji() {
    if [ "$USE_EMOJI" = "true" ]; then
        echo "$1"
    else
        echo "$2"
    fi
}

# Print functions
print_info() {
    local icon=$(emoji "i" "i")
    echo -e "${BLUE}${icon}${NC} $1"
}

print_success() {
    local icon=$(emoji "$(printf '\xE2\x9C\x93')" "+")
    echo -e "${GREEN}${icon}${NC} $1"
}

print_warning() {
    local icon=$(emoji "!" "!")
    echo -e "${YELLOW}${icon}${NC} $1"
}

print_error() {
    local icon=$(emoji "x" "x")
    echo -e "${RED}${icon}${NC} $1"
}

print_header() {
    echo -e "${BOLD}${CYAN}$1${NC}"
}

# Get module description
get_module_description() {
    local module="$1"
    local icon_mode="$2"  # "icon", "text", or "both"

    local icon=""
    local text=""

    case "$module" in
        # Core modules
        directory)    icon="$(emoji '📁' '[D]')"; text="Current directory name" ;;
        context)      icon="$(emoji '📊' '[C]')"; text="Context window usage with progress bar" ;;
        git)          icon="$(emoji '🌿' '[G]')"; text="Git branch, status, and file count" ;;
        project)      icon="$(emoji '⚡' '[P]')"; text="Project type detection (Nuxt, Rust, etc.)" ;;
        model)        icon="$(emoji '🤖' '[M]')"; text="Claude model and output style" ;;
        cost)         icon="$(emoji '💰' '[$]')"; text="Session cost, burn rate, and TPM" ;;
        rate-limits)  icon="$(emoji '⏱️ ' '[R]')"; text="5-hour and 7-day rate limits" ;;
        time)         icon="$(emoji '🕐' '[T]')"; text="Current date and time" ;;
        battery)      icon="$(emoji '🔋' '[B]')"; text="Battery percentage (macOS)" ;;
        # System modules
        cpu)          icon="$(emoji '💻' '[CPU]')"; text="CPU usage percentage" ;;
        memory)       icon="$(emoji '🧠' '[MEM]')"; text="Memory/RAM usage" ;;
        disk)         icon="$(emoji '💾' '[DSK]')"; text="Disk space usage" ;;
        network)      icon="$(emoji '🌐' '[NET]')"; text="Network info (IP address)" ;;
        uptime)       icon="$(emoji '⏱️ ' '[UP]')"; text="System uptime" ;;
        load)         icon="$(emoji '📊' '[LD]')"; text="System load average" ;;
        temperature)  icon="$(emoji '🌡️ ' '[TMP]')"; text="CPU temperature" ;;
        brightness)   icon="$(emoji '☀️ ' '[BRT]')"; text="Screen brightness (macOS)" ;;
        processes)    icon="$(emoji '🔄' '[PRC]')"; text="Process count" ;;
        # Dev tools
        docker)       icon="$(emoji '🐳' '[DOC]')"; text="Docker container status" ;;
        node)         icon="$(emoji '⬢ ' '[NOD]')"; text="Node.js version" ;;
        # Extra
        weather)      icon="$(emoji '🌤️ ' '[WTH]')"; text="Weather (via wttr.in)" ;;
        timezone)     icon="$(emoji '🌍' '[TZ]')"; text="Multiple timezone clocks" ;;
        *)            icon="?"; text="Unknown module" ;;
    esac

    case "$icon_mode" in
        icon) echo "$icon" ;;
        text) echo "$text" ;;
        *) echo "$icon $text" ;;
    esac
}

# Parse module definition string
get_module_name() { echo "$1" | cut -d: -f1; }
get_module_default() { echo "$1" | cut -d: -f2; }
get_module_category() { echo "$1" | cut -d: -f3; }

# Check if module is in selected array
is_module_selected() {
    local module="$1"
    for sel in "${SELECTED_MODULES[@]}"; do
        if [ "$sel" = "$module" ]; then
            return 0
        fi
    done
    return 1
}

# Add module to selection
select_module() {
    local module="$1"
    if ! is_module_selected "$module"; then
        SELECTED_MODULES+=("$module")
    fi
}

# Remove module from selection
deselect_module() {
    local module="$1"
    local new_array=()
    for sel in "${SELECTED_MODULES[@]}"; do
        if [ "$sel" != "$module" ]; then
            new_array+=("$sel")
        fi
    done
    SELECTED_MODULES=("${new_array[@]}")
}

# Toggle module selection
toggle_module() {
    local module="$1"
    if is_module_selected "$module"; then
        deselect_module "$module"
        return 1
    else
        select_module "$module"
        return 0
    fi
}

# =============================================================================
# BANNER
# =============================================================================
show_banner() {
    echo ""
    echo -e "${CYAN}"
    cat << 'EOF'
    ____             _      __
   / __ )____ ______(_)____/ /_____ _
  / __  / __ `/ ___/ / ___/ __/ __ `/
 / /_/ / /_/ / /  / (__  ) /_/ /_/ /
/_____/\__,_/_/  /_/____/\__/\__,_/
EOF
    echo -e "${NC}"
    local coffee=$(emoji "☕" "")
    echo -e "  ${DIM}Serving up fresh stats for Claude Code${NC} $coffee"
    echo ""
}

# =============================================================================
# MULTISELECT MODULE SELECTION
# =============================================================================

# Display multiselect menu for a category of modules
multiselect_category() {
    local category_name="$1"
    local category_desc="$2"
    shift 2
    local modules=("$@")

    local count=${#modules[@]}
    if [ "$count" -eq 0 ]; then
        return
    fi

    echo ""
    echo -e "${BOLD}${MAGENTA}=== $category_name ===${NC}"
    [ -n "$category_desc" ] && echo -e "${DIM}$category_desc${NC}"
    echo ""

    # Build numbered list
    local i=1
    local module_names=()
    for mod_def in "${modules[@]}"; do
        local name=$(get_module_name "$mod_def")
        local desc=$(get_module_description "$name" "both")
        local selected=""

        if is_module_selected "$name"; then
            selected="${GREEN}[x]${NC}"
        else
            selected="${DIM}[ ]${NC}"
        fi

        printf "  ${CYAN}%2d)${NC} %s %s\n" "$i" "$selected" "$desc"
        module_names+=("$name")
        i=$((i + 1))
    done

    echo ""
    echo -e "  ${DIM}Enter numbers to toggle (e.g., 1,3,5 or 1-3,7 or 'all' or 'none')${NC}"
    echo -e "  ${DIM}Press Enter to continue to next category${NC}"
    echo ""

    read -p "  Toggle modules: " input

    if [ -z "$input" ]; then
        return
    fi

    # Handle special keywords
    case "$input" in
        all|ALL)
            for name in "${module_names[@]}"; do
                select_module "$name"
            done
            echo -e "  ${GREEN}Selected all $category_name${NC}"
            return
            ;;
        none|NONE)
            for name in "${module_names[@]}"; do
                deselect_module "$name"
            done
            echo -e "  ${DIM}Deselected all $category_name${NC}"
            return
            ;;
    esac

    # Parse ranges and individual numbers
    # Replace commas with spaces, then handle ranges
    local parsed=""
    input=$(echo "$input" | tr ',' ' ')

    for item in $input; do
        if echo "$item" | grep -q '-'; then
            # Handle range like 1-3
            local start=$(echo "$item" | cut -d'-' -f1)
            local end=$(echo "$item" | cut -d'-' -f2)
            if [ "$start" -le "$end" ] 2>/dev/null; then
                for ((n=start; n<=end; n++)); do
                    parsed="$parsed $n"
                done
            fi
        else
            parsed="$parsed $item"
        fi
    done

    # Toggle selected modules
    for num in $parsed; do
        num=$(echo "$num" | tr -d ' ')
        if [ "$num" -ge 1 ] 2>/dev/null && [ "$num" -le "$count" ] 2>/dev/null; then
            local idx=$((num - 1))
            local name="${module_names[$idx]}"
            if toggle_module "$name"; then
                echo -e "  ${GREEN}+ $name${NC}"
            else
                echo -e "  ${DIM}- $name${NC}"
            fi
        fi
    done
}

# Main interactive module selection
interactive_module_selection() {
    local pkg_icon=$(emoji "📦" "[PKG]")
    print_header "$pkg_icon Module Selection"
    echo ""
    echo "Select which modules to include in your statusline."
    echo "Use the multiselect interface to toggle modules on/off."
    echo ""

    # Initialize with default selections
    for mod_def in "${ALL_MODULES[@]}"; do
        local name=$(get_module_name "$mod_def")
        local default=$(get_module_default "$mod_def")
        if [ "$default" = "true" ]; then
            select_module "$name"
        fi
    done

    # Show current selection summary
    echo -e "${DIM}Default selection: ${#SELECTED_MODULES[@]} modules${NC}"
    echo ""

    # Core modules
    multiselect_category "Core Modules (Claude Code specific)" "" "${CORE_MODULES[@]}"

    # System modules
    multiselect_category "System Monitoring" "These show system stats (CPU, memory, etc.)" "${SYSTEM_MODULES[@]}"

    # Dev tools
    multiselect_category "Development Tools" "Docker, Node.js, and other dev tools" "${DEV_MODULES[@]}"

    # Extra modules
    multiselect_category "Extra Modules" "Weather, multiple timezones, etc." "${EXTRA_MODULES[@]}"

    # Final summary
    echo ""
    print_header "Selected Modules (${#SELECTED_MODULES[@]} total)"
    echo ""

    if [ ${#SELECTED_MODULES[@]} -eq 0 ]; then
        print_warning "No modules selected. Using core defaults."
        for mod_def in "${CORE_MODULES[@]}"; do
            select_module "$(get_module_name "$mod_def")"
        done
    fi

    # Display selection grouped by category
    for category in "core" "system" "dev" "extra"; do
        local cat_modules=()
        for mod_def in "${ALL_MODULES[@]}"; do
            local name=$(get_module_name "$mod_def")
            local cat=$(get_module_category "$mod_def")
            if [ "$cat" = "$category" ] && is_module_selected "$name"; then
                cat_modules+=("$name")
            fi
        done

        if [ ${#cat_modules[@]} -gt 0 ]; then
            local cat_label=""
            case "$category" in
                core) cat_label="Core" ;;
                system) cat_label="System" ;;
                dev) cat_label="Dev Tools" ;;
                extra) cat_label="Extra" ;;
            esac
            echo -e "  ${CYAN}$cat_label:${NC} ${cat_modules[*]}"
        fi
    done
    echo ""
}

# =============================================================================
# MODULE ORDERING
# =============================================================================
interactive_module_ordering() {
    local count=${#SELECTED_MODULES[@]}
    if [ "$count" -le 1 ]; then
        return
    fi

    echo ""
    local ruler_icon=$(emoji "📐" "[ORD]")
    print_header "$ruler_icon Module Order"
    echo ""
    echo "Current order:"

    local i=1
    for module in "${SELECTED_MODULES[@]}"; do
        echo -e "  ${CYAN}$i)${NC} $module"
        i=$((i + 1))
    done
    echo ""

    read -p "Would you like to reorder the modules? [y/N]: " reorder
    if [ "$reorder" != "y" ] && [ "$reorder" != "Y" ]; then
        return
    fi

    echo ""
    echo "Enter the new order as comma-separated numbers."
    echo "Example: 2,1,3,4 would put module 2 first, then 1, then 3, then 4"
    echo "Or enter 'reverse' to reverse the order"
    echo ""

    read -p "New order: " order_input

    if [ -z "$order_input" ]; then
        print_info "Keeping current order"
        return
    fi

    # Handle reverse keyword
    if [ "$order_input" = "reverse" ]; then
        local reversed=()
        for ((i=${#SELECTED_MODULES[@]}-1; i>=0; i--)); do
            reversed+=("${SELECTED_MODULES[$i]}")
        done
        SELECTED_MODULES=("${reversed[@]}")
        print_success "Reversed module order"
        return
    fi

    # Parse order
    local order_nums=$(echo "$order_input" | tr ',' ' ')
    local new_order=()
    local valid=true
    local seen=()

    for num in $order_nums; do
        num=$(echo "$num" | tr -d ' ')
        if [ "$num" -ge 1 ] 2>/dev/null && [ "$num" -le "$count" ] 2>/dev/null; then
            # Check for duplicates
            for s in "${seen[@]}"; do
                if [ "$s" = "$num" ]; then
                    print_warning "Duplicate number: $num"
                    valid=false
                    break
                fi
            done
            if [ "$valid" = "true" ]; then
                seen+=("$num")
                local idx=$((num - 1))
                new_order+=("${SELECTED_MODULES[$idx]}")
            fi
        else
            print_warning "Invalid number: $num"
            valid=false
            break
        fi
    done

    if [ "$valid" = "true" ] && [ ${#new_order[@]} -eq $count ]; then
        SELECTED_MODULES=("${new_order[@]}")
        echo ""
        print_success "New order:"
        local j=1
        for module in "${SELECTED_MODULES[@]}"; do
            echo -e "  ${CYAN}$j)${NC} $module"
            j=$((j + 1))
        done
    else
        print_warning "Invalid order input. Keeping current order."
        print_info "Make sure to include all $count module numbers exactly once."
    fi
}

# =============================================================================
# DISPLAY PREFERENCES
# =============================================================================
interactive_display_preferences() {
    echo ""
    local style_icon=$(emoji "🎨" "[STY]")
    print_header "$style_icon Display Preferences"
    echo ""

    # Emoji preference
    echo -e "${BOLD}Icon Style:${NC}"
    echo ""
    echo "  1) $(emoji '📁' '[D]') Emoji icons (default)"
    echo "     Example: 📁 myproject | 📊 ████░░ 75% | 🌿 main"
    echo ""
    echo "  2) [D] ASCII/Text mode (no emojis)"
    echo "     Example: DIR: myproject | CTX: #### 75% | GIT: main"
    echo ""

    read -p "  Choose style [1-2, default=1]: " icon_choice

    case "$icon_choice" in
        2)
            USE_EMOJI="false"
            print_success "Using ASCII/Text mode (no emojis)"
            ;;
        *)
            USE_EMOJI="true"
            print_success "Using Emoji icons"
            ;;
    esac

    echo ""

    # Status indicator style
    echo -e "${BOLD}Status Indicators:${NC}"
    echo ""
    if [ "$USE_EMOJI" = "true" ]; then
        echo "  1) 🟢🟡🔴 Emoji circles (default)"
        echo "  2) ●●● Colored dots"
        echo "  3) [OK][WARN][CRIT] ASCII text"
    else
        echo "  1) [OK][WARN][CRIT] ASCII text (default for text mode)"
        echo "  2) ●●● Dots"
    fi
    echo ""

    read -p "  Choose indicator style [1-${USE_EMOJI:+3}${USE_EMOJI:-2}, default=1]: " status_choice

    if [ "$USE_EMOJI" = "true" ]; then
        case "$status_choice" in
            2) STATUS_STYLE="dots" ;;
            3) STATUS_STYLE="ascii" ;;
            *) STATUS_STYLE="emoji" ;;
        esac
    else
        case "$status_choice" in
            2) STATUS_STYLE="dots" ;;
            *) STATUS_STYLE="ascii" ;;
        esac
    fi

    echo ""

    # Progress bar style
    echo -e "${BOLD}Progress Bar Style:${NC}"
    echo ""
    if [ "$USE_EMOJI" = "true" ]; then
        echo "  1) ████░░░░ Block style (default)"
        echo "  2) ▓▓▓▓░░░░ Shaded blocks"
        echo "  3) ●●●●○○○○ Circles"
        echo "  4) ####---- ASCII"
    else
        echo "  1) ####---- ASCII (default for text mode)"
        echo "  2) ====---- Equals"
        echo "  3) ****.... Stars"
    fi
    echo ""

    if [ "$USE_EMOJI" = "true" ]; then
        read -p "  Choose progress bar style [1-4, default=1]: " bar_choice
        case "$bar_choice" in
            2) PROGRESS_FILLED="▓"; PROGRESS_EMPTY="░" ;;
            3) PROGRESS_FILLED="●"; PROGRESS_EMPTY="○" ;;
            4) PROGRESS_FILLED="#"; PROGRESS_EMPTY="-" ;;
            *) PROGRESS_FILLED="█"; PROGRESS_EMPTY="░" ;;
        esac
    else
        read -p "  Choose progress bar style [1-3, default=1]: " bar_choice
        case "$bar_choice" in
            2) PROGRESS_FILLED="="; PROGRESS_EMPTY="-" ;;
            3) PROGRESS_FILLED="*"; PROGRESS_EMPTY="." ;;
            *) PROGRESS_FILLED="#"; PROGRESS_EMPTY="-" ;;
        esac
    fi

    echo ""
    print_success "Display preferences saved"
}

# =============================================================================
# CONFIGURATION GENERATION
# =============================================================================
generate_config() {
    local config_file="$1"

    cat > "$config_file" << 'HEADER'
# =============================================================================
# Barista Configuration
# =============================================================================
# Generated by install.sh
# Enable/disable modules by setting to "true" or "false"
# For full configuration options, see barista.conf in the repo
# =============================================================================

HEADER

    # Write global settings based on installer selections
    echo "# Global Settings" >> "$config_file"
    if [ "$USE_EMOJI" = "false" ]; then
        echo 'USE_ICONS="false"' >> "$config_file"
    else
        echo 'USE_ICONS="true"' >> "$config_file"
    fi

    # Status style
    echo "STATUS_STYLE=\"${STATUS_STYLE:-emoji}\"" >> "$config_file"

    # Progress bar characters
    echo "PROGRESS_BAR_FILLED=\"${PROGRESS_FILLED:-█}\"" >> "$config_file"
    echo "PROGRESS_BAR_EMPTY=\"${PROGRESS_EMPTY:-░}\"" >> "$config_file"
    echo "" >> "$config_file"

    # Write module enable/disable settings
    echo "# Module Settings" >> "$config_file"
    for mod_def in "${ALL_MODULES[@]}"; do
        local name=$(get_module_name "$mod_def")
        local var_name="MODULE_$(echo "$name" | tr '[:lower:]-' '[:upper:]_')"
        local enabled="false"

        if is_module_selected "$name"; then
            enabled="true"
        fi

        echo "$var_name=\"$enabled\"" >> "$config_file"
    done

    # Write module order
    echo "" >> "$config_file"
    echo "# Module display order (comma-separated)" >> "$config_file"
    local order_str=""
    for module in "${SELECTED_MODULES[@]}"; do
        if [ -z "$order_str" ]; then
            order_str="$module"
        else
            order_str="$order_str,$module"
        fi
    done
    echo "MODULE_ORDER=\"$order_str\"" >> "$config_file"

    # Write footer with basic settings
    cat >> "$config_file" << 'FOOTER'

# =============================================================================
# Display Settings
# =============================================================================

SEPARATOR=" | "
PROGRESS_BAR_WIDTH=8

# =============================================================================
# Advanced Settings
# =============================================================================

# Cache duration for expensive operations (seconds)
CACHE_MAX_AGE=60

# Enable debug logging
DEBUG_MODE="false"

# =============================================================================
# Per-Directory Overrides
# =============================================================================
# Barista supports per-directory configuration overrides.
# Create a .barista.conf file in any project directory to override settings
# for that project only. This is useful for:
#   - Minimal statusline in large monorepos
#   - Different modules for different project types
#   - Disabling slow modules in certain directories
FOOTER
}

# =============================================================================
# VALIDATION
# =============================================================================
validate_config() {
    local config_file="$1"
    local errors=0

    if [ ! -f "$config_file" ]; then
        return 0
    fi

    # Source the config to validate
    (
        . "$config_file" 2>/dev/null

        # Validate MODULE_ORDER contains valid modules
        if [ -n "$MODULE_ORDER" ]; then
            local order=$(echo "$MODULE_ORDER" | tr ',' ' ')
            for module in $order; do
                module=$(echo "$module" | tr -d ' ')
                local valid=false
                for mod_def in "${ALL_MODULES[@]}"; do
                    if [ "$(get_module_name "$mod_def")" = "$module" ]; then
                        valid=true
                        break
                    fi
                done
                if [ "$valid" = "false" ]; then
                    echo "Warning: Unknown module in MODULE_ORDER: $module"
                fi
            done
        fi

        # Validate threshold values are numeric
        for var in CONTEXT_WARNING_THRESHOLD CONTEXT_CRITICAL_THRESHOLD \
                   RATE_WARNING_THRESHOLD RATE_CRITICAL_THRESHOLD \
                   BATTERY_LOW_THRESHOLD BATTERY_CRITICAL_THRESHOLD; do
            eval "val=\${$var:-}"
            if [ -n "$val" ] && ! echo "$val" | grep -qE '^[0-9]+$'; then
                echo "Warning: $var should be a number, got: $val"
            fi
        done
    )

    return $errors
}

# =============================================================================
# BACKUP/RESTORE
# =============================================================================
detect_existing_statusline() {
    local existing_type=""
    local existing_command=""
    local existing_files=""

    if [ -f "$SETTINGS_FILE" ]; then
        existing_command=$(jq -r '.statusLine.command // empty' "$SETTINGS_FILE" 2>/dev/null)
        if [ -n "$existing_command" ]; then
            existing_type="command"
        fi
    fi

    if [ -d "$BARISTA_DIR" ]; then
        existing_files="$BARISTA_DIR (modular)"
    fi
    if [ -f "$CLAUDE_DIR/barista.sh" ]; then
        if [ -n "$existing_files" ]; then
            existing_files="$existing_files, $CLAUDE_DIR/barista.sh (single file)"
        else
            existing_files="$CLAUDE_DIR/barista.sh (single file)"
        fi
    fi

    if [ -n "$existing_command" ] || [ -n "$existing_files" ]; then
        echo "detected"
        echo "$existing_command"
        echo "$existing_files"
    else
        echo "none"
    fi
}

backup_existing_statusline() {
    print_info "Backing up existing statusline configuration..."

    mkdir -p "$BACKUP_DIR"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local manifest="{\"timestamp\": \"$timestamp\", \"files\": [], \"settings_statusline\": null}"

    if [ -f "$SETTINGS_FILE" ]; then
        local statusline_config=$(jq '.statusLine // null' "$SETTINGS_FILE" 2>/dev/null)
        if [ "$statusline_config" != "null" ] && [ -n "$statusline_config" ]; then
            manifest=$(echo "$manifest" | jq --argjson config "$statusline_config" '.settings_statusline = $config' 2>/dev/null) || {
                print_warning "Could not backup statusLine config"
            }
            print_success "Backed up statusLine config from settings.json"
        fi
    fi

    if [ -d "$BARISTA_DIR" ]; then
        local backup_modular="$BACKUP_DIR/barista-modular-$timestamp"
        cp -r "$BARISTA_DIR" "$backup_modular" && {
            manifest=$(echo "$manifest" | jq --arg path "$backup_modular" --arg orig "$BARISTA_DIR" \
                '.files += [{"original": $orig, "backup": $path, "type": "directory"}]' 2>/dev/null)
            print_success "Backed up Barista directory"
        }
    fi

    if [ -f "$CLAUDE_DIR/barista.sh" ]; then
        local backup_single="$BACKUP_DIR/barista.sh.$timestamp"
        cp "$CLAUDE_DIR/barista.sh" "$backup_single" && {
            manifest=$(echo "$manifest" | jq --arg path "$backup_single" --arg orig "$CLAUDE_DIR/barista.sh" \
                '.files += [{"original": $orig, "backup": $path, "type": "file"}]' 2>/dev/null)
            print_success "Backed up single-file barista.sh"
        }
    fi

    # Save manifest
    echo "$manifest" > "$BACKUP_MANIFEST" 2>/dev/null || {
        print_warning "Could not save backup manifest"
    }

    echo ""
    print_info "Backup location: $BACKUP_DIR"
    echo ""
}

restore_from_backup() {
    if [ ! -f "$BACKUP_MANIFEST" ]; then
        print_error "No backup manifest found at $BACKUP_MANIFEST"
        print_info "Cannot restore - no previous statusline was backed up"
        return 1
    fi

    print_info "Restoring previous statusline from backup..."
    echo ""

    local manifest
    manifest=$(cat "$BACKUP_MANIFEST") || {
        print_error "Could not read backup manifest"
        return 1
    }

    local timestamp=$(echo "$manifest" | jq -r '.timestamp // "unknown"')
    print_info "Restoring from backup created at: $timestamp"

    # Restore files
    echo "$manifest" | jq -c '.files[]' 2>/dev/null | while read -r file_info; do
        local original=$(echo "$file_info" | jq -r '.original')
        local backup=$(echo "$file_info" | jq -r '.backup')
        local type=$(echo "$file_info" | jq -r '.type')

        if [ -e "$backup" ]; then
            if [ "$type" = "directory" ]; then
                rm -rf "$original" 2>/dev/null
                cp -r "$backup" "$original" && print_success "Restored: $original"
            else
                rm -f "$original" 2>/dev/null
                cp "$backup" "$original" && print_success "Restored: $original"
            fi
        else
            print_warning "Backup not found: $backup"
        fi
    done

    # Restore settings.json statusLine
    local settings_statusline=$(echo "$manifest" | jq '.settings_statusline')
    if [ "$settings_statusline" != "null" ] && [ -f "$SETTINGS_FILE" ]; then
        local tmp_file=$(mktemp)
        if jq --argjson statusline "$settings_statusline" '.statusLine = $statusline' "$SETTINGS_FILE" > "$tmp_file" 2>/dev/null; then
            mv "$tmp_file" "$SETTINGS_FILE"
            print_success "Restored statusLine config in settings.json"
        else
            rm -f "$tmp_file"
            print_warning "Could not restore statusLine config"
        fi
    elif [ "$settings_statusline" = "null" ] && [ -f "$SETTINGS_FILE" ]; then
        local tmp_file=$(mktemp)
        if jq 'del(.statusLine)' "$SETTINGS_FILE" > "$tmp_file" 2>/dev/null; then
            mv "$tmp_file" "$SETTINGS_FILE"
            print_success "Removed statusLine from settings.json (none existed before)"
        else
            rm -f "$tmp_file"
        fi
    fi

    echo ""
    print_success "Restore complete!"
    print_info "Restart Claude Code to apply changes"
}

# =============================================================================
# UNINSTALL
# =============================================================================
do_uninstall() {
    show_banner
    print_header "Uninstalling Barista..."
    echo ""

    if [ -f "$BACKUP_MANIFEST" ]; then
        echo -e "${YELLOW}A backup of your previous statusline was found.${NC}"
        echo ""
        echo "Options:"
        echo "  1) Restore previous statusline from backup"
        echo "  2) Just remove current statusline (no restore)"
        echo "  3) Cancel"
        echo ""
        read -p "Choose an option [1-3]: " choice

        case $choice in
            1)
                [ -d "$BARISTA_DIR" ] && rm -rf "$BARISTA_DIR" && print_success "Removed Barista directory"
                [ -f "$CLAUDE_DIR/barista.sh" ] && rm "$CLAUDE_DIR/barista.sh" && print_success "Removed barista.sh"

                restore_from_backup

                echo ""
                read -p "Remove backup files? [y/N]: " remove_backup
                if [ "$remove_backup" = "y" ] || [ "$remove_backup" = "Y" ]; then
                    rm -rf "$BACKUP_DIR" && print_success "Removed backup directory"
                fi
                ;;
            2)
                [ -d "$BARISTA_DIR" ] && rm -rf "$BARISTA_DIR" && print_success "Removed Barista directory"
                [ -f "$CLAUDE_DIR/barista.sh" ] && rm "$CLAUDE_DIR/barista.sh" && print_success "Removed barista.sh"

                if [ -f "$SETTINGS_FILE" ]; then
                    local tmp_file=$(mktemp)
                    if jq 'del(.statusLine)' "$SETTINGS_FILE" > "$tmp_file" 2>/dev/null; then
                        mv "$tmp_file" "$SETTINGS_FILE"
                        print_success "Removed statusLine from settings.json"
                    else
                        rm -f "$tmp_file"
                    fi
                fi
                ;;
            *)
                print_info "Uninstall cancelled"
                exit 0
                ;;
        esac
    else
        [ -d "$BARISTA_DIR" ] && rm -rf "$BARISTA_DIR" && print_success "Removed Barista directory"
        [ -f "$CLAUDE_DIR/barista.sh" ] && rm "$CLAUDE_DIR/barista.sh" && print_success "Removed barista.sh"

        if [ -f "$SETTINGS_FILE" ]; then
            local tmp_file=$(mktemp)
            if jq 'del(.statusLine)' "$SETTINGS_FILE" > "$tmp_file" 2>/dev/null; then
                mv "$tmp_file" "$SETTINGS_FILE"
                print_success "Removed statusLine from settings.json"
            else
                rm -f "$tmp_file"
            fi
        fi
    fi

    echo ""
    print_success "Uninstall complete!"
    print_info "Restart Claude Code to apply changes"
}

# =============================================================================
# MAIN INSTALLATION
# =============================================================================
do_install() {
    local mode="$1"
    show_banner

    # Check requirements
    print_info "Checking requirements..."

    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed."
        echo ""
        echo "Install jq:"
        echo "  macOS:  brew install jq"
        echo "  Ubuntu: sudo apt-get install jq"
        echo "  Fedora: sudo dnf install jq"
        echo ""
        exit 1
    fi
    print_success "jq is installed"

    if ! command -v bc &> /dev/null; then
        print_warning "bc is not installed (burn rate/TPM calculations may not work)"
    else
        print_success "bc is installed"
    fi

    if [ ! -f "$SCRIPT_DIR/barista.sh" ]; then
        print_error "Source file not found: $SCRIPT_DIR/barista.sh"
        exit 1
    fi
    print_success "Source files found"

    echo ""

    # Detect existing statusline
    local detection=$(detect_existing_statusline)
    local first_line=$(echo "$detection" | head -1)

    if [ "$first_line" = "detected" ]; then
        local warn_icon=$(emoji "⚠️ " "[!]")
        print_header "$warn_icon Existing Statusline Detected"
        echo ""

        local existing_command=$(echo "$detection" | sed -n '2p')
        local existing_files=$(echo "$detection" | tail -n +3)

        [ -n "$existing_command" ] && echo -e "  Current command: ${CYAN}$existing_command${NC}"
        [ -n "$existing_files" ] && echo -e "  Existing files: ${YELLOW}$existing_files${NC}"

        echo ""
        echo -e "${YELLOW}${BOLD}WARNING:${NC} Installing will overwrite your existing statusline."
        echo -e "Your current statusline will be ${GREEN}backed up${NC} and can be ${GREEN}restored${NC}."
        echo ""

        if [ "$mode" = "interactive" ]; then
            read -p "Continue with installation? [y/N]: " confirm
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                print_info "Installation cancelled"
                exit 0
            fi
        fi

        echo ""
        backup_existing_statusline
    fi

    # Module selection based on mode
    case "$mode" in
        interactive)
            interactive_module_selection
            interactive_module_ordering
            interactive_display_preferences
            ;;
        minimal)
            # Just directory, context, git, model
            SELECTED_MODULES=("directory" "context" "git" "model")
            ;;
        *)
            # Use defaults (core modules)
            for mod_def in "${CORE_MODULES[@]}"; do
                local name=$(get_module_name "$mod_def")
                local default=$(get_module_default "$mod_def")
                if [ "$default" = "true" ]; then
                    select_module "$name"
                fi
            done
            ;;
    esac

    # Show summary
    echo ""
    local summary_icon=$(emoji "📋" "[SUM]")
    print_header "$summary_icon Installation Summary"
    echo ""
    echo "Modules to install (${#SELECTED_MODULES[@]} total):"

    local preview=""
    for module in "${SELECTED_MODULES[@]}"; do
        local icon=$(get_module_description "$module" "icon")
        echo -e "  ${GREEN}+${NC} $module"
        preview="$preview$icon "
    done

    echo ""
    echo -e "Preview: ${DIM}$preview${NC}"
    echo ""

    # Show display settings
    echo -e "${DIM}Display settings:${NC}"
    if [ "$USE_EMOJI" = "true" ]; then
        echo -e "  ${DIM}Icons: Emoji${NC}"
    else
        echo -e "  ${DIM}Icons: ASCII/Text${NC}"
    fi
    echo -e "  ${DIM}Status: ${STATUS_STYLE}${NC}"
    echo -e "  ${DIM}Progress: ${PROGRESS_FILLED}${PROGRESS_FILLED}${PROGRESS_FILLED}${PROGRESS_EMPTY}${PROGRESS_EMPTY}${NC}"
    echo ""

    if [ "$mode" = "interactive" ]; then
        read -p "Proceed with installation? [Y/n]: " final_confirm
        if [ "$final_confirm" = "n" ] || [ "$final_confirm" = "N" ]; then
            print_info "Installation cancelled"
            exit 0
        fi
    fi

    echo ""

    # Create directories
    mkdir -p "$CLAUDE_DIR" || {
        print_error "Could not create $CLAUDE_DIR"
        exit 1
    }

    # Remove existing installation
    [ -d "$BARISTA_DIR" ] && rm -rf "$BARISTA_DIR"
    [ -f "$CLAUDE_DIR/barista.sh" ] && rm "$CLAUDE_DIR/barista.sh"

    # Install files
    print_info "Installing Barista..."

    mkdir -p "$BARISTA_DIR" || {
        print_error "Could not create $BARISTA_DIR"
        exit 1
    }

    cp "$SCRIPT_DIR/barista.sh" "$BARISTA_DIR/" || {
        print_error "Could not copy barista.sh"
        exit 1
    }
    chmod +x "$BARISTA_DIR/barista.sh"

    mkdir -p "$BARISTA_DIR/modules"
    cp "$SCRIPT_DIR/modules/"*.sh "$BARISTA_DIR/modules/" || {
        print_error "Could not copy modules"
        exit 1
    }

    # Validate module files
    local module_count=$(ls -1 "$BARISTA_DIR/modules/"*.sh 2>/dev/null | wc -l | tr -d ' ')
    if [ "$module_count" -eq 0 ]; then
        print_warning "No module files found - statusline may not work correctly"
    else
        print_success "Installed $module_count module files"
    fi

    # Generate config
    generate_config "$BARISTA_DIR/barista.conf"

    # Validate generated config
    validate_config "$BARISTA_DIR/barista.conf"

    print_success "Installed statusline to $BARISTA_DIR"

    # Update settings.json
    print_info "Configuring settings.json..."

    if [ -f "$SETTINGS_FILE" ]; then
        local tmp_file=$(mktemp)
        if jq '.statusLine = {"type": "command", "command": "~/.claude/barista/barista.sh"}' "$SETTINGS_FILE" > "$tmp_file" 2>/dev/null; then
            mv "$tmp_file" "$SETTINGS_FILE"
            print_success "Updated settings.json"
        else
            rm -f "$tmp_file"
            print_warning "Could not update settings.json - you may need to configure manually"
        fi
    else
        cat > "$SETTINGS_FILE" << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/barista/barista.sh"
  }
}
EOF
        print_success "Created settings.json"
    fi

    # Test installation
    print_info "Verifying installation..."

    local test_json='{"workspace":{"current_dir":"'"$HOME"'"},"model":{"display_name":"Test"},"output_style":{"name":"default"},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":1000}}}'
    local test_output
    test_output=$(echo "$test_json" | "$BARISTA_DIR/barista.sh" 2>&1)

    if [ -n "$test_output" ] && [ ${#test_output} -gt 5 ]; then
        print_success "Statusline test passed!"
        echo ""
        echo "Sample output:"
        echo "  $test_output"
    else
        print_warning "Statusline produced minimal output - check for errors"
        print_info "Try running: echo '$test_json' | ~/.claude/barista/barista.sh"
    fi

    # Final message
    echo ""
    echo "================================================================"
    echo "                   Installation Complete!                       "
    echo "================================================================"
    echo ""
    print_success "Restart Claude Code to see your new statusline"
    echo ""
    echo "Configuration:"
    echo "  Edit:     $BARISTA_DIR/barista.conf"
    echo "  Modules:  $BARISTA_DIR/modules/"
    echo ""
    echo "Per-directory overrides:"
    echo "  Create .barista.conf in any project directory"
    echo ""

    if [ -f "$BACKUP_MANIFEST" ]; then
        echo -e "${GREEN}Your previous statusline was backed up.${NC}"
        echo -e "To restore it, run: ${CYAN}$0 --uninstall${NC}"
        echo ""
    fi
}

# =============================================================================
# HELP
# =============================================================================
show_help() {
    show_banner
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  (none)       Interactive install with multiselect module picker"
    echo "  --defaults   Install with core modules enabled (default order)"
    echo "  --minimal    Quick install with minimal modules (dir, context, git, model)"
    echo "  --force      Same as --defaults, no confirmation prompts"
    echo "  --no-emoji   Disable emojis in installer and generated config"
    echo "  --no-color   Disable colors in installer output"
    echo "  --uninstall  Uninstall and optionally restore previous statusline"
    echo "  --help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                      # Interactive multiselect installation"
    echo "  $0 --no-emoji           # Install without emojis"
    echo "  $0 --minimal --no-emoji # Minimal install, no emojis"
    echo ""
    echo -e "${BOLD}Available Modules:${NC}"
    echo ""
    echo -e "${CYAN}Core (enabled by default):${NC}"
    for mod_def in "${CORE_MODULES[@]}"; do
        local name=$(get_module_name "$mod_def")
        local desc=$(get_module_description "$name" "both")
        echo "  $name - $desc"
    done
    echo ""
    echo -e "${CYAN}System Monitoring:${NC}"
    for mod_def in "${SYSTEM_MODULES[@]}"; do
        local name=$(get_module_name "$mod_def")
        local desc=$(get_module_description "$name" "both")
        echo "  $name - $desc"
    done
    echo ""
    echo -e "${CYAN}Development Tools:${NC}"
    for mod_def in "${DEV_MODULES[@]}"; do
        local name=$(get_module_name "$mod_def")
        local desc=$(get_module_description "$name" "both")
        echo "  $name - $desc"
    done
    echo ""
    echo -e "${CYAN}Extra:${NC}"
    for mod_def in "${EXTRA_MODULES[@]}"; do
        local name=$(get_module_name "$mod_def")
        local desc=$(get_module_description "$name" "both")
        echo "  $name - $desc"
    done
    echo ""
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --no-emoji)
                USE_EMOJI="false"
                shift
                ;;
            --no-color)
                USE_COLOR="false"
                shift
                ;;
            --uninstall)
                INSTALL_MODE="uninstall"
                shift
                ;;
            --force)
                INSTALL_MODE="force"
                shift
                ;;
            --defaults)
                INSTALL_MODE="defaults"
                shift
                ;;
            --minimal)
                INSTALL_MODE="minimal"
                shift
                ;;
            --help|-h)
                INSTALL_MODE="help"
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Run '$0 --help' for usage information"
                exit 1
                ;;
        esac
    done
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    parse_args "$@"
    setup_colors

    case "$INSTALL_MODE" in
        uninstall)
            do_uninstall
            ;;
        help)
            show_help
            ;;
        force|defaults)
            do_install "defaults"
            ;;
        minimal)
            do_install "minimal"
            ;;
        *)
            do_install "interactive"
            ;;
    esac
}

main "$@"
