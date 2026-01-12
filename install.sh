#!/bin/bash

# =============================================================================
# Barista Installer ☕
# =============================================================================
# Installs Barista - the modular statusline for Claude Code CLI
#
# Usage:
#   ./install.sh              Install with interactive module selection
#   ./install.sh --uninstall  Uninstall and restore previous statusline
#   ./install.sh --force      Install with all defaults (no prompts)
#   ./install.sh --defaults   Install with all modules enabled
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BARISTA_DIR="$CLAUDE_DIR/barista"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
BACKUP_DIR="$CLAUDE_DIR/.barista-backup"
BACKUP_MANIFEST="$BACKUP_DIR/manifest.json"

# Default core module order (enabled by default)
CORE_MODULE_ORDER="directory context git project model cost rate-limits time battery"

# System monitoring modules (disabled by default)
SYSTEM_MODULE_ORDER="cpu memory disk network uptime load temperature brightness processes"

# Development tools modules (disabled by default)
DEV_MODULE_ORDER="docker node"

# Extra modules (disabled by default)
EXTRA_MODULE_ORDER="weather timezone"

# All modules combined
ALL_MODULES="$CORE_MODULE_ORDER $SYSTEM_MODULE_ORDER $DEV_MODULE_ORDER $EXTRA_MODULE_ORDER"

# Default module order (just core modules)
DEFAULT_MODULE_ORDER="$CORE_MODULE_ORDER"

# Get module description
get_module_description() {
    case "$1" in
        # Core modules
        directory)    echo "📁 Current directory name" ;;
        context)      echo "📊 Context window usage with progress bar" ;;
        git)          echo "🌿 Git branch, status, and file count" ;;
        project)      echo "⚡ Project type detection (Nuxt, Rust, etc.)" ;;
        model)        echo "🤖 Claude model and output style" ;;
        cost)         echo "💰 Session cost, burn rate, and TPM" ;;
        rate-limits)  echo "⏱️  5-hour and 7-day rate limits" ;;
        time)         echo "🕐 Current date and time" ;;
        battery)      echo "🔋 Battery percentage (macOS)" ;;
        # System monitoring modules
        cpu)          echo "💻 CPU usage percentage" ;;
        memory)       echo "🧠 Memory/RAM usage" ;;
        disk)         echo "💾 Disk space usage" ;;
        network)      echo "🌐 Network info (IP address)" ;;
        uptime)       echo "⏱️  System uptime" ;;
        load)         echo "📊 System load average" ;;
        temperature)  echo "🌡️  CPU temperature (requires osx-cpu-temp)" ;;
        brightness)   echo "☀️  Screen brightness (macOS)" ;;
        processes)    echo "🔄 Process count" ;;
        # Development tools
        docker)       echo "🐳 Docker container status" ;;
        node)         echo "⬢  Node.js version" ;;
        # Extra modules
        weather)      echo "🌤️  Weather (via wttr.in)" ;;
        timezone)     echo "🌍 Multiple timezone clocks" ;;
        *)            echo "Unknown module" ;;
    esac
}

# Get module category
get_module_category() {
    case "$1" in
        directory|context|git|project|model|cost|rate-limits|time|battery)
            echo "core" ;;
        cpu|memory|disk|network|uptime|load|temperature|brightness|processes)
            echo "system" ;;
        docker|node)
            echo "dev" ;;
        weather|timezone)
            echo "extra" ;;
        *)
            echo "unknown" ;;
    esac
}

# Selected modules (populated during interactive setup)
SELECTED_MODULES=""

# Print with color
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_header() { echo -e "${BOLD}${CYAN}$1${NC}"; }

# Banner
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
    echo -e "  ${DIM}Serving up fresh stats for Claude Code${NC} ☕"
    echo ""
}

# Interactive module selection
interactive_module_selection() {
    print_header "📦 Module Selection"
    echo ""
    echo "Select which modules to include in your statusline."
    echo "Modules are grouped by category. You can reorder them in the next step."
    echo ""

    local selected=""

    # Core modules (enabled by default)
    echo -e "${BOLD}${MAGENTA}━━━ Core Modules (Claude Code specific) ━━━${NC}"
    echo ""
    for module in $CORE_MODULE_ORDER; do
        local desc=$(get_module_description "$module")
        echo -e "  ${CYAN}•${NC} ${BOLD}$module${NC}"
        echo -e "    ${DIM}$desc${NC}"
        read -p "    Include? [Y/n]: " choice
        if [ "$choice" != "n" ] && [ "$choice" != "N" ]; then
            if [ -z "$selected" ]; then
                selected="$module"
            else
                selected="$selected $module"
            fi
            echo -e "    ${GREEN}✓ Added${NC}"
        else
            echo -e "    ${DIM}✗ Skipped${NC}"
        fi
        echo ""
    done

    # System modules
    echo -e "${BOLD}${MAGENTA}━━━ System Monitoring Modules ━━━${NC}"
    echo -e "${DIM}These show system stats (CPU, memory, etc.)${NC}"
    echo ""
    read -p "Include system monitoring modules? [y/N]: " include_system
    if [ "$include_system" = "y" ] || [ "$include_system" = "Y" ]; then
        for module in $SYSTEM_MODULE_ORDER; do
            local desc=$(get_module_description "$module")
            echo -e "  ${CYAN}•${NC} ${BOLD}$module${NC}"
            echo -e "    ${DIM}$desc${NC}"
            read -p "    Include? [y/N]: " choice
            if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
                selected="$selected $module"
                echo -e "    ${GREEN}✓ Added${NC}"
            else
                echo -e "    ${DIM}✗ Skipped${NC}"
            fi
            echo ""
        done
    else
        echo -e "  ${DIM}Skipped system modules${NC}"
        echo ""
    fi

    # Development tools
    echo -e "${BOLD}${MAGENTA}━━━ Development Tools ━━━${NC}"
    echo -e "${DIM}Docker, Node.js, and other dev tools${NC}"
    echo ""
    read -p "Include development tools modules? [y/N]: " include_dev
    if [ "$include_dev" = "y" ] || [ "$include_dev" = "Y" ]; then
        for module in $DEV_MODULE_ORDER; do
            local desc=$(get_module_description "$module")
            echo -e "  ${CYAN}•${NC} ${BOLD}$module${NC}"
            echo -e "    ${DIM}$desc${NC}"
            read -p "    Include? [y/N]: " choice
            if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
                selected="$selected $module"
                echo -e "    ${GREEN}✓ Added${NC}"
            else
                echo -e "    ${DIM}✗ Skipped${NC}"
            fi
            echo ""
        done
    else
        echo -e "  ${DIM}Skipped dev tools modules${NC}"
        echo ""
    fi

    # Extra modules
    echo -e "${BOLD}${MAGENTA}━━━ Extra Modules ━━━${NC}"
    echo -e "${DIM}Weather, multiple timezones, etc.${NC}"
    echo ""
    read -p "Include extra modules? [y/N]: " include_extra
    if [ "$include_extra" = "y" ] || [ "$include_extra" = "Y" ]; then
        for module in $EXTRA_MODULE_ORDER; do
            local desc=$(get_module_description "$module")
            echo -e "  ${CYAN}•${NC} ${BOLD}$module${NC}"
            echo -e "    ${DIM}$desc${NC}"
            read -p "    Include? [y/N]: " choice
            if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
                selected="$selected $module"
                echo -e "    ${GREEN}✓ Added${NC}"
            else
                echo -e "    ${DIM}✗ Skipped${NC}"
            fi
            echo ""
        done
    else
        echo -e "  ${DIM}Skipped extra modules${NC}"
        echo ""
    fi

    # Trim leading/trailing spaces
    selected=$(echo "$selected" | sed 's/^ *//;s/ *$//')

    if [ -z "$selected" ]; then
        print_warning "No modules selected. Using core defaults."
        SELECTED_MODULES="$CORE_MODULE_ORDER"
        return
    fi

    SELECTED_MODULES="$selected"
}

# Count words in a string
count_words() {
    echo $1 | wc -w | tr -d ' '
}

# Get nth word from string (1-indexed)
get_word() {
    echo $1 | awk "{print \$$2}"
}

# Interactive module ordering
interactive_module_ordering() {
    local module_count=$(count_words "$SELECTED_MODULES")
    if [ "$module_count" -le 1 ]; then
        return
    fi

    echo ""
    print_header "📐 Module Order"
    echo ""
    echo "Current order:"
    local i=1
    for module in $SELECTED_MODULES; do
        echo -e "  ${CYAN}$i)${NC} $module"
        i=$((i + 1))
    done
    echo ""

    read -p "Would you like to reorder the modules? [y/N]: " reorder
    if [ "$reorder" != "y" ] && [ "$reorder" != "Y" ]; then
        return
    fi

    echo ""
    echo "Enter the new order as a comma-separated list of numbers."
    echo "Example: 2,1,3,4 would put module 2 first, then 1, then 3, then 4"
    echo ""

    read -p "New order: " order_input

    if [ -z "$order_input" ]; then
        print_info "Keeping current order"
        return
    fi

    # Parse the order - convert comma to space
    local order_nums=$(echo "$order_input" | tr ',' ' ')
    local new_order=""
    local valid=true

    for num in $order_nums; do
        num=$(echo "$num" | tr -d ' ')
        if [ "$num" -ge 1 ] 2>/dev/null && [ "$num" -le "$module_count" ]; then
            local module=$(get_word "$SELECTED_MODULES" "$num")
            if [ -z "$new_order" ]; then
                new_order="$module"
            else
                new_order="$new_order $module"
            fi
        else
            print_warning "Invalid number: $num"
            valid=false
            break
        fi
    done

    local new_count=$(count_words "$new_order")
    if [ "$valid" = "true" ] && [ "$new_count" -eq "$module_count" ]; then
        SELECTED_MODULES="$new_order"
        echo ""
        print_success "New order:"
        local j=1
        for module in $SELECTED_MODULES; do
            echo -e "  ${CYAN}$j)${NC} $module"
            j=$((j + 1))
        done
    else
        print_warning "Invalid order input. Keeping current order."
    fi
}

# Generate config file based on selections
generate_config() {
    local config_file="$1"

    cat > "$config_file" << 'HEADER'
# =============================================================================
# Claude Code Statusline Configuration
# =============================================================================
# Generated by install.sh
# Enable/disable modules by setting to "true" or "false"
# For full configuration options, see the main barista.conf in the repo
# =============================================================================

HEADER

    # Write core module settings
    echo "# Core Modules" >> "$config_file"
    for module in $CORE_MODULE_ORDER; do
        local var_name="MODULE_$(echo "$module" | tr '[:lower:]-' '[:upper:]_')"
        local enabled="false"

        for selected in $SELECTED_MODULES; do
            if [ "$selected" = "$module" ]; then
                enabled="true"
                break
            fi
        done

        echo "$var_name=\"$enabled\"" >> "$config_file"
    done

    # Write system module settings
    echo "" >> "$config_file"
    echo "# System Monitoring Modules" >> "$config_file"
    for module in $SYSTEM_MODULE_ORDER; do
        local var_name="MODULE_$(echo "$module" | tr '[:lower:]-' '[:upper:]_')"
        local enabled="false"

        for selected in $SELECTED_MODULES; do
            if [ "$selected" = "$module" ]; then
                enabled="true"
                break
            fi
        done

        echo "$var_name=\"$enabled\"" >> "$config_file"
    done

    # Write dev tools module settings
    echo "" >> "$config_file"
    echo "# Development Tools Modules" >> "$config_file"
    for module in $DEV_MODULE_ORDER; do
        local var_name="MODULE_$(echo "$module" | tr '[:lower:]-' '[:upper:]_')"
        local enabled="false"

        for selected in $SELECTED_MODULES; do
            if [ "$selected" = "$module" ]; then
                enabled="true"
                break
            fi
        done

        echo "$var_name=\"$enabled\"" >> "$config_file"
    done

    # Write extra module settings
    echo "" >> "$config_file"
    echo "# Extra Modules" >> "$config_file"
    for module in $EXTRA_MODULE_ORDER; do
        local var_name="MODULE_$(echo "$module" | tr '[:lower:]-' '[:upper:]_')"
        local enabled="false"

        for selected in $SELECTED_MODULES; do
            if [ "$selected" = "$module" ]; then
                enabled="true"
                break
            fi
        done

        echo "$var_name=\"$enabled\"" >> "$config_file"
    done

    # Write module order
    echo "" >> "$config_file"
    echo "# Module display order (comma-separated)" >> "$config_file"
    local order_str=$(echo "$SELECTED_MODULES" | tr ' ' ',')
    echo "MODULE_ORDER=\"$order_str\"" >> "$config_file"

    cat >> "$config_file" << 'FOOTER'

# =============================================================================
# Display Settings
# =============================================================================

# Section separator
SEPARATOR=" | "

# Progress bar settings
PROGRESS_BAR_WIDTH=8
PROGRESS_BAR_FILLED="█"
PROGRESS_BAR_EMPTY="░"

# =============================================================================
# Advanced Settings
# =============================================================================

# Cache duration for API calls (seconds)
CACHE_MAX_AGE=60

# Enable debug logging (creates ~/.claude/barista.log)
DEBUG_MODE="false"
FOOTER
}

# Detect existing statusline configuration
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
            existing_files="$existing_files
$CLAUDE_DIR/barista.sh (single file)"
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

# Backup existing statusline
backup_existing_statusline() {
    print_info "Backing up existing statusline configuration..."

    mkdir -p "$BACKUP_DIR"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local manifest="{\"timestamp\": \"$timestamp\", \"files\": [], \"settings_statusline\": null}"

    if [ -f "$SETTINGS_FILE" ]; then
        local statusline_config=$(jq '.statusLine // null' "$SETTINGS_FILE" 2>/dev/null)
        if [ "$statusline_config" != "null" ]; then
            manifest=$(echo "$manifest" | jq --argjson config "$statusline_config" '.settings_statusline = $config')
            print_success "Backed up statusLine config from settings.json"
        fi
    fi

    if [ -d "$BARISTA_DIR" ]; then
        local backup_modular="$BACKUP_DIR/barista-modular-$timestamp"
        cp -r "$BARISTA_DIR" "$backup_modular"
        manifest=$(echo "$manifest" | jq --arg path "$backup_modular" --arg orig "$BARISTA_DIR" '.files += [{"original": $orig, "backup": $path, "type": "directory"}]')
        print_success "Backed up Barista directory"
    fi

    if [ -f "$CLAUDE_DIR/barista.sh" ]; then
        local backup_single="$BACKUP_DIR/barista.sh.$timestamp"
        cp "$CLAUDE_DIR/barista.sh" "$backup_single"
        manifest=$(echo "$manifest" | jq --arg path "$backup_single" --arg orig "$CLAUDE_DIR/barista.sh" '.files += [{"original": $orig, "backup": $path, "type": "file"}]')
        print_success "Backed up single-file barista.sh"
    fi

    for f in "$CLAUDE_DIR"/barista*.sh "$CLAUDE_DIR"/barista.conf "$CLAUDE_DIR"/statusline*.sh; do
        if [ -f "$f" ] && [ "$f" != "$CLAUDE_DIR/barista.sh" ]; then
            local basename=$(basename "$f")
            local backup_path="$BACKUP_DIR/${basename}.$timestamp"
            cp "$f" "$backup_path"
            manifest=$(echo "$manifest" | jq --arg path "$backup_path" --arg orig "$f" '.files += [{"original": $orig, "backup": $path, "type": "file"}]')
            print_success "Backed up $basename"
        fi
    done

    echo "$manifest" > "$BACKUP_MANIFEST"
    print_success "Created backup manifest"

    echo ""
    print_info "Backup location: $BACKUP_DIR"
    echo ""
}

# Restore from backup
restore_from_backup() {
    if [ ! -f "$BACKUP_MANIFEST" ]; then
        print_error "No backup manifest found at $BACKUP_MANIFEST"
        print_info "Cannot restore - no previous statusline was backed up"
        return 1
    fi

    print_info "Restoring previous statusline from backup..."
    echo ""

    local manifest=$(cat "$BACKUP_MANIFEST")
    local timestamp=$(echo "$manifest" | jq -r '.timestamp')

    print_info "Restoring from backup created at: $timestamp"

    local files=$(echo "$manifest" | jq -c '.files[]' 2>/dev/null)
    if [ -n "$files" ]; then
        echo "$files" | while read -r file_info; do
            local original=$(echo "$file_info" | jq -r '.original')
            local backup=$(echo "$file_info" | jq -r '.backup')
            local type=$(echo "$file_info" | jq -r '.type')

            if [ -e "$backup" ]; then
                if [ "$type" = "directory" ]; then
                    rm -rf "$original" 2>/dev/null || true
                    cp -r "$backup" "$original"
                else
                    rm -f "$original" 2>/dev/null || true
                    cp "$backup" "$original"
                fi
                print_success "Restored: $original"
            else
                print_warning "Backup not found: $backup"
            fi
        done
    fi

    local settings_statusline=$(echo "$manifest" | jq '.settings_statusline')
    if [ "$settings_statusline" != "null" ] && [ -f "$SETTINGS_FILE" ]; then
        local tmp_file=$(mktemp)
        jq --argjson statusline "$settings_statusline" '.statusLine = $statusline' "$SETTINGS_FILE" > "$tmp_file"
        mv "$tmp_file" "$SETTINGS_FILE"
        print_success "Restored statusLine config in settings.json"
    elif [ "$settings_statusline" = "null" ] && [ -f "$SETTINGS_FILE" ]; then
        local tmp_file=$(mktemp)
        jq 'del(.statusLine)' "$SETTINGS_FILE" > "$tmp_file"
        mv "$tmp_file" "$SETTINGS_FILE"
        print_success "Removed statusLine from settings.json (none existed before)"
    fi

    echo ""
    print_success "Restore complete!"
    print_info "Restart Claude Code to apply changes"
}

# Uninstall
do_uninstall() {
    show_banner
    print_header "Uninstalling Claude Code Custom Statusline..."
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
                if [ -d "$BARISTA_DIR" ]; then
                    rm -rf "$BARISTA_DIR"
                    print_success "Removed Barista directory"
                fi
                if [ -f "$CLAUDE_DIR/barista.sh" ]; then
                    rm "$CLAUDE_DIR/barista.sh"
                    print_success "Removed barista.sh"
                fi

                restore_from_backup

                echo ""
                read -p "Remove backup files? [y/N]: " remove_backup
                if [ "$remove_backup" = "y" ] || [ "$remove_backup" = "Y" ]; then
                    rm -rf "$BACKUP_DIR"
                    print_success "Removed backup directory"
                fi
                ;;
            2)
                if [ -d "$BARISTA_DIR" ]; then
                    rm -rf "$BARISTA_DIR"
                    print_success "Removed Barista directory"
                fi
                if [ -f "$CLAUDE_DIR/barista.sh" ]; then
                    rm "$CLAUDE_DIR/barista.sh"
                    print_success "Removed barista.sh"
                fi

                if [ -f "$SETTINGS_FILE" ]; then
                    local tmp_file=$(mktemp)
                    jq 'del(.statusLine)' "$SETTINGS_FILE" > "$tmp_file"
                    mv "$tmp_file" "$SETTINGS_FILE"
                    print_success "Removed statusLine from settings.json"
                fi
                ;;
            *)
                print_info "Uninstall cancelled"
                exit 0
                ;;
        esac
    else
        if [ -d "$BARISTA_DIR" ]; then
            rm -rf "$BARISTA_DIR"
            print_success "Removed Barista directory"
        fi
        if [ -f "$CLAUDE_DIR/barista.sh" ]; then
            rm "$CLAUDE_DIR/barista.sh"
            print_success "Removed barista.sh"
        fi

        if [ -f "$SETTINGS_FILE" ]; then
            local tmp_file=$(mktemp)
            jq 'del(.statusLine)' "$SETTINGS_FILE" > "$tmp_file"
            mv "$tmp_file" "$SETTINGS_FILE"
            print_success "Removed statusLine from settings.json"
        fi
    fi

    echo ""
    print_success "Uninstall complete!"
    print_info "Restart Claude Code to apply changes"
}

# Main installation
do_install() {
    local mode=$1  # "interactive", "force", or "defaults"
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
        print_header "⚠️  Existing Statusline Detected"
        echo ""

        local existing_command=$(echo "$detection" | sed -n '2p')
        local existing_files=$(echo "$detection" | tail -n +3)

        if [ -n "$existing_command" ]; then
            echo -e "  Current statusLine command: ${CYAN}$existing_command${NC}"
        fi

        if [ -n "$existing_files" ]; then
            echo "  Existing files:"
            echo "$existing_files" | while read -r file; do
                [ -n "$file" ] && echo -e "    - ${YELLOW}$file${NC}"
            done
        fi

        echo ""
        echo -e "${YELLOW}${BOLD}WARNING:${NC} Installing will overwrite your existing statusline configuration."
        echo -e "Your current statusline will be ${GREEN}backed up${NC} and can be ${GREEN}restored${NC} using:"
        echo -e "  ${CYAN}$0 --uninstall${NC}"
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

    # Interactive module selection
    if [ "$mode" = "interactive" ]; then
        interactive_module_selection
        interactive_module_ordering
    else
        SELECTED_MODULES="$DEFAULT_MODULE_ORDER"
    fi

    # Show summary
    echo ""
    print_header "📋 Installation Summary"
    echo ""
    echo "Modules to install (in order):"
    local preview=""
    for module in $SELECTED_MODULES; do
        local desc=$(get_module_description "$module")
        local emoji=$(echo "$desc" | cut -d' ' -f1)
        echo -e "  ${GREEN}✓${NC} $module - $desc"
        preview="$preview$emoji "
    done
    echo ""
    echo -e "Preview: ${DIM}$preview${NC}"
    echo ""

    if [ "$mode" = "interactive" ]; then
        read -p "Proceed with installation? [Y/n]: " final_confirm
        if [ "$final_confirm" = "n" ] || [ "$final_confirm" = "N" ]; then
            print_info "Installation cancelled"
            exit 0
        fi
    fi

    echo ""

    # Create .claude directory if it doesn't exist
    if [ ! -d "$CLAUDE_DIR" ]; then
        mkdir -p "$CLAUDE_DIR"
        print_success "Created $CLAUDE_DIR"
    fi

    # Remove existing installations
    if [ -d "$BARISTA_DIR" ]; then
        rm -rf "$BARISTA_DIR"
    fi
    if [ -f "$CLAUDE_DIR/barista.sh" ]; then
        rm "$CLAUDE_DIR/barista.sh"
    fi

    # Install new statusline
    print_info "Installing Barista..."
    mkdir -p "$BARISTA_DIR"

    cp "$SCRIPT_DIR/barista.sh" "$BARISTA_DIR/"
    chmod +x "$BARISTA_DIR/barista.sh"

    mkdir -p "$BARISTA_DIR/modules"
    cp "$SCRIPT_DIR/modules/"*.sh "$BARISTA_DIR/modules/"

    # Generate custom config based on selections
    generate_config "$BARISTA_DIR/barista.conf"

    print_success "Installed statusline to $BARISTA_DIR"

    # Update settings.json
    print_info "Configuring settings.json..."

    if [ -f "$SETTINGS_FILE" ]; then
        local tmp_file=$(mktemp)
        jq '.statusLine = {"type": "command", "command": "~/.claude/barista/barista.sh"}' "$SETTINGS_FILE" > "$tmp_file"
        mv "$tmp_file" "$SETTINGS_FILE"
        print_success "Updated settings.json"
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

    # Verify installation
    print_info "Verifying installation..."

    local test_output=$(echo '{"workspace":{"current_dir":"'$HOME'"},"model":{"display_name":"Test"},"output_style":{"name":"default"},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":1000}}}' | "$BARISTA_DIR/barista.sh" 2>&1)

    if [ -n "$test_output" ]; then
        print_success "Statusline test passed!"
        echo ""
        echo "Sample output:"
        echo "  $test_output"
    else
        print_warning "Statusline produced no output - check for errors"
    fi

    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                   Installation Complete!                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    print_success "Restart Claude Code to see your new statusline"
    echo ""
    echo "Configuration:"
    echo "  Edit:     $BARISTA_DIR/barista.conf"
    echo "  Modules:  $BARISTA_DIR/modules/"
    echo ""

    if [ -f "$BACKUP_MANIFEST" ]; then
        echo -e "${GREEN}Your previous statusline was backed up.${NC}"
        echo -e "To restore it, run: ${CYAN}$0 --uninstall${NC}"
        echo ""
    fi
}

# Parse arguments
case "$1" in
    --uninstall)
        do_uninstall
        ;;
    --force)
        do_install "force"
        ;;
    --defaults)
        do_install "defaults"
        ;;
    --help|-h)
        show_banner
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  (none)       Interactive install - choose modules and order"
        echo "  --defaults   Install with core modules enabled (default order)"
        echo "  --force      Same as --defaults, no confirmation prompts"
        echo "  --uninstall  Uninstall and optionally restore previous statusline"
        echo "  --help       Show this help message"
        echo ""
        echo -e "${BOLD}Core Modules (Claude Code specific):${NC}"
        for module in $CORE_MODULE_ORDER; do
            echo "  - $module: $(get_module_description "$module")"
        done
        echo ""
        echo -e "${BOLD}System Monitoring Modules:${NC}"
        for module in $SYSTEM_MODULE_ORDER; do
            echo "  - $module: $(get_module_description "$module")"
        done
        echo ""
        echo -e "${BOLD}Development Tools Modules:${NC}"
        for module in $DEV_MODULE_ORDER; do
            echo "  - $module: $(get_module_description "$module")"
        done
        echo ""
        echo -e "${BOLD}Extra Modules:${NC}"
        for module in $EXTRA_MODULE_ORDER; do
            echo "  - $module: $(get_module_description "$module")"
        done
        echo ""
        ;;
    *)
        do_install "interactive"
        ;;
esac
