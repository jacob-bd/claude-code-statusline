#!/bin/bash
# Verifies the preview engine shells out to the real statusline-command.sh
# and reflects both the mock payload and the current in-progress segment list.
set -euo pipefail
cd "$(dirname "$0")/.."
source configure.sh

# segments_to_json produces valid, ordered JSON
enabled_segments=(model cost)
json=$(segments_to_json)
parsed=$(echo "$json" | jq -r '.segments | join(",")')
if [[ "$parsed" != "model,cost" ]]; then
    echo "FAIL: segments_to_json expected 'model,cost', got '$parsed'"
    exit 1
fi
echo "PASS: segments_to_json produces valid JSON with the right segment order"

# render_live_preview reflects the mock payload's model name
# (the real renderer converts spaces to non-breaking spaces; normalize back
# for a plain-space substring check since fidelity to that behavior is the point)
enabled_segments=(model)
preview_output=$(render_live_preview)
preview_output=${preview_output//$'\xc2\xa0'/ }
if [[ "$preview_output" != *"Sonnet 5"* ]]; then
    echo "FAIL: expected preview output to contain 'Sonnet 5', got: $preview_output"
    exit 1
fi
echo "PASS: render_live_preview reflects the real renderer's output"

# render_live_preview picks up config changes immediately, no stale caching
enabled_segments=(cost)
preview_output=$(render_live_preview)
if [[ "$preview_output" != *'$0.85'* ]]; then
    echo "FAIL: expected preview output to contain \$0.85 for the cost segment, got: $preview_output"
    exit 1
fi
echo "PASS: render_live_preview reflects config changes without stale caching"
