#!/bin/bash
# Verifies the pure list-manipulation functions the cursor-driven wizard is built on.
set -euo pipefail
cd "$(dirname "$0")/.."
source configure.sh

# move_segment_up
enabled_segments=(a b c)
cursor=1
move_segment_up 1
if [[ "${enabled_segments[*]}" != "b a c" || $cursor -ne 0 ]]; then
    echo "FAIL: move_segment_up(1) expected 'b a c' cursor=0, got '${enabled_segments[*]}' cursor=$cursor"
    exit 1
fi
echo "PASS: move_segment_up swaps with the previous element and moves the cursor"

enabled_segments=(a b c)
cursor=0
move_segment_up 0
if [[ "${enabled_segments[*]}" != "a b c" || $cursor -ne 0 ]]; then
    echo "FAIL: move_segment_up(0) should no-op at the top, got '${enabled_segments[*]}' cursor=$cursor"
    exit 1
fi
echo "PASS: move_segment_up no-ops at index 0"

# move_segment_down
enabled_segments=(a b c)
cursor=1
move_segment_down 1
if [[ "${enabled_segments[*]}" != "a c b" || $cursor -ne 2 ]]; then
    echo "FAIL: move_segment_down(1) expected 'a c b' cursor=2, got '${enabled_segments[*]}' cursor=$cursor"
    exit 1
fi
echo "PASS: move_segment_down swaps with the next element and moves the cursor"

enabled_segments=(a b c)
cursor=2
move_segment_down 2
if [[ "${enabled_segments[*]}" != "a b c" || $cursor -ne 2 ]]; then
    echo "FAIL: move_segment_down(2) should no-op at the bottom, got '${enabled_segments[*]}' cursor=$cursor"
    exit 1
fi
echo "PASS: move_segment_down no-ops at the last index"

# remove_segment_at
enabled_segments=(a b c)
cursor=1
remove_segment_at 1
if [[ "${enabled_segments[*]}" != "a c" ]]; then
    echo "FAIL: remove_segment_at(1) expected 'a c', got '${enabled_segments[*]}'"
    exit 1
fi
echo "PASS: remove_segment_at removes the correct element"

enabled_segments=(a b c)
cursor=2
remove_segment_at 2
if [[ "${enabled_segments[*]}" != "a b" || $cursor -ne 1 ]]; then
    echo "FAIL: remove_segment_at(2) expected 'a b' cursor=1, got '${enabled_segments[*]}' cursor=$cursor"
    exit 1
fi
echo "PASS: remove_segment_at clamps the cursor after removing the last row"

# append_segment
enabled_segments=(a b)
append_segment "c"
if [[ "${enabled_segments[*]}" != "a b c" ]]; then
    echo "FAIL: append_segment expected 'a b c', got '${enabled_segments[*]}'"
    exit 1
fi
echo "PASS: append_segment appends to the end"

# is_multi_allowed
if ! is_multi_allowed "flex"; then
    echo "FAIL: is_multi_allowed('flex') should be true"
    exit 1
fi
if ! is_multi_allowed "newline"; then
    echo "FAIL: is_multi_allowed('newline') should be true"
    exit 1
fi
if is_multi_allowed "model"; then
    echo "FAIL: is_multi_allowed('model') should be false"
    exit 1
fi
echo "PASS: is_multi_allowed distinguishes flex/newline from regular segments"

# is_available_to_add
enabled_segments=(model flex)
if is_available_to_add "model"; then
    echo "FAIL: is_available_to_add('model') should be false once enabled"
    exit 1
fi
if ! is_available_to_add "flex"; then
    echo "FAIL: is_available_to_add('flex') should be true even when already enabled"
    exit 1
fi
if ! is_available_to_add "cost"; then
    echo "FAIL: is_available_to_add('cost') should be true when not enabled"
    exit 1
fi
echo "PASS: is_available_to_add respects the multi-allowed exception"

# get_available_segment_ids
enabled_segments=(timestamp model)
available=$(get_available_segment_ids)
if echo "$available" | grep -qx "timestamp"; then
    echo "FAIL: 'timestamp' is enabled, should not be listed as available"
    exit 1
fi
if ! echo "$available" | grep -qx "effort"; then
    echo "FAIL: 'effort' is not enabled, should be listed as available"
    exit 1
fi
if ! echo "$available" | grep -qx "flex"; then
    echo "FAIL: 'flex' should always be listed as available"
    exit 1
fi
echo "PASS: get_available_segment_ids filters correctly"

# reset_to_defaults
enabled_segments=(x y z)
cursor=2
reset_to_defaults
if [[ "${enabled_segments[*]}" != "${DEFAULT_SEGMENTS[*]}" || $cursor -ne 0 ]]; then
    echo "FAIL: reset_to_defaults expected '${DEFAULT_SEGMENTS[*]}' cursor=0, got '${enabled_segments[*]}' cursor=$cursor"
    exit 1
fi
echo "PASS: reset_to_defaults restores the default list and resets the cursor"

# insert_newline_at
enabled_segments=(a b c)
cursor=0
insert_newline_at 1
if [[ "${enabled_segments[*]}" != "a b newline c" || $cursor -ne 2 ]]; then
    echo "FAIL: insert_newline_at(1) expected 'a b newline c' cursor=2, got '${enabled_segments[*]}' cursor=$cursor"
    exit 1
fi
echo "PASS: insert_newline_at inserts a break after the given index and moves the cursor past it"

enabled_segments=(a b c)
insert_newline_at 2
if [[ "${enabled_segments[*]}" != "a b c newline" ]]; then
    echo "FAIL: insert_newline_at(2) at the last index expected 'a b c newline', got '${enabled_segments[*]}'"
    exit 1
fi
echo "PASS: insert_newline_at appends a trailing break when run on the last row"
