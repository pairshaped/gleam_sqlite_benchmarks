# Gleam SQLite

This bucket runs the request-shaped benchmark through:

- `sqlight` for SQLite
- `pog` for local Postgres

Run SQLite:

```sh
gleam deps download
gleam run 10000
```

Run the Postgres cases:

```sh
gleam run -m postgres_tests 10000
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

Both runners print primary throughput rows without probes, then `probed_*` rows
with scheduler, sendfile, and read-file probes enabled.
