#!/bin/bash
# Verifies $COLUMNS affects flex-fill width, and $STATUSLINE_WIDTH still wins over it.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP_CONFIG=$(mktemp)
echo '{"segments":["model","flex","cost"]}' > "$TMP_CONFIG"
MOCK_JSON='{"model":{"display_name":"X"},"cost":{"total_cost_usd":1}}'

len_narrow=$(echo "$MOCK_JSON" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" COLUMNS=40 bash statusline-command.sh | wc -c)
len_wide=$(echo "$MOCK_JSON" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" COLUMNS=100 bash statusline-command.sh | wc -c)

if [[ "$len_narrow" -ge "$len_wide" ]]; then
    echo "FAIL: expected COLUMNS=40 output ($len_narrow bytes) shorter than COLUMNS=100 output ($len_wide bytes)"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: \$COLUMNS changes flex-fill width"

len_override=$(echo "$MOCK_JSON" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" STATUSLINE_WIDTH=100 COLUMNS=40 bash statusline-command.sh | wc -c)
diff_override=$(( len_override - len_wide ))
[[ $diff_override -lt 0 ]] && diff_override=$(( -diff_override ))

if [[ "$diff_override" -gt 3 ]]; then
    echo "FAIL: expected STATUSLINE_WIDTH=100 to override COLUMNS=40 (should match ~COLUMNS=100 length), got $len_override vs $len_wide bytes"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: \$STATUSLINE_WIDTH takes priority over \$COLUMNS"

rm -f "$TMP_CONFIG"
