# =============================================================================
# Project Module - Detects project type and dev server status
# =============================================================================
# Configuration options:
#   PROJECT_STYLE           - "icon", "text", "both" (default: both)
#   PROJECT_SHOW_DEV_SERVER - Show dev server indicator (default: true)
#   PROJECT_SHOW_BUILD      - Show build indicator (default: true)
#   PROJECT_DEV_ICON        - Dev server icon (default: 🚀)
#   PROJECT_BUILD_ICON      - Build icon (default: 🔨)
#   PROJECT_ICON_*          - Custom icons for each project type
# =============================================================================

# Get project icon (allows custom overrides)
_get_project_icon() {
    local project_type="$1"
    local default_icon="$2"

    case "$project_type" in
        nuxt)    echo "${PROJECT_ICON_NUXT:-$default_icon}" ;;
        nextjs)  echo "${PROJECT_ICON_NEXTJS:-$default_icon}" ;;
        vite)    echo "${PROJECT_ICON_VITE:-$default_icon}" ;;
        svelte)  echo "${PROJECT_ICON_SVELTE:-$default_icon}" ;;
        astro)   echo "${PROJECT_ICON_ASTRO:-$default_icon}" ;;
        remix)   echo "${PROJECT_ICON_REMIX:-$default_icon}" ;;
        node)    echo "${PROJECT_ICON_NODE:-$default_icon}" ;;
        rust)    echo "${PROJECT_ICON_RUST:-$default_icon}" ;;
        go)      echo "${PROJECT_ICON_GO:-$default_icon}" ;;
        python)  echo "${PROJECT_ICON_PYTHON:-$default_icon}" ;;
        ruby)    echo "${PROJECT_ICON_RUBY:-$default_icon}" ;;
        php)     echo "${PROJECT_ICON_PHP:-$default_icon}" ;;
        swift)   echo "${PROJECT_ICON_SWIFT:-$default_icon}" ;;
        kotlin)  echo "${PROJECT_ICON_KOTLIN:-$default_icon}" ;;
        java)    echo "${PROJECT_ICON_JAVA:-$default_icon}" ;;
        elixir)  echo "${PROJECT_ICON_ELIXIR:-$default_icon}" ;;
        deno)    echo "${PROJECT_ICON_DENO:-$default_icon}" ;;
        bun)     echo "${PROJECT_ICON_BUN:-$default_icon}" ;;
        *)       echo "$default_icon" ;;
    esac
}

# Format project output based on style
_format_project() {
    local icon="$1"
    local name="$2"
    local style="${PROJECT_STYLE:-both}"

    if [ "${USE_ICONS:-true}" != "true" ]; then
        echo "$name"
        return
    fi

    case "$style" in
        icon)
            echo "$icon"
            ;;
        text)
            echo "$name"
            ;;
        *)  # both (default)
            echo "$icon $name"
            ;;
    esac
}

module_project() {
    local current_dir="$1"
    local result=""
    local show_dev="${PROJECT_SHOW_DEV_SERVER:-true}"
    local show_build="${PROJECT_SHOW_BUILD:-true}"
    local dev_icon="${PROJECT_DEV_ICON:-🚀}"
    local build_icon="${PROJECT_BUILD_ICON:-🔨}"

    # Detect project type
    if [ -f "$current_dir/package.json" ]; then
        if [ -f "$current_dir/nuxt.config.ts" ] || [ -f "$current_dir/nuxt.config.js" ]; then
            result=$(_format_project "$(_get_project_icon nuxt "⚡")" "Nuxt")
        elif [ -f "$current_dir/next.config.js" ] || [ -f "$current_dir/next.config.ts" ] || [ -f "$current_dir/next.config.mjs" ]; then
            result=$(_format_project "$(_get_project_icon nextjs "▲")" "Next.js")
        elif [ -f "$current_dir/vite.config.ts" ] || [ -f "$current_dir/vite.config.js" ]; then
            result=$(_format_project "$(_get_project_icon vite "⚡")" "Vite")
        elif [ -f "$current_dir/svelte.config.js" ]; then
            result=$(_format_project "$(_get_project_icon svelte "🔥")" "Svelte")
        elif [ -f "$current_dir/astro.config.mjs" ]; then
            result=$(_format_project "$(_get_project_icon astro "🚀")" "Astro")
        elif [ -f "$current_dir/remix.config.js" ]; then
            result=$(_format_project "$(_get_project_icon remix "💿")" "Remix")
        else
            result=$(_format_project "$(_get_project_icon node "📦")" "Node.js")
        fi
    elif [ -f "$current_dir/Cargo.toml" ]; then
        result=$(_format_project "$(_get_project_icon rust "🦀")" "Rust")
    elif [ -f "$current_dir/go.mod" ]; then
        result=$(_format_project "$(_get_project_icon go "🐹")" "Go")
    elif [ -f "$current_dir/requirements.txt" ] || [ -f "$current_dir/pyproject.toml" ] || [ -f "$current_dir/setup.py" ]; then
        result=$(_format_project "$(_get_project_icon python "🐍")" "Python")
    elif [ -f "$current_dir/Gemfile" ]; then
        result=$(_format_project "$(_get_project_icon ruby "💎")" "Ruby")
    elif [ -f "$current_dir/composer.json" ]; then
        result=$(_format_project "$(_get_project_icon php "🐘")" "PHP")
    elif ls "$current_dir"/*.xcodeproj 1>/dev/null 2>&1 || ls "$current_dir"/*.xcworkspace 1>/dev/null 2>&1 || [ -f "$current_dir/Package.swift" ]; then
        result=$(_format_project "$(_get_project_icon swift "🍎")" "Swift")
    elif [ -f "$current_dir/build.gradle" ] || [ -f "$current_dir/build.gradle.kts" ]; then
        if grep -q "kotlin" "$current_dir/build.gradle" 2>/dev/null || grep -q "kotlin" "$current_dir/build.gradle.kts" 2>/dev/null; then
            result=$(_format_project "$(_get_project_icon kotlin "🟣")" "Kotlin")
        elif [ -d "$current_dir/app/src/main/kotlin" ]; then
            result=$(_format_project "$(_get_project_icon kotlin "🟣")" "Kotlin")
        else
            result=$(_format_project "$(_get_project_icon java "☕")" "Java")
        fi
    elif [ -f "$current_dir/settings.gradle.kts" ]; then
        result=$(_format_project "$(_get_project_icon kotlin "🟣")" "Kotlin")
    elif [ -f "$current_dir/mix.exs" ]; then
        result=$(_format_project "$(_get_project_icon elixir "💧")" "Elixir")
    elif [ -f "$current_dir/deno.json" ] || [ -f "$current_dir/deno.jsonc" ]; then
        result=$(_format_project "$(_get_project_icon deno "🦕")" "Deno")
    elif [ -f "$current_dir/bun.lockb" ]; then
        result=$(_format_project "$(_get_project_icon bun "🍞")" "Bun")
    fi

    # Check for dev server / build process
    if [ -n "$result" ]; then
        if [ "$show_dev" = "true" ] && pgrep -f "npm.*dev\|yarn.*dev\|pnpm.*dev\|bun.*dev" >/dev/null 2>&1; then
            result="$result $dev_icon"
        elif [ "$show_build" = "true" ] && pgrep -f "npm.*build\|yarn.*build\|pnpm.*build" >/dev/null 2>&1; then
            result="$result $build_icon"
        fi
    fi

    echo "$result"
}
