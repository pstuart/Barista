# Barista - Claude Code Statusline

A modular, shell-based statusline for Claude Code CLI that displays real-time development information including context usage, rate limits, costs, git status, and more.

## Project Overview

Barista is a **Bash shell script** project (Bash 3.2+ compatible for macOS). It generates a customizable status line that Claude Code displays at the bottom of the terminal. The architecture is modular - each piece of information (git, battery, CPU, etc.) is handled by a separate module in the `modules/` directory.

## Architecture

```
Barista/
├── barista.sh          # Main entry point - loads config, modules, orchestrates output
├── barista.conf        # Default configuration file
├── install.sh          # Interactive installer with arrow key navigation
├── VERSION             # Version tracking (semver)
├── modules/
│   ├── utils.sh        # Shared utility functions (MUST load first)
│   ├── directory.sh    # Current directory module
│   ├── context.sh      # Context window usage with progress bar
│   ├── git.sh          # Git branch and status
│   ├── project.sh      # Project type detection (Node, Rust, Python, etc.)
│   ├── model.sh        # Current Claude model info
│   ├── cost.sh         # Session cost and burn rate
│   ├── rate-limits.sh  # 5-hour and 7-day rate limit tracking
│   ├── time.sh         # Date and time display
│   ├── battery.sh      # Battery percentage (macOS)
│   ├── cpu.sh          # CPU usage
│   ├── memory.sh       # RAM usage
│   ├── disk.sh         # Disk space
│   ├── network.sh      # Network info
│   ├── node.sh         # Node.js version
│   ├── docker.sh       # Docker container status
│   ├── weather.sh      # Weather via wttr.in
│   └── ...             # Additional modules
└── README.md
```

## How It Works

1. **Claude Code calls `barista.sh`** with JSON input containing workspace info, model, context window data, etc.
2. **Configuration is loaded** in order of precedence:
   - Built-in defaults in `barista.sh`
   - `barista.conf` in script directory
   - `$CLAUDE_CONFIG_DIR/barista.conf` (user overrides, defaults to `~/.claude/`)
   - `.barista.conf` in current project directory (per-project overrides)
3. **Modules are loaded** from `modules/` directory (`utils.sh` first, then all others)
4. **Modules are executed** in the order specified by `MODULE_ORDER` config
5. **Output is concatenated** with the configured `SEPARATOR` and printed

## Key Files

### `barista.sh` (Main Entry Point)
- Resolves `CLAUDE_CONFIG_DIR` (env var or defaults to `$HOME/.claude`)
- Defines default configuration values
- Loads configuration files in precedence order
- Loads all module files from `modules/`
- Contains module registry mapping names to functions
- Executes enabled modules and joins output with separator
- Adjusts separator spacing based on `DISPLAY_MODE`

### `modules/utils.sh` (Required Utilities)
- **Theme system**: `apply_theme()` sets icons and indicators based on `COLOR_THEME`
- **Cache system**: File-based caching for expensive operations
- **Safe number handling**: `safe_int()`, `safe_divide()`, `safe_percent()`
- **Status indicators**: `get_status()` (3-level), `get_status_4level()` (4-level for rate limits)
- **Icon handling**: `get_icon()` respects `USE_ICONS` setting
- **Progress bar**: `progress_bar()` generates visual bars
- **JSON helpers**: `json_get()`, `json_get_int()` for safe extraction
- **Display mode checks**: `is_compact()`, `is_verbose()`
- **Logging**: `log_debug()` for debug mode

### `barista.conf` (Configuration)
All settings are documented with comments. Key settings:
- `SEPARATOR` - Character(s) between modules (default: `" | "`)
- `DISPLAY_MODE` - `"normal"`, `"compact"`, or `"verbose"`
- `COLOR_THEME` - `"default"`, `"minimal"`, `"vibrant"`, `"monochrome"`, or `"nerd"`
- `USE_ICONS` - Enable/disable emoji icons
- `STATUS_STYLE` - `"emoji"`, `"ascii"`, or `"dots"`
- `MODULE_*` - Enable/disable individual modules
- `MODULE_ORDER` - Comma-separated list defining display order

## Color Themes

The `COLOR_THEME` setting changes status indicators and icons globally:

| Theme | Status Indicators | Icon Style | Use Case |
|-------|-------------------|------------|----------|
| **default** | 🟢 🟡 🟠 🔴 | Standard emoji (📁 📊 🌿) | General use |
| **minimal** | ◦ ◦ ◦ ● | Geometric (→ ◐ ⎇ ◈) | Clean, subtle look |
| **vibrant** | 💚 💛 🧡 ❤️ | Expressive (📂 🎯 🔀 🧠) | High visibility |
| **monochrome** | [OK] [~~] [!!] [XX] | ASCII text (DIR: CTX: GIT:) | Terminal compatibility |
| **nerd** |     | Nerd Font glyphs | Requires Nerd Font |

Themes are applied via `apply_theme()` in `utils.sh` after all configs are loaded.

## Module Structure

Each module follows this pattern:

```bash
# =============================================================================
# Module Name - Brief description
# =============================================================================
# Configuration options:
#   OPTION_NAME    - Description (default: value)
# =============================================================================

module_name() {
    local input="$1"  # JSON input (for modules that need it)

    # Get configuration with defaults
    local icon=$(get_icon "${MODULE_ICON:-📊}" "FALLBACK:")
    local some_option="${SOME_OPTION:-default}"

    # Do work...

    # Build and output result
    local result="$icon some_value"
    echo "$result"
}
```

### Module Types

1. **Input-dependent modules** (context, model, cost): Receive JSON input as `$1`
2. **Directory-dependent modules** (git, project): Receive current directory as `$1`
3. **Standalone modules** (time, battery, cpu): Take no arguments

## Display Modes

The `DISPLAY_MODE` setting affects multiple behaviors:

- **`normal`**: Balanced display with icons and key info, padded separators, spaces before status indicators
- **`compact`**: Minimal display, no separator padding, no spaces before status indicators
- **`verbose`**: Full display with all available information

## Status Indicators

Two systems for visual status:

1. **3-level** (`get_status`): green/yellow/red based on warning/critical thresholds
2. **4-level** (`get_status_4level`): green/yellow/orange/red for more granular rate limit display

Both respect `DISPLAY_MODE` for spacing and `STATUS_STYLE` for appearance (emoji/ascii/dots).

## Adding a New Module

1. Create `modules/mymodule.sh` following the pattern above
2. Add to module registry in `barista.sh`:
   ```bash
   case "$module_name" in
       mymodule)     echo "module_mymodule" ;;
   ```
3. Add to `run_module()` case if it needs special arguments
4. Add configuration defaults to `barista.sh` and `barista.conf`:
   ```bash
   MODULE_MYMODULE="false"  # Disabled by default
   ```
5. Add to `MODULE_ORDER` where you want it to appear

## Coding Conventions

- **Bash 3.2+ compatible** - No associative arrays, use `case` statements instead
- **Use utility functions** - `safe_int()`, `json_get()`, etc. for safe operations
- **Local variables** - Always declare with `local` in functions
- **Quoting** - Always quote variables: `"$var"` not `$var`
- **Configuration pattern**: `local value="${CONFIG_VAR:-default}"`
- **Error handling** - Redirect stderr: `command 2>/dev/null`
- **Comments** - Document configuration options at module top

## Testing

Test the statusline manually:
```bash
echo '{"workspace":{"current_dir":"'$PWD'"},"model":{"display_name":"Test"},"output_style":{"name":"default"},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":10000}}}' | ./barista.sh
```

Enable debug mode:
```bash
DEBUG_MODE="true"  # In config
# Logs to $CLAUDE_CONFIG_DIR/barista.log
```

## Dependencies

- **Required**: `jq` (JSON processor), `bc` (calculator)
- **macOS specific**: `security` (keychain access for OAuth tokens)
- **Optional**: Various CLI tools for specific modules (docker, node, etc.)

## Custom Config Directory

Barista respects the `CLAUDE_CONFIG_DIR` environment variable for users who have moved their Claude configuration from the default `~/.claude/`. This is resolved once in `barista.sh` and inherited by all modules:

```bash
CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
```

Files stored in this directory:
- `barista.conf` - User config overrides
- `barista-cache/` - Cache for expensive operations (weather, network, etc.)
- `barista.log` - Debug log (when `DEBUG_MODE="true"`)
- `.usage_history` - Rate limit history for projections

Modules also include their own `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` fallback for robustness if sourced independently.

## Rate Limits Module

The rate limits module (`rate-limits.sh`) is the most complex:
- Fetches usage from Anthropic API using OAuth token from macOS Keychain
- Caches responses to avoid excessive API calls
- Maintains history file for projection calculations
- Implements file size caps to prevent memory issues
- Shows 4-level color indicators for usage thresholds

## Installation

The installer (`install.sh`) provides:
- Interactive module selection with arrow key navigation
- Live preview of statusline
- Multiple presets (minimal, developer, etc.)
- Auto-update checking from GitHub
- Backup/restore of previous statusline
