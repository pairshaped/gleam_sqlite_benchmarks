# DigitalOcean CPU-Optimized, 4 vCPU, Xeon Platinum 8168

The same plan and CPU as the [2-vCPU report on this CPU](../do-c-2-8168/README.md),
so the two reports show what more cores do. This Droplet started as an earlier
2-vCPU 8168 Droplet and was resized to 4 vCPUs.

## Machine

- Plan: DigitalOcean CPU-Optimized, Regular Intel, `c-4` (4 dedicated vCPUs,
  8 GB RAM), NYC1
- CPU: Intel Xeon Platinum 8168 @ 2.70 GHz, as assigned by DigitalOcean. The plan doesn't let you choose
  the CPU, so another Droplet of the same plan may get different hardware and
  different results.
- OS: Debian 13.7, Linux 6.12, x86_64
- Background services and timers stopped (see the top-level README)

## Toolchains

All from `flake.nix`: SQLite 3.51.0 (C, Zig, Rust), Rust 1.99.0 with
rusqlite 0.40.2, Zig 0.16.0, Go 1.26.8 with
ncruces/go-sqlite3 0.35.6 (its own SQLite 3.53.4), Bun 1.4.3 (its embedded
SQLite is also 3.51.0), Gleam 1.19.2 on Erlang/OTP 28 with esqlite 0.9.0 (its
bundled SQLite is 3.50.4). The tuned Gleam row uses `+SDio 4`.

## Sequential mode

10,000 requests per case, 5 runs, medians. Microseconds per request; lower is
better.

| Runner | Read request | vs C | Update | vs C |
| --- | ---: | ---: | ---: | ---: |
| C | 120 | 1.0x | 40 | 1.0x |
| Zig (`ReleaseSafe`) | 120 | 1.0x | 41 | 1.0x |
| Rust (`rusqlite`) | 124 | 1.0x | 41 | 1.0x |
| Bun | 144 | 1.2x | 51 | 1.3x |
| Go (`ncruces/go-sqlite3`) | 199 | 1.7x | 46 | 1.2x |
| Gleam, default BEAM | 333 | 2.8x | 108 | 2.7x |
| Gleam, `+SDio 4` | 332 | 2.8x | 104 | 2.6x |

- Rust, Bun and Go land where they did on 2 vCPUs: one request at a time runs
  on one core, so the extra cores don't change their numbers.
- Gleam improved the most: from 995 µs at 2 vCPUs to 333 µs here, with most
  runs consistent (the read request ranged from 318 to 700 µs). With 4 vCPUs,
  the BEAM's dirty I/O scheduler handoffs are much cheaper, and the default and
  tuned rows now match.

## Concurrent mode

Each worker count ran for 5 seconds after a 1-second warm-up, 3 runs, medians.
With 4 vCPUs, 8 workers is oversubscribed.

### Read throughput (requests/sec, higher is better)

| Runner | 1 | 2 | 4 | 8 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: | ---: |
| C | 8,096 | 17,471 | 24,611 | 27,266 | 3.4x |
| Zig | 7,852 | 15,123 | 25,424 | 27,094 | 3.5x |
| Rust | 7,838 | 13,367 | 21,296 | 25,164 | 3.2x |
| Bun | 7,048 | 11,354 | 18,872 | 22,124 | 3.1x |
| Go | 5,194 | 9,237 | 11,515 | 11,163 | 2.2x |
| Gleam, default BEAM | 1,512 | 3,415 | 3,725 | 5,556 | 3.7x |
| Gleam, `+SDio 4` | 1,191 | 3,207 | 4,877 | 6,198 | 5.2x |

### Write throughput (requests/sec)

| Runner | 1 | 2 | 4 | 8 workers |
| --- | ---: | ---: | ---: | ---: |
| C | 22,624 | 36,379 | 36,749 | 36,654 |
| Zig | 25,431 | 36,581 | 36,641 | 35,268 |
| Rust | 23,170 | 33,069 | 33,029 | 33,123 |
| Bun | 19,706 | 29,453 | 29,150 | 29,496 |
| Go | 21,313 | 22,919 | 21,458 | 21,076 |
| Gleam, default BEAM | 9,574 | 7,702 | 8,330 | 8,137 |
| Gleam, `+SDio 4` | 9,200 | 3,110 | 2,758 | 1 (24 failed requests) |

### Mixed throughput (every tenth request writes, requests/sec)

| Runner | 1 | 2 | 4 | 8 workers |
| --- | ---: | ---: | ---: | ---: |
| C | 11,125 | 8,862 | 17,943 | 23,001 |
| Zig | 10,765 | 8,718 | 17,599 | 23,001 |
| Rust | 10,395 | 7,966 | 14,044 | 20,849 |
| Bun | 9,168 | 8,140 | 12,756 | 17,642 |
| Go | 6,046 | 9,411 | 10,001 | 10,309 |
| Gleam, default BEAM | 3,402 | 3,547 | 3,970 | 5,732 |
| Gleam, `+SDio 4` | 3,405 | 2,455 | 4,366 | 6,152 |

The full summary, including p99 latency tables, is in
[concurrent/summary.md](concurrent/summary.md).

### What the concurrent numbers say

- Reads scale cleanly. C reaches 2.2x at 2 workers and 3.0x at 4, the extra
  above 2x presumably from hyperthreading. Both 2-vCPU Droplets' weak 2-worker
  results didn't reproduce here, which points to how a 2-vCPU Droplet's vCPUs
  map to physical cores rather than to SQLite.
- Zig matches C throughout. Rust reaches about 90% of C's throughput at 8
  workers and Bun about 80%, so both keep a steady gap as workers are added.
- Go's reads plateau at about 11,500 requests per second from 4 workers on,
  around 41% of C at 8 workers. Its writes hold at about 57% of C, and its
  longest single write wait stayed under 200 ms at every worker count.
- Writes flatten from 2 workers on in every language. The longest single write
  wait grew with the worker count: about 3 seconds at 8 workers for C and Zig,
  against 1.7 to 2.8 seconds at 4. That's SQLite's busy timeout starving
  writers.
- Gleam with the default BEAM scales from a low base and never failed. With
  `+SDio 4`, writes collapse as writers are added: 2 and 4 writers already ran
  at well under half the default's throughput, and 8 writers stalled almost
  completely, with 24 requests failing on their busy timeout. That's the
  dirty I/O thread hazard described in the top-level README.

## Raw data

- [sequential/](sequential/): per-run CSVs, `metadata.txt` and `summary.md`.
- [concurrent/](concurrent/): the same for concurrent mode.
