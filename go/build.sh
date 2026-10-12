#!/usr/bin/env bash
# Build the Go runner against the shared SQLite from the Nix shell. The
# libsqlite3 tag makes go-sqlite3 link it instead of its bundled copy.
set -euo pipefail
cd "$(dirname "$0")"
CGO_ENABLED=1 \
CGO_CFLAGS="$(pkg-config --cflags sqlite3)" \
CGO_LDFLAGS="$(pkg-config --libs sqlite3)" \
  go build -tags libsqlite3 -o benchmark .
