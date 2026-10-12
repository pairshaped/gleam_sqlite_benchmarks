# OVHcloud VPS, 8 vCPU, KVM Haswell model

An OVHcloud VPS in Beauharnois (BHS), reinstalled with Debian 13 for this run.
It is the first report from a provider other than DigitalOcean and the first
with 8 vCPUs.

## Machine

- Plan: OVHcloud VPS (model `vps-2027-model4`), 8 vCPUs, about 22 GB RAM,
  200 GB disk, BHS region
- CPU: KVM presents a generic `Intel Core Processor (Haswell, no TSX)` model
  with AVX2, so the physical CPU behind it isn't visible from the guest. That
  makes absolute numbers harder to compare with other machines than usual;
  compare by each runner's ratio to C. [lscpu.txt](lscpu.txt) has the details.
- OS: Debian 13.6, Linux 6.12, x86_64
- Background services and timers stopped (see the top-level README)
- CPU steal stayed low: at most 0.12% of a sequential suite run and 0.38% of a
  concurrent one

## Toolchains

All from `flake.nix` at `28bf6ab`, the same as the DigitalOcean reports.

## Sequential mode

10,000 requests per case, 5 runs, medians. Microseconds per request; lower is
better.

| Runner | Read request | vs C | Update | vs C |
| --- | ---: | ---: | ---: | ---: |
| C | 111 | 1.0x | 23 | 1.0x |
| Zig (`ReleaseSafe`) | 113 | 1.0x | 23 | 1.0x |
| Rust (`rusqlite`) | 125 | 1.1x | 26 | 1.1x |
| Bun | 145 | 1.3x | 36 | 1.6x |
| Go (`ncruces/go-sqlite3`) | 213 | 1.9x | 39 | 1.7x |
| Gleam, default BEAM | 336 | 3.0x | 89 | 3.8x |
| Gleam, `+SDio 8` | 461 | 4.1x | 89 | 3.8x |

- Reads land close to the 8168 Droplets (C at 111 µs against 120 to 126), but
  the update transaction is much faster: 23 µs for C against about 40 µs on
  the 4-vCPU 8168. Storage, not the CPU, probably makes the difference; the
  update commits a transaction and the read request doesn't.
- Zig and Rust stay within about 10% of C, as on every other machine.
- Gleam's read request swung from 299 to 697 µs across runs with the default
  BEAM. Capping dirty I/O threads at the vCPU count made it slower here.

## Concurrent mode

Each worker count ran for 5 seconds after a 1-second warm-up, 3 runs, medians.
With 8 vCPUs, 16 workers is oversubscribed.

### Read throughput (requests/sec, higher is better)

| Runner | 1 | 2 | 4 | 8 | 16 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| C | 8,622 | 14,042 | 37,781 | 53,612 | 47,623 | 6.2x |
| Zig | 8,202 | 14,384 | 37,558 | 48,179 | 39,425 | 5.9x |
| Rust | 7,274 | 8,991 | 29,484 | 44,942 | 43,698 | 6.2x |
| Bun | 6,431 | 7,551 | 24,870 | 42,279 | 44,085 | 6.9x |
| Go | 4,742 | 8,306 | 15,505 | 25,607 | 21,556 | 5.4x |
| Gleam, default BEAM | 2,979 | 3,737 | 5,657 | 6,742 | 7,821 | 2.6x |
| Gleam, `+SDio 8` | 2,864 | 4,299 | 5,670 | 7,582 | 8,744 | 3.1x |

### Write throughput (requests/sec)

| Runner | 1 | 2 | 4 | 8 | 16 workers |
| --- | ---: | ---: | ---: | ---: | ---: |
| C | 42,462 | 39,207 | 39,154 | 40,923 | 38,830 |
| Zig | 36,851 | 38,689 | 38,388 | 39,575 | 29,964 |
| Rust | 33,684 | 34,454 | 30,888 | 32,208 | 32,667 |
| Bun | 26,960 | 26,289 | 25,564 | 22,929 | 17,994 |
| Go | 23,455 | 23,731 | 21,064 | 21,876 | 21,864 |
| Gleam, default BEAM | 11,166 | 10,506 | 10,794 | 11,018 | 1 (60 failed requests) |
| Gleam, `+SDio 8` | 10,559 | 10,008 | 10,973 | 11,449 | 1 (48 failed requests) |

### Mixed throughput (every tenth request writes, requests/sec)

| Runner | 1 | 2 | 4 | 8 | 16 workers |
| --- | ---: | ---: | ---: | ---: | ---: |
| C | 11,047 | 13,259 | 26,379 | 32,864 | 32,083 |
| Zig | 11,346 | 12,815 | 27,173 | 30,858 | 30,873 |
| Rust | 9,972 | 9,206 | 21,963 | 27,155 | 27,373 |
| Bun | 8,148 | 8,400 | 19,934 | 23,509 | 26,781 |
| Go | 5,663 | 9,196 | 15,524 | 21,143 | 19,263 |
| Gleam, default BEAM | 3,256 | 4,773 | 6,091 | 6,633 | 8,565 |
| Gleam, `+SDio 8` | 3,176 | 4,703 | 6,468 | 6,639 | 6,971 |

The full summary, including p99 and maximum latency tables, is in
[concurrent/summary.md](concurrent/summary.md).

### What the concurrent numbers say

- Reads scale to 6.2x at 8 workers for C and Rust, and Bun reaches 6.9x by 16
  workers. At 8 workers, Zig runs at 90% of C, Rust 84%, Bun 79%, Go 48% and
  Gleam 13% to 14%.
- 2 workers gained little over 1 for every runner except Go, then 4 workers
  jumped. The same pattern showed on the 2-vCPU Droplets, so it may come from
  how the hypervisor places the first two busy vCPUs.
- Writes stay flat at every worker count, as SQLite allows one writer at a
  time. C holds about 40,000 writes per second. The longest single write wait
  reached 1 to 2 seconds for C, Zig, Rust and Bun from 2 workers on (SQLite's
  busy timeout starving writers), while Go's `ncruces/go-sqlite3` never let a
  write wait more than 141 ms.
- Gleam stalls at 16 writers with either setting: both rows fell to 1 request
  per second, with 60 and 48 failed requests. With `+SDio 8` it held up through
  8 writers this time, unlike the smaller Droplets, where the capped setting
  stalled once writers matched the vCPU count. That's the dirty I/O thread
  hazard from the top-level README: once waiting writers occupy every dirty I/O
  thread, the writer holding the lock can't commit.
- Mixed throughput scales to about 3x for C. Go keeps a larger share of C here
  (64% at 8 workers) than in pure reads.

## Raw data

- [sequential/](sequential/): per-run CSVs, `metadata.txt` and `summary.md`.
- [concurrent/](concurrent/): the same for concurrent mode.
- [lscpu.txt](lscpu.txt): the guest's CPU, Debian release and kernel.
