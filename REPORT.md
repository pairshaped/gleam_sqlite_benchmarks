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
| Rust `rusqlite` SQLite | 0.69s, 14,529 req/sec | 0.33s, 29,920 req/sec |
| Rust Marmot-generated `rusqlite` SQLite | 0.95s, 10,559 req/sec | 0.27s, 37,671 req/sec |
| Rust SQLx SQLite | 4.03s, 2,481 req/sec | 0.78s, 12,886 req/sec |
| Gleam SQLite (`sqlight`) | 3.49s, 2,863 req/sec | 2.02s, 4,940 req/sec |
| Gleam Marmot-generated `sqlight` SQLite | 1.81s, 5,536 req/sec | 2.17s, 4,602 req/sec |
| Ruby ActiveRecord SQLite | 12.34s, 810 req/sec | 3.74s, 2,674 req/sec |

The direct Rust driver row is much faster than the other measured paths for this
many-small-query SQLite shape.

The SQLx-vs-rusqlite gap is large in this shape: SQLx was about 5.9x slower on
the read-heavy request and about 2.3x slower on the update request. This is not
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

- `gleam/`: Gleam benchmark project, including raw SQLite, Gleam
  Marmot-generated SQLite, and local Postgres through `pog`.
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

Gleam has two SQLite paths:

- `app_request/*`: request loop implemented through the existing Erlang FFI
  calls.
- `gleam_marmot/app_request/*`: request loop using generated Gleam Marmot
  functions from the shared SQL files in `rust/src/app_request/sql`.
  One-column SQL files use `-- returns: ValueRow` so the generated Gleam API
  shares a single scalar row type.

Rust has three primary SQLite paths:

- `rust_rusqlite/*`: direct `rusqlite` calls in the same request shape.
- `rust_marmot/*`: generated `rusqlite` calls from colocated `.sql` files.
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
| Gleam SQLite | `app_request/admin_item_edit` | 10,000 | 3,492,963us | 349 | 27,395,000 |
| Gleam SQLite | `app_request/admin_item_update` | 10,000 | 2,024,260us | 202 | 5,550,000 |
| Gleam Marmot-generated SQLite | `gleam_marmot/app_request/admin_item_edit` | 10,000 | 1,806,172us | 180 | 27,395,000 |
| Gleam Marmot-generated SQLite | `gleam_marmot/app_request/admin_item_update` | 10,000 | 2,172,858us | 217 | 5,550,000 |
| Rust `rusqlite` SQLite | `rust_rusqlite/app_request/admin_item_edit` | 10,000 | 688,275us | 68 | 27,395,000 |
| Rust `rusqlite` SQLite | `rust_rusqlite/app_request/admin_item_update` | 10,000 | 334,227us | 33 | 5,550,000 |
| Rust Marmot-generated `rusqlite` SQLite | `rust_marmot/app_request/admin_item_edit` | 10,000 | 947,007us | 94 | 27,395,000 |
| Rust Marmot-generated `rusqlite` SQLite | `rust_marmot/app_request/admin_item_update` | 10,000 | 265,458us | 26 | 5,550,000 |
| Rust SQLx SQLite | `rust_sqlx/app_request/admin_item_edit` | 10,000 | 4,030,585us | 403 | 27,395,000 |
| Rust SQLx SQLite | `rust_sqlx/app_request/admin_item_update` | 10,000 | 776,064us | 77 | 5,550,000 |
| Ruby ActiveRecord SQLite | `active_record/app_request/admin_item_edit` | 10,000 | 12,342,330us | 1,234 | 27,395,000 |
| Ruby ActiveRecord SQLite | `active_record/app_request/admin_item_update` | 10,000 | 3,739,989us | 373 | 5,550,000 |

The matching checksums are intentional. They make it easier to notice when two
runners stop doing equivalent work.

For reference, the local `pog` run produced two shapes:

| Runner | Case | Items | Time | us/item | Check |
| --- | --- | ---: | ---: | ---: | ---: |
| Gleam Postgres (`pog`) | `app_request/admin_item_edit` | 10,000 | 12,894,179us | 1,289 | 27,395,000 |
| Gleam Postgres (`pog`) | `batched_request/admin_item_edit` | 10,000 | 4,504,108us | 450 | 27,395,000 |
| Gleam Postgres (`pog`) | `app_request/admin_item_update` | 10,000 | 3,941,688us | 394 | 5,550,000 |
| Gleam Postgres (`pog`) | `batched_request/admin_item_update` | 10,000 | 2,275,080us | 227 | 5,550,000 |

The batched rows are much faster than the chatty rows in this run: about 2.9x
faster for the read-heavy request and about 1.7x faster for the update request.
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
| Gleam SQLite | `admin_item_edit` | 3,492,963us | 10,112,099us | 2.9x |
| Gleam SQLite | `admin_item_update` | 2,024,260us | 4,685,758us | 2.3x |
| Gleam Postgres (`pog`) | `app_request/admin_item_edit` | 12,894,179us | 25,670,143us | 2.0x |
| Gleam Postgres (`pog`) | `batched_request/admin_item_edit` | 4,504,108us | 6,970,838us | 1.5x |
| Gleam Postgres (`pog`) | `app_request/admin_item_update` | 3,941,688us | 8,599,266us | 2.2x |
| Gleam Postgres (`pog`) | `batched_request/admin_item_update` | 2,275,080us | 4,725,647us | 2.1x |

## Rust SQLx Variants

After the main benchmark pass, the Rust runner was extended to isolate SQLx
overhead. Gleam and Ruby were not rerun for this pass.

The most useful change was avoiding pool checkout on every query. Holding one
SQLx connection for the request loop made the read-heavy request much faster,
but it still did not catch `rusqlite`.

| Runner | Case | Items | Time | us/item | Check |
| --- | --- | ---: | ---: | ---: | ---: |
| Rust `rusqlite` SQLite | `rust_rusqlite/app_request/admin_item_edit` | 10,000 | 688,275us | 68 | 27,395,000 |
| Rust `rusqlite` SQLite | `rust_rusqlite/app_request/admin_item_update` | 10,000 | 334,227us | 33 | 5,550,000 |
| Rust SQLx pool 5 | `rust_sqlx/app_request/admin_item_edit` | 10,000 | 4,030,585us | 403 | 27,395,000 |
| Rust SQLx pool 5 | `rust_sqlx/app_request/admin_item_update` | 10,000 | 776,064us | 77 | 5,550,000 |
| Rust SQLx pool 1 | `rust_sqlx_pool1/app_request/admin_item_edit` | 10,000 | 5,877,427us | 587 | 27,395,000 |
| Rust SQLx pool 1 | `rust_sqlx_pool1/app_request/admin_item_update` | 10,000 | 760,092us | 76 | 5,550,000 |
| Rust SQLx acquired connection | `rust_sqlx_conn/app_request/admin_item_edit` | 10,000 | 1,449,535us | 144 | 27,395,000 |
| Rust SQLx acquired connection | `rust_sqlx_conn/app_request/admin_item_update` | 10,000 | 594,134us | 59 | 5,550,000 |
| Rust SQLx direct connection | `rust_sqlx_direct/app_request/admin_item_edit` | 10,000 | 1,508,306us | 150 | 27,395,000 |
| Rust SQLx direct connection | `rust_sqlx_direct/app_request/admin_item_update` | 10,000 | 598,480us | 59 | 5,550,000 |
| Rust SQLx tuned direct connection | `rust_sqlx_direct_tuned/app_request/admin_item_edit` | 10,000 | 1,464,903us | 146 | 27,395,000 |
| Rust SQLx tuned direct connection | `rust_sqlx_direct_tuned/app_request/admin_item_update` | 10,000 | 617,794us | 61 | 5,550,000 |
| Rust SQLx manual transaction | `rust_sqlx_manual_tx/app_request/admin_item_update` | 10,000 | 648,096us | 64 | 5,550,000 |

The result is fairly clear:

- Pool size 1 did not help the read-heavy request. It was slower.
- Holding one SQLx connection helped a lot: about 2.5x faster than the baseline
  SQLx pool path on the read-heavy request.
- Direct SQLx connection was roughly the same as holding one pooled connection.
- SQLx worker/cache tuning did not help.
- Manual `BEGIN`/`COMMIT` did not help the update request.

The best SQLx read-heavy row remained about 2.1x slower than `rusqlite`. The
best SQLx update row remained about 1.8x slower than `rusqlite`.

## How To Reproduce

Gleam SQLite:

```sh
cd gleam
gleam deps download
gleam run 10000
```

Regenerate the Gleam Marmot module after changing SQL files:

```sh
cd gleam
gleam run -m marmot
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
cd gleam && gleam run -m marmot
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
