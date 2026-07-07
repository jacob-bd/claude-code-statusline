#!/bin/bash
# Verifies cache_read shows the read token count with its % share of total context.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP_CONFIG=$(mktemp)
echo '{"segments":["cache_read"]}' > "$TMP_CONFIG"

MOCK_JSON='{"context_window":{"current_usage":{"cache_read_input_tokens":1600,"cache_creation_input_tokens":400,"input_tokens":0}}}'
output=$(echo "$MOCK_JSON" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" bash statusline-command.sh)
output=${output//$'\xc2\xa0'/ }
if [[ "$output" != *"Cache Read: 1.6k (80%)"* ]]; then
    echo "FAIL: expected 'Cache Read: 1.6k (80%)', got: $output"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: cache_read shows token count and percentage"

MOCK_JSON_ZERO='{"context_window":{"current_usage":{"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"input_tokens":0}}}'
output_zero=$(echo "$MOCK_JSON_ZERO" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" bash statusline-command.sh)
if [[ -n "$output_zero" ]]; then
    echo "FAIL: expected empty output when cache_read_input_tokens=0, got: $output_zero"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: cache_read hides when zero"

rm -f "$TMP_CONFIG"
