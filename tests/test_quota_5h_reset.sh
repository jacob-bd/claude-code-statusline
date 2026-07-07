#!/bin/bash
# Verifies quota_5h_reset counts down from rate_limits.five_hour.resets_at.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP_CONFIG=$(mktemp)
echo '{"segments":["quota_5h_reset"]}' > "$TMP_CONFIG"

# 2h5m30s from now: lands mid-minute so a second or two of script startup
# latency between this and the script's own `date +%s` can't tip the
# rendered minute count down to 2h4m.
RESET_AT=$(( $(date +%s) + 7530 ))
MOCK_JSON=$(printf '{"rate_limits":{"five_hour":{"resets_at":%d}}}' "$RESET_AT")
output=$(echo "$MOCK_JSON" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" bash statusline-command.sh)
output=${output//$'\xc2\xa0'/ }
if [[ "$output" != *"resets in 2h5m"* ]]; then
    echo "FAIL: expected 'resets in 2h5m', got: $output"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: quota_5h_reset formats a 2h5m countdown"

MOCK_JSON_ABSENT='{}'
output_absent=$(echo "$MOCK_JSON_ABSENT" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" bash statusline-command.sh)
if [[ -n "$output_absent" ]]; then
    echo "FAIL: expected empty output when rate_limits absent, got: $output_absent"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: quota_5h_reset hides when rate_limits absent"

rm -f "$TMP_CONFIG"
