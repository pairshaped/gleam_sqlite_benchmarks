#!/usr/bin/env bash
# Build the Zig runner against the shared SQLite from the Nix shell.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck disable=SC2046
zig build-exe benchmark.zig -O ReleaseSafe -lc -lsqlite3 $(pkg-config --cflags --libs sqlite3) -femit-bin=benchmark
