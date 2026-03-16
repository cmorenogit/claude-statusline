# @cmoreno/claude-statusline

A rich two-line statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that shows context usage, API rate limits, git branch, session duration, and lines changed.

## Preview

```
Opus 4.6 (1M context) (1M) | my-project | main | [####------] 40% | 1h12m | +185/-6
current ●●●●○○○○ 40% ⟳ 3:22pm  │  weekly ●●○○○○○○ 20% ⟳ mar 20, 8:00am
```

### Line 1 — Session info

| Section | Description |
|---------|-------------|
| `Opus 4.6 (1M context)` | Active model name |
| `(1M)` | Context window size (200K or 1M) |
| `my-project` | Current project directory |
| `main` | Git branch |
| `[####------] 40%` | Context window usage with color-coded bar |
| `1h12m` | Real wall-clock session duration |
| `+185/-6` | Lines added/removed in session |

### Line 2 — API rate limits

| Section | Description |
|---------|-------------|
| `current ●●●●○○○○ 40%` | 5-hour usage window with visual bar |
| `⟳ 3:22pm` | Time when 5-hour window resets |
| `weekly ●●○○○○○○ 20%` | 7-day usage window with visual bar |
| `⟳ mar 20, 8:00am` | Date/time when weekly window resets |
| `extra $2.50/$10.00` | Extra credits used/limit (if enabled) |

### Colors

Usage bars change color based on percentage:

- **Green** — below 50%
- **Orange** — 50-69%
- **Yellow** — 70-89%
- **Red** — 90%+

## Install

```bash
npx @cmoreno/claude-statusline
```

This will:
1. Check dependencies (`jq`, `curl`, `git`, `bash 4+`)
2. Back up your existing statusline (if any)
3. Install the statusline script to `~/.claude/statusline.sh`
4. Update `~/.claude/settings.json` with the statusline config

Restart Claude Code to see the new status line.

## Uninstall

```bash
npx @cmoreno/claude-statusline --uninstall
```

This restores your previous statusline from backup and removes the config from settings.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- `bash` 4+ (macOS: `brew install bash`)
- `jq` — JSON parsing
- `curl` — API usage fetching
- `git` — branch detection

## How it works

- **Context data** is extracted from the JSON that Claude Code pipes to the statusline command via stdin
- **API rate limits** are fetched from `api.anthropic.com/api/oauth/usage` using your OAuth token (from Keychain, credentials file, or env var)
- **Rate limit data is cached** for 60 seconds to avoid API spam
- **Session duration** is derived from the transcript file creation time
- All JSON parsing is batched into minimal `jq` calls for performance

## Platform support

| Platform | Status |
|----------|--------|
| macOS (Apple Silicon) | Fully supported |
| macOS (Intel) | Supported (requires `brew install bash`) |
| Linux | Supported |

## License

MIT
