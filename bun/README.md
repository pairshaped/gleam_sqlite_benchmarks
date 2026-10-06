# Bun SQLite

This bucket runs the request-shaped SQLite benchmark through Bun's built-in
`bun:sqlite` driver:

- `bun_sqlite/*`: `db.prepare(sql)` for every query, finalized after use. This
  matches the `rusqlite` and `sqlight` rows, which compile each statement per
  call rather than reusing a hot prepared statement.
- `bun_sqlite_cached/*`: `db.query(sql)`, Bun's idiomatic API. It caches the
  compiled statement by SQL text on the connection, so repeat queries skip
  `sqlite3_prepare`.

Run it:

```sh
bun run benchmark.ts 5000
```

The runner creates `bun_benchmark.sqlite3` in this directory and prints:

```text
case,items,micros,us_per_item,check
```

Cases:

- `bun_sqlite/app_request/seed_dummy_data`
- `bun_sqlite/app_request/admin_item_edit`
- `bun_sqlite/app_request/admin_item_update`
- `bun_sqlite_cached/app_request/seed_dummy_data`
- `bun_sqlite_cached/app_request/admin_item_edit`
- `bun_sqlite_cached/app_request/admin_item_update`

SQLite is configured with WAL, `synchronous=NORMAL`, `busy_timeout=5000`, and
foreign keys enabled. The update request runs inside `db.transaction`, which
issues `BEGIN`/`COMMIT` around the reads and the single row update.

The `check` column uses the same arithmetic as the Rust runner, so matching
`check` values between `bun_sqlite/*` and `rust_rusqlite/*` confirm the two
runners did the same work.
