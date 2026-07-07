#!/bin/bash
# Verifies configure.sh can be sourced (for unit testing) without launching main().
set -euo pipefail
cd "$(dirname "$0")/.."

# If the guard is missing, sourcing runs main(), which blocks on `read -r choice`
# waiting on stdin. Feeding 'q' lets an unguarded main() exit(0) quickly instead
# of hanging the test suite, and "SOURCED_OK" never gets printed in that case
# because exit terminates the process before control returns to this script.
result=$(printf 'q\n' | bash -c 'source configure.sh; echo "SOURCED_OK"' 2>/dev/null || true)

if [[ "$result" != "SOURCED_OK" ]]; then
    echo "FAIL: sourcing configure.sh should print SOURCED_OK without launching main(), got: $result"
    exit 1
fi
echo "PASS: configure.sh can be sourced without launching main()"
