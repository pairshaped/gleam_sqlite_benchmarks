# DigitalOcean CPU-Optimized, 2 vCPU, Xeon Platinum 8280

## Machine

- Plan: DigitalOcean CPU-Optimized, Regular Intel, `c-2` (2 dedicated vCPUs,
  4 GB RAM)
- CPU: Intel Xeon Platinum 8280 @ 2.70 GHz
- OS: Debian 13.7, Linux 6.12, x86_64
- Background services and timers stopped (see the top-level README)

This Droplet ran SQLite about twice as fast as the same plan on a Xeon Platinum
8168 ([2-vCPU](../do-c-2-8168/README.md), [4-vCPU](../do-c-4-8168/README.md)):
C took 56 µs per read request here against 114 µs on the 8168, at the same
clock speed. Compare reports across CPUs by each runner's ratio to C, not by
absolute numbers.

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
| C | 56 | 1.0x | 14 | 1.0x |
| Zig | 58 | 1.0x | 12 | 0.9x |
| Rust (`rusqlite`) | 62 | 1.1x | 14 | 1.1x |
| Bun | 83 | 1.5x | 20 | 1.5x |
| Go (`ncruces/go-sqlite3`) | 122 | 2.2x | 22 | 1.6x |
| Gleam, default BEAM | 229 | 4.1x | 62 | 4.4x |
| Gleam, `+SDio 2` | 290 | 5.2x | 59 | 4.3x |

- Zig and Rust stay within about 10% of C.
- Bun and Go cost relatively more than on the slower 8168 machines, though
  their absolute numbers are faster. Their overhead per call is roughly fixed,
  so it's a bigger share when SQLite's own work takes less time.
- Gleam was inconsistent again on the read request: five runs ranged from 228
  to 676 µs with the default BEAM and from 229 to 492 µs with `+SDio 2`. Capping
  the dirty I/O threads didn't help on this machine, unlike on the
  [8168](../do-c-2-8168/README.md).

## Concurrent mode

Each worker count ran for 5 seconds after a 1-second warm-up, 3 runs, medians.
With 2 vCPUs, 4 workers is oversubscribed.

### Read throughput (requests/sec, higher is better)

| Runner | 1 | 2 | 4 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: |
| C | 17,404 | 18,485 | 28,892 | 1.7x |
| Zig | 17,716 | 18,106 | 28,977 | 1.6x |
| Rust | 15,949 | 14,801 | 25,252 | 1.6x |
| Bun | 13,215 | 12,539 | 19,672 | 1.5x |
| Go | 8,206 | 8,838 | 8,803 | 1.1x |
| Gleam, default BEAM | 1,456 | 2,016 | 4,422 | 3.0x |
| Gleam, `+SDio 2` | 1,418 | 4,806 | 6,656 | 4.7x |

### Write throughput (requests/sec)

| Runner | 1 | 2 | 4 workers |
| --- | ---: | ---: | ---: |
| C | 80,937 | 78,535 | 78,587 |
| Zig | 79,027 | 78,309 | 81,118 |
| Rust | 71,600 | 71,609 | 70,987 |
| Bun | 56,753 | 55,420 | 54,956 |
| Go | 43,560 | 43,023 | 43,994 |
| Gleam, default BEAM | 6,057 | 5,615 | 5,862 |
| Gleam, `+SDio 2` | 16,284 | 16,216 | 0 (12 failed requests) |

### Mixed throughput (every tenth request writes, requests/sec)

| Runner | 1 | 2 | 4 workers |
| --- | ---: | ---: | ---: |
| C | 20,927 | 17,318 | 25,969 |
| Zig | 21,961 | 18,307 | 27,325 |
| Rust | 18,034 | 14,810 | 24,723 |
| Bun | 16,633 | 13,367 | 18,412 |
| Go | 9,569 | 9,766 | 9,461 |
| Gleam, default BEAM | 1,589 | 2,163 | 4,678 |
| Gleam, `+SDio 2` | 4,402 | 2,922 | 5,756 (2 failed requests) |

The full summary, including p99 latency tables, is in
[concurrent/summary.md](concurrent/summary.md).

### What the concurrent numbers say

- Two workers barely beat one on reads, in every native runner and Bun, while
  four workers reach about 1.7x. The 4-vCPU Droplet scaled cleanly at 2 workers,
  so this most likely comes from how a 2-vCPU Droplet's vCPUs map to physical
  cores, such as two hyperthreads of one core.
- Write throughput doesn't grow with workers at all, because SQLite allows one
  writer at a time. With one writer, the longest wait was under 20 ms; with two
  or more, one write waited about 1 to 2 seconds while the rest took
  microseconds. That's SQLite's busy timeout starving writers.
- Zig matches C, Rust reaches 80 to 95% of C's throughput, and Bun about 70%.
- Go stays flat at about 8,800 reads per second regardless of workers, around
  30% of C at 4 workers. Its writes hold at about 55% of C, and its longest
  write wait stayed under 100 ms.
- Gleam with `+SDio 2` stalled with 4 writers: waiting writers held both dirty
  I/O threads, so the writer holding the lock couldn't commit until the
  5-second busy timeouts expired. This is the hazard described in the
  top-level README's Gleam caveats.

## Raw data

- [sequential/](sequential/): per-run CSVs, `metadata.txt` and `summary.md`.
- [concurrent/](concurrent/): the same for concurrent mode.
