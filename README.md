# SQLite Request-Shape Benchmarks

This repo runs one synthetic, app-shaped SQLite workload in six languages and
compares how much each adds on top of SQLite itself, one request at a time and
with many workers at once:

- [c/](c/README.md): the SQLite C API with no wrapper. This is the baseline.
- [rust/](rust/README.md): Rust with `rusqlite`.
- [zig/](zig/README.md): Zig calling the SQLite C API directly, built with
  runtime safety checks on (`ReleaseSafe`).
- [go/](go/README.md): Go with `ncruces/go-sqlite3`, the fastest Go SQLite
  library here.
- [bun/](bun/README.md): Bun with its built-in `bun:sqlite`.
- [gleam/](gleam/README.md): Gleam on the BEAM with `esqlite`.

The schema, rows and names are synthetic. The request shapes come from a
production admin app: many small indexed reads, a recursive parent lookup and a
short save transaction.

Results live in [REPORT.md](REPORT.md), with one report per machine under
[reports/](reports/). Every published number comes from a dedicated cloud VM.
Laptop runs are fine for checking that the runners build and agree, but
background apps make their timings unreliable, so they aren't reported.

The hardware behind a cloud VM matters as much as its size. Two 2-vCPU
DigitalOcean CPU-Optimized Droplets landed on different Intel Xeon generations,
and the newer one (Platinum 8280) ran SQLite about twice as fast as the older
one (Platinum 8168). The 8280 Droplet may have been on DigitalOcean's Premium
Intel option, which pairs a newer CPU with NVMe storage; that's unconfirmed.
Each report names its CPU; compare reports by each runner's ratio to C on the
same machine, and check `lscpu` before trusting a new box.

## What runs

There are two modes. Sequential mode runs requests one at a time on one
connection and measures what a language adds per request. Concurrent mode runs
several workers at once and measures how each language scales across cores.

### Sequential mode

Each runner prints CSV:

```text
case,items,micros,us_per_item,check
```

Every runner measures three cases, prefixed with its own name (for example
`c_sqlite/app_request/admin_item_edit`):

- `app_request/seed_dummy_data`: creates the dummy schema and seed rows.
- `app_request/admin_item_edit`: a read-heavy request with 26 queries over 22
  distinct statements: point selects, filtered counts, small joins and a
  recursive parent lookup.
- `app_request/admin_item_update`: one transaction with six reads and one row
  update.

The `check` column is a checksum of every value the requests read. All runners
must print the same checks, which is how you know they did the same work.

The Rust runner adds a `rust_rusqlite_query_only` read case on a connection
with `PRAGMA query_only = ON`.

### Concurrent mode

W workers run at once, each with its own connection and statement cache, for a
fixed time. Each language uses its usual concurrency model: OS threads in C,
Zig and Rust, goroutines in Go, worker threads in Bun and processes in Gleam.
Every worker opens its connection before the clock starts, runs a warm-up, then
records the latency of each request that starts inside the measured window.

There are three workloads: `read` runs the edit request, `write` runs the update
transaction, and `mixed` makes every tenth request a write. Each runs at 1, 2,
4 and so on up to the CPU count, then at twice the CPU count to show what
oversubscription does.

Each runner prints:

```text
case,workers,seconds,requests,requests_per_second,p50_us,p95_us,p99_us,max_us
```

Concurrent writes start with `BEGIN IMMEDIATE`. A plain `BEGIN` transaction
that reads and then writes fails at once with `SQLITE_BUSY` if another
connection committed in between, without waiting on the busy timeout, so the
write numbers would measure errors. Every connection also sets its busy timeout
before any other pragma, so connections opened at the same moment wait for
each other instead of failing.

Read the write rows with two SQLite behaviours in mind:

- SQLite allows one writer at a time, so write throughput flattens no matter
  how many workers you add.
- The busy timeout is unfair. A writer that finds the database locked sleeps
  and retries, while whichever connection holds the lock keeps winning, so one
  write can wait hundreds of milliseconds while the others take microseconds.
  That hides above the 99th percentile, which is why the output includes the
  maximum. Part of the maximum is also SQLite's automatic WAL checkpoint, which
  flushes to disk every 1,000 pages and can take tens of milliseconds on a VM
  even with a single writer. An app that sends all writes through one writer,
  queuing them itself, avoids the starvation.

The checksum doesn't apply here, because readers see counters that writers keep
changing. Instead, any failed query stops the run.

## A fair comparison

Two things would quietly skew the numbers, so the runners control both.

### Statement caching

Every runner reuses every compiled statement it runs, including `BEGIN` and
`COMMIT`, and the caches are big enough that nothing is evicted.

That matters more than it sounds. The read request cycles through 22 distinct
statements. A cache smaller than that evicts each statement just before its
next use, so every lookup misses and the request ends up slower than it would
with no cache at all. rusqlite's default cache holds 16 statements and Bun's
holds 20, so both thrash on this request out of the box.

- C and Zig prepare each statement once per connection and keep it.
- Rust uses `prepare_cached` with the cache raised to 256 statements.
- Go caches one prepared statement per SQL string on its connection.
- Bun uses `db.query` with `Database.MAX_QUERY_CACHE_SIZE` raised to 256.
- Gleam keeps one compiled `esqlite` statement per connection and SQL string in
  the process dictionary. See the Gleam caveats below.

### One SQLite

C, Zig and Rust link the same SQLite 3.51.0 library, built from SQLite's release
tarball by the flake. Bun 1.4.3 embeds its own copy of the same release. Go's
`ncruces/go-sqlite3` runs its own SQLite 3.53.4, compiled to Wasm and translated
to Go, and Gleam uses the SQLite 3.50.4 that `esqlite` bundles.

## Gleam caveats

The Gleam rows need more context than the others before you apply them to a
production app.

### The statement cache is per process

The Gleam cache lives in one BEAM process. This benchmark runs every request in
that one process, so the cache stays warm for the whole run. A Gleam web server
such as Mist or Wisp handles each request or connection in its own process, so a
per-process cache starts cold on every request and only helps statements that
repeat within that request.

Treat the Gleam rows as a best case: one process, warm cache. To keep compiled
statements across requests, a real app has to keep them with the connection,
for example in a long-lived process that owns it.

### Dirty I/O schedulers: why Gleam has two rows

`esqlite` runs every SQLite call on the BEAM's dirty I/O schedulers, so each
query moves the calling process to a dirty I/O thread and back. The BEAM starts
10 dirty I/O threads regardless of how many CPUs the machine has. On a small VM
those extra threads fight over the cores, waking them is slow, and runs flip
between fast and slow with no other change. On a 2-vCPU Droplet with a Xeon
Platinum 8168, cached Gleam read requests took anywhere from 423 to 1,286 µs
with the default settings.

So the Gleam runner runs twice:

- `gleam_sqlite` uses the BEAM defaults. This is what an app gets unless
  someone tunes it, and it's the row to compare against the other languages.
- `gleam_sqlite_sdio` sets `+SDio` to the machine's CPU count. On that 8168
  Droplet it held runs at 423 to 435 µs. On a 2-vCPU Droplet with a Xeon
  Platinum 8280 it didn't help: both rows stayed inconsistent, and the tuned
  one was slower. Whether the cap helps depends on the machine. On a machine
  with 10 or more CPUs the two rows should match, because the default already
  fits.

The tuned row is a real production option, with one condition. `+SDio` matching
the CPU count is a one-line setting in `vm.args` or `ERL_FLAGS`, but SQLite's
busy timeout sleeps on the dirty I/O thread running the query. If as many
connections are waiting on a lock as there are dirty I/O threads, every thread
is asleep and the connection holding the lock can't run its `COMMIT`, so
everything stalls until the timeouts expire and those queries fail. Concurrent
mode reproduces this: 4 writers stall with `+SDio 2`, and 12 writers stall on
the default 10 threads. Gleam's concurrent rows report those failures in the
`errors` column instead of stopping the run.

So the cap is safe when writes go through one connection, such as a single
writer process that queues them; readers in WAL mode don't wait on writers.
With many writer connections, keep them below the dirty I/O thread count and
don't lower `+SDio`. Don't go below the CPU count either way: `+SDio 1` measures
the same in sequential mode, but it pushes every SQLite call and file operation
on the node through one thread.

## Bun caveat: SQLite blocks the JavaScript thread

`bun:sqlite` is synchronous. A query runs to completion on the JavaScript thread
that called it, and nothing else on that thread runs in the meantime: no other
request, timer or I/O callback. For the queries in this benchmark that costs a
few microseconds each and doesn't matter.

Lock waits are the problem. When a write finds the database locked, SQLite's
busy timeout sleeps inside the call, on that same thread. In concurrent mode a
single write waited one to two seconds under contention, in every language. In
Bun that sleep freezes every other request handled by the same thread for as
long as it lasts. The concurrent runner hides this because each worker thread
runs only its own requests; a web server would not.

A Bun app on SQLite has to be designed around it from the start:

- Give writes one owner. Run a single writer, in its own worker thread or
  process, that holds the only connection that writes and takes requests
  through a queue. Only that connection ever waits on the write lock, and the
  wait never blocks a thread that serves other requests.
- Spread reads across processes or worker threads, each with its own read
  connection. In WAL mode readers don't wait on the writer, but a single
  JavaScript thread still serializes every query it runs, so one thread caps
  read throughput at about one core.
- Keep queries short. Any slow query, such as an unindexed scan or a large
  report, blocks its thread for its whole duration.

This is the same single-writer pattern that avoids SQLite's write starvation in
any language. In Bun it is required, not just recommended.

## Toolchains

`flake.nix` pins every toolchain: SQLite 3.51.0, Clang or GCC from nixpkgs,
Rust 1.99.0, Zig 0.16.0, Go 1.26, Bun 1.4.3, Gleam 1.19.2 with Erlang/OTP 28 and
rebar3, and Ruby for the summary script. Gleam and Bun come from the projects'
own release binaries and SQLite from its release tarball, all checked by hash,
so a new release doesn't wait on nixpkgs. The flake supports `x86_64-linux`,
`aarch64-linux` and `aarch64-darwin`.

Enter the shell from the repo root and run any command below inside it:

```sh
nix develop
```

Or run one command directly, such as `nix develop -c scripts/run_all.sh 10000`.

## Run everything

```sh
RUNS=5 scripts/run_all.sh 10000
MODE=concurrent RUNS=3 scripts/run_all.sh
```

Each builds every runner, runs every suite `RUNS` times, and writes raw CSV
files, machine metadata and a median summary under `benchmark-results/`. Set
`SUITES` to run a subset, for example `SUITES="c rust"`. The suites are `c`,
`rust`, `zig`, `go`, `bun`, `gleam_sqlite` and `gleam_sqlite_sdio`.

Concurrent mode takes `DURATION` (seconds measured per point, default 5),
`WARMUP` (default 1) and `WORKERS` (a comma-separated list, defaulting to powers
of two up to the CPU count plus twice the CPU count).

Keep the request count around 10,000. At 1,000 the CPU hasn't reached full
speed yet, and single runs swing widely. To save time, lower `RUNS`
before lowering the request count. For a quick check that everything builds and
the checks agree, `RUNS=1 scripts/run_all.sh 1000` is enough.

To run one language on its own, follow its README.

## Run on a throwaway Linux box

Nothing in the suite touches the network or real data, so any Linux host with
Nix can run it. A rented VPS you destroy afterwards works well; destroy it
rather than powering it off, since a stopped VPS usually still bills.

Choose the box deliberately:

- Building needs about 2 GB of RAM, mostly for the Rust release build. On 1 GB,
  add swap and set `CARGO_BUILD_JOBS=1`.
- Plans with dedicated vCPUs give steadier numbers. Shared vCPUs work but are
  noisier, so raise `RUNS` and compare medians. On Linux, `run_all.sh` records
  CPU steal (time the hypervisor gave to other tenants) for each suite run in
  `steal.csv`, and the summary lists it when any is above zero.
- Avoid burstable plans that throttle once CPU credits run out mid-run.
- On x86, check for AVX2 (`grep -c avx2 /proc/cpuinfo`). Bun's standard x64
  build needs it.
- Turn off background services and timers first (shown below). Automatic
  updates or an agent check firing mid-run would show up as a slow run.

Keep concrete hostnames, SSH users and server paths in private notes, not in
this public repo.

```sh
ssh <benchmark-user>@<benchmark-host>
# DigitalOcean's Debian 13 image ships without git.
apt-get update && apt-get install -y git

# Stop background services and timers that would compete for CPU mid-run, and
# keep them off across reboots and resizes. Leaves SSH, networking and journald.
systemctl disable --now unattended-upgrades.service droplet-agent.service \
  apt-daily.timer apt-daily-upgrade.timer man-db.timer dpkg-db-backup.timer \
  e2scrub_all.timer fstrim.timer droplet-agent-update.timer apt-listchanges.timer
systemctl mask --now systemd-tmpfiles-clean.timer
# Images change; confirm nothing is still scheduled. Only masked timers, showing
# no next run, should be left.
systemctl list-timers
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

git clone https://github.com/pairshaped/gleam_sqlite_benchmarks.git
cd gleam_sqlite_benchmarks

# Detach the run so a dropped SSH connection doesn't kill it.
nohup bash -c 'RUNS=5 OUT_DIR=benchmark-results/<box-name> nix develop -c scripts/run_all.sh 10000; echo $? > run.done' > run.log 2>&1 < /dev/null &
tail -f run.log
```

Copy `benchmark-results/` back with `scp -r` before destroying the box.

To benchmark uncommitted local changes instead of cloning, copy the tree with
`rsync` (install it with `apt-get install -y rsync`). Skip build output
(`gleam/build`, `rust/target`, `bun/node_modules`, `c/benchmark`,
`zig/benchmark`, `go/benchmark`, `benchmark-results`, `*.sqlite3*`) and keep
`.git`, because the flake reads files through Git. Then `chown -R` the tree to
the user running Nix: `rsync -a` keeps your local owner, and Nix refuses a Git
repository owned by another user. New files must be tracked or added with
`git add -N`, or Nix won't see them.

## Change the shape

Each runner holds its own copy of the seed SQL and request sequence:

- C: `c/benchmark.c`
- Rust: `rust/src/main.rs`
- Zig: `zig/benchmark.zig`
- Go: `go/main.go`
- Bun: `bun/benchmark.ts`
- Gleam: `gleam/src/sqlite_tests_ffi.erl`, driven by `gleam/src/sqlite_tests.gleam`

To test a different workload, change all six the same way and keep the CSV
shape. If the checks stop matching across runners, the runners no longer do the
same work. Useful knobs:

- number of tables and indexes created by the seed step
- rows inserted per table
- number of queries in `admin_item_edit`
- number of queries and writes in `admin_item_update`
- whether the parent lookup is SQL-recursive or done in application code

The request-count argument controls how many simulated requests run. It doesn't
change seed sizes unless you edit the seed step.
