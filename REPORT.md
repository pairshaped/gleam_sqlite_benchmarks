# Report

Results come from dedicated cloud machines only, one report per machine. The
[README](README.md) explains the workload, how the runners keep the comparison
fair, and the caveats for Gleam and Bun.

Most results ran on DigitalOcean CPU-Optimized Droplets; one ran on an
OVHcloud VPS and one on OVHcloud bare metal. DigitalOcean assigns the CPU and
doesn't let you choose it on this plan, and the CPU it assigned changed the
results a lot: one Droplet ran SQLite twice as fast as another of the same
size. Each report names the CPU it got, where the machine shows it. Expect
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
peak at about 203,000 requests per second. Its speed also
exposed write starvation that the slower machines hid: some writes in every
runner except Go waited out SQLite's 5-second busy timeout and failed.

The OVHcloud VPS reads at about the 8168's speed but commits the update
transaction almost twice as fast, likely from storage, and it is the only
8-vCPU VM. Its guest only sees a generic Haswell CPU model, so compare it
by ratios to C.

The two 8168 reports differ only in size, so together they show what more cores
do. The 8280 ran SQLite about twice as fast as the 8168 at the same clock speed,
so compare it with the others by each runner's ratio to C on the same machine.
That Droplet may have been on DigitalOcean's Premium Intel option, with NVMe
storage as well as the newer CPU; that's unconfirmed.

## One request at a time

Read request, microseconds and ratio to C on the same machine:

| Runner | 8168, 2 vCPUs | 8168, 4 vCPUs | 8280, 2 vCPUs | OVH VPS, 8 vCPUs | 9700X, bare metal |
| --- | ---: | ---: | ---: | ---: | ---: |
| C | 126 (1.0x) | 120 (1.0x) | 56 (1.0x) | 111 (1.0x) | 25 (1.0x) |
| Zig | 124 (1.0x) | 120 (1.0x) | 58 (1.0x) | 113 (1.0x) | 22 (0.9x) |
| Rust (`rusqlite`) | 129 (1.0x) | 124 (1.0x) | 62 (1.1x) | 125 (1.1x) | 25 (1.0x) |
| Bun | 156 (1.2x) | 144 (1.2x) | 83 (1.5x) | 145 (1.3x) | 28 (1.1x) |
| Go (`ncruces/go-sqlite3`) | 211 (1.7x) | 199 (1.7x) | 122 (2.2x) | 213 (1.9x) | 44 (1.7x) |
| Gleam, default BEAM | 995 (7.9x) | 333 (2.8x) | 229 (4.1x) | 336 (3.0x) | 65 (2.6x) |
| Gleam, `+SDio` = vCPUs | 1,281 (10.1x) | 332 (2.8x) | 290 (5.2x) | 461 (4.1x) | 65 (2.6x) |

- Zig and Rust stay within about 10% of C everywhere.
- On the 8168, adding cores changes nothing for one request at a time, except
  for Gleam, which got 3 times faster: `esqlite` runs every SQLite call on a
  dirty I/O scheduler thread, and those handoffs get much cheaper with more
  cores.
- Bun, Go and Gleam cost relatively more on the faster 8280, as if their
  overhead per call were fixed. The 9700X, faster still, breaks that pattern:
  there Bun costs only 1.1 times C and Gleam 2.6 times, their best ratios
  anywhere. How a CPU runs JIT-compiled JavaScript and BEAM thread handoffs
  matters as much as raw speed.
- Capping Gleam's dirty I/O threads at the vCPU count helped in an early scan
  on one 2-vCPU 8168 Droplet, but not in the full runs on another 8168 or on
  the 8280. On 2 vCPUs, Gleam's runs swing between fast and slow either way.

## Many workers at once

As a share of C's throughput on the same machine, with as many workers as
vCPUs (16, one per thread, on the 9700X).

Reads:

| Runner | 8168, 2 | 8168, 4 | 8280, 2 | OVH VPS, 8 | 9700X, 16 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Zig | 99% | 103% | 98% | 90% | 100% |
| Rust | 81% | 87% | 80% | 84% | 99% |
| Bun | 68% | 77% | 68% | 79% | 104% |
| Go | 54% | 47% | 48% | 48% | 34% |
| Gleam, default BEAM | 17% | 15% | 11% | 13% | 15% |

Writes:

| Runner | 8168, 2 | 8168, 4 | 8280, 2 | OVH VPS, 8 | 9700X, 16 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Zig | 99% | 100% | 100% | 97% | 104% |
| Rust | 92% | 90% | 91% | 79% | 87% |
| Bun | 80% | 79% | 71% | 56% | 68% |
| Go | 64% | 58% | 55% | 53% | 55% |
| Gleam, default BEAM | 18% | 23% | 7% | 27% | stalled |

Mixed (every tenth request writes):

| Runner | 8168, 2 | 8168, 4 | 8280, 2 | OVH VPS, 8 | 9700X, 16 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Zig | 99% | 98% | 106% | 94% | 104% |
| Rust | 90% | 78% | 86% | 83% | 99% |
| Bun | 85% | 71% | 77% | 72% | 97% |
| Go | 81% | 56% | 56% | 64% | 54% |
| Gleam, default BEAM | 27% | 22% | 12% | 20% | stalled |

- Zig matches C. Rust and Bun scale like C with a roughly steady gap on the
  VMs, and caught up with it on the 9700X: 99% and 104% of C's reads at 16
  workers.
- Go's reads plateau early: about 6,100 requests per second on the 2-vCPU 8168,
  11,500 on the 4-vCPU 8168, 8,800 on the 8280, 25,600 on the OVH VPS and
  80,000 on the 9700X, whatever the worker count.
- SQLite allows one writer at a time, so write throughput stops growing at one
  or two workers in every language. Its busy timeout is also unfair: under
  contention one write waited 1 to 3 seconds while others took microseconds.
  On the fast 9700X, some writes waited out the whole 5-second timeout and
  failed, in every runner except Go. Go's `ncruces/go-sqlite3` was the
  exception everywhere, never letting a write wait more than about 200 ms.
  Sending writes through one connection avoids the starvation in any language.
- Gleam with dirty I/O threads capped at the vCPU count stalls once enough
  writers wait: they occupy every dirty I/O thread, so the writer holding the
  lock can't commit until the busy timeouts expire. It stalled at 4 writers on
  both 2-vCPU machines and at 8 writers on 4 vCPUs. On machines with more
  cores, the default BEAM's 10 dirty I/O threads became the limit instead: it
  stalled at 16 writers on both the OVH VPS and the 9700X, while the capped
  setting held through 8 writers on the VPS and 16 on the 9700X.
- Bun's synchronous `bun:sqlite` means a write waiting on the lock blocks its
  whole JavaScript thread. The benchmark's worker threads hide that; a server
  has to plan around it with a single writer.
- On every machine except the 4-vCPU 8168, two workers barely beat one on
  reads, then four jumped ahead. That includes the 8-vCPU OVH VPS and the
  bare-metal 9700X, so it isn't just how a 2-vCPU Droplet's vCPUs map to
  physical cores. See the open questions.

## What it means

With SQLite embedded in the process and on the hot path, the runners split by
how they reach SQLite's C code. Each request here makes several calls into
SQLite for each of its 26 queries, so a fixed cost per call adds up quickly.

- C, Zig and Rust call SQLite directly, with no cost to cross into C. They land
  within about 10% of each other.
- Bun's built-in `bun:sqlite` is a native binding with a small cost per call,
  which keeps it about 10 to 50% behind, depending on the CPU.
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
- Why the 9700X ran Bun and Gleam so close to C.
- Why two workers gain so little over one on most machines and four gain so
  much. On the 9700X, default CPU frequency scaling keeping a single busy
  thread below full boost is a likely cause; it doesn't explain the VMs.
- Why Go's `ncruces/go-sqlite3` commits faster than C on the 9700X (the update
  takes 15 µs against 19), when it trails C everywhere else. It brings its own
  SQLite build and file layer, so it may flush or checkpoint differently;
  comparing compile options and counting disk flushes would tell.
