# Claude Code Configurable Statusline

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat-square&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/jacobbd)
![Version](https://img.shields.io/badge/version-0.2.0-blue.svg)

A highly customizable statusline for [Claude Code](https://claude.com/claude-code) with an interactive setup wizard. Displays accurate context usage, API costs, subscription quotas (5-hour and 7-day), and 12 other configurable segments.

![Claude Code Statusline](assets/statusline.png)

For details on recent changes, see the [Changelog](CHANGELOG.md).

## Features

- **Interactive Setup Wizard**: Terminal UI to easily toggle and reorder segments.
- **Accurate Context & Quota Tracking**: Uses Claude Code's native JSON payload for exact context percentage and Pro/Max subscriber rate limits.
- **Smart Cost Display**: Automatically hides API costs if you're on a Claude subscription and have quota bars enabled.
- **16 Available Segments**: Choose from Model, Timestamp, Git, Output Style, Effort, Duration, Thinking Status, PR Info, and more.
- **Zero Dependencies**: Pure `bash` (3.2+ compatible) and `jq`. No external network requests, no cache files.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed (v2.1.132+ recommended for native context percentage)
- `jq` for JSON parsing:
  - **macOS**: `brew install jq`
  - **Linux**: `sudo apt install jq` (Debian/Ubuntu) or `sudo dnf install jq` (Fedora)
  - **Windows**: `winget install jqlang.jq` or `choco install jq` or `scoop install jq`

### Setup

Run this one-line command in your terminal. It will download the scripts, update your Claude Code settings, and automatically launch the configuration wizard:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/jacob-bd/claude-code-statusline/main/install.sh)"
```

*Note: Restart Claude Code after installation to apply the changes.*

### Uninstallation

To remove the custom statusline and revert Claude Code to its default behavior:

1. Open your Claude Code settings file: `~/.claude/settings.json`
2. Delete the entire `"statusLine"` block.
3. Restart Claude Code.
4. (Optional) Delete the scripts and config:
   ```bash
   rm ~/.claude/statusline-command.sh ~/.claude/configure.sh ~/.claude/statusline-config.json
   ```

## Configuration Wizard

Run the interactive wizard to choose which segments appear and in what order:

```bash
bash ~/.claude/configure.sh
```

![Configuration Wizard](assets/wizard.png)

### How it works
1. Type a number (1-19) and press Enter to toggle a segment on or off.
2. The live preview updates instantly.
3. Press `s` to save your configuration to `~/.claude/statusline-config.json`.
4. Your Claude Code statusline will update on the next prompt!

> [!TIP]
> **Handling Truncation (`..`)**: Claude Code keeps the status line on a single line and will automatically truncate it with `..` if it exceeds your terminal width. If your status line is getting cut off:
> 1. Run `configure.sh` and toggle off less important segments (e.g., Output Style, Thinking, or Version).
> 2. Reduce the progress bar widths in your config file (see *Advanced Configuration* below).

### Available Segments

| Segment | Example | Description |
|---------|---------|-------------|
| **Timestamp** | `[10:05:06]` | Current local time |
| **Model** | `Sonnet 5` | Active model display name |
| **Effort level** | `⚡med` | Current reasoning effort level |
| **Output style** | `concise` | Active output style |
| **Directory** | `my-project` | Current directory (relative to workspace) |
| **Git status** | `on main*+` | Branch name and indicators (`*` uncommitted, `+` staged, `?` untracked) |
| **Context window** | `[████░░░░] 42% 114k left`| Context usage percentage and remaining tokens |
| **Context % only** | `Context: 42% 114k left` | Context usage percentage only (saves space) |
| **API Cost** | `$0.85` | Session total cost |
| **Quota 5h** | `5h [██░░] 24%` | Subscription 5-hour rolling rate limit (Pro/Max) |
| **Quota 5h % only**| `5h 24%` | Subscription 5-hour rate limit percentage only (saves space) |
| **Quota 7d** | `7d [████░░] 41%` | Subscription 7-day rate limit (Pro/Max) |
| **Quota 7d % only**| `7d 41%` | Subscription 7-day rate limit percentage only (saves space) |
| **Duration** | `⏱ 2m34s` | Total time waiting for API responses |
| **Lines changed** | `+48/-12` | Lines of code added/removed |
| **Session name** | `📌 my-session` | Custom session name |
| **Thinking** | `💭 on` | Extended thinking status |
| **Version** | `v2.1.200` | Claude Code version |
| **PR info** | `PR #42 ✓` | Open PR number and review status |

## Advanced Configuration

You can manually edit the config file at `~/.claude/statusline-config.json`:

```json
{
  "segments": [
    "timestamp",
    "model",
    "directory",
    "git",
    "context",
    "cost",
    "quota_5h",
    "quota_7d"
  ],
  "context_bar_width": 20,
  "bar_width": 10
}
```

The order of items in the `segments` array determines their display order from left to right.

## License

MIT License - feel free to modify and share!
