#!/bin/bash
# End-to-end test: pipe a scripted key sequence into the real interactive
# main() loop and assert on the resulting saved config. This is possible
# because `read -n1` works against a plain pipe — no pty/expect needed.
#
# Starting from DEFAULT_SEGMENTS = (timestamp model style directory git
# context cost quota_5h quota_7d) [indices 0-8], the sequence:
#   DOWN DOWN   -> cursor lands on index 2 ("style")
#   d           -> removes "style"; list is now (timestamp model directory
#                  git context cost quota_5h quota_7d), cursor stays at 2
#                  ("directory")
#   ENTER       -> enters move mode on "directory" (index 2)
#   UP          -> swaps "directory" above "model": (timestamp directory
#                  model git context cost quota_5h quota_7d), cursor -> 1
#   ENTER       -> exits move mode
#   a           -> opens the add picker; catalog order means the first
#                  available (not-yet-enabled) segment is "effort"
#   ENTER       -> adds "effort" to the end of the list
#   s           -> saves and exits
set -euo pipefail
cd "$(dirname "$0")/.."

TMP_CONFIG=$(mktemp -u)
rm -f "$TMP_CONFIG"

KEY_UP=$'\x1b[A'
KEY_DOWN=$'\x1b[B'
KEY_ENTER=$'\r'
KEYS="${KEY_DOWN}${KEY_DOWN}d${KEY_ENTER}${KEY_UP}${KEY_ENTER}a${KEY_ENTER}s"

printf '%s' "$KEYS" | STATUSLINE_CONFIG_FILE="$TMP_CONFIG" bash configure.sh > /dev/null

if [[ ! -f "$TMP_CONFIG" ]]; then
    echo "FAIL: expected $TMP_CONFIG to be written by 's' (save & exit)"
    exit 1
fi

actual=$(jq -c '.segments' "$TMP_CONFIG")
expected='["timestamp","directory","model","git","context","cost","quota_5h","quota_7d","effort"]'

if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: expected segments $expected, got $actual"
    rm -f "$TMP_CONFIG"
    exit 1
fi

echo "PASS: navigate/remove/move/add/save key sequence produces the expected config"
rm -f "$TMP_CONFIG"
