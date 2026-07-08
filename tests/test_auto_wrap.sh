#!/bin/bash
# Verifies that a line of segments exceeding the terminal width auto-wraps
# onto additional physical lines instead of truncating with "...", so no
# enabled segment is ever silently hidden.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP_CONFIG=$(mktemp)
echo '{"segments":["timestamp","model","style","directory","git","cost"]}' > "$TMP_CONFIG"
MOCK_JSON='{"model":{"display_name":"Sonnet 5"},"output_style":{"name":"concise"},"workspace":{"current_dir":"/tmp/my-project","project_dir":"/tmp/my-project"},"cost":{"total_cost_usd":0.85}}'

# Narrow enough to force wrapping across more than one physical line.
output=$(echo "$MOCK_JSON" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" COLUMNS=40 bash statusline-command.sh)
line_count=$(echo "$output" | wc -l | tr -d ' ')

if [[ "$line_count" -le 1 ]]; then
    echo "FAIL: expected output to wrap onto more than one line at COLUMNS=40, got $line_count line(s): $output"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: overflowing segments wrap onto multiple physical lines ($line_count lines)"

if [[ "$output" == *"..."* ]]; then
    echo "FAIL: expected no truncation ellipsis when auto-wrapping, got: $output"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: no segment content was truncated"

if [[ "$output" != *'$0.85'* ]]; then
    echo "FAIL: expected the cost segment ('\$0.85') to survive the wrap onto a later line, got: $output"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: a segment pushed onto a wrapped line still renders in full"

rm -f "$TMP_CONFIG"
