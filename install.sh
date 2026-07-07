#!/bin/bash

# ── Claude Code Statusline Installer ──────────────────────────────────
# Version: 0.2.0
# One-line installer for the Claude Code Configurable Statusline.
# Usage: curl -sL https://raw.githubusercontent.com/jacob-bd/claude-code-statusline/main/install.sh | bash

set -e

CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
REPO_URL="https://raw.githubusercontent.com/jacob-bd/claude-code-statusline/main"

echo -e "\n\033[1;36m╭──────────────────────────────────────────────────────────╮\033[0m"
echo -e "\033[1;36m│\033[0m  \033[1mInstalling Claude Code Statusline\033[0m                       \033[1;36m│\033[0m"
echo -e "\033[1;36m╰──────────────────────────────────────────────────────────╯\033[0m\n"

# 1. Create directory
echo -e "  \033[36m•\033[0m Creating ~/.claude directory..."
mkdir -p "$CLAUDE_DIR"

# 2. Download or Copy scripts
if [[ -f "./statusline-command.sh" && -f "./configure.sh" ]]; then
    # Developer/local mode: Copy from current working directory
    echo -e "  \033[36m•\033[0m Installing from local repository..."
    cp "./statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh"
    cp "./configure.sh" "$CLAUDE_DIR/configure.sh"
    chmod +x "$CLAUDE_DIR/statusline-command.sh" "$CLAUDE_DIR/configure.sh"
else
    # Production mode: Download from GitHub
    echo -e "  \033[36m•\033[0m Downloading statusline-command.sh..."
    curl -sL "$REPO_URL/statusline-command.sh" -o "$CLAUDE_DIR/statusline-command.sh"
    chmod +x "$CLAUDE_DIR/statusline-command.sh"

    echo -e "  \033[36m•\033[0m Downloading configure.sh..."
    curl -sL "$REPO_URL/configure.sh" -o "$CLAUDE_DIR/configure.sh"
    chmod +x "$CLAUDE_DIR/configure.sh"
fi

# 3. Configure settings.json
echo -e "  \033[36m•\033[0m Updating Claude Code settings..."
if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo '{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}' > "$SETTINGS_FILE"
else
    # Check if statusLine is already configured
    if grep -q '"statusLine"' "$SETTINGS_FILE"; then
        echo -e "    \033[33mWarning\033[0m: 'statusLine' is already configured in settings.json."
        echo "    Please ensure it is set to: \"command\": \"bash ~/.claude/statusline-command.sh\""
    else
        # Very basic append using sed to insert statusLine before the last brace
        # (This is a naive approach; users with complex JSON might need manual editing, 
        # but this works for most basic setups)
        echo -e "    \033[33mNote\033[0m: settings.json exists. Please manually add the statusLine block:"
        echo '    "statusLine": { "type": "command", "command": "bash ~/.claude/statusline-command.sh" }'
    fi
fi

echo -e "\n  \033[32m✓ Installation complete!\033[0m"
echo -e "  Starting the configuration wizard in 3 seconds...\n"
sleep 3

# 4. Launch wizard
bash "$CLAUDE_DIR/configure.sh" < /dev/tty
