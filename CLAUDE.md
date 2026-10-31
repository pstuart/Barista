# Barista - Claude Code Statusline

A modular, shell-based statusline for Claude Code CLI that displays real-time development information including context usage, rate limits, costs, git status, and more.

## Project Overview

Barista is a **Bash shell script** project (Bash 3.2+ compatible for macOS). It generates a customizable status line that Claude Code displays at the bottom of the terminal. The architecture is modular - each piece of information (git, battery, CPU, etc.) is handled by a separate module in the `modules/` directory.

## How It Works

1. **Claude Code calls `barista.sh`** with JSON input containing workspace info, model, context window data, etc.
2. **Configuration is loaded** in order of precedence:
   - Built-in defaults in `barista.sh`
   - `barista.conf` in script directory
   - `$CLAUDE_CONFIG_DIR/barista.conf` (user overrides, defaults to `~/.claude/`)
   - `.barista.conf` in current project directory (per-project overrides)

   Packaged `barista.conf` and the user override (`$CLAUDE_CONFIG_DIR/barista.conf`) are sourced as bash after a group/world-writable check. Per-directory `.barista.conf` is untrusted: `load_config_safe` (KEY=VALUE allowlist) never sources it. Config-derived numerics are validated before they reach `bc`/URL sinks. `barista config --project` uses the same safe parser.
3. **Modules are loaded** from `modules/` directory (`utils.sh` first, then all others)
4. **Modules are executed** in the order specified by `MODULE_ORDER` config
5. **Output is concatenated** with the configured `SEPARATOR` and printed

## Adding a New Module

The module template and module types ("the pattern above" in step 1) are in `.claude/rules/module-development.md`.

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

Regression tests live in `tests/` (pure-bash assert harness, no framework). Each file runs standalone:
```bash
bash tests/test_utils.sh           # utils.sh helpers
bash tests/test_rate_limits.sh     # rate-limit parsers/backoff
bash tests/test_config_cli.sh      # barista config CLI (set/toggle/project)
bash tests/test_install_update.sh  # installer update flags + runtime copy
# also: test_cache, test_git_cache, test_project, test_sandbox, test_update, test_uptime
```

Lint with `shellcheck` — `.shellcheckrc` disables SC2155 and SC2034 project-wide (see issue #21 for the policy).

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

## Path-scoped rules

Detail that used to live in this file is in `.claude/rules/`. Each file loads automatically when Claude reads or edits a matching path:

- `.claude/rules/architecture.md`: annotated tree of the repo, and what barista.sh, modules/utils.sh and barista.conf contain.
- `.claude/rules/module-development.md`: color themes, module template and types, display modes, and status indicator systems.
- `.claude/rules/rate-limits.md`: how modules/rate-limits.sh fetches, caches, backs off and projects usage.
- `.claude/rules/installer.md`: what install.sh provides and copies.
