#!/bin/bash
# Verifies worktree renders workspace.git_worktree when present and hides when absent.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP_CONFIG=$(mktemp)
echo '{"segments":["worktree"]}' > "$TMP_CONFIG"

MOCK_JSON='{"workspace":{"git_worktree":"feature-x"}}'
output=$(echo "$MOCK_JSON" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" bash statusline-command.sh)
output=${output//$'\xc2\xa0'/ }
if [[ "$output" != *"feature-x"* ]]; then
    echo "FAIL: expected output to contain feature-x, got: $output"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: worktree renders feature-x"

MOCK_JSON_ABSENT='{}'
output_absent=$(echo "$MOCK_JSON_ABSENT" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" bash statusline-command.sh)
if [[ -n "$output_absent" ]]; then
    echo "FAIL: expected empty output when not inside a git worktree, got: $output_absent"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: worktree hides when absent"

rm -f "$TMP_CONFIG"
