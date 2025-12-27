# Claude Code Statusline

A custom statusline script for [Claude Code](https://claude.com/claude-code) that provides accurate cost tracking and context usage warnings.

## Features

- **Accurate Cost Display**: Shows total session cost across all models (Opus, Sonnet, Haiku combined)
- **Context Usage Bar**: Visual progress bar with conservative thresholds to warn before autocompact
- **Git Integration**: Shows current branch and status indicators (`*` uncommitted, `+` staged, `?` untracked)
- **Timestamp**: Current time for each update
- **Model & Style**: Shows active model and output style

## Screenshot

```
[17:30:45] Opus 4.5 | default | myproject on main*+ | [████████░░░░░░░░░░░░] 32% ctx | $2.11
```

## Why Conservative Context Thresholds?

The Claude Code statusline JSON only exposes ~50% of actual context usage (messages only, missing system prompt, tools, and MCP overhead). To compensate:

| Statusline Shows | Actual Context | Color  |
|------------------|----------------|--------|
| 0-25%            | ~50%           | Green  |
| 25-40%           | ~65-80%        | Yellow |
| 40%+             | ~80%+ (autocompact zone) | Red |

When you see **yellow**, autocompact is approaching. When you see **red**, you're in the danger zone.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- `jq` for JSON parsing:
  ```bash
  # macOS
  brew install jq

  # Linux (Debian/Ubuntu)
  sudo apt install jq

  # Linux (Fedora)
  sudo dnf install jq
  ```

### Setup

1. **Download the script:**
   ```bash
   mkdir -p ~/.claude
   curl -o ~/.claude/statusline-command.sh https://raw.githubusercontent.com/jacob-bd/claude-code-statusline/main/statusline-command.sh
   chmod +x ~/.claude/statusline-command.sh
   ```

2. **Configure Claude Code** - add to `~/.claude/settings.json`:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "bash ~/.claude/statusline-command.sh"
     }
   }
   ```

   Or if you already have settings, just add the `statusLine` block.

3. **Restart Claude Code** to apply changes.

## Customization

### Adjust Context Thresholds

Edit the script and modify these lines to change when colors trigger:

```bash
if [[ $pct -lt 25 ]]; then
    color='\033[32m'  # green
elif [[ $pct -lt 40 ]]; then
    color='\033[33m'  # yellow
else
    color='\033[31m'  # red
fi
```

### Change Progress Bar Width

Modify `bar_width=20` to your preferred width.

## Limitations

### Context Bar Accuracy

The context percentage shown is **not the full picture**. Claude Code's statusline JSON only provides `current_usage` which represents approximately 50% of actual context:

**What's included in the JSON:**
- Message tokens (your conversation)
- Cache creation/read tokens

**What's NOT included:**
- System prompt (~3k tokens)
- System tools (~16k tokens)
- MCP tools (can be 30k+ tokens depending on your setup)
- Custom agents
- Memory files

This means when the statusline shows 30%, your actual context might be 60%+. The conservative color thresholds compensate for this hidden overhead.

### MCP Variability

If you frequently enable/disable MCP servers, the hidden overhead changes. The thresholds are tuned for a typical setup with MCPs enabled. With MCPs disabled, you have more headroom than the colors suggest.

## How It Works

The script receives JSON input from Claude Code containing:
- `cost.total_cost_usd` - Accurate total cost across all models
- `context_window.current_usage` - Current context token usage
- `workspace` - Directory information
- `model` - Active model info

It processes this data and outputs a formatted statusline with ANSI colors.

## License

MIT License - feel free to modify and share!

## Contributing

Issues and PRs welcome. If you find ways to get more accurate context data from Claude Code, please share!
