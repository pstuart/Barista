---
paths:
  - "modules/**"
---

# Module Development Reference

## Color Themes

COLOR_THEME fills status indicators and icons only when those variables are still unset; shipped barista.conf assigns the default emoji first, so minimal, vibrant, and nerd do not restyle them, while monochrome still forces STATUS_STYLE=ascii and USE_ICONS=false.

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
