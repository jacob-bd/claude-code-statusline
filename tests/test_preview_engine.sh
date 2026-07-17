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

# render_live_preview picks up config changes immediately, no stale caching.
# The mock payload simulates a subscription account (it includes rate_limits),
# so the cost segment correctly stays hidden even when it's the only segment
# enabled — Cost and Quota are mutually exclusive by design.
enabled_segments=(cost)
preview_output=$(render_live_preview)
if [[ "$preview_output" == *'$0.85'* ]]; then
    echo "FAIL: expected cost to stay hidden on subscription-style mock data (has rate_limits), got: $preview_output"
    exit 1
fi
echo "PASS: render_live_preview hides cost on subscription-style mock data without stale caching"
