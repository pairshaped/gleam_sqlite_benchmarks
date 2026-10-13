# OVHcloud bare metal, AMD Ryzen 7 9700X

An OVHcloud dedicated server in Beauharnois (BHS), in the same configuration as
OVH's RISE-S plan. It is the first bare-metal report and the only one with
dedicated physical cores.

## Machine

- Hardware: AMD Ryzen 7 9700X (8 Zen 5 cores, 16 threads), 64 GB DDR5 (62 GB
  usable), two Samsung 512 GB NVMe drives in software RAID 1, BHS
- OS: NixOS 26.05, Linux 6.18, x86_64
- CPU frequency scaling left at the defaults (`amd-pstate-epp`, `powersave`
  governor, `balance_performance`), so cores ramp up under load rather than
  sitting at full boost
- Stopped for the run: the agent hub and its sessions, a Rails app and its
  PostgreSQL, `atop` and its process accounting, local HTTPS previews and two
  timers. Still running: SSH, Tailscale, Caddy (idle), journald, fail2ban and
  disk monitoring.

## Toolchains

All from `flake.nix` at `6c6299a`, the same toolchains as the earlier reports.
This is the first run after every runner started counting expired busy
timeouts as errors (see the top-level README).

## Sequential mode

10,000 requests per case, 5 runs, medians. Microseconds per request; lower is
better.

| Runner | Read request | vs C | Update | vs C |
| --- | ---: | ---: | ---: | ---: |
| C | 25 | 1.0x | 19 | 1.0x |
| Zig (`ReleaseSafe`) | 22 | 0.9x | 19 | 1.0x |
| Rust (`rusqlite`) | 25 | 1.0x | 20 | 1.1x |
| Bun | 28 | 1.1x | 21 | 1.1x |
| Go (`ncruces/go-sqlite3`) | 44 | 1.7x | 15 | 0.8x |
| Gleam, default BEAM | 65 | 2.6x | 33 | 1.7x |
| Gleam, `+SDio 16` | 65 | 2.6x | 33 | 1.7x |

- The read request takes 25 µs for C, against 111 µs on the OVHcloud VPS and
  56 µs on the DigitalOcean Platinum 8280: about 4.5 times faster than the VPS.
- The update transaction gains much less, 19 µs against the VPS's 23 µs. It
  commits a transaction, and its time is mostly SQLite's WAL bookkeeping and
  checkpoint flushes to disk rather than CPU work.
- Zig, Rust and Bun stay within about 10% of C, as everywhere. Gleam costs
  2.6 times C here, its lowest ratio on any machine: fast cores make the dirty
  I/O scheduler handoffs cheap.

## Concurrent mode

Each worker count ran for 5 seconds after a 1-second warm-up, 3 runs, medians.
With 16 threads, 32 workers is oversubscribed.

### Read throughput (requests/sec, higher is better)

| Runner | 1 | 2 | 4 | 8 | 16 | 32 workers |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| C | 43,576 | 68,468 | 193,063 | 202,618 | 168,540 | 145,148 |
| Zig | 43,710 | 68,020 | 192,850 | 202,954 | 168,268 | 144,338 |
| Rust | 38,315 | 60,800 | 170,117 | 192,688 | 166,203 | 143,574 |
| Bun | 35,640 | 59,938 | 163,623 | 202,105 | 174,824 | 177,849 |
| Go | 22,554 | 43,466 | 78,696 | 80,164 | 56,512 | 36,061 |
| Gleam, default BEAM | 14,797 | 21,290 | 21,659 | 25,709 | 25,759 | 25,751 |
| Gleam, `+SDio 16` | 12,996 | 20,980 | 21,859 | 25,987 | 25,720 | 26,403 |

### Write throughput (requests/sec)

| Runner | 1 | 2 | 4 | 8 | 16 | 32 workers |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| C | 42,000 | 204,145 | 197,640 | 194,102 | 193,066 | 199,187 |
| Zig | 42,200 | 202,047 | 196,754 | 193,871 | 201,392 | 193,854 |
| Rust | 40,107 | 179,906 | 168,059 | 168,215 | 168,734 | 169,510 |
| Bun | 39,252 | 135,791 | 138,181 | 134,254 | 131,761 | 131,924 |
| Go | 54,593 | 106,948 | 106,876 | 106,073 | 106,139 | 103,874 |
| Gleam, default BEAM | 25,075 | 48,797 | 48,324 | 48,575 | 1 | 0 |
| Gleam, `+SDio 16` | 25,013 | 48,674 | 49,369 | 49,045 | 51,778 | 3 |

### Failed writes (expired busy timeouts, summed across 3 runs)

| Runner | 1 | 2 | 4 | 8 | 16 | 32 workers |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| C | 0 | 0 | 0 | 2 | 2 | 27 |
| Zig | 0 | 0 | 1 | 3 | 8 | 15 |
| Rust | 0 | 0 | 0 | 0 | 1 | 15 |
| Bun | 0 | 0 | 3 | 4 | 3 | 16 |
| Go | 0 | 0 | 0 | 0 | 0 | 0 |
| Gleam, default BEAM | 0 | 0 | 0 | 0 | 58 | 120 |
| Gleam, `+SDio 16` | 0 | 0 | 0 | 0 | 0 | 96 |

### Mixed throughput (every tenth request writes, requests/sec)

| Runner | 1 | 2 | 4 | 8 | 16 | 32 workers |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| C | 47,176 | 49,963 | 96,108 | 163,491 | 160,767 | 145,514 |
| Zig | 47,563 | 50,153 | 97,462 | 162,937 | 166,965 | 142,868 |
| Rust | 41,853 | 43,621 | 81,832 | 145,120 | 158,607 | 142,870 |
| Bun | 38,280 | 39,835 | 74,108 | 130,011 | 156,478 | 140,963 |
| Go | 23,641 | 23,909 | 59,735 | 87,830 | 87,137 | 40,223 |
| Gleam, default BEAM | 15,357 | 15,991 | 23,362 | 24,166 | 23 | 19 |
| Gleam, `+SDio 16` | 15,529 | 16,039 | 23,196 | 24,092 | 24,935 | 37 |

The full summary, including p99 and maximum latency tables, is in
[concurrent/summary.md](concurrent/summary.md).

### What the concurrent numbers say

- Reads peak at about 203,000 requests per second for C and Zig at 8 workers,
  roughly 3.8 times the VPS's 53,600. Each request runs 26 queries, so that is
  over 5 million SQL statements per second. Rust reaches 95% of C and Bun
  matches it; Go plateaus near 80,000, and Gleam near 26,000.
- Going from 1 worker to 2 or 4 gains far more than the added cores explain,
  and writes jump from about 42,000 to 204,000 per second at 2 workers even
  though SQLite runs one writer at a time. A single busy thread probably runs
  at a lower clock under the default frequency scaling, so the 1-worker and
  sequential numbers likely understate this CPU's single-thread speed.
- Fast hardware makes writer starvation worse. The longest single write wait
  reached 1 to 5 seconds from 2 writers on for C, Zig and Rust, and from 4 for
  Bun. Some writes waited out the full 5-second busy timeout and failed: from
  4 writers on for Zig and Bun, 8 for C and 16 for Rust. On the slower VPS, no
  write in those runners ever failed. Go's
  `ncruces/go-sqlite3` again kept every write under 150 ms and never failed
  one. Sending writes through a single writer avoids this in any language.
- Gleam stalls at 32 writers with either setting, and with the default 10 dirty
  I/O threads it already stalls at 16. With `+SDio 16` it held up through 16
  writers, so on this many cores, matching dirty I/O threads to the thread
  count moved the stall point out rather than in.

## Raw data

- [sequential/](sequential/): per-run CSVs, `metadata.txt` and `summary.md`.
- [concurrent/](concurrent/): the same for concurrent mode.
- [lscpu.txt](lscpu.txt): the CPU, NixOS version and kernel.
