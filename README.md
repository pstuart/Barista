# Barista ☕

**Serving up fresh stats for your Claude Code sessions.**

A feature-rich, modular statusline for [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) that brews real-time development information including context usage, rate limits, costs, and more.

![Barista](https://img.shields.io/badge/Barista-Claude_Code-D97757?style=for-the-badge&logo=anthropic&logoColor=white)
![Version](https://img.shields.io/badge/Version-1.1.0-green?style=for-the-badge)
![Shell Script](https://img.shields.io/badge/Shell_Script-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

<p align="center">
  <img src="demo.gif" alt="Barista Demo" width="800">
</p>

## What's New in v1.1.0 🆕

- **Auto-Update Checking** - Barista now checks GitHub for updates and can self-update
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
📁 myproject | 📊 ██████░░ 75%🔴 (10k→⚡) | 🌿 main [●+] 📝 3 | ⚡ Nuxt 🚀 | 🤖 Claude Opus 4.5 | 💰 $2.50 @$5.00/h | 5h:45%🟡 7d:23%🟢 | 📅 01/12 🕐 04:30 PM | 🔋 85%
```

**With different separators:**
```
📁 myproject › 📊 ████░░░░ 50%🟢 › 🌿 main › 🤖 Opus    # Arrow style
📁 myproject • 📊 ████░░░░ 50%🟢 • 🌿 main • 🤖 Opus    # Bullet style
DIR: myproject | CTX: ####---- 50%[OK] | GIT: main      # ASCII mode
```

### Temperature Gauge

| Indicator | Context Usage | Rate Limits |
|-----------|---------------|-------------|
| 🟢 | Below 60% - Smooth sipping | Projected to stay under limit |
| 🟡 | 60-75% - Getting hot | Warning, approaching threshold |
| 🔴 | Above 75% - Boiling over | Critical, limit imminent |

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
   cp -r barista ~/.claude/barista
   chmod +x ~/.claude/barista/barista.sh
   ```

2. **Configure Claude Code settings:**

   Edit `~/.claude/settings.json`:
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

Edit `barista.conf` or create `~/.claude/barista.conf` for user overrides.

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
2. `~/.claude/barista/barista.conf`
3. `~/.claude/barista.conf` (user overrides)
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

# Custom order
MODULE_ORDER="directory,context,git,project,model,cost,rate-limits,time,battery"
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

*Barista v1.1.0 - Because your Claude Code deserves a great statusline.*

</div>
