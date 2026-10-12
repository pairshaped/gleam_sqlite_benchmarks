# Go SQLite

This runner uses `ncruces/go-sqlite3` through its direct API, without
`database/sql`. It needs no cgo: the library compiles SQLite to Wasm and
translates that to Go source, so it runs its own copy of SQLite (3.53.4 in
v0.35.6) instead of the shared 3.51.0 the C, Zig and Rust runners link.

Build and run inside the Nix shell:

```sh
./build.sh
./benchmark 5000
./benchmark concurrent 5 1 1,2,4
```

It creates `go_benchmark.sqlite3` in this directory and prints
`go_ncruces/app_request/*` and `go_ncruces/concurrent/*` rows. One connection
caches a prepared statement per SQL string. In concurrent mode each worker is a
goroutine with its own connection.

## Why this library

Of the maintained Go SQLite libraries, `ncruces/go-sqlite3` was the fastest on
this workload. Both alternatives ran on the same 2-vCPU Droplet as the other
reports, with C as a same-session reference, before they were removed.

| µs per request, sequential | Read request | Update |
| --- | ---: | ---: |
| C | 114 | 36 |
| SQLite C API called directly through cgo | 143 | 55 |
| `ncruces/go-sqlite3`, direct API | 195 | 47 |
| `database/sql` with `mattn/go-sqlite3` | 222 | 64 |

Under concurrency, `ncruces` beat `mattn` on writes and mixed requests, and on
reads with 1 or 2 workers; at 4 workers the two tied on reads. Its write
throughput held at about 19,800 requests per second at 4 workers, where `mattn`
fell from about 15,900 with one worker to 12,500.

## Caveat: what Go costs here

- Even calling SQLite's C API directly, Go was about 1.25x C on the read
  request. Each of the request's 26 queries crosses from Go into C several
  times, and every cgo crossing has a fixed cost.
- `database/sql` with `mattn/go-sqlite3` added about another 55% on top of
  that, from the generic `database/sql` layer and the driver.
- `ncruces` avoids cgo entirely. Its translated SQLite runs slower than native
  code, but Go-to-Go calls are cheap, so it beat the direct cgo binding on the
  update, which is mostly tiny calls.
- None of the Go variants scaled reads far past about 6,000 requests per second
  on 2 vCPUs, except the direct cgo binding.
- `ncruces` never starved a writer under contention: its longest wait at 4
  writers was about 120 ms, against over a second for C and the cgo-based
  variants.

For the same libraries on a different workload (bulk inserts, large scans and
concurrent full-table reads), see
[modernc.org/sqlite-bench](https://pkg.go.dev/modernc.org/sqlite-bench).
