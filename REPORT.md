# Report

Results come from dedicated cloud VMs only, one report per machine. The
[README](README.md) explains the workload, how the runners keep the comparison
fair, and the caveats for Gleam and Bun.

| Machine | vCPUs | CPU | Report |
| --- | ---: | --- | --- |
| DigitalOcean CPU-Optimized `c-2` | 2 | Intel Xeon Platinum 8168 | [reports/do-c-2-8168](reports/do-c-2-8168/README.md) |
| DigitalOcean CPU-Optimized `c-4` (the same Droplet, resized) | 4 | Intel Xeon Platinum 8168 | [reports/do-c-4-8168](reports/do-c-4-8168/README.md) |
| DigitalOcean CPU-Optimized `c-2` | 2 | Intel Xeon Platinum 8280 | [reports/do-c-2-8280](reports/do-c-2-8280/README.md) |

The two 8168 reports differ only in size, so together they show what more cores
do. The 8280 ran SQLite about twice as fast as the 8168 at the same clock speed
and on the same plan, so compare it with the others by each runner's ratio to C
on the same machine.

## One request at a time

Read request, microseconds and ratio to C on the same machine:

| Runner | 8168, 2 vCPUs | 8168, 4 vCPUs | 8280, 2 vCPUs |
| --- | ---: | ---: | ---: |
| C | 114 (1.0x) | 120 (1.0x) | 56 (1.0x) |
| Zig | 116 (1.0x) | 120 (1.0x) | 58 (1.0x) |
| Rust (`rusqlite`) | 123 (1.1x) | 124 (1.0x) | 62 (1.1x) |
| Bun | 145 (1.3x) | 144 (1.2x) | 83 (1.5x) |
| Go (`ncruces/go-sqlite3`) | 195 (1.7x) | 199 (1.7x) | 122 (2.2x) |
| Gleam, default BEAM | 1,147 (10.0x) | 333 (2.8x) | 229 (4.1x) |
| Gleam, `+SDio` = vCPUs | 432 (3.8x) | 332 (2.8x) | 290 (5.2x) |

- Zig and Rust stay within about 10% of C everywhere.
- On the 8168, adding cores changes nothing for one request at a time, except
  for Gleam, which got 3.4 times faster: `esqlite` runs every SQLite call on a
  dirty I/O scheduler thread, and those handoffs get much cheaper with more
  cores.
- Bun, Go and Gleam cost relatively more on the faster 8280. Their overhead per
  call is roughly fixed, so it's a bigger share when SQLite's own work is
  faster.
- Capping Gleam's dirty I/O threads at the vCPU count helped a lot on the
  2-vCPU 8168 and not at all on the 2-vCPU 8280.

## Many workers at once

As a share of C's throughput on the same machine, with as many workers as vCPUs:

| Runner | Reads (8168 2 / 4, 8280 2) | Writes (8168 2 / 4, 8280 2) | Mixed (8168 2 / 4, 8280 2) |
| --- | ---: | ---: | ---: |
| Zig | 99% / 103%, 98% | 97% / 100%, 100% | 99% / 98%, 106% |
| Rust | 80% / 87%, 80% | 86% / 90%, 91% | 91% / 78%, 86% |
| Bun | 68% / 77%, 68% | 77% / 79%, 71% | 85% / 71%, 77% |
| Go | 53% / 47%, 48% | 53% / 58%, 55% | 79% / 56%, 56% |
| Gleam, default BEAM | 10% / 15%, 11% | 6% / 23%, 7% | 14% / 22%, 12% |

- Zig matches C. Rust and Bun scale like C, keeping a roughly steady gap.
- Go's reads plateau early: about 6,000 requests per second on the 2-vCPU 8168,
  11,500 on the 4-vCPU 8168 and 8,800 on the 8280, whatever the worker count.
- SQLite allows one writer at a time, so write throughput stops growing at one
  or two workers in every language. Its busy timeout is also unfair: under
  contention one write waited 1 to 3 seconds while others took microseconds.
  Go's `ncruces/go-sqlite3` was the exception, never letting a write wait more
  than about 200 ms. Sending writes through one connection avoids the
  starvation in any language.
- Gleam with dirty I/O threads capped at the vCPU count stalls once enough
  writers wait: they occupy every dirty I/O thread, so the writer holding the
  lock can't commit until the busy timeouts expire. It stalled at 4 writers on
  both 2-vCPU machines and at 8 writers on 4 vCPUs.
- Bun's synchronous `bun:sqlite` means a write waiting on the lock blocks its
  whole JavaScript thread. The benchmark's worker threads hide that; a server
  has to plan around it with a single writer.
- On both 2-vCPU Droplets, two workers barely beat one on reads, in every
  language. The same 8168 Droplet resized to 4 vCPUs scaled cleanly at 2
  workers, which points to how a 2-vCPU Droplet's vCPUs map to physical cores
  rather than to SQLite.

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
