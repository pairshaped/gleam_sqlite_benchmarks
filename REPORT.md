# Report

Results come from dedicated cloud VMs only, one report per machine. The
[README](README.md) explains the workload, how the runners keep the comparison
fair, and the caveats for Gleam and Bun.

Most results ran on DigitalOcean CPU-Optimized Droplets; one ran on an OVHcloud VPS and one on OVHcloud bare metal. DigitalOcean
assigns the CPU and doesn't let you choose it on this plan, and the CPU it
assigned changed the results a lot: one Droplet ran SQLite twice as fast as
another of the same size. Each report names the exact CPU it got. Expect
different numbers on other hardware, on a future Droplet of the same plan, or
with other providers; the ratios between languages on the same machine travel
better than the absolute numbers.

| Machine | vCPUs | CPU | Report |
| --- | ---: | --- | --- |
| DigitalOcean CPU-Optimized `c-2` | 2 | Intel Xeon Platinum 8168 | [reports/do-c-2-8168](reports/do-c-2-8168/README.md) |
| DigitalOcean CPU-Optimized `c-4` (the same Droplet, resized) | 4 | Intel Xeon Platinum 8168 | [reports/do-c-4-8168](reports/do-c-4-8168/README.md) |
| DigitalOcean CPU-Optimized `c-2` | 2 | Intel Xeon Platinum 8280 | [reports/do-c-2-8280](reports/do-c-2-8280/README.md) |
| OVHcloud VPS (`vps-2027-model4`) | 8 | KVM-reported Haswell model; physical CPU not visible | [reports/ovh-vps-8](reports/ovh-vps-8/README.md) |
| OVHcloud bare metal, RISE-S configuration | 8 cores, 16 threads | AMD Ryzen 7 9700X | [reports/dev-box-9700x](reports/dev-box-9700x/README.md) |

The Ryzen 7 9700X bare-metal box is the fastest machine by far: C runs the
read request in 25 µs, about 4.5 times faster than the OVHcloud VPS, and reads
peak at about 203,000 requests per second. It was the owner's development box,
with development services and agents stopped for the run. Its speed also
exposed write starvation that the slower machines hid: some writes in every
runner except Go waited out SQLite's 5-second busy timeout and failed.

The OVHcloud VPS reads at about the 8168's speed but commits the update
transaction almost twice as fast, likely from storage, and it is the only
8-vCPU machine. Its guest only sees a generic Haswell CPU model, so compare it
by ratios to C. The comparison tables below cover the DigitalOcean machines;
its own numbers are in its report.

The two 8168 reports differ only in size, so together they show what more cores
do. The 8280 ran SQLite about twice as fast as the 8168 at the same clock speed,
so compare it with the others by each runner's ratio to C on the same machine.
That Droplet may have been on DigitalOcean's Premium Intel option, with NVMe
storage as well as the newer CPU; that's unconfirmed.

## One request at a time

Read request, microseconds and ratio to C on the same machine:

| Runner | 8168, 2 vCPUs | 8168, 4 vCPUs | 8280, 2 vCPUs |
| --- | ---: | ---: | ---: |
| C | 126 (1.0x) | 120 (1.0x) | 56 (1.0x) |
| Zig | 124 (1.0x) | 120 (1.0x) | 58 (1.0x) |
| Rust (`rusqlite`) | 129 (1.0x) | 124 (1.0x) | 62 (1.1x) |
| Bun | 156 (1.2x) | 144 (1.2x) | 83 (1.5x) |
| Go (`ncruces/go-sqlite3`) | 211 (1.7x) | 199 (1.7x) | 122 (2.2x) |
| Gleam, default BEAM | 995 (7.9x) | 333 (2.8x) | 229 (4.1x) |
| Gleam, `+SDio` = vCPUs | 1,281 (10.1x) | 332 (2.8x) | 290 (5.2x) |

- Zig and Rust stay within about 10% of C everywhere.
- On the 8168, adding cores changes nothing for one request at a time, except
  for Gleam, which got 3 times faster: `esqlite` runs every SQLite call on a
  dirty I/O scheduler thread, and those handoffs get much cheaper with more
  cores.
- Bun, Go and Gleam cost relatively more on the faster 8280. Their overhead per
  call is roughly fixed, so it's a bigger share when SQLite's own work is
  faster.
- Capping Gleam's dirty I/O threads at the vCPU count helped in an early scan
  on one 2-vCPU 8168 Droplet, but not in the full runs on another 8168 or on
  the 8280. On 2 vCPUs, Gleam's runs swing between fast and slow either way.

## Many workers at once

As a share of C's throughput on the same machine, with as many workers as vCPUs:

| Runner | Reads (8168 2 / 4, 8280 2) | Writes (8168 2 / 4, 8280 2) | Mixed (8168 2 / 4, 8280 2) |
| --- | ---: | ---: | ---: |
| Zig | 99% / 103%, 98% | 99% / 100%, 100% | 99% / 98%, 106% |
| Rust | 81% / 87%, 80% | 92% / 90%, 91% | 90% / 78%, 86% |
| Bun | 68% / 77%, 68% | 80% / 79%, 71% | 85% / 71%, 77% |
| Go | 54% / 47%, 48% | 64% / 58%, 55% | 81% / 56%, 56% |
| Gleam, default BEAM | 17% / 15%, 11% | 18% / 23%, 7% | 27% / 22%, 12% |

- Zig matches C. Rust and Bun scale like C, keeping a roughly steady gap.
- Go's reads plateau early: about 6,100 requests per second on the 2-vCPU 8168,
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
- On every 2-vCPU Droplet, two workers barely beat one on reads, in every
  language. The 4-vCPU 8168 Droplet scaled cleanly at 2 workers, which points
  to how a 2-vCPU Droplet's vCPUs map to physical cores rather than to SQLite.

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
  speed, and writes three times as fast. If that Droplet was on the Premium
  Intel option, its NVMe storage would explain much of the write gap. The newer
  CPU may also pay less for the Spectre-era mitigations that slow the system
  calls behind SQLite's file locks. Neither is tested.
- How the results change on bare metal with many more cores, where Gleam's
  default 10 dirty I/O threads each get a core of their own.
