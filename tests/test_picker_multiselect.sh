#!/bin/bash
# End-to-end test: multi-select on the "Add a segment" picker screen.
# Starting from DEFAULT_SEGMENTS, the catalog order means the picker lists
# not-yet-enabled segments as: effort(0), duration(1), lines(2), session(3), ...
set -euo pipefail
cd "$(dirname "$0")/.."

KEY_UP=$'\x1b[A'
KEY_DOWN=$'\x1b[B'
KEY_ENTER=$'\r'
KEY_SPACE=' '

# Scenario 1: check "effort" (index 0), move down to "lines" (index 2),
# check it too, then Enter should add both — in the order they were checked.
TMP_CONFIG=$(mktemp -u)
rm -f "$TMP_CONFIG"
KEYS="a${KEY_SPACE}${KEY_DOWN}${KEY_DOWN}${KEY_SPACE}${KEY_ENTER}s"
printf '%s' "$KEYS" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" bash configure.sh > /dev/null

actual=$(jq -c '.segments' "$TMP_CONFIG")
expected='["timestamp","model","style","directory","git","context","cost","quota_5h","quota_7d","effort","lines"]'
if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: expected segments $expected, got $actual"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: checking two segments with Space and pressing Enter adds both, in check order"
rm -f "$TMP_CONFIG"

# Scenario 2: check "effort" then un-check it (Space twice) — with nothing
# checked, Enter must fall back to adding just the highlighted row, so the
# original single-add flow keeps working unchanged.
TMP_CONFIG=$(mktemp -u)
rm -f "$TMP_CONFIG"
KEYS="a${KEY_SPACE}${KEY_SPACE}${KEY_ENTER}s"
printf '%s' "$KEYS" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" bash configure.sh > /dev/null

actual=$(jq -c '.segments' "$TMP_CONFIG")
expected='["timestamp","model","style","directory","git","context","cost","quota_5h","quota_7d","effort"]'
if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: expected segments $expected, got $actual"
    rm -f "$TMP_CONFIG"
    exit 1
fi
echo "PASS: un-checking back to none falls back to adding the highlighted row on Enter"
rm -f "$TMP_CONFIG"
