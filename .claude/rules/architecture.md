---
paths:
  - "barista.sh"
  - "barista.conf"
  - "modules/utils.sh"
  - "lib/**"
---

# Architecture and Key Files

## Architecture

```
Barista/
├── barista.sh          # Main entry point - loads config, modules, orchestrates output
├── barista.conf        # Default configuration file
├── install.sh          # Interactive installer with arrow key navigation
├── VERSION             # Version tracking (semver)
├── lib/
│   └── config-tui.sh   # Runtime config TUI (`barista config`) — must ship with install
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
│   ├── sandbox.sh      # Lock icon when in a macOS app sandbox
│   ├── version.sh      # Barista version, shown briefly after startup
│   ├── update.sh       # Daily GitHub check for new releases
│   └── ...             # Additional modules
├── tests/              # Regression tests (bash tests/test_*.sh, standalone)
├── .shellcheckrc       # Shellcheck policy (SC2155, SC2034 disabled)
└── README.md
```

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
- **Display mode checks**: `is_compact()`
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
