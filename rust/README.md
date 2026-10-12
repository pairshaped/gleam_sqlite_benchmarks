# Rust SQLite

This runner drives SQLite from Rust through `rusqlite`, linked against the
flake's shared SQLite 3.51.0 rather than a bundled copy.

Run it in release mode inside the Nix shell. Debug-mode numbers aren't useful
for this comparison.

```sh
cargo run --release --quiet -- 5000
```

It creates `rust_benchmark.sqlite3` in this directory and prints:

- `rust_rusqlite/app_request/*`: the three benchmark cases.
- `rust_rusqlite_query_only/app_request/admin_item_edit`: the read request on a
  connection with `PRAGMA query_only = ON`, after checking that a write through
  that connection is rejected.

Every query goes through `prepare_cached`, and `BEGIN` and `COMMIT` run as
cached statements too. `Connection::transaction` would send them through
`execute_batch`, which parses them again on every request.

The connection setup raises rusqlite's statement cache from 16 to 256
(`STATEMENT_CACHE_CAPACITY`). The read request cycles through 22 distinct
statements, so the default evicts every statement just before its next use and
runs slower than not caching at all.

Earlier versions of this benchmark also measured Marmot-generated Rust and
SQLx. Marmot generates the same `prepare_cached` calls as this runner and
measured the same once both had an adequate cache. SQLx mostly measured pool
and connection settings that would need retuning on every machine.
