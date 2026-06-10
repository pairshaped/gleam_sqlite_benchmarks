# SQLite Request-Shape Benchmark Report

## TLDR

These benchmarks were run on an M4 MacBook Air.

The benchmark compares a synthetic app-shaped SQLite workload across Gleam,
Rust, and Ruby. The data is dummy data. The query shape is production-derived:
a read-heavy request with about 26 small indexed queries, and a write request
with a short transaction.

Representative 10,000-request results:

| Runner | `admin_item_edit` | `admin_item_update` |
| --- | ---: | ---: |
| Rust `rusqlite` SQLite | 0.67s, 14,884 req/sec | 0.37s, 26,675 req/sec |
| Rust SQLx SQLite | 4.02s, 2,486 req/sec | 0.90s, 11,122 req/sec |
| Gleam SQLite (`sqlight`) | 3.43s, 2,915 req/sec | 2.47s, 4,054 req/sec |
| Ruby ActiveRecord SQLite | 12.35s, 809 req/sec | 3.74s, 2,670 req/sec |

The direct Rust driver row is much faster than the other measured paths for this
many-small-query SQLite shape.

The SQLx-vs-rusqlite gap is large in this shape: SQLx was about 6.0x slower on
the read-heavy request and about 2.4x slower on the update request. This is not
from a fake hot prepared-statement loop; both Rust rows use the same
request-shaped query sequence.

The Ruby numbers should be read differently from the others. ActiveRecord is an
ORM, so this is not a driver/runtime peer comparison. It is included because ORM
overhead is a realistic reference point for this kind of request shape.

The repo includes a Gleam Postgres runner through `pog`. It prints both the
production-derived request sequence and a compact `batched_request/*` sequence
using fewer, larger statements. Both are real OLTP shapes. The batched rows test
the cost of protocol round-trips, not whether the original request shape is
invalid for Postgres. The Postgres instance is still whatever local server you
point it at. This repo does not claim tuned PostgreSQL numbers.

The Gleam runners also emit `probed_*` rows with scheduler and file IO probes
enabled. Those rows are included to make runtime interference visible. They are
not used for the main cross-language throughput table.

## Repository Layout

- `gleam/`: Gleam benchmark project, including SQLite and local Postgres through
  `pog`.
- `rust/`: Rust `rusqlite` and SQLx benchmark.
- `ruby/`: Ruby ActiveRecord benchmark.

The old direct `pgo` comparison and raw database-ceiling cases have been removed
from the runnable benchmark surface. The remaining cases are the app-shaped seed,
read request, and update request.

## Hardware

Representative numbers in this report came from:

- Machine: MacBook Air with Apple M4.
- OS: macOS.
- Database placement: local process or local SQLite file.

The exact M4 Air configuration was not encoded into the benchmark output. Treat
these as local development-machine numbers, not portable capacity claims.

## Workload

All runners use the same dummy schema shape. The names and rows are synthetic,
but the request shapes are based on production-style app requests:

- users
- clubs with a parent relationship
- events/items
- sponsors
- tags
- taxes
- fees
- products
- addons
- custom fields
- discounts
- alert/config tables

The seed step creates small fixed-size tables. The row count argument controls
the number of simulated requests, not the seed data size.

### `app_request/admin_item_edit`

This case represents a read-heavy admin edit page. It performs about 26 small
queries:

- point selects by primary key or unique-ish field
- filtered counts
- small lookup rows
- addon and discount lookups
- one parent-chain lookup
- a final counter read

Gleam SQLite and Rust use SQL for the parent-chain lookup. The Ruby ActiveRecord
runner walks the parent chain through model lookups because the point of that
bucket is ORM-shaped behavior.

### `app_request/admin_item_update`

This case represents a small save request:

- starts a transaction
- performs a few request-sized reads
- updates one row
- commits

The update is deliberately short and indexed.

### `batched_request/admin_item_edit`

This is the same checksum as `app_request/admin_item_edit`, but expressed as one
larger query instead of about 26 small queries.

### `batched_request/admin_item_update`

This is the same checksum as `app_request/admin_item_update`, but the read and
write work is combined into one statement inside the transaction.

## Runtime Details

SQLite connections are configured with:

```sql
PRAGMA journal_mode=WAL;
PRAGMA busy_timeout=5000;
PRAGMA foreign_keys=ON;
```

Rust has two primary SQLite paths:

- `rust_rusqlite/*`: direct `rusqlite` calls in the same request shape.
- `rust_sqlx/*`: `sqlx` with a `SqlitePool` and `max_connections(5)`.

The Rust runner also includes SQLx variants to isolate pool and connection
overhead. Those rows are discussed below.

Ruby uses ActiveRecord 8.1.x and sqlite3 2.x on Ruby 4.0.5 through asdf.
ActiveRecord logging and verbose query logs are disabled.

The `pog` runner defaults to:

```text
PGHOST=/tmp
PGPORT=5432
PGUSER=$USER
PGDATABASE=postgres
PGPASSWORD=
```

## Result Table

These are representative 10,000-request rows from the M4 MacBook Air run.

| Runner | Case | Items | Time | us/item | Check |
| --- | --- | ---: | ---: | ---: | ---: |
| Gleam SQLite | `app_request/admin_item_edit` | 10,000 | 3,430,500us | 343 | 27,395,000 |
| Gleam SQLite | `app_request/admin_item_update` | 10,000 | 2,466,888us | 246 | 5,550,000 |
| Rust `rusqlite` SQLite | `rust_rusqlite/app_request/admin_item_edit` | 10,000 | 671,851us | 67 | 27,395,000 |
| Rust `rusqlite` SQLite | `rust_rusqlite/app_request/admin_item_update` | 10,000 | 374,879us | 37 | 5,550,000 |
| Rust SQLx SQLite | `rust_sqlx/app_request/admin_item_edit` | 10,000 | 4,022,771us | 402 | 27,395,000 |
| Rust SQLx SQLite | `rust_sqlx/app_request/admin_item_update` | 10,000 | 899,148us | 89 | 5,550,000 |
| Ruby ActiveRecord SQLite | `active_record/app_request/admin_item_edit` | 10,000 | 12,353,988us | 1,235 | 27,395,000 |
| Ruby ActiveRecord SQLite | `active_record/app_request/admin_item_update` | 10,000 | 3,744,670us | 374 | 5,550,000 |

The matching checksums are intentional. They make it easier to notice when two
runners stop doing equivalent work.

For reference, the local `pog` run produced two shapes:

| Runner | Case | Items | Time | us/item | Check |
| --- | --- | ---: | ---: | ---: | ---: |
| Gleam Postgres (`pog`) | `app_request/admin_item_edit` | 10,000 | 22,012,295us | 2,201 | 27,395,000 |
| Gleam Postgres (`pog`) | `batched_request/admin_item_edit` | 10,000 | 5,517,460us | 551 | 27,395,000 |
| Gleam Postgres (`pog`) | `app_request/admin_item_update` | 10,000 | 4,204,633us | 420 | 5,550,000 |
| Gleam Postgres (`pog`) | `batched_request/admin_item_update` | 10,000 | 2,272,807us | 227 | 5,550,000 |

The batched rows are much faster than the chatty rows in this run: about 4.0x
faster for the read-heavy request and about 1.9x faster for the update request.
That matches the expected direction. It also shows why the batched rows are
useful when reasoning about round-trip overhead.

## Probe Impact

The first version of this report used Gleam SQLite timings measured while the
scheduler, sendfile, and read-file probes were running. That was useful for
runtime-interference testing, but it made the main throughput comparison unfair.

The runner now prints plain rows first and `probed_*` rows second. On the M4
MacBook Air run, probe overhead was significant:

| Runner | Case | Plain | Probed | Slowdown |
| --- | --- | ---: | ---: | ---: |
| Gleam SQLite | `admin_item_edit` | 3,430,500us | 10,574,763us | 3.1x |
| Gleam SQLite | `admin_item_update` | 2,466,888us | 4,796,053us | 1.9x |
| Gleam Postgres (`pog`) | `app_request/admin_item_edit` | 22,012,295us | 27,223,693us | 1.2x |
| Gleam Postgres (`pog`) | `batched_request/admin_item_edit` | 5,517,460us | 8,394,702us | 1.5x |
| Gleam Postgres (`pog`) | `app_request/admin_item_update` | 4,204,633us | 8,396,235us | 2.0x |
| Gleam Postgres (`pog`) | `batched_request/admin_item_update` | 2,272,807us | 4,349,497us | 1.9x |

## Rust SQLx Variants

After the main benchmark pass, the Rust runner was extended to isolate SQLx
overhead. Gleam and Ruby were not rerun for this pass.

The most useful change was avoiding pool checkout on every query. Holding one
SQLx connection for the request loop made the read-heavy request much faster,
but it still did not catch `rusqlite`.

| Runner | Case | Items | Time | us/item | Check |
| --- | --- | ---: | ---: | ---: | ---: |
| Rust `rusqlite` SQLite | `rust_rusqlite/app_request/admin_item_edit` | 10,000 | 708,197us | 70 | 27,395,000 |
| Rust `rusqlite` SQLite | `rust_rusqlite/app_request/admin_item_update` | 10,000 | 324,748us | 32 | 5,550,000 |
| Rust SQLx pool 5 | `rust_sqlx/app_request/admin_item_edit` | 10,000 | 4,171,184us | 417 | 27,395,000 |
| Rust SQLx pool 5 | `rust_sqlx/app_request/admin_item_update` | 10,000 | 813,700us | 81 | 5,550,000 |
| Rust SQLx pool 1 | `rust_sqlx_pool1/app_request/admin_item_edit` | 10,000 | 6,106,208us | 610 | 27,395,000 |
| Rust SQLx pool 1 | `rust_sqlx_pool1/app_request/admin_item_update` | 10,000 | 780,602us | 78 | 5,550,000 |
| Rust SQLx acquired connection | `rust_sqlx_conn/app_request/admin_item_edit` | 10,000 | 1,637,995us | 163 | 27,395,000 |
| Rust SQLx acquired connection | `rust_sqlx_conn/app_request/admin_item_update` | 10,000 | 606,945us | 60 | 5,550,000 |
| Rust SQLx direct connection | `rust_sqlx_direct/app_request/admin_item_edit` | 10,000 | 1,692,974us | 169 | 27,395,000 |
| Rust SQLx direct connection | `rust_sqlx_direct/app_request/admin_item_update` | 10,000 | 641,832us | 64 | 5,550,000 |
| Rust SQLx tuned direct connection | `rust_sqlx_direct_tuned/app_request/admin_item_edit` | 10,000 | 1,712,228us | 171 | 27,395,000 |
| Rust SQLx tuned direct connection | `rust_sqlx_direct_tuned/app_request/admin_item_update` | 10,000 | 650,273us | 65 | 5,550,000 |
| Rust SQLx manual transaction | `rust_sqlx_manual_tx/app_request/admin_item_update` | 10,000 | 689,775us | 68 | 5,550,000 |

The result is fairly clear:

- Pool size 1 did not help the read-heavy request. It was slower.
- Holding one SQLx connection helped a lot: about 2.5x faster than the baseline
  SQLx pool path on the read-heavy request.
- Direct SQLx connection was roughly the same as holding one pooled connection.
- SQLx worker/cache tuning did not help.
- Manual `BEGIN`/`COMMIT` did not help the update request.

The best SQLx read-heavy row remained about 2.3x slower than `rusqlite`. The
best SQLx update row remained about 1.9x slower than `rusqlite`.

## How To Reproduce

Gleam SQLite:

```sh
cd gleam
gleam deps download
gleam run 10000
```

Gleam Postgres:

```sh
cd gleam
gleam run -m postgres_tests 10000
```

Rust SQLite:

```sh
cd rust
cargo run --release --quiet -- 10000
```

Ruby ActiveRecord SQLite:

```sh
cd ruby
asdf exec bundle install
asdf exec bundle exec ruby benchmark.rb 10000
```

## How To Tweak The Benchmark

Change seed sizes to test broader pages:

- number of events/items
- addons per event/item
- custom fields per event/item
- discounts and discount items
- parent-chain depth

Change request functions to test different query shapes:

- replace counts with row hydration
- return wider rows
- increase number of point selects
- add joins
- move parent-chain traversal from SQL into application code
- add more writes inside the transaction
- increase SQLite or SQLx pool sizes

Keep the checksum updated when changing shape. A matching checksum is the easiest
way to verify that the runners still do comparable work.

## Postgres Tuning

This repo does not tune PostgreSQL. That is deliberate. A benchmark script can
set connection parameters, but server tuning belongs to the Postgres instance:
`shared_buffers`, `effective_cache_size`, `work_mem`, `max_connections`,
checkpoint settings, WAL settings, and OS cache behavior all depend on the
machine and dataset.

For this specific small cached dataset, the biggest Postgres variable is
round-trip count. The compact `batched_request/*` rows remove most of the
protocol round-trips and are far more informative than changing memory settings
while still running 26 small queries.

To make Postgres tuning matter in this repo, increase seed sizes in
`gleam/src/postgres_tests_ffi.erl`, add wider result sets, add joins or sorts
that can spill, and run against a dedicated local Postgres instance with known
server settings.

## Caveats

This is a request-shape benchmark, not a database benchmark suite.

The Postgres path is intentionally limited. It is local Postgres through `pog`.
The `batched_request/*` rows test fewer protocol round-trips, but the server is
not tuned by this repo.

The Rust `rusqlite` path is not the old prepared-statement microbenchmark. It
uses the same request-shaped query sequence as the SQLx path.

The Ruby path is intentionally ORM-shaped. It is useful as a realistic
ActiveRecord comparison, but it should not be read as a SQLite adapter ceiling.

The Gleam runners emit plain rows and separate `probed_*` rows. The Rust and
Ruby runners do not currently emit equivalent probe rows.

## Verification

The cleanup pass used these checks:

```sh
cd gleam && gleam format src test
cd gleam && gleam test
cd gleam && gleam run 100
cd gleam && gleam run -m postgres_tests 100
cd gleam && gleam run 10000
cd gleam && gleam run -m postgres_tests 10000
cd rust && cargo fmt
cd rust && cargo check
cd rust && cargo run --release --quiet -- 100
cd rust && cargo run --release --quiet -- 10000
cd ruby && asdf exec bundle exec ruby -c benchmark.rb
cd ruby && asdf exec bundle exec ruby benchmark.rb 100
cd ruby && asdf exec bundle exec ruby benchmark.rb 10000
```
