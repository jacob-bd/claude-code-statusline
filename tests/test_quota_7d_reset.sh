#!/bin/bash
# Verifies quota_7d_reset counts down from rate_limits.seven_day.resets_at.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP_CONFIG=$(mktemp)
echo '{"segments":["quota_7d_reset"]}' > "$TMP_CONFIG"

# 2d3h30m from now: comfortably inside the "3h" hour bucket so a second or
# two of script startup latency can't tip the rendered hour count down.
RESET_AT=$(( $(date +%s) + 185400 ))
MOCK_JSON=$(printf '{"rate_limits":{"seven_day":{"resets_at":%d}}}' "$RESET_AT")
output=$(echo "$MOCK_JSON" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" bash statusline-command.sh)
output=${output//$'\xc2\xa0'/ }
if [[ "$output" != *"resets in 2d3h"* ]]; then
    echo "FAIL: expected 'resets in 2d3h', got: $output"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: quota_7d_reset formats a 2d3h countdown"

MOCK_JSON_ABSENT='{}'
output_absent=$(echo "$MOCK_JSON_ABSENT" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" bash statusline-command.sh)
if [[ -n "$output_absent" ]]; then
    echo "FAIL: expected empty output when rate_limits absent, got: $output_absent"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: quota_7d_reset hides when rate_limits absent"

rm -f "$TMP_CONFIG"
