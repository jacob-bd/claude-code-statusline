#!/bin/bash
# Verifies api_duration formats cost.total_api_duration_ms as m/s, distinct from wall-clock duration.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP_CONFIG=$(mktemp)
echo '{"segments":["api_duration"]}' > "$TMP_CONFIG"

MOCK_JSON='{"cost":{"total_api_duration_ms":72000}}'
output=$(echo "$MOCK_JSON" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" bash statusline-command.sh)
output=${output//$'\xc2\xa0'/ }
if [[ "$output" != *"api 1m12s"* ]]; then
    echo "FAIL: expected 'api 1m12s', got: $output"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: api_duration formats 72000ms as 1m12s"

MOCK_JSON_ZERO='{"cost":{"total_api_duration_ms":0}}'
output_zero=$(echo "$MOCK_JSON_ZERO" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" bash statusline-command.sh)
if [[ -n "$output_zero" ]]; then
    echo "FAIL: expected empty output when total_api_duration_ms=0, got: $output_zero"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: api_duration hides when zero"

rm -f "$TMP_CONFIG"
