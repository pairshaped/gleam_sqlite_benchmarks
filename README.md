# SQLite Request-Shape Benchmarks

This repo compares one synthetic but app-shaped SQLite workload across three
language buckets:

- [gleam/](gleam/): Gleam on BEAM with `sqlight`, Gleam Marmot-generated
  `sqlight`, plus local Postgres through `pog`.
- [rust/](rust/): Rust with hand-written `rusqlite`, Marmot-generated
  `rusqlite`, and `sqlx` against SQLite.
- [ruby/](ruby/): Ruby with ActiveRecord and SQLite.

The benchmark intentionally avoids real application data. The schema, rows, and
names are synthetic. The request shapes are based on production-style app
requests: many small indexed reads, a recursive parent lookup, and a short save
transaction.

See [REPORT.md](REPORT.md) for findings and representative numbers from an M4
MacBook Air.

## Docs

- [Report](REPORT.md): TLDR, result tables, caveats, and reproduction commands.
- [Gleam runner](gleam/README.md): `sqlight` and `pog` commands and defaults.
- [Rust runner](rust/README.md): hand-written `rusqlite`, Marmot-generated
  `rusqlite`, and SQLx commands.
- [Ruby runner](ruby/README.md): ActiveRecord command and ORM notes.

## What Runs

Each runner prints CSV:

```text
case,items,micros,us_per_item,check
```

The main cases are:

- `app_request/seed_dummy_data`: creates a small dummy schema and seed rows.
- `app_request/admin_item_edit`: a read-heavy request with point selects,
  filtered counts, small joins, and a recursive parent lookup.
- `app_request/admin_item_update`: a short transaction with a few reads and one
  row update.

The Gleam SQLite runner prints raw FFI-backed `app_request/*` rows,
`gleam_marmot/app_request/*` rows generated from the shared SQL files, then
`probed_*` rows with scheduler, `file:sendfile/2`, and `file:read_file/1`
probes enabled.

## Run Gleam SQLite

```sh
cd gleam
gleam deps download
gleam run 10000
```

## Run Gleam Postgres

The Postgres runner uses `pog` and defaults to a local Unix socket. It prints two
request shapes:

- `app_request/*`: the production-derived request shape used by the SQLite
  cases. It is a real-world OLTP shape: many small indexed reads and a short
  save transaction.
- `batched_request/*`: the same logical work with fewer, larger SQL statements.
  This tests the effect of reducing protocol round-trips.

```text
PGHOST=/tmp
PGPORT=5432
PGUSER=$USER
PGDATABASE=postgres
PGPASSWORD=
```

Run it with:

```sh
cd gleam
gleam run -m postgres_tests 10000
```

Override the `PG*` variables if your local Postgres uses different settings.

The runner does not tune PostgreSQL server config. If you want a serious
Postgres run, use a dedicated local instance and set memory/cache settings for
that machine and dataset. For this small cached dataset, protocol round-trips
matter more than settings such as `shared_buffers`, `work_mem`, or
`effective_cache_size`.

## Run Rust

```sh
cd rust
cargo run --release --quiet -- 10000
```

Use release mode. Debug-mode Rust numbers are not useful for this comparison.
The Rust runner prints both `rust_rusqlite/*` and `rust_sqlx/*` rows. The
`rust_marmot/*` rows use generated `rusqlite` functions from colocated SQL
files. The `rusqlite` rows use the same request shape with normal driver calls,
not a hot prepared-statement loop.

## Run Ruby ActiveRecord

Ruby is managed with asdf in this repo:

```sh
cd ruby
asdf exec bundle install
asdf exec bundle exec ruby benchmark.rb 10000
```

ActiveRecord logging and verbose query logs are disabled. The benchmark uses
ActiveRecord models and relations for the measured request work. Raw SQL is used
only for schema and seed setup.

## Change the Shape

The useful knobs are in the seed and request functions:

- Gleam SQLite raw FFI path: `gleam/src/sqlite_tests_ffi.erl`
- Shared Marmot SQL files: `rust/src/app_request/sql`
- Gleam Marmot runner: `gleam/src/sqlite_tests.gleam`
- Gleam Postgres: `gleam/src/postgres_tests_ffi.erl`
- Rust SQLx: `rust/src/main.rs`
- Ruby ActiveRecord: `ruby/benchmark.rb`

To test a different workload, keep the CSV shape and checksums, then change:

- number of tables and indexes created by the seed step
- rows inserted per table
- number of queries in `admin_item_edit`
- number of queries and writes in `admin_item_update`
- whether the parent lookup is SQL-recursive or application-recursive
- connection pool sizes
- Postgres request shape: chatty request sequence vs fewer larger statements

The row count argument controls how many simulated requests run. It does not
change seed-table sizes unless you edit the seed functions.
