#!/bin/bash
# Verifies STATUSLINE_CONFIG_FILE overrides the default config path.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP_CONFIG=$(mktemp)
echo '{"segments":["model"]}' > "$TMP_CONFIG"
MOCK_JSON='{"model":{"display_name":"TestModel"},"workspace":{"current_dir":"/tmp"}}'

output=$(echo "$MOCK_JSON" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" bash statusline-command.sh)

if [[ "$output" != *"TestModel"* ]]; then
    echo "FAIL: expected output to contain TestModel, got: $output"
    rm -f "$TMP_CONFIG"
    exit 1
fi
if [[ "$output" == *"/tmp"* ]]; then
    echo "FAIL: directory segment should not render (config only enables 'model'), got: $output"
    rm -f "$TMP_CONFIG"
    exit 1
fi

echo "PASS: STATUSLINE_CONFIG_FILE override respected"
rm -f "$TMP_CONFIG"
