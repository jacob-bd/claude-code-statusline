#!/bin/bash
# Runs every tests/test_*.sh script and reports a summary.
set -uo pipefail
cd "$(dirname "$0")"

fail_count=0
total=0

for test_file in test_*.sh; do
    total=$((total + 1))
    echo "── $test_file ──"
    if bash "$test_file"; then
        :
    else
        fail_count=$((fail_count + 1))
    fi
    echo
done

echo "======================================"
echo "$((total - fail_count))/$total passed"
if [[ $fail_count -gt 0 ]]; then
    exit 1
fi
