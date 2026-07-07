#!/bin/bash
# Verifies read_key classifies raw keypress byte sequences correctly.
# read -n1 works fine against a pipe (no real TTY needed), which is what
# makes this — and the Task 6 end-to-end test — possible without a pty.
set -euo pipefail
cd "$(dirname "$0")/.."
source configure.sh

check_key() {
    local input_bytes="$1" expected="$2"
    local actual
    actual=$(printf '%b' "$input_bytes" | read_key)
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: input '$input_bytes' expected '$expected', got '$actual'"
        exit 1
    fi
    echo "PASS: '$input_bytes' -> $expected"
}

check_key '\x1b[A' "UP"
check_key '\x1b[B' "DOWN"
check_key '\r' "ENTER"
check_key '\n' "ENTER"
check_key 'a' "CHAR:a"
check_key 'q' "CHAR:q"
check_key '\x1b' "ESC"
