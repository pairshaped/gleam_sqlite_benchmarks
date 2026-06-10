# Rust SQLite

This bucket runs the request-shaped SQLite benchmark through two Rust paths:

- `rust_rusqlite/*`: direct `rusqlite` calls.
- `rust_sqlx/*`: `sqlx` with a `SqlitePool` and `max_connections(5)`.
- `rust_sqlx_pool1/*`: same SQLx pool path with `max_connections(1)`.
- `rust_sqlx_conn/*`: SQLx using one acquired pooled connection for the request
  loop.
- `rust_sqlx_direct/*`: SQLx using a direct `SqliteConnection`.
- `rust_sqlx_direct_tuned/*`: direct SQLx connection with worker/cache knobs
  adjusted.
- `rust_sqlx_manual_tx/*`: direct SQLx connection with manual `BEGIN`/`COMMIT`
  for the update request.

Run it in release mode:

```sh
cargo run --release --quiet -- 10000
```

The runner creates `rust_benchmark.sqlite3` in this directory and prints:

```text
case,items,micros,us_per_item,check
```

Cases:

- `rust_rusqlite/app_request/seed_dummy_data`
- `rust_rusqlite/app_request/admin_item_edit`
- `rust_rusqlite/app_request/admin_item_update`
- `rust_sqlx/app_request/seed_dummy_data`
- `rust_sqlx/app_request/admin_item_edit`
- `rust_sqlx/app_request/admin_item_update`
- `rust_sqlx_pool1/app_request/*`
- `rust_sqlx_conn/app_request/*`
- `rust_sqlx_direct/app_request/*`
- `rust_sqlx_direct_tuned/app_request/*`
- `rust_sqlx_manual_tx/app_request/admin_item_update`

SQLite is configured with WAL, `busy_timeout=5000`, and foreign keys enabled.
The baseline SQLx pool uses `max_connections(5)`. The `rusqlite` path uses the
same request-shaped sequence with normal driver calls, not a hot
prepared-statement loop.

The SQLx variants are included to isolate overhead. The current fastest SQLx
shape for the read-heavy request is `rust_sqlx_conn/*`, which avoids checking a
connection out of the pool for every query. The direct and tuned direct
connections were not meaningfully faster in the M4 MacBook Air run.
