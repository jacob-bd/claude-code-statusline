#!/bin/bash
# Regression test: line truncation must not split multi-byte UTF-8 characters
# (block-drawing bars, emoji). Splitting mid-character can crash macOS's
# system awk ("towc: multibyte conversion failure") or emit a corrupted
# replacement byte, producing empty/garbled output on narrow terminals.
#
# Truncation-with-"..." only still applies to lines using "flex" (auto-wrap
# handles overflow for everything else) -- "flex" is included here so this
# exercises that code path specifically.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP_CONFIG=$(mktemp)
echo '{"segments":["context","flex"]}' > "$TMP_CONFIG"
MOCK_JSON='{"context_window":{"used_percentage":42,"remaining_percentage":58,"context_window_size":200000}}'

# Narrow enough that the block-character progress bar must be truncated.
output=$(echo "$MOCK_JSON" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" COLUMNS=30 bash statusline-command.sh)

if [[ -z "$output" ]]; then
    echo "FAIL: expected non-empty output, got empty (truncation likely crashed)"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: truncated output is non-empty"

if [[ "$output" == *$'\xef\xbf\xbd'* ]]; then
    echo "FAIL: output contains a UTF-8 replacement character, a multi-byte sequence was split: $output"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: no split multi-byte characters in truncated output"

if [[ "$output" != *"..."* ]]; then
    echo "FAIL: expected truncation ellipsis '...' in output, got: $output"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: truncation ellipsis present"

rm -f "$TMP_CONFIG"
