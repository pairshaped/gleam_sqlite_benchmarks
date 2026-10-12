# C SQLite

This runner calls the SQLite C API directly, with no wrapper. It's the baseline:
every other runner wraps this same API, so the gap between a runner and this one
is the cost that runner adds.

Build and run it inside the Nix shell:

```sh
make
./benchmark 5000
```

It links the flake's shared SQLite 3.51.0, creates `c_benchmark.sqlite3` in this
directory and prints `c_sqlite/app_request/*` rows.

Each connection prepares all of its statements once, `BEGIN` and `COMMIT`
included, and reuses them for every request. That's the same reuse the other
runners get from their statement caches, without the cost of looking a
statement up by its SQL text, so this runner is the floor rather than a typical
app.
