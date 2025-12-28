# Claude Code Statusline

A custom statusline script for [Claude Code](https://claude.com/claude-code) that provides accurate cost tracking and context usage warnings.

## Features

- **Accurate Cost Display**: Shows total session cost across all models (Opus, Sonnet, Haiku combined)
- **Context Usage Bar**: Visual progress bar with static overhead estimation for better accuracy
- **Git Integration**: Shows current branch and status indicators (`*` uncommitted, `+` staged, `?` untracked)
- **Timestamp**: Current time for each update
- **Model & Style**: Shows active model and output style

## Screenshot

```
[17:30:45] Opus 4.5 | default | myproject on main*+ | [████████████████░░░░] 78% ctx | $2.11
```

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

### Adjust Static Overhead

The script adds ~53k tokens to account for hidden overhead (system prompt, tools, MCPs). Edit line ~75 in the script:

```bash
STATIC_OVERHEAD=53000  # Default: typical setup with MCPs enabled
```

**Recommended values:**
| Setup | STATIC_OVERHEAD |
|-------|-----------------|
| Full MCPs enabled | 53000 |
| Some MCPs disabled | 35000-45000 |
| MCPs disabled | 20000 |

### Adjust Color Thresholds

Edit these lines to change when colors trigger:

```bash
if [[ $pct -lt 50 ]]; then
    color='\033[32m'  # green
elif [[ $pct -lt 75 ]]; then
    color='\033[33m'  # yellow
else
    color='\033[31m'  # red
fi
```

### Change Progress Bar Width

Modify `bar_width=20` to your preferred width.

## Limitations

### Context Bar Accuracy

Claude Code's statusline JSON only provides `current_usage` (message tokens), not the full context including:

- System prompt (~3k tokens)
- System tools (~16k tokens)
- MCP tools (can be 30k+ tokens depending on your setup)
- Custom agents
- Memory files

We compensate by adding a static overhead estimate (~53k by default). This gets you closer to accurate, but not perfect.

**Known issue:** There are [multiple open GitHub issues](https://github.com/anthropics/claude-code/issues/516) requesting Anthropic to expose total context usage in the statusline JSON. Upvote if you want this fixed properly!

### Calculating Your Own Overhead

To find the right `STATIC_OVERHEAD` for your setup:

1. Run `/context` in Claude Code
2. Add up everything **except** Messages:
   ```
   System prompt:  3,000
   System tools:  16,000
   MCP tools:     33,500  (varies based on your MCPs)
   Custom agents:     50
   Memory files:     494
   ─────────────────────
   STATIC_OVERHEAD = 53,044 → round to 53000
   ```

3. Edit the script and set your value:
   ```bash
   STATIC_OVERHEAD=53000
   ```

**Tip:** If you frequently enable/disable MCP servers, you may need to adjust this value. The MCP tools line in `/context` shows the biggest variable component.

## How It Works

The script receives JSON input from Claude Code containing:
- `cost.total_cost_usd` - Accurate total cost across all models
- `context_window.current_usage` - Current context token usage (messages only)
- `context_window.context_window_size` - Total context window (200k for most models)
- `workspace` - Directory information
- `model` - Active model info

It adds the static overhead to `current_usage` and calculates the percentage against the full context window.

## Related Issues

- [#516](https://github.com/anthropics/claude-code/issues/516) - "Always show available context percentage" (109+ upvotes)
- [#14058](https://github.com/anthropics/claude-code/issues/14058) - "Include actual context window usage in statusline JSON"
- [#13776](https://github.com/anthropics/claude-code/issues/13776) - "Expose full context usage in statusline API"

## License

MIT License - feel free to modify and share!

## Contributing

Issues and PRs welcome. If you find ways to get more accurate context data from Claude Code, please share!
