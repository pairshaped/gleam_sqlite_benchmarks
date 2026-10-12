# Gleam SQLite

This runner drives SQLite from Gleam on the BEAM through `esqlite`, the NIF
library underneath `sqlight`. The request loop is Gleam
(`src/sqlite_tests.gleam`); the queries go through a small Erlang module
(`src/sqlite_tests_ffi.erl`).

Run it inside the Nix shell:

```sh
gleam run 5000
```

It creates `sqlite_tests_benchmark.sqlite3` in this directory and prints
`gleam_esqlite/app_request/*` rows.

## Statement cache

`esqlite3:q/3` compiles the statement on every call. The FFI instead keeps one
compiled statement per connection and SQL string, `BEGIN` and `COMMIT`
included, so it matches the other runners. The cache lives in the process
dictionary and stays warm only because this runner handles every request in one
process. A web server that runs each request in its own process would start cold
on every request, so read these rows as a best case.

## Dirty I/O schedulers

`esqlite` runs every SQLite call on a dirty I/O scheduler thread, and the BEAM
starts 10 of them regardless of CPU count. On small VMs the thread handoffs make
Gleam slow and inconsistent from run to run. `scripts/run_all.sh` runs this
runner twice: once with the defaults (`gleam_sqlite`) and once with
`ERL_FLAGS="+SDio <cpu count>"` (`gleam_sqlite_sdio`). The top-level README
explains what each row means for a production app, including when the cap can
stall writers.

In concurrent mode, a lock wait sleeps on a dirty I/O thread. Once waiting
writers occupy every dirty I/O thread, the writer holding the lock can't
commit, and requests fail when their busy timeout expires. The runner counts
those in the `errors` column instead of stopping.

To try the tuned setting by hand:

```sh
ERL_FLAGS="+SDio 2" gleam run 5000
```
