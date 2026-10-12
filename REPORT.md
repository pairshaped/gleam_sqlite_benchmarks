# Report

Results come from dedicated cloud VMs only, one report per machine. The
[README](README.md) explains the workload, how the runners keep the comparison
fair, and the caveats for Gleam and Bun.

| Machine | vCPUs | Report |
| --- | ---: | --- |
| DigitalOcean CPU-Optimized `c-2`, Intel Xeon Platinum 8168 | 2 | [reports/do-c-2](reports/do-c-2/README.md) |

## Findings so far

These come from the 2-vCPU machine. Larger machines will show how far the
concurrent numbers keep scaling.

### One request at a time

Microseconds per request, lower is better:

| Runner | Read request | vs C | Update | vs C |
| --- | ---: | ---: | ---: | ---: |
| C | 114 | 1.0x | 40 | 1.0x |
| Zig | 116 | 1.0x | 38 | 1.0x |
| Rust (`rusqlite`) | 123 | 1.1x | 43 | 1.1x |
| Bun | 145 | 1.3x | 51 | 1.3x |
| Go (`ncruces/go-sqlite3`) | 195 | 1.7x | 47 | 1.3x |
| Gleam, default BEAM | 1,147 | 10.0x | 115 | 2.9x |
| Gleam, `+SDio 2` | 432 | 3.8x | 125 | 3.1x |

Go's row comes from a later rerun that repeated C as a reference (114 µs and
36 µs), so its ratios are against that run's C.

- Zig and Rust add almost nothing on top of SQLite's C API.
- Bun adds about 30%.
- Go adds about 70% with the fastest Go library, which avoids cgo by running
  SQLite translated to Go.
- Gleam pays for `esqlite` running every SQLite call on a dirty I/O scheduler
  thread. On a small VM those handoffs dominate, and runs swing between fast
  and slow. Capping dirty I/O threads at the vCPU count makes the fast mode
  usual but not guaranteed.

### Many workers at once

At 4 workers on 2 vCPUs, as a share of C's throughput:

| Runner | Reads | Writes | Mixed |
| --- | ---: | ---: | ---: |
| Rust | 91% | 90% | 93% |
| Zig | 99% | 99% | 102% |
| Bun | 77% | 75% | 73% |
| Go | 34% | 55% | 36% |

- Rust and Bun scale like C, each keeping a steady gap instead of falling
  further behind under load.
- Go's reads stop scaling at about 6,000 requests per second. Its writes hold at
  about half of C's, and it was the only runner that never starved a writer.
- SQLite allows one writer at a time, so write throughput flattens around two
  workers in every language. Its busy timeout is unfair: under contention one
  write waited 1 to 2 seconds while others took microseconds. Sending writes
  through one connection avoids that.
- Gleam with dirty I/O threads capped at the vCPU count stalled outright with 4
  writers: waiting writers occupied every dirty I/O thread, so the writer
  holding the lock couldn't commit until the busy timeouts expired.
- Bun's synchronous `bun:sqlite` means a write waiting on the lock blocks its
  whole JavaScript thread. The benchmark's worker threads hide that; a server
  has to plan around it with a single writer.

## Open questions

- Why two workers use only about two thirds of two vCPUs on reads. The leading
  theory is lock traffic on SQLite's shared WAL index from the request's 26
  separate read transactions; wrapping a request's reads in one transaction
  would test it.
- How the concurrent results change with more vCPUs.
