# Bun SQLite

This bucket runs the request-shaped SQLite benchmark through Bun's built-in
`bun:sqlite` driver, using `db.query`, Bun's idiomatic API. `db.query` caches
the compiled statement by SQL text on the connection.

Bun's cache holds 20 statements by default and evicts the oldest when it fills.
The read request cycles through 22 distinct statements, so the default evicts
every statement just before its next use and runs slower than not caching at
all. The runner raises `Database.MAX_QUERY_CACHE_SIZE` to 256.

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

In concurrent mode (`bun run benchmark.ts concurrent <duration> <warmup>
<workers>`), each worker is a Bun worker thread with its own connection, and
writes use `db.transaction(...).immediate` for `BEGIN IMMEDIATE`. Each worker
thread only runs its own requests, so the numbers don't show one request's lock
wait blocking another; see the caveat below.

SQLite is configured with WAL, `synchronous=NORMAL`, `busy_timeout=5000`, and
foreign keys enabled. The update request runs inside `db.transaction`, which
issues `BEGIN`/`COMMIT` around the reads and the single row update.

The `check` column uses the same arithmetic as the Rust runner, so matching
`check` values between `bun_sqlite/*` and `rust_rusqlite/*` confirm the two
runners did the same work.

`bun:sqlite` is synchronous: each query, including any time SQLite's busy
timeout spends sleeping while it waits for a lock, blocks the JavaScript thread
that called it. In a server, a write waiting on the lock would freeze every
other request on that thread. A Bun app on SQLite needs one dedicated writer
(a worker thread or process that owns the only writing connection and takes
writes through a queue) and its reads spread across processes or workers. The
top-level README covers this in its Bun caveat.

The runner has no runtime dependencies. `bun install` only fetches type
declarations for `bun run typecheck`.
