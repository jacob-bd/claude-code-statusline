#!/bin/bash
# Verifies vim_mode renders vim.mode when present and hides when absent.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP_CONFIG=$(mktemp)
echo '{"segments":["vim_mode"]}' > "$TMP_CONFIG"

MOCK_JSON='{"vim":{"mode":"NORMAL"}}'
output=$(echo "$MOCK_JSON" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" bash statusline-command.sh)
output=${output//$'\xc2\xa0'/ }
if [[ "$output" != *"NORMAL"* ]]; then
    echo "FAIL: expected output to contain NORMAL, got: $output"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: vim_mode renders NORMAL"

MOCK_JSON_ABSENT='{}'
output_absent=$(echo "$MOCK_JSON_ABSENT" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" bash statusline-command.sh)
if [[ -n "$output_absent" ]]; then
    echo "FAIL: expected empty output when vim mode is disabled (field absent), got: $output_absent"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: vim_mode hides when absent"

rm -f "$TMP_CONFIG"
