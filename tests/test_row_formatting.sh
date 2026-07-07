#!/bin/bash
# Verifies enabled-list rows are formatted with the correct label, number, and cursor/move markers.
set -euo pipefail
cd "$(dirname "$0")/.."
source configure.sh

row=$(format_enabled_row 0 "model" false false)
if [[ "$row" != *"1. Model"* ]]; then
    echo "FAIL: expected row to contain '1. Model', got: $row"
    exit 1
fi
if [[ "$row" == "▸"* || "$row" == "◆"* ]]; then
    echo "FAIL: a non-cursor, non-moving row should have no marker, got: $row"
    exit 1
fi
echo "PASS: format_enabled_row renders a plain row correctly"

row_cursor=$(format_enabled_row 2 "cost" true false)
if [[ "$row_cursor" != "▸"* ]]; then
    echo "FAIL: cursor row should start with ▸, got: $row_cursor"
    exit 1
fi
if [[ "$row_cursor" != *"3. API Cost"* ]]; then
    echo "FAIL: expected row to contain '3. API Cost', got: $row_cursor"
    exit 1
fi
echo "PASS: format_enabled_row marks the cursor row"

row_moving=$(format_enabled_row 1 "git" false true)
if [[ "$row_moving" != "◆"* ]]; then
    echo "FAIL: moving row should start with ◆, got: $row_moving"
    exit 1
fi
echo "PASS: format_enabled_row marks the moving row"
