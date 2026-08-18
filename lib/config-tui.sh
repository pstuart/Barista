#!/bin/bash
# =============================================================================
# Barista runtime config TUI (Refs #24)
# =============================================================================
# Sourced by barista.sh when invoked as: barista.sh config [options]
# Bash 3.2 compatible. No side effects on source beyond function definitions.
# =============================================================================

# Colors (TTY only)
_cfg_init_colors() {
    if [ -t 1 ] && [ "${NO_COLOR:-}" != "1" ] && [ "${USE_COLOR:-true}" != "false" ]; then
        CFG_BOLD=$'\033[1m'
        CFG_DIM=$'\033[2m'
        CFG_CYAN=$'\033[36m'
        CFG_GREEN=$'\033[32m'
        CFG_YELLOW=$'\033[33m'
        CFG_MAGENTA=$'\033[35m'
        CFG_NC=$'\033[0m'
    else
        CFG_BOLD=""; CFG_DIM=""; CFG_CYAN=""; CFG_GREEN=""; CFG_YELLOW=""; CFG_MAGENTA=""; CFG_NC=""
    fi
}

# Module catalog: name:default:category:description
_CFG_CORE_MODULES=(
    "sandbox:true:core:Sandbox lock indicator"
    "version:true:core:Barista version (brief)"
    "update:true:core:Update checker"
    "directory:true:core:Working directory"
    "context:true:core:Context usage bar"
    "git:true:core:Git branch/status"
    "project:true:core:Project type"
    "model:true:core:Claude model"
    "cost:true:core:Session cost"
    "rate-limits:true:core:Rate limits"
    "time:true:core:Date/time"
    "battery:true:core:Battery (macOS)"
)
_CFG_SYSTEM_MODULES=(
    "cpu:false:system:CPU usage"
    "memory:false:system:RAM usage"
    "disk:false:system:Disk space"
    "network:false:system:Network info"
    "uptime:false:system:System uptime"
    "load:false:system:Load average"
    "temperature:false:system:CPU temperature"
    "brightness:false:system:Screen brightness"
    "processes:false:system:Process count"
)
_CFG_DEV_MODULES=(
    "docker:false:dev:Docker status"
    "node:false:dev:Node.js version"
)
_CFG_EXTRA_MODULES=(
    "weather:false:extra:Weather (wttr.in)"
    "timezone:false:extra:Multi-timezone clocks"
)
_CFG_ALL_MODULES=("${_CFG_CORE_MODULES[@]}" "${_CFG_SYSTEM_MODULES[@]}" "${_CFG_DEV_MODULES[@]}" "${_CFG_EXTRA_MODULES[@]}")

_cfg_module_var() {
    # name -> MODULE_NAME (hyphens to underscores, upper)
    echo "MODULE_$(echo "$1" | tr '[:lower:]-' '[:upper:]_')"
}

# --set / assign allowlist: same prefixes as barista.sh load_config_safe.
_cfg_is_allowed_key() {
    local key="$1"
    case "$key" in
        *[!A-Za-z0-9_]*|'') return 1 ;;
    esac
    case "$key" in
        MODULE_*|SEPARATOR|DISPLAY_MODE|COLOR_THEME|USE_ICONS|\
        USE_STATUS_INDICATORS|STATUS_STYLE|STATUS_*|\
        PROGRESS_BAR_*|DIRECTORY_*|CONTEXT_*|GIT_*|\
        PROJECT_*|MODEL_*|COST_*|RATE_*|TIME_*|\
        BATTERY_*|CPU_*|MEMORY_*|DISK_*|NETWORK_*|\
        UPTIME_*|LOAD_*|TEMP_*|BRIGHTNESS_*|PROC_*|\
        DOCKER_*|NODE_*|WEATHER_*|TIMEZONE_*|SANDBOX_*|\
        CACHE_MAX_AGE|DEBUG_MODE|LAYOUT_MODE|\
        TERMINAL_WIDTH|RIGHT_SIDE_RESERVE|VERSION_*|UPDATE_*)
            return 0
            ;;
        *) return 1 ;;
    esac
}

# Keys this TUI always rewrites from current shell state.
_cfg_is_tui_owned_key() {
    local key="$1" mod_def name var
    case "$key" in
        SEPARATOR|DISPLAY_MODE|COLOR_THEME|USE_ICONS|USE_STATUS_INDICATORS|\
        STATUS_STYLE|LAYOUT_MODE|NETWORK_SHOW_WAN|NETWORK_WAN_REDACT|MODULE_ORDER)
            return 0
            ;;
    esac
    for mod_def in "${_CFG_ALL_MODULES[@]}"; do
        name=$(_cfg_mod_name "$mod_def")
        var=$(_cfg_module_var "$name")
        if [ "$key" = "$var" ]; then
            return 0
        fi
    done
    return 1
}

_cfg_module_name_from_var() {
    local want="$1" mod_def name var
    for mod_def in "${_CFG_ALL_MODULES[@]}"; do
        name=$(_cfg_mod_name "$mod_def")
        var=$(_cfg_module_var "$name")
        if [ "$var" = "$want" ]; then
            echo "$name"
            return 0
        fi
    done
    return 1
}

# Values that would break KEY="value" or inject when the user config is sourced.
_cfg_value_is_safe() {
    local val="$1"
    case "$val" in
        *\`*|*\$*|*\;*|*\|*|*\&*|*\>*|*\<*|*\"*|*\'*|*\\*|*\(*|*\)*)
            return 1
            ;;
    esac
    case "$val" in
        *[[:cntrl:]]*) return 1 ;;
    esac
    return 0
}

_cfg_assign() {
    local key="$1" val="$2"
    _cfg_is_allowed_key "$key" || return 1
    printf -v "$key" '%s' "$val"
}

_cfg_shell_quote() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//\$/\\\$}
    s=${s//\`/\\\`}
    printf '%s' "$s"
}

_cfg_module_enabled() {
    local name="$1" var val
    var=$(_cfg_module_var "$name")
    val="${!var:-false}"
    case "$val" in
        true|TRUE|1|yes|YES|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

_cfg_set_module() {
    local name="$1" state="$2" var
    var=$(_cfg_module_var "$name")
    printf -v "$var" '%s' "$state"
}

_cfg_toggle_module() {
    local name="$1"
    if _cfg_module_enabled "$name"; then
        _cfg_set_module "$name" "false"
    else
        _cfg_set_module "$name" "true"
    fi
}

_cfg_mod_name() { echo "$1" | cut -d: -f1; }
_cfg_mod_default() { echo "$1" | cut -d: -f2; }
_cfg_mod_desc() { echo "$1" | cut -d: -f4-; }

# Resolve config path to edit (user global by default)
_cfg_resolve_path() {
    local scope="${1:-global}"
    case "$scope" in
        global|user)
            echo "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/barista.conf"
            ;;
        project|dir|local)
            echo "${PWD}/.barista.conf"
            ;;
        *)
            echo "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/barista.conf"
            ;;
    esac
}

# Load defaults + existing conf into shell vars.
# Project .barista.conf is never sourced (same rule as barista.sh main).
_cfg_load_into_shell() {
    local path="$1"
    local scope="${2:-global}"
    # Ship defaults from packaged conf if present
    if [ -n "${SCRIPT_DIR:-}" ] && [ -f "$SCRIPT_DIR/barista.conf" ]; then
        if config_not_group_or_world_writable "$SCRIPT_DIR/barista.conf" 2>/dev/null; then
            # shellcheck disable=SC1090
            . "$SCRIPT_DIR/barista.conf"
        fi
    fi
    if [ -f "$path" ]; then
        if [ "$scope" = "project" ]; then
            _cfg_load_safe_kv "$path"
        elif config_not_group_or_world_writable "$path" 2>/dev/null; then
            # shellcheck disable=SC1090
            . "$path"
        else
            _cfg_load_safe_kv "$path"
        fi
    fi
    # Ensure MODULE_* exist for every catalog entry
    local mod_def name var def
    for mod_def in "${_CFG_ALL_MODULES[@]}"; do
        name=$(_cfg_mod_name "$mod_def")
        def=$(_cfg_mod_default "$mod_def")
        var=$(_cfg_module_var "$name")
        if [ -z "${!var+x}" ]; then
            printf -v "$var" '%s' "$def"
        fi
    done
    COLOR_THEME="${COLOR_THEME:-default}"
    SEPARATOR="${SEPARATOR:- | }"
    DISPLAY_MODE="${DISPLAY_MODE:-normal}"
    LAYOUT_MODE="${LAYOUT_MODE:-smart}"
    USE_ICONS="${USE_ICONS:-true}"
    USE_STATUS_INDICATORS="${USE_STATUS_INDICATORS:-true}"
    STATUS_STYLE="${STATUS_STYLE:-emoji}"
    NETWORK_SHOW_WAN="${NETWORK_SHOW_WAN:-false}"
    NETWORK_WAN_REDACT="${NETWORK_WAN_REDACT:-true}"
}

_cfg_load_safe_kv() {
    # Prefer the shared parser in barista.sh (full prefix allowlist, printf -v).
    if type load_config_safe >/dev/null 2>&1; then
        load_config_safe "$1"
        return $?
    fi

    local config_path="$1" line key val
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|\#*) continue ;;
        esac
        key="${line%%=*}"
        [ "$key" = "$line" ] && continue
        _cfg_is_allowed_key "$key" || continue
        val="${line#*=}"
        val="${val#\"}"; val="${val%\"}"
        val="${val#\'}"; val="${val%\'}"
        _cfg_value_is_safe "$val" || continue
        printf -v "$key" '%s' "$val"
    done < "$config_path"
}

_cfg_rebuild_module_order() {
    local order="" mod_def name
    for mod_def in "${_CFG_ALL_MODULES[@]}"; do
        name=$(_cfg_mod_name "$mod_def")
        if _cfg_module_enabled "$name"; then
            if [ -n "$order" ]; then
                order="${order},${name}"
            else
                order="$name"
            fi
        fi
    done
    MODULE_ORDER="$order"
}

_cfg_order_add() {
    local name="$1"
    case ",${MODULE_ORDER}," in
        *",${name},"*) return 0 ;;
    esac
    if [ -n "${MODULE_ORDER:-}" ]; then
        MODULE_ORDER="${MODULE_ORDER},${name}"
    else
        MODULE_ORDER="$name"
    fi
}

_cfg_order_remove() {
    local name="$1" new="" m old_ifs
    old_ifs="$IFS"
    IFS=','
    for m in ${MODULE_ORDER:-}; do
        m="${m#"${m%%[![:space:]]*}"}"
        m="${m%"${m##*[![:space:]]}"}"
        [ -z "$m" ] && continue
        [ "$m" = "$name" ] && continue
        if [ -n "$new" ]; then
            new="${new},${m}"
        else
            new="$m"
        fi
    done
    IFS="$old_ifs"
    MODULE_ORDER="$new"
}

_cfg_sync_module_order() {
    local name="$1"
    if _cfg_module_enabled "$name"; then
        _cfg_order_add "$name"
    else
        _cfg_order_remove "$name"
    fi
}

# $1 path  $2 rebuild_order (1=catalog rebuild, default 0)  $3 extra key to emit
_cfg_write_conf() {
    local path="$1"
    local rebuild_order="${2:-0}"
    local extra_key="${3:-}"
    local dir tmp extras line key
    dir=$(dirname "$path")
    mkdir -p "$dir" || return 1

    if [ "$rebuild_order" = "1" ] || [ -z "${MODULE_ORDER:-}" ]; then
        _cfg_rebuild_module_order
    fi

    extras=""
    if [ -f "$path" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in
                ''|\#*) continue ;;
            esac
            case "$line" in
                *=*)
                    key="${line%%=*}"
                    case "$key" in
                        *[!A-Za-z0-9_]*|'') continue ;;
                    esac
                    if _cfg_is_tui_owned_key "$key"; then
                        continue
                    fi
                    if [ -n "$extra_key" ] && [ "$key" = "$extra_key" ]; then
                        continue
                    fi
                    extras="${extras}${line}"$'\n'
                    ;;
            esac
        done < "$path"
    fi

    tmp=$(mktemp "${TMPDIR:-/tmp}/barista-conf.XXXXXX") || return 1

    {
        echo "# Barista configuration — written by barista config ($(date -u +%Y-%m-%dT%H:%MZ))"
        echo "# Edit with: barista config   or hand-edit this file"
        echo ""
        echo "# Display"
        echo "SEPARATOR=\"$(_cfg_shell_quote "${SEPARATOR}")\""
        echo "DISPLAY_MODE=\"$(_cfg_shell_quote "${DISPLAY_MODE}")\""
        echo "COLOR_THEME=\"$(_cfg_shell_quote "${COLOR_THEME}")\""
        echo "USE_ICONS=\"$(_cfg_shell_quote "${USE_ICONS}")\""
        echo "USE_STATUS_INDICATORS=\"$(_cfg_shell_quote "${USE_STATUS_INDICATORS}")\""
        echo "STATUS_STYLE=\"$(_cfg_shell_quote "${STATUS_STYLE}")\""
        echo "LAYOUT_MODE=\"$(_cfg_shell_quote "${LAYOUT_MODE}")\""
        echo ""
        echo "# Network privacy"
        echo "NETWORK_SHOW_WAN=\"$(_cfg_shell_quote "${NETWORK_SHOW_WAN}")\""
        echo "NETWORK_WAN_REDACT=\"$(_cfg_shell_quote "${NETWORK_WAN_REDACT}")\""
        echo ""
        echo "# Modules"
        local mod_def name var val
        for mod_def in "${_CFG_ALL_MODULES[@]}"; do
            name=$(_cfg_mod_name "$mod_def")
            var=$(_cfg_module_var "$name")
            val="${!var:-false}"
            echo "${var}=\"$(_cfg_shell_quote "${val}")\""
        done
        echo ""
        echo "MODULE_ORDER=\"$(_cfg_shell_quote "${MODULE_ORDER}")\""
        if [ -n "$extra_key" ] && ! _cfg_is_tui_owned_key "$extra_key"; then
            echo ""
            echo "${extra_key}=\"$(_cfg_shell_quote "${!extra_key}")\""
        fi
        if [ -n "$extras" ]; then
            echo ""
            echo "# Preserved settings"
            printf '%s' "$extras"
        fi
    } > "$tmp" || { rm -f "$tmp"; return 1; }

    mv "$tmp" "$path" || { rm -f "$tmp"; return 1; }
    chmod 600 "$path" 2>/dev/null || true
    return 0
}

_cfg_show() {
    local path="$1"
    echo "Config file: $path"
    if [ ! -f "$path" ]; then
        echo "(file does not exist yet — defaults will be used until saved)"
    fi
    echo ""
    echo "COLOR_THEME=$COLOR_THEME  DISPLAY_MODE=$DISPLAY_MODE  LAYOUT_MODE=$LAYOUT_MODE"
    echo "SEPARATOR=\"$SEPARATOR\"  USE_ICONS=$USE_ICONS  STATUS_STYLE=$STATUS_STYLE"
    echo "NETWORK_SHOW_WAN=$NETWORK_SHOW_WAN  NETWORK_WAN_REDACT=$NETWORK_WAN_REDACT"
    echo ""
    echo "Modules:"
    local mod_def name state
    for mod_def in "${_CFG_ALL_MODULES[@]}"; do
        name=$(_cfg_mod_name "$mod_def")
        if _cfg_module_enabled "$name"; then state="on "; else state="off"; fi
        printf "  [%s] %-14s %s\n" "$state" "$name" "$(_cfg_mod_desc "$mod_def")"
    done
    echo ""
    echo "MODULE_ORDER=$MODULE_ORDER"
}

_cfg_preview_line() {
    # Static sample preview (no network / git) so TUI stays snappy
    local parts="" mod_def name sample
    for mod_def in "${_CFG_ALL_MODULES[@]}"; do
        name=$(_cfg_mod_name "$mod_def")
        _cfg_module_enabled "$name" || continue
        case "$name" in
            directory) sample="📁 project" ;;
            context) sample="📊 ███░░ 42%" ;;
            git) sample="🌿 main" ;;
            project) sample="⚡ bash" ;;
            model) sample="🤖 Claude" ;;
            cost) sample="💰 \$0.12" ;;
            rate-limits) sample="5h:20%" ;;
            time) sample="🕐 12:00" ;;
            battery) sample="🔋 90%" ;;
            cpu) sample="CPU 12%" ;;
            memory) sample="RAM 40%" ;;
            disk) sample="Disk 55%" ;;
            network) sample="🌐 lan" ;;
            docker) sample="🐳 0" ;;
            node) sample="Node 22" ;;
            weather) sample="☀️ 72°" ;;
            sandbox) sample="🔒" ;;
            version) sample="v${BARISTA_VERSION:-?}" ;;
            update) sample="" ;;
            *) sample="$name" ;;
        esac
        [ -z "$sample" ] && continue
        if [ -n "$parts" ]; then
            parts="${parts}${SEPARATOR}${sample}"
        else
            parts="$sample"
        fi
    done
    echo "${parts:-(no modules enabled)}"
}

# ---- Interactive menus -------------------------------------------------------

_cfg_draw_module_menu() {
    local title="$1" current_idx="$2"
    shift 2
    local items=("$@")
    local count=${#items[@]}
    local i=0 name desc state

    if [ "${_CFG_MENU_DRAWN:-false}" = "true" ]; then
        printf "\033[%dA" $((count + 7))
    fi

    printf "\033[K${CFG_BOLD}${CFG_MAGENTA}=== %s ===${CFG_NC}\n" "$title"
    printf "\033[K${CFG_DIM}Space toggle · a all · n none · Enter next · s save · q quit${CFG_NC}\n"
    printf "\033[K${CFG_DIM}Preview: %s${CFG_NC}\n" "$(_cfg_preview_line)"
    printf "\033[K\n"

    i=0
    for item in "${items[@]}"; do
        name=$(_cfg_mod_name "$item")
        desc=$(_cfg_mod_desc "$item")
        printf "\033[K"
        if [ "$i" -eq "$current_idx" ]; then
            printf "  ${CFG_CYAN}>${CFG_NC} "
        else
            printf "    "
        fi
        if _cfg_module_enabled "$name"; then
            printf "${CFG_GREEN}[x]${CFG_NC} "
        else
            printf "${CFG_DIM}[ ]${CFG_NC} "
        fi
        if [ "$i" -eq "$current_idx" ]; then
            printf "${CFG_BOLD}%s${CFG_NC} ${CFG_DIM}%s${CFG_NC}\n" "$name" "$desc"
        else
            printf "%s ${CFG_DIM}%s${CFG_NC}\n" "$name" "$desc"
        fi
        i=$((i + 1))
    done
    printf "\033[K\n"
    _CFG_MENU_DRAWN="true"
}

_cfg_interactive_modules() {
    local title="$1"
    shift
    local modules=("$@")
    local count=${#modules[@]}
    [ "$count" -eq 0 ] && return 0

    local current_idx=0
    local name key escape_seq
    _CFG_MENU_DRAWN="false"
    printf "\033[?25l"
    echo ""
    _cfg_draw_module_menu "$title" "$current_idx" "${modules[@]}"

    while true; do
        IFS= read -rsn1 key
        if [[ "$key" == $'\e' ]]; then
            read -rsn2 escape_seq
            case "$escape_seq" in
                '[A'|'OA')
                    if [ "$current_idx" -gt 0 ]; then current_idx=$((current_idx - 1)); else current_idx=$((count - 1)); fi
                    ;;
                '[B'|'OB')
                    if [ "$current_idx" -lt $((count - 1)) ]; then current_idx=$((current_idx + 1)); else current_idx=0; fi
                    ;;
            esac
        elif [[ "$key" == " " ]]; then
            name=$(_cfg_mod_name "${modules[$current_idx]}")
            _cfg_toggle_module "$name"
        elif [ "$key" = "a" ] || [ "$key" = "A" ]; then
            for mod_def in "${modules[@]}"; do
                _cfg_set_module "$(_cfg_mod_name "$mod_def")" "true"
            done
        elif [ "$key" = "n" ] || [ "$key" = "N" ]; then
            for mod_def in "${modules[@]}"; do
                _cfg_set_module "$(_cfg_mod_name "$mod_def")" "false"
            done
        elif [ "$key" = "s" ] || [ "$key" = "S" ]; then
            _CFG_SAVE_REQUESTED=1
            break
        elif [ "$key" = "q" ] || [ "$key" = "Q" ]; then
            _CFG_QUIT_REQUESTED=1
            break
        elif [ "$key" = "" ]; then
            break
        fi
        _cfg_draw_module_menu "$title" "$current_idx" "${modules[@]}"
    done
    printf "\033[?25h"
    echo ""
}

_cfg_interactive_choice() {
    local title="$1"
    shift
    local options=("$@")
    local count=${#options[@]}
    local current_idx=0 drawn="false" key escape_seq label

    printf "\033[?25l"
    echo ""
    while true; do
        if [ "$drawn" = "true" ]; then
            printf "\033[%dA" $((count + 3))
        fi
        printf "\033[K${CFG_BOLD}%s${CFG_NC}\n" "$title"
        printf "\033[K\n"
        local i=0
        for opt in "${options[@]}"; do
            printf "\033[K"
            label="${opt%%|*}"
            if [ "$i" -eq "$current_idx" ]; then
                printf "  ${CFG_CYAN}>${CFG_NC} ${CFG_GREEN}◉${CFG_NC} ${CFG_BOLD}%s${CFG_NC}\n" "$label"
            else
                printf "    ${CFG_DIM}○${CFG_NC} %s\n" "$label"
            fi
            i=$((i + 1))
        done
        printf "\033[K${CFG_DIM}  ↑/↓ Navigate  ⏎ Select${CFG_NC}\n"
        drawn="true"
        IFS= read -rsn1 key
        if [[ "$key" == $'\e' ]]; then
            read -rsn2 escape_seq
            case "$escape_seq" in
                '[A'|'OA') if [ "$current_idx" -gt 0 ]; then current_idx=$((current_idx - 1)); else current_idx=$((count - 1)); fi ;;
                '[B'|'OB') if [ "$current_idx" -lt $((count - 1)) ]; then current_idx=$((current_idx + 1)); else current_idx=0; fi ;;
            esac
        elif [ "$key" = "" ]; then
            break
        fi
    done
    printf "\033[?25h"
    echo ""
    CFG_CHOICE_RESULT=$current_idx
}

_cfg_run_interactive() {
    local path="$1"
    _CFG_SAVE_REQUESTED=0
    _CFG_QUIT_REQUESTED=0

    echo ""
    printf "%sBarista config%s  %s\n" "$CFG_BOLD" "$CFG_NC" "$path"
    echo "Arrow keys · Space toggle · s save · q cancel without write"
    echo ""

    _cfg_interactive_modules "Core modules" "${_CFG_CORE_MODULES[@]}"
    [ "${_CFG_QUIT_REQUESTED:-0}" = "1" ] && { echo "Cancelled — no changes written."; return 1; }
    [ "${_CFG_SAVE_REQUESTED:-0}" = "1" ] && { _cfg_write_conf "$path" 1 && echo "Saved $path"; return 0; }

    _cfg_interactive_modules "System modules" "${_CFG_SYSTEM_MODULES[@]}"
    [ "${_CFG_QUIT_REQUESTED:-0}" = "1" ] && { echo "Cancelled — no changes written."; return 1; }
    [ "${_CFG_SAVE_REQUESTED:-0}" = "1" ] && { _cfg_write_conf "$path" 1 && echo "Saved $path"; return 0; }

    _cfg_interactive_modules "Dev modules" "${_CFG_DEV_MODULES[@]}"
    [ "${_CFG_QUIT_REQUESTED:-0}" = "1" ] && { echo "Cancelled — no changes written."; return 1; }
    [ "${_CFG_SAVE_REQUESTED:-0}" = "1" ] && { _cfg_write_conf "$path" 1 && echo "Saved $path"; return 0; }

    _cfg_interactive_modules "Extra modules" "${_CFG_EXTRA_MODULES[@]}"
    [ "${_CFG_QUIT_REQUESTED:-0}" = "1" ] && { echo "Cancelled — no changes written."; return 1; }
    [ "${_CFG_SAVE_REQUESTED:-0}" = "1" ] && { _cfg_write_conf "$path" 1 && echo "Saved $path"; return 0; }

    _cfg_interactive_choice "Color theme" \
        "default|Standard emoji" \
        "minimal|Geometric" \
        "vibrant|Expressive" \
        "monochrome|ASCII" \
        "nerd|Nerd Font glyphs"
    case "${CFG_CHOICE_RESULT:-0}" in
        0) COLOR_THEME="default" ;;
        1) COLOR_THEME="minimal" ;;
        2) COLOR_THEME="vibrant" ;;
        3) COLOR_THEME="monochrome" ;;
        4) COLOR_THEME="nerd" ;;
    esac

    _cfg_interactive_choice "WAN IP (privacy)" \
        "off|Do not fetch WAN IP (recommended)" \
        "redacted|Fetch but redact" \
        "show|Show full WAN IP"
    case "${CFG_CHOICE_RESULT:-0}" in
        0) NETWORK_SHOW_WAN="false"; NETWORK_WAN_REDACT="true" ;;
        1) NETWORK_SHOW_WAN="true"; NETWORK_WAN_REDACT="true" ;;
        2) NETWORK_SHOW_WAN="true"; NETWORK_WAN_REDACT="false" ;;
    esac

    echo ""
    printf "Preview: %s\n" "$(_cfg_preview_line)"
    echo ""
    printf "Save to %s? [Y/n] " "$path"
    local confirm
    read -r confirm
    case "$confirm" in
        n|N|no|NO)
            echo "Cancelled — no changes written."
            return 1
            ;;
    esac
    if _cfg_write_conf "$path" 1; then
        echo "Saved $path"
        echo "Restart Claude Code (or re-render statusline) to apply."
        return 0
    fi
    echo "Failed to write $path" >&2
    return 1
}

_cfg_usage() {
    cat <<'EOF'
Usage: barista config [options]
       barista.sh config [options]

Post-install TUI and CLI for barista.conf (does not re-run the installer).

Options:
  (none)              Interactive TUI (modules + theme + WAN privacy)
  --show              Print current config summary
  --list              Alias for --show
  --set KEY=VALUE     Set a single key (MODULE_*, COLOR_THEME, …) and save
  --toggle NAME       Toggle a module on/off by short name (e.g. git, cpu)
  --path              Print resolved config path and exit
  --project           Edit ./.barista.conf instead of user global
  --global            Edit $CLAUDE_CONFIG_DIR/barista.conf (default)
  -h, --help          This help

Examples:
  barista config
  barista config --show
  barista config --toggle weather
  barista config --set COLOR_THEME=minimal
  barista config --project --set MODULE_CPU=true
EOF
}

# Entry point
barista_config_main() {
    _cfg_init_colors
    local scope="global"
    local action="interactive"
    local set_kv="" toggle_name=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --show|--list) action="show"; shift ;;
            --path) action="path"; shift ;;
            --project) scope="project"; shift ;;
            --global) scope="global"; shift ;;
            --set)
                action="set"
                set_kv="${2:-}"
                if [ -z "$set_kv" ]; then echo "config: --set requires KEY=VALUE" >&2; return 2; fi
                shift 2
                ;;
            --toggle)
                action="toggle"
                toggle_name="${2:-}"
                if [ -z "$toggle_name" ]; then echo "config: --toggle requires module name" >&2; return 2; fi
                shift 2
                ;;
            -h|--help|help) _cfg_usage; return 0 ;;
            *)
                echo "config: unknown option: $1" >&2
                _cfg_usage >&2
                return 2
                ;;
        esac
    done

    local path
    path=$(_cfg_resolve_path "$scope")

    if [ "$action" = "path" ]; then
        echo "$path"
        return 0
    fi

    # config_not_group_or_world_writable comes from barista.sh
    _cfg_load_into_shell "$path" "$scope"

    case "$action" in
        show)
            _cfg_show "$path"
            return 0
            ;;
        set)
            local key="${set_kv%%=*}" val="${set_kv#*=}"
            if [ "$key" = "$set_kv" ] || [ -z "$key" ]; then
                echo "config: --set requires KEY=VALUE" >&2
                return 2
            fi
            if ! _cfg_is_allowed_key "$key"; then
                echo "config: unknown or invalid key: $key" >&2
                return 2
            fi
            if ! _cfg_value_is_safe "$val"; then
                echo "config: invalid value characters" >&2
                return 2
            fi
            if ! _cfg_assign "$key" "$val"; then
                echo "config: could not set $key" >&2
                return 2
            fi
            local set_mod
            if set_mod=$(_cfg_module_name_from_var "$key"); then
                _cfg_sync_module_order "$set_mod"
            fi
            if _cfg_write_conf "$path" 0 "$key"; then
                echo "Set $key=$val → $path"
                return 0
            fi
            return 1
            ;;
        toggle)
            local found=0 mod_def name
            for mod_def in "${_CFG_ALL_MODULES[@]}"; do
                name=$(_cfg_mod_name "$mod_def")
                if [ "$name" = "$toggle_name" ]; then
                    found=1
                    _cfg_toggle_module "$name"
                    _cfg_sync_module_order "$name"
                    break
                fi
            done
            if [ "$found" -eq 0 ]; then
                echo "config: unknown module: $toggle_name" >&2
                return 2
            fi
            if _cfg_write_conf "$path" 0; then
                if _cfg_module_enabled "$toggle_name"; then
                    echo "Enabled $toggle_name → $path"
                else
                    echo "Disabled $toggle_name → $path"
                fi
                return 0
            fi
            return 1
            ;;
        interactive)
            if [ ! -t 0 ] || [ ! -t 1 ]; then
                echo "config: interactive TUI requires a TTY. Use --show / --set / --toggle." >&2
                return 2
            fi
            _cfg_run_interactive "$path"
            return $?
            ;;
    esac
}
