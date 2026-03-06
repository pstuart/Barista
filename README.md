# Barista ☕

**Serving up fresh stats for your Claude Code sessions.**

A feature-rich, modular statusline for [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) that brews real-time development information including context usage, rate limits, costs, and more.

![Barista](https://img.shields.io/badge/Barista-Claude_Code-D97757?style=for-the-badge&logo=anthropic&logoColor=white)
![Version](https://img.shields.io/badge/Version-1.6.1-green?style=for-the-badge)
![Shell Script](https://img.shields.io/badge/Shell_Script-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

<p align="center">
  <img src="demo.gif" alt="Barista Demo" width="800">
</p>

## What's New in v1.6.1 🆕

- **Hex-Encoded Keychain Fix** - Handles macOS 15+ and recent Claude Code versions that store OAuth credentials as hex-encoded data in the Keychain (community contribution by @gcko)
- Progressive fallback: tries plain JSON, then hex-decoding via `xxd`, then regex extraction

### v1.6.0

- **Rate Limit 429 Backoff** - Automatically backs off API calls after receiving 429 responses
- **Version Display** - Shows current Barista version in installer and statusline
- **Update Checker** - Enhanced update checking from GitHub releases

### v1.5.0

- **Smart Terminal Layout** - New `LAYOUT_MODE` setting with intelligent line wrapping
  - `smart` (default) - Wraps at separator boundaries when content exceeds terminal width
  - `newline` - Forces Claude's right-side info to next line
  - `wrap` - Pads output to line boundary
  - `truncate` - Cuts output with "..." to fit on same line
  - `none` - No adjustments, natural terminal behavior
- Prevents awkward mid-module line breaks on wide statuslines
- Configurable `RIGHT_SIDE_RESERVE` and `TERMINAL_WIDTH` settings

### v1.4.0

- **Custom Config Directory** - Respects `CLAUDE_CONFIG_DIR` environment variable for users who relocate their Claude configuration from `~/.claude/`
- All paths (cache, logs, usage history, user config) resolve dynamically
- No changes needed if using the default location

### v1.3.0

- **Enhanced Color Themes** - 5 distinct visual themes that actually look different:
  - `default` - Standard emoji (🟢🟡🟠🔴)
  - `minimal` - Subtle geometric shapes (◦ ◐ → ⎇)
  - `vibrant` - Bold heart colors (💚💛🧡❤️)
  - `monochrome` - Pure ASCII ([OK] [~~] [!!] [XX])
  - `nerd` - Nerd Font icons (requires Nerd Font)
- **Improved Spacing** - Status indicators now have proper spacing in normal/verbose modes
- **Smart Compact Mode** - Separator padding and status spacing automatically removed in compact mode
- **Fixed Installer Preview** - Preview now shows actual sample data instead of just icons

### v1.2.0
- **Memory Optimizations** - Fixed unbounded history file growth, added file size caps
- **Interactive Update Check** - Installer now prompts to check for updates on startup with version display
- **4-Level Rate Limit Colors** - Visual indicators at 50%/75%/95% thresholds (🟢→🟡→🟠→🔴)
- **Monorepo Performance** - Git module now limits output to prevent memory spikes in large repos

### v1.1.0
- **Auto-Update Checking** - Barista checks GitHub for updates and can self-update
- **Interactive Installer** - Arrow key navigation with space to toggle selections
- **Customizable Separators** - Choose from pipe, arrow, bullet, and more
- **Color Themes** - Default, minimal, vibrant, or monochrome
- **Display Modes** - Normal, compact, or verbose output
- **Live Preview** - See your statusline before installing
- **Bash 3.2 Compatible** - Works with macOS default bash (no brew required)

## What's On The Menu ☕

### Core Modules (The House Blend)

| Module | What It Serves |
|--------|----------------|
| **directory** | Current working directory name |
| **context** | Visual progress bar showing context usage with auto-compact warnings |
| **git** | Branch name, dirty status, staged/modified/untracked indicators |
| **project** | Auto-detects Node.js, Nuxt, Next.js, Vite, Rust, Go, Python, Swift, and more |
| **model** | Current Claude model and output style |
| **cost** | Session cost with burn rate ($/hour) and tokens per minute (TPM) |
| **rate-limits** | Real-time 5-hour and 7-day rate limit tracking with projections |
| **time** | Current date and time |
| **battery** | Battery percentage (macOS) |

### System Modules (The Espresso Shots)

| Module | What It Serves |
|--------|----------------|
| **cpu** | CPU usage percentage |
| **memory** | RAM usage |
| **disk** | Disk space usage |
| **network** | IP address and network info |
| **uptime** | System uptime |
| **load** | System load average |
| **temperature** | CPU temperature (requires osx-cpu-temp) |
| **brightness** | Screen brightness |
| **processes** | Process count |

### Dev Tools (The Specialty Drinks)

| Module | What It Serves |
|--------|----------------|
| **docker** | Docker container status |
| **node** | Node.js version |
| **weather** | Current weather via wttr.in |
| **timezone** | Multiple timezone clocks |

## Fresh Brew Sample

```
📁 myproject | 📊 ██████░░ 75%🔴 (10k→⚡) | 🌿 main [●+] 📝 3 | ⚡ Nuxt 🚀 | 🤖 Claude Opus 4.5 | 💰 $2.50 @$5.00/h | 5h:45%🟢 7d:78%🟠 | 📅 01/12 🕐 04:30 PM | 🔋 85%
```

**With different separators:**
```
📁 myproject › 📊 ████░░░░ 50%🟢 › 🌿 main › 🤖 Opus    # Arrow style
📁 myproject • 📊 ████░░░░ 50%🟢 • 🌿 main • 🤖 Opus    # Bullet style
DIR: myproject | CTX: ####---- 50%[OK] | GIT: main      # ASCII mode
```

### Temperature Gauge

**Context Usage (3-level):**
| Indicator | Usage | Status |
|-----------|-------|--------|
| 🟢 | Below 60% | Smooth sipping |
| 🟡 | 60-75% | Getting warm |
| 🔴 | Above 75% | Boiling over |

**Rate Limits (4-level):**
| Indicator | Usage | Status |
|-----------|-------|--------|
| 🟢 | Below 50% | Plenty of headroom |
| 🟡 | 50-75% | Moderate usage |
| 🟠 | 75-95% | High usage |
| 🔴 | Above 95% | Critical, near limit |

## Requirements

- **Claude Code CLI** - [Installation Guide](https://docs.anthropic.com/en/docs/claude-code)
- **Bash 3.2+** - Works with macOS default bash
- **jq** - JSON processor (required)
- **bc** - Basic calculator (usually pre-installed)
- **macOS** - For battery and OAuth keychain access (Linux support partial)

```bash
# Install dependencies on macOS
brew install jq
```

## Installation

### Quick Brew

```bash
# Clone the repo
git clone https://github.com/pstuart/Barista.git
cd Barista

# Run the installer
./install.sh
```

The interactive installer features:
- **Arrow key navigation** - Use ↑/↓ to move, Space to toggle, Enter to confirm
- **Module categories** - Core, System, Dev Tools, and Extra modules
- **Display customization** - Icons, separators, colors, and themes
- **Live preview** - See your statusline before installing
- **Automatic backup** - Your previous statusline is saved

### Installer Options

```bash
# Installation
./install.sh                 # Interactive installation with keyboard navigation
./install.sh --defaults      # Install with core modules, no prompts
./install.sh --minimal       # Quick install with minimal modules
./install.sh --force         # Same as --defaults, no confirmation

# Display options
./install.sh --no-emoji      # Install without emojis (ASCII mode)
./install.sh --no-color      # Install without colors

# Updates
./install.sh --check-update  # Check if a newer version is available
./install.sh --update        # Download and install the latest version
./install.sh --version       # Show current version

# Other
./install.sh --uninstall     # Uninstall and restore previous statusline
./install.sh --help          # Show all options
```

### Staying Up to Date

Barista automatically checks for updates when you run the installer. You can also manually check:

```bash
./install.sh --check-update   # Check for updates
./install.sh --update         # Update to latest version
```

### Manual Brew

1. **Copy barista to your Claude directory:**
   ```bash
   CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
   cp -r barista "$CLAUDE_DIR/barista"
   chmod +x "$CLAUDE_DIR/barista/barista.sh"
   ```

2. **Configure Claude Code settings:**

   Edit your `settings.json` (in `$CLAUDE_CONFIG_DIR` or `~/.claude/`):
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/barista/barista.sh"
     }
   }
   ```

3. **Restart Claude Code** to taste your fresh statusline.

## Customization

### Interactive Display Preferences

The installer lets you customize:

| Setting | Options |
|---------|---------|
| **Icon Style** | Emoji icons or ASCII text |
| **Status Indicators** | 🟢🟡🔴 Emoji, ●●● Dots, or [OK][WARN] ASCII |
| **Progress Bars** | ████░░ Blocks, ▓▓▓░░ Shaded, ●●●○○ Circles, #### Hash |
| **Separators** | \| Pipe, ║ Double, › Arrow, • Bullet, : Colon |
| **Color Themes** | Default, Minimal, Vibrant, Monochrome |
| **Display Mode** | Normal, Compact, Verbose |

### Configuration Files

Edit `barista.conf` or create a user override config in your Claude config directory:

```bash
# Default location
~/.claude/barista.conf

# Or if using a custom config directory
$CLAUDE_CONFIG_DIR/barista.conf
```

#### Custom Config Directory

If you've moved your Claude configuration from the default `~/.claude/`, set the `CLAUDE_CONFIG_DIR` environment variable:

```bash
export CLAUDE_CONFIG_DIR="/path/to/my/claude-config"
```

Barista will automatically use that directory for:
- User config overrides (`barista.conf`)
- Cache files (`barista-cache/`)
- Debug logs (`barista.log`)
- Rate limit history (`.usage_history`)

No other configuration changes are needed.

#### Per-Directory Overrides

Create `.barista.conf` in any project directory to customize the statusline for that project:

```bash
# ~/myproject/.barista.conf
# Minimal statusline for this large monorepo
DISPLAY_MODE="compact"
MODULE_WEATHER="false"
MODULE_ORDER="directory,context,git,model"
```

Configuration is loaded in order of precedence:
1. Built-in defaults
2. `barista.conf` (in script directory)
3. `$CLAUDE_CONFIG_DIR/barista.conf` (user overrides, defaults to `~/.claude/`)
4. `.barista.conf` (per-directory overrides)

### Full Configuration Options

```bash
# =============================================================================
# GLOBAL SETTINGS
# =============================================================================

SEPARATOR=" | "           # Section separator (or " › ", " • ", etc.)
DISPLAY_MODE="normal"     # "normal", "compact", "verbose"
COLOR_THEME="default"     # "default", "minimal", "vibrant", "monochrome"
USE_ICONS="true"          # Enable emoji icons
STATUS_STYLE="emoji"      # "emoji", "ascii", "dots"

# Progress bar customization
PROGRESS_BAR_WIDTH=8
PROGRESS_BAR_FILLED="█"   # Or "▓", "●", "#"
PROGRESS_BAR_EMPTY="░"    # Or "░", "○", "-"

# =============================================================================
# MODULE ENABLE/DISABLE
# =============================================================================

# Core modules (on by default)
MODULE_DIRECTORY="true"
MODULE_CONTEXT="true"
MODULE_GIT="true"
MODULE_PROJECT="true"
MODULE_MODEL="true"
MODULE_COST="true"
MODULE_RATE_LIMITS="true"
MODULE_TIME="true"
MODULE_BATTERY="true"

# System modules (off by default)
MODULE_CPU="false"
MODULE_MEMORY="false"
MODULE_DISK="false"
MODULE_NETWORK="false"
MODULE_LOAD="false"

# =============================================================================
# RATE LIMIT SETTINGS (v1.2.0+)
# =============================================================================

RATE_SHOW_USAGE_STATUS="true"   # Show 4-level color indicators
RATE_LOW_THRESHOLD=50           # Green/yellow boundary
RATE_MEDIUM_THRESHOLD=75        # Yellow/orange boundary
RATE_HIGH_THRESHOLD=95          # Orange/red boundary

# Custom order
MODULE_ORDER="directory,context,git,project,model,cost,rate-limits,time,battery"

# =============================================================================
# TERMINAL LAYOUT (v1.5.0+)
# =============================================================================

LAYOUT_MODE="smart"          # "smart", "newline", "wrap", "truncate", "none"
TERMINAL_WIDTH=""            # Manual override (empty = auto-detect)
RIGHT_SIDE_RESERVE=20        # Space reserved for Claude's right-side display
```

### Preset Recipes

**Espresso (Minimal):**
```bash
DISPLAY_MODE="compact"
SEPARATOR=" › "
MODULE_ORDER="directory,context,git,model"
```

**Americano (Developer):**
```bash
MODULE_CPU="true"
MODULE_MEMORY="true"
MODULE_DOCKER="true"
MODULE_ORDER="directory,git,docker,cpu,memory,model,cost,rate-limits,battery"
```

**Decaf (ASCII-only):**
```bash
USE_ICONS="false"
STATUS_STYLE="ascii"
SEPARATOR=" | "
PROGRESS_BAR_FILLED="#"
PROGRESS_BAR_EMPTY="-"
```

**Monochrome (Minimal colors):**
```bash
COLOR_THEME="monochrome"
STATUS_STYLE="dots"
SEPARATOR=" • "
```

## The Menu (Architecture)

```
~/.claude/barista/
├── barista.sh          # Main entry point
├── barista.conf        # Configuration file
├── VERSION             # Version tracking
└── modules/
    ├── utils.sh        # Shared utility functions
    ├── directory.sh    # Directory module
    ├── context.sh      # Context window module
    ├── git.sh          # Git module
    ├── project.sh      # Project detection module
    ├── model.sh        # Model info module
    ├── cost.sh         # Cost & TPM module
    ├── rate-limits.sh  # Rate limits module
    ├── time.sh         # Date/time module
    ├── battery.sh      # Battery module
    └── ...             # Additional modules
```

### Crafting Custom Modules

Create a new file in `modules/` following this recipe:

```bash
# =============================================================================
# My Custom Module - Description
# =============================================================================

module_mycustom() {
    local input="$1"  # JSON input from Claude Code
    # Your logic here
    echo "🎯 My Output"
}
```

Then add to `barista.conf`:
```bash
MODULE_MYCUSTOM="true"
MODULE_ORDER="...,mycustom,..."
```

## Troubleshooting

### Rate limits show "--"
- Ensure you're using Claude Code with a Pro/Team subscription
- Check you're on macOS with credentials stored in Keychain
- Verify you're logged in (`claude login`)

### Modules not loading
- Check file permissions: `chmod +x barista.sh`
- Verify module files exist in `modules/` directory
- Enable debug mode: `DEBUG_MODE="true"`

### Arrow keys not working in installer
- Make sure you're running in a proper terminal (not a script)
- Try a different terminal emulator if issues persist

### Testing manually
```bash
echo '{"workspace":{"current_dir":"'$PWD'"},"model":{"display_name":"Test"},"output_style":{"name":"default"},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":10000}}}' | ~/.claude/barista/barista.sh
```

## Uninstall

```bash
./install.sh --uninstall
```

This will offer to restore your previous statusline if one was backed up.

## Credits

- Inspired by [cc-statusline](https://github.com/chongdashu/cc-statusline) by [@chongdashu](https://github.com/chongdashu)
- Built for use with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) by Anthropic

## License

MIT License - See [LICENSE](LICENSE) for details.

## Author

**Patrick D. Stuart**
- Website: [patrickstuart.com](https://patrickstuart.com)
- GitHub: [@pstuart](https://github.com/pstuart)
- Twitter: [@pstuart](https://twitter.com/pstuart)

---

<div align="center">

**Enjoy your fresh brew!** ☕

*Barista v1.5.0 - Because your Claude Code deserves a great statusline.*

</div>
