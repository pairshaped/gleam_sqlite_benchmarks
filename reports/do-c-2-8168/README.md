# DigitalOcean CPU-Optimized, 2 vCPU, Xeon Platinum 8168

The same plan and CPU as the [4-vCPU report](../do-c-4-8168/README.md), so the two
reports show what more cores do. That 4-vCPU Droplet started as an earlier 2-vCPU
8168 Droplet; this run replaced the earlier one's report. A 2-vCPU Droplet with a
faster CPU has its own [report](../do-c-2-8280/README.md).

## Machine

- Plan: DigitalOcean CPU-Optimized, Regular Intel, `c-2` (2 dedicated vCPUs,
  4 GB RAM), NYC1
- CPU: Intel Xeon Platinum 8168 @ 2.70 GHz, as assigned by DigitalOcean. The plan doesn't let you choose
  the CPU, so another Droplet of the same plan may get different hardware and
  different results.
- OS: Debian 13.7, Linux 6.12, x86_64
- Background services and timers stopped (see the top-level README)

## Toolchains

All from `flake.nix`: SQLite 3.51.0 (C, Zig, Rust), Rust 1.99.0 with
rusqlite 0.40.2, Zig 0.16.0, Go 1.26.8 with ncruces/go-sqlite3 0.35.6 (its own
SQLite 3.53.4), Bun 1.4.3 (its embedded SQLite is also 3.51.0), Gleam 1.19.2 on
Erlang/OTP 28 with esqlite 0.9.0 (its bundled SQLite is 3.50.4). The tuned
Gleam row uses `+SDio 2`.

## Sequential mode

10,000 requests per case, 5 runs, medians. Microseconds per request; lower is
better.

| Runner | Read request | vs C | Update | vs C |
| --- | ---: | ---: | ---: | ---: |
| C | 126 | 1.0x | 37 | 1.0x |
| Zig | 124 | 1.0x | 38 | 1.0x |
| Rust (`rusqlite`) | 129 | 1.0x | 41 | 1.1x |
| Bun | 156 | 1.2x | 46 | 1.2x |
| Go (`ncruces/go-sqlite3`) | 211 | 1.7x | 46 | 1.2x |
| Gleam, default BEAM | 995 | 7.9x | 306 | 8.1x |
| Gleam, `+SDio 2` | 1,281 | 10.1x | 306 | 8.1x |

- Zig and Rust stay level with C.
- Bun adds about 20%, and Go about 70% on the read request.
- Gleam's runs swung between a fast mode and a slow one with both settings: the
  read request ranged from 433 to 1,297 µs with the default BEAM and from 430 to
  1,296 µs with `+SDio 2`. Capping the dirty I/O threads helped on the earlier
  8168 Droplet (see the scans below) but not on this one.

## Concurrent mode

Each worker count ran for 5 seconds after a 1-second warm-up, 3 runs, medians.
With 2 vCPUs, 4 workers is oversubscribed.

### Read throughput (requests/sec, higher is better)

| Runner | 1 | 2 | 4 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: |
| C | 7,764 | 11,189 | 17,635 | 2.3x |
| Zig | 7,833 | 11,022 | 17,529 | 2.2x |
| Rust | 7,145 | 9,096 | 15,960 | 2.2x |
| Bun | 6,593 | 7,624 | 13,745 | 2.1x |
| Go | 4,683 | 6,096 | 6,080 | 1.3x |
| Gleam, default BEAM | 2,053 | 1,950 | 2,410 | 1.2x |
| Gleam, `+SDio 2` | 797 | 2,806 | 3,953 | 5.0x |

### Write throughput (requests/sec)

| Runner | 1 | 2 | 4 workers |
| --- | ---: | ---: | ---: |
| C | 25,800 | 32,489 | 32,273 |
| Zig | 25,808 | 32,039 | 32,573 |
| Rust | 23,871 | 29,910 | 30,131 |
| Bun | 21,821 | 26,129 | 24,473 |
| Go | 20,634 | 20,916 | 18,949 |
| Gleam, default BEAM | 9,497 | 5,746 | 5,959 |
| Gleam, `+SDio 2` | 9,200 | 6,020 | 0 (12 failed requests) |

### Mixed throughput (every tenth request writes, requests/sec)

| Runner | 1 | 2 | 4 workers |
| --- | ---: | ---: | ---: |
| C | 10,681 | 8,367 | 15,662 |
| Zig | 10,569 | 8,322 | 15,774 |
| Rust | 9,717 | 7,566 | 14,283 |
| Bun | 8,565 | 7,079 | 11,514 |
| Go | 5,671 | 6,799 | 5,711 |
| Gleam, default BEAM | 2,820 | 2,245 | 2,792 |
| Gleam, `+SDio 2` | 946 | 2,676 | 3,851 (5 failed requests) |

The full summary, including p99 latency tables, is in
[concurrent/summary.md](concurrent/summary.md).

### What the concurrent numbers say

- Two workers use only about two thirds of the two vCPUs on reads, in every
  native runner and Bun, while four workers keep both busy. The 4-vCPU Droplet
  on this CPU scaled cleanly at 2 workers, so this most likely comes from how a
  2-vCPU Droplet's vCPUs map to physical cores, such as two hyperthreads of one
  core.
- Zig matches C. At 2 workers, Rust reaches 81 to 92% of C's throughput and
  Bun 68 to 85%.
- Go's reads stop at about 6,100 requests per second. Its writes hold at 60 to
  65% of C, and its longest single write wait stayed under 150 ms, against 1.1
  to 1.6 seconds for C, Zig, Rust and Bun at 4 workers. That's SQLite's busy
  timeout starving writers.
- Gleam with `+SDio 2` stalled with 4 writers: waiting writers held both dirty
  I/O threads, so the writer holding the lock couldn't commit until the
  5-second busy timeouts expired. This is the hazard described in the
  top-level README's Gleam caveats.

## Earlier scans on another 8168 Droplet

These ran on the earlier 2-vCPU 8168 Droplet, which was later resized for the
4-vCPU report. They compare settings within that one machine.

### Gleam dirty I/O scheduler scan

A scan with an earlier build of the Gleam runner:
statements cached, but `BEGIN` and `COMMIT` not yet cached, 3,000 requests per
run. The read request, one value per run:

| BEAM setting | Read request (µs) |
| --- | --- |
| Default (10 dirty I/O threads) | 1,286, 423, 429 |
| Busy-waiting off (`+sbwt none +sbwtdcpu none +sbwtdio none`) | 1,439, 1,441, 1,398 |
| `+SDio 1` | 432, 419, 432 |
| `+SDio 2` (one per vCPU) | 435, 425, 423, 425 |
| `+SDio 4` | 1,271, 416, 1,289, 1,286 |
| `+sbt db` (scheduler pinning) | 429, 584, 1,277 |
| `+S 1 +SDio 1 +SDcpu 1` | 1,269, 1,267, 1,269 |

More dirty I/O threads than vCPUs gives a fast or slow run depending on whether a
spinning thread catches each handoff. Turning busy-waiting off makes every run
slow, so the spinning is what produces the fast runs. On that Droplet, one
dirty I/O thread per vCPU kept runs fast and consistent; the full run above, on
another 8168 Droplet, didn't benefit. See the top-level README before applying
this to an app with several writer connections.

### esqlite's `-Os` build

`esqlite` compiles its bundled SQLite with `-Os`. Rebuilding it with the same
flags but `-O2`, then running Gleam with `+SDio 2` (10,000 requests, 3 runs
each, µs per request):

| esqlite build | Read request | Update |
| --- | --- | --- |
| `-Os` (as shipped) | 1,016, 1,270, 462 | 120, 346, 112 |
| `-O2` | 383, 384, 1,245 | 102, 100, 299 |

In fast runs, `-O2` cut the read request by about 17% and the update by about
12%. It didn't fix the slow runs: one `-O2` run still took 1,245 µs.

## Raw data

- [sequential/](sequential/): per-run CSVs, `metadata.txt` and `summary.md`.
- [concurrent/](concurrent/): the same for concurrent mode.
