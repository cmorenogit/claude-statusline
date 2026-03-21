# @cmorenogit/claude-statusline

A rich two-line statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with Catppuccin Mocha theme, Nerd Font icons, and block-char progress bars.

## Preview

```
⚡ Opus 4.6 (1M context) │ 📁 app-profile │  feature/foo │ +103/-69
⚙  ████░░░░░░ 45% │ 🕐 23m │ ⚡  ░░░░░░░░░░ 2% 󰑐 17:00 │ 📅  █░░░░░░░░░ 11% 󰑐 mar27 00:00
```

### Line 1 — Session info

| Icon | Section | Description |
|------|---------|-------------|
| `⚡` | Model | Active model display name |
| `📁` | Directory | Current project directory |
| `` | Branch | Git branch (read from `.git/HEAD`, no fork) |
| | Lines | Lines added (green) / removed (red) in session |

### Line 2 — Metrics & rate limits

| Icon | Section | Description |
|------|---------|-------------|
| `⚙` | Context | Context window usage with 10-block bar (each = 10%) |
| `🕐` | Duration | Wall-clock session duration |
| `⚡` | Current | 5-hour API usage window with bar |
| `📅` | Weekly | 7-day API usage window with bar |
| `$` | Extra | Extra credits used/limit (if enabled) |
| `󰑐` | Reset | Time until window resets (24h format) |

### Color theme — Catppuccin Mocha

| Element | Color | Hex |
|---------|-------|-----|
| Model | Blue | `#89b4fa` |
| Directory | Text | `#cdd6f4` |
| Branch | Green | `#a6e3a1` |
| Context icon | Mauve | `#cba6f7` |
| Duration | Subtext | `#a6adc8` |
| Current icon | Peach | `#fab387` |
| Weekly icon | Blue | `#89b4fa` |
| Extra icon | Yellow | `#f9e2af` |
| Reset times | Overlay | `#7f849c` |
| Separators | Surface | `#585b70` |

Usage bars change color based on percentage:

| Range | Color | Hex |
|-------|-------|-----|
| < 50% | Green | `#a6e3a1` |
| 50-69% | Peach | `#fab387` |
| 70-89% | Yellow | `#f9e2af` |
| 90%+ | Red | `#f38ba8` |

## Prerequisites

- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** CLI installed and authenticated
- **Bash 4+** — macOS ships with bash 3, install with `brew install bash`
- **[Nerd Font](https://www.nerdfonts.com/)** — required for icons (e.g., JetBrains Mono NF, DankMono NF, MesloLGS NF)
- **jq** — JSON parsing (`brew install jq`)
- **curl** — API usage fetching (pre-installed on macOS)
- **Truecolor terminal** — for Catppuccin colors (Ghostty, iTerm2, Kitty, Alacritty, WezTerm)

## Install

```bash
npx @cmorenogit/claude-statusline
```

This will:
1. Detect your bash 4+ path and patch the shebang
2. Back up your existing statusline (if any)
3. Install the script to `~/.claude/statusline-command.sh`
4. Update `~/.claude/settings.json` with the statusline config

Restart Claude Code to see the new status line.

## Update

```bash
npx @cmorenogit/claude-statusline@latest
```

## Uninstall

```bash
npx @cmorenogit/claude-statusline --uninstall
```

Restores your previous statusline from backup and removes the config from settings.

## How it works

- **Context data** is extracted from the JSON that Claude Code pipes to stdin
- **API rate limits** are fetched from `api.anthropic.com/api/oauth/usage` using your OAuth token (Keychain or credentials file)
- **Rate limit data is cached** for 5 minutes to avoid API overhead
- **Git branch** is read directly from `.git/HEAD` (no fork)
- **Session duration** is derived from transcript file birth time using `$EPOCHSECONDS`
- **No subshells** — helper functions use bash namerefs (`local -n`) to avoid fork overhead
- All JSON parsing is batched into minimal `jq` calls

### Performance

| Scenario | Time |
|----------|------|
| With cache (99% of calls) | ~37ms |
| Cache miss (every 5 min) | ~480ms |

## Platform

macOS only (Apple Silicon & Intel). Requires `brew install bash` for bash 4+.

## License

MIT
