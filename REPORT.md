# Report

Results come from dedicated cloud VMs only, one report per machine. The
[README](README.md) explains the workload, how the runners keep the comparison
fair, and the caveats for Gleam and Bun.

| Machine | vCPUs | Report |
| --- | ---: | --- |
| DigitalOcean CPU-Optimized `c-2`, Intel Xeon Platinum 8168 | 2 | [reports/do-c-2](reports/do-c-2/README.md) |
| DigitalOcean CPU-Optimized `c-4`, same CPU (the same Droplet, resized) | 4 | [reports/do-c-4](reports/do-c-4/README.md) |

## One request at a time

Microseconds per read request, lower is better:

| Runner | 2 vCPUs | 4 vCPUs | vs C on 4 vCPUs |
| --- | ---: | ---: | ---: |
| C | 114 | 120 | 1.0x |
| Zig | 116 | 120 | 1.0x |
| Rust (`rusqlite`) | 123 | 124 | 1.0x |
| Bun | 145 | 144 | 1.2x |
| Go (`ncruces/go-sqlite3`) | 195 | 199 | 1.7x |
| Gleam, default BEAM | 1,147 | 333 | 2.8x |
| Gleam, `+SDio` = vCPUs | 432 | 332 | 2.8x |

- Zig and Rust add almost nothing on top of SQLite's C API.
- Bun adds about 20 to 30%, and Go about 70% on reads with the fastest Go
  library.
- Every runner except Gleam is the same on 2 and 4 vCPUs, since one request
  runs on one core. Gleam pays for `esqlite` running every SQLite call on a
  dirty I/O scheduler thread, and those handoffs are far cheaper with more
  cores: 3.4 times faster on 4 vCPUs than 2 with default settings.

## Many workers at once

As a share of C's throughput, with as many workers as vCPUs:

| Runner | Reads, 2 / 4 vCPUs | Writes, 2 / 4 vCPUs | Mixed, 2 / 4 vCPUs |
| --- | ---: | ---: | ---: |
| Zig | 99% / 103% | 97% / 100% | 99% / 98% |
| Rust | 80% / 87% | 86% / 90% | 91% / 78% |
| Bun | 68% / 77% | 77% / 79% | 85% / 71% |
| Go | 53% / 47% | 53% / 58% | 79% / 56% |
| Gleam, default BEAM | 10% / 15% | 6% / 23% | 14% / 22% |

- Zig matches C. Rust and Bun scale like C, keeping a roughly steady gap.
- Go's reads plateau early, at about 6,000 requests per second on 2 vCPUs and
  11,500 on 4.
- SQLite allows one writer at a time, so write throughput flattens from about
  two workers on in every language. Its busy timeout is also unfair: under
  contention one write waited up to 3 seconds while others took microseconds.
  Go's `ncruces/go-sqlite3` was the exception, never letting a write wait more
  than about 200 ms. Sending writes through one connection avoids the
  starvation in any language.
- Gleam with dirty I/O threads capped at the vCPU count stalls once writers
  outnumber the threads: waiting writers occupy every dirty I/O thread, so the
  writer holding the lock can't commit until the busy timeouts expire. It
  stalled at 4 writers on 2 vCPUs and at 8 writers on 4.
- Bun's synchronous `bun:sqlite` means a write waiting on the lock blocks its
  whole JavaScript thread. The benchmark's worker threads hide that; a server
  has to plan around it with a single writer.

## What it means

With SQLite embedded in the process and on the hot path, the runners split by
how they reach SQLite's C code. Each request here makes several calls into
SQLite for each of its 26 queries, so a fixed cost per call adds up quickly.

- C, Zig and Rust call SQLite directly, with no cost to cross into C. They land
  within about 10% of each other.
- Bun's built-in `bun:sqlite` is a native binding with a small cost per call,
  which keeps it about 20 to 30% behind.
- Go can only call C through cgo, and every cgo call has a fixed cost. The way
  around it, `ncruces/go-sqlite3`, runs SQLite translated into Go, trading call
  overhead for a slower engine. Either way Go pays.
- Gleam reaches SQLite through `esqlite`, which runs every call on a dirty I/O
  scheduler thread, so each query pays for thread handoffs. More cores make
  them cheaper, but small VMs, where cheap embedded-SQLite deployments
  typically run, are where they cost the most.

This is about embedded SQLite, not each language in general. A service that
talks to a database server over the network spends most of its time waiting on
round trips, where a few hundred nanoseconds per call wouldn't show, and Go's
pure-Go drivers and goroutines are built for that. This benchmark doesn't
measure that case.

## Open questions

- How the results change on bare metal with many more cores, where Gleam's
  default 10 dirty I/O threads each get a core of their own.
