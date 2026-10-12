#!/usr/bin/env bash
# Build the Go runner. ncruces/go-sqlite3 needs no cgo and brings its own SQLite.
set -euo pipefail
cd "$(dirname "$0")"
CGO_ENABLED=0 go build -o benchmark .
