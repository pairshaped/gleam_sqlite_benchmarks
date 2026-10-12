# Go SQLite

This runner uses the most common Go setup: `database/sql` with the
`mattn/go-sqlite3` driver. It's built with the driver's `libsqlite3` tag, so it
links the flake's shared SQLite 3.51.0 instead of the driver's bundled copy.

Build and run it inside the Nix shell:

```sh
./build.sh
./benchmark 5000
```

The runner creates `go_benchmark.sqlite3` in this directory and prints
`go_sqlite/app_request/*` rows.

It holds one dedicated `*sql.Conn` and caches one prepared `*sql.Stmt` per SQL
string. Transactions run `BEGIN` and `COMMIT` as cached statements on that
connection rather than through `sql.Tx`, so connection-pool checkouts and
per-transaction re-preparing aren't part of what's measured. The remaining gap
to C is `database/sql` and cgo overhead.
