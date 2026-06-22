# Gleam SQLite

This bucket runs the request-shaped benchmark through:

- raw `sqlight`/esqlite FFI calls for SQLite
- Gleam Marmot-generated `sqlight` functions for SQLite
- `pog` for local Postgres

Run SQLite:

```sh
gleam deps download
gleam run 5000
```

The SQLite runner emits:

- `app_request/*`: the current FFI-backed SQLite request path.
- `gleam_marmot/app_request/*`: generated functions from the shared SQL files
  under `../rust/src/app_request/sql`.
- `probed_app_request/*`: the FFI-backed SQLite path with scheduler, sendfile,
  and read-file probes enabled.

Regenerate the Gleam Marmot module after changing the shared SQL files:

```sh
gleam run -m marmot
```

The shared one-column SQL files use `-- returns: ValueRow` so generated Gleam
functions return the same row type for scalar values.

Run the Postgres cases:

```sh
gleam run -m postgres_tests 5000
```

The Postgres runner prints both the production-derived request shape and a
batched variant:

- `app_request/*`: the same many-query request sequence as SQLite.
- `batched_request/*`: fewer, larger statements for the same checksum.

The runner does not tune PostgreSQL server config. For this small cached dataset,
round-trips dominate more than memory settings.

Postgres defaults:

```text
PGHOST=/tmp
PGPORT=5432
PGUSER=$USER
PGDATABASE=postgres
PGPASSWORD=
```

Both runners print:

```text
case,items,micros,us_per_item,check
```

The SQLite runner prints primary throughput rows without probes, then `probed_*`
rows with scheduler, sendfile, and read-file probes enabled.
