# Report

Results come from dedicated cloud VMs only, one report per machine. The
[README](README.md) explains the workload, how the runners keep the comparison
fair, and the caveats for Gleam and Bun.

| Machine | vCPUs | CPU | Report |
| --- | ---: | --- | --- |
| DigitalOcean CPU-Optimized `c-2` | 2 | Intel Xeon Platinum 8280 | [reports/do-c-2](reports/do-c-2/README.md) |
| DigitalOcean CPU-Optimized `c-4` | 4 | Intel Xeon Platinum 8168 | [reports/do-c-4](reports/do-c-4/README.md) |

The two machines differ in CPU as well as size. The 8280 ran SQLite about twice
as fast as the 8168 at the same clock speed, so compare them by each runner's
ratio to C on the same machine.

## One request at a time

Read request, microseconds and ratio to C on the same machine:

| Runner | 2 vCPUs (8280) | 4 vCPUs (8168) |
| --- | ---: | ---: |
| C | 56 (1.0x) | 120 (1.0x) |
| Zig | 58 (1.0x) | 120 (1.0x) |
| Rust (`rusqlite`) | 62 (1.1x) | 124 (1.0x) |
| Bun | 83 (1.5x) | 144 (1.2x) |
| Go (`ncruces/go-sqlite3`) | 122 (2.2x) | 199 (1.7x) |
| Gleam, default BEAM | 229 (4.1x) | 333 (2.8x) |
| Gleam, `+SDio` = vCPUs | 290 (5.2x) | 332 (2.8x) |

- Zig and Rust stay within about 10% of C on both machines.
- Bun, Go and Gleam cost relatively more on the faster CPU. Their overhead per
  call is roughly fixed, so it's a bigger share when SQLite's own work is
  faster.
- Gleam pays for `esqlite` running every SQLite call on a dirty I/O scheduler
  thread, and its runs swing between fast and slow. Capping the dirty I/O
  threads at the vCPU count didn't fix that on either machine.

## Many workers at once

As a share of C's throughput on the same machine, with as many workers as vCPUs:

| Runner | Reads, 2 / 4 vCPUs | Writes, 2 / 4 vCPUs | Mixed, 2 / 4 vCPUs |
| --- | ---: | ---: | ---: |
| Zig | 98% / 103% | 100% / 100% | 106% / 98% |
| Rust | 80% / 87% | 91% / 90% | 86% / 78% |
| Bun | 68% / 77% | 71% / 79% | 77% / 71% |
| Go | 48% / 47% | 55% / 58% | 56% / 56% |
| Gleam, default BEAM | 11% / 15% | 7% / 23% | 12% / 22% |

- Zig matches C. Rust and Bun scale like C, keeping a roughly steady gap.
- Go's reads plateau early: about 8,800 requests per second on the 2-vCPU
  machine and 11,500 on the 4-vCPU one, whatever the worker count.
- SQLite allows one writer at a time, so write throughput stops growing at one
  or two workers in every language. Its busy timeout is also unfair: under
  contention one write waited 1 to 3 seconds while others took microseconds.
  Go's `ncruces/go-sqlite3` was the exception, never letting a write wait more
  than about 200 ms. Sending writes through one connection avoids the
  starvation in any language.
- Gleam with dirty I/O threads capped at the vCPU count stalls once enough
  writers wait: they occupy every dirty I/O thread, so the writer holding the
  lock can't commit until the busy timeouts expire. It stalled at 4 writers on
  2 vCPUs and at 8 writers on 4.
- Bun's synchronous `bun:sqlite` means a write waiting on the lock blocks its
  whole JavaScript thread. The benchmark's worker threads hide that; a server
  has to plan around it with a single writer.
- On 2-vCPU Droplets, two workers barely beat one on reads in every language,
  which didn't happen on 4 vCPUs. That points to how a 2-vCPU Droplet's vCPUs
  map to physical cores rather than to SQLite.

## What it means

With SQLite embedded in the process and on the hot path, the runners split by
how they reach SQLite's C code. Each request here makes several calls into
SQLite for each of its 26 queries, so a fixed cost per call adds up quickly.

- C, Zig and Rust call SQLite directly, with no cost to cross into C. They land
  within about 10% of each other.
- Bun's built-in `bun:sqlite` is a native binding with a small cost per call,
  which keeps it about 20 to 50% behind, depending on the CPU.
- Go can only call C through cgo, and every cgo call has a fixed cost. The way
  around it, `ncruces/go-sqlite3`, runs SQLite translated into Go, trading call
  overhead for a slower engine. Either way Go pays.
- Gleam reaches SQLite through `esqlite`, which runs every call on a dirty I/O
  scheduler thread, so each query pays for thread handoffs. Small VMs, where
  cheap embedded-SQLite deployments typically run, are where they cost the
  most.

This is about embedded SQLite, not each language in general. A service that
talks to a database server over the network spends most of its time waiting on
round trips, where a few hundred nanoseconds per call wouldn't show, and Go's
pure-Go drivers and goroutines are built for that. This benchmark doesn't
measure that case.

## Open questions

- Why the 8280 ran SQLite about twice as fast as the 8168 at the same clock
  speed. Each read transaction takes file locks through system calls, and older
  CPUs pay more for the Spectre-era mitigations that slow system calls, but
  that's untested.
- How the results change on bare metal with many more cores, where Gleam's
  default 10 dirty I/O threads each get a core of their own.
