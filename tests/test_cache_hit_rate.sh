#!/bin/bash
# Verifies the cache_hit_rate segment computes read / (read + creation) * 100.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP_CONFIG=$(mktemp)
echo '{"segments":["cache_hit_rate"]}' > "$TMP_CONFIG"

MOCK_JSON='{"context_window":{"current_usage":{"cache_read_input_tokens":80,"cache_creation_input_tokens":20,"input_tokens":0}}}'
output=$(echo "$MOCK_JSON" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" bash statusline-command.sh)
output=${output//$'\xc2\xa0'/ }
if [[ "$output" != *"Cache Hit: 80.0%"* ]]; then
    echo "FAIL: expected 'Cache Hit: 80.0%', got: $output"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: cache_hit_rate computes 80.0% for read=80,creation=20"

MOCK_JSON_EMPTY='{"context_window":{"current_usage":{"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"input_tokens":0}}}'
output_empty=$(echo "$MOCK_JSON_EMPTY" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" bash statusline-command.sh)
if [[ -n "$output_empty" ]]; then
    echo "FAIL: expected empty output when read+creation=0, got: $output_empty"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: cache_hit_rate hides when read+creation=0"

rm -f "$TMP_CONFIG"
