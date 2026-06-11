# SQLite Request-Shape Benchmark Report

## TLDR

These benchmarks are intended to be run on a quiet dedicated Linux host. The
reference host is a bare-metal server:

- OS: Debian GNU/Linux 13 (trixie)
- CPU: AMD Ryzen 7 9700X, 8 cores / 16 threads
- Memory: 62 GiB
- Architecture: x86_64

The benchmark compares a synthetic app-shaped SQLite workload across Gleam,
Rust, and Ruby. The data is dummy data. The query shape is production-derived:
a read-heavy request with about 26 small indexed queries, and a write request
with a short transaction.

Representative 10,000-request results:

| Runner | `admin_item_edit` | `admin_item_update` |
| --- | ---: | ---: |
| Rust `rusqlite` SQLite | 0.59s, 16,907 req/sec | 0.28s, 35,098 req/sec |
| Rust Marmot-generated `rusqlite` SQLite | 0.78s, 12,886 req/sec | 0.22s, 45,815 req/sec |
| Rust SQLx SQLite | 1.83s, 5,476 req/sec | 0.57s, 17,405 req/sec |
| Gleam SQLite (`sqlight`) | 1.14s, 8,809 req/sec | 0.45s, 22,073 req/sec |
| Gleam Marmot-generated `sqlight` SQLite | 1.24s, 8,065 req/sec | 0.47s, 21,408 req/sec |
| Ruby ActiveRecord SQLite | 12.73s, 785 req/sec | 4.23s, 2,364 req/sec |

The direct Rust driver row is much faster than the other measured paths for this
many-small-query SQLite shape.

The SQLx-vs-rusqlite gap is large in this shape: SQLx is about 3.1x slower on
the read-heavy request and about 2.0x slower on the update request. This is not
from a fake hot prepared-statement loop; both Rust rows use the same
request-shaped query sequence.

The Ruby numbers should be read differently from the others. ActiveRecord is an
ORM, so this is not a driver/runtime peer comparison. It is included because ORM
overhead is a realistic reference point for this kind of request shape.

The repo includes a Gleam Postgres runner through `pog`. It prints both the
production-derived request sequence and a compact `batched_request/*` sequence
using fewer, larger statements. Both are real OLTP shapes. The batched rows test
the cost of protocol round-trips, not whether the `app_request/*` shape is
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

The runnable benchmark surface focuses on the app-shaped seed, read request,
and update request.

## Hardware

The reference run uses:

- Machine: bare-metal server.
- OS: Debian GNU/Linux 13 (trixie).
- CPU: AMD Ryzen 7 9700X, 8 cores / 16 threads.
- Memory: 62 GiB.
- Architecture: x86_64.
- Database placement: local process or local SQLite file inside the benchmark
  container.

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
PRAGMA synchronous=NORMAL;
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

These are representative 10,000-request rows.

| Runner | Case | Items | Time | us/item | Check |
| --- | --- | ---: | ---: | ---: | ---: |
| Gleam SQLite | `app_request/admin_item_edit` | 10,000 | 1,135,184us | 113 | 27,395,000 |
| Gleam SQLite | `app_request/admin_item_update` | 10,000 | 453,052us | 45 | 5,550,000 |
| Gleam Marmot-generated SQLite | `gleam_marmot/app_request/admin_item_edit` | 10,000 | 1,239,871us | 123 | 27,395,000 |
| Gleam Marmot-generated SQLite | `gleam_marmot/app_request/admin_item_update` | 10,000 | 467,107us | 46 | 5,550,000 |
| Rust `rusqlite` SQLite | `rust_rusqlite/app_request/admin_item_edit` | 10,000 | 591,459us | 59 | 27,395,000 |
| Rust `rusqlite` SQLite | `rust_rusqlite/app_request/admin_item_update` | 10,000 | 284,919us | 28 | 5,550,000 |
| Rust Marmot-generated `rusqlite` SQLite | `rust_marmot/app_request/admin_item_edit` | 10,000 | 776,036us | 77 | 27,395,000 |
| Rust Marmot-generated `rusqlite` SQLite | `rust_marmot/app_request/admin_item_update` | 10,000 | 218,269us | 21 | 5,550,000 |
| Rust SQLx SQLite | `rust_sqlx/app_request/admin_item_edit` | 10,000 | 1,826,036us | 182 | 27,395,000 |
| Rust SQLx SQLite | `rust_sqlx/app_request/admin_item_update` | 10,000 | 574,538us | 57 | 5,550,000 |
| Ruby ActiveRecord SQLite | `active_record/app_request/admin_item_edit` | 10,000 | 12,732,861us | 1,273 | 27,395,000 |
| Ruby ActiveRecord SQLite | `active_record/app_request/admin_item_update` | 10,000 | 4,230,022us | 423 | 5,550,000 |

The matching checksums are intentional. They make it easier to notice when two
runners stop doing equivalent work.

For reference, the local `pog` run produced two shapes:

| Runner | Case | Items | Time | us/item | Check |
| --- | --- | ---: | ---: | ---: | ---: |
| Gleam Postgres (`pog`) | `app_request/admin_item_edit` | 10,000 | 7,963,548us | 796 | 27,395,000 |
| Gleam Postgres (`pog`) | `batched_request/admin_item_edit` | 10,000 | 4,657,410us | 465 | 27,395,000 |
| Gleam Postgres (`pog`) | `app_request/admin_item_update` | 10,000 | 17,309,572us | 1,730 | 5,550,000 |
| Gleam Postgres (`pog`) | `batched_request/admin_item_update` | 10,000 | 16,276,321us | 1,627 | 5,550,000 |

The batched rows are faster than the chatty rows: about 1.7x faster
for the read-heavy request and about 1.1x faster for the update request.
That matches the expected direction. It also shows why the batched rows are
useful when reasoning about round-trip overhead.

## Probe Impact

The runner prints plain rows and separate `probed_*` rows. Probe overhead can be
significant:

| Runner | Case | Plain | Probed | Slowdown |
| --- | --- | ---: | ---: | ---: |
| Gleam SQLite | `admin_item_edit` | 1,135,184us | 1,823,617us | 1.6x |
| Gleam SQLite | `admin_item_update` | 453,052us | 640,988us | 1.4x |
| Gleam Postgres (`pog`) | `app_request/admin_item_edit` | 7,963,548us | 12,431,822us | 1.6x |
| Gleam Postgres (`pog`) | `batched_request/admin_item_edit` | 4,657,410us | 5,898,673us | 1.3x |
| Gleam Postgres (`pog`) | `app_request/admin_item_update` | 17,309,572us | 17,951,184us | 1.0x |
| Gleam Postgres (`pog`) | `batched_request/admin_item_update` | 16,276,321us | 16,639,675us | 1.0x |

## Rust SQLx Variants

The Rust runner includes several SQLx shapes to isolate SQLx overhead.

Holding one SQLx connection for the request loop makes the read-heavy request
much faster than checking out through the pool for each query, but it still does
not catch `rusqlite`.

| Runner | Case | Items | Time | us/item | Check |
| --- | --- | ---: | ---: | ---: | ---: |
| Rust `rusqlite` SQLite | `rust_rusqlite/app_request/admin_item_edit` | 10,000 | 591,459us | 59 | 27,395,000 |
| Rust `rusqlite` SQLite | `rust_rusqlite/app_request/admin_item_update` | 10,000 | 284,919us | 28 | 5,550,000 |
| Rust SQLx pool 5 | `rust_sqlx/app_request/admin_item_edit` | 10,000 | 1,826,036us | 182 | 27,395,000 |
| Rust SQLx pool 5 | `rust_sqlx/app_request/admin_item_update` | 10,000 | 574,538us | 57 | 5,550,000 |
| Rust SQLx pool 1 | `rust_sqlx_pool1/app_request/admin_item_edit` | 10,000 | 2,777,851us | 277 | 27,395,000 |
| Rust SQLx pool 1 | `rust_sqlx_pool1/app_request/admin_item_update` | 10,000 | 512,644us | 51 | 5,550,000 |
| Rust SQLx acquired connection | `rust_sqlx_conn/app_request/admin_item_edit` | 10,000 | 1,129,149us | 112 | 27,395,000 |
| Rust SQLx acquired connection | `rust_sqlx_conn/app_request/admin_item_update` | 10,000 | 499,218us | 49 | 5,550,000 |
| Rust SQLx direct connection | `rust_sqlx_direct/app_request/admin_item_edit` | 10,000 | 1,134,108us | 113 | 27,395,000 |
| Rust SQLx direct connection | `rust_sqlx_direct/app_request/admin_item_update` | 10,000 | 487,329us | 48 | 5,550,000 |
| Rust SQLx tuned direct connection | `rust_sqlx_direct_tuned/app_request/admin_item_edit` | 10,000 | 1,077,739us | 107 | 27,395,000 |
| Rust SQLx tuned direct connection | `rust_sqlx_direct_tuned/app_request/admin_item_update` | 10,000 | 504,356us | 50 | 5,550,000 |
| Rust SQLx manual transaction | `rust_sqlx_manual_tx/app_request/admin_item_update` | 10,000 | 475,469us | 47 | 5,550,000 |

The result is fairly clear:

- Pool size 1 does not help the read-heavy request. It is slower.
- Holding one SQLx connection helps a lot: about 1.6x faster than the baseline
  SQLx pool path on the read-heavy request.
- Direct SQLx connection is roughly the same as holding one pooled connection.
- SQLx worker/cache tuning helps the read-heavy request a little, but not the
  update request.
- Manual `BEGIN`/`COMMIT` is the fastest SQLx update row in this run.

The best SQLx read-heavy row remained about 1.8x slower than `rusqlite`. The
best SQLx update row remained about 1.7x slower than `rusqlite`.

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

The Rust `rusqlite` path is not a prepared-statement microbenchmark. It uses the
same request-shaped query sequence as the SQLx path.

The Ruby path is intentionally ORM-shaped. It is useful as a realistic
ActiveRecord comparison, but it should not be read as a SQLite adapter ceiling.

The Gleam runners emit plain rows and separate `probed_*` rows. The Rust and
Ruby runners do not currently emit equivalent probe rows.

## Verification

The checks used:

```sh
cd gleam && gleam format src test
cd gleam && gleam test
cd gleam && gleam run 1000
cd rust && cargo fmt --check
cd rust && cargo check
cd rust && cargo run --release --quiet -- 1000
cd ruby && asdf exec bundle exec ruby -c benchmark.rb
cd ruby && asdf exec bundle exec ruby benchmark.rb 1000

DOCKER_BUILDKIT=1 docker build --ssh default \
  --build-arg BENCHMARK_GIT_REV="$(git rev-parse --short HEAD)" \
  -f docker/bench.Dockerfile \
  -t sqlite-tests-bench .

docker run --rm \
  -v "$PWD/benchmark-results:/app/benchmark-results" \
  -e RUNS=5 \
  sqlite-tests-bench 10000
```
