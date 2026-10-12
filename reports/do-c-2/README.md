# DigitalOcean CPU-Optimized, 2 vCPU

## Machine

- Plan: DigitalOcean CPU-Optimized, Regular Intel, `c-2` (2 dedicated vCPUs,
  4 GB RAM), NYC1
- CPU: Intel Xeon Platinum 8168 @ 2.70 GHz, 1 thread per vCPU as reported to the
  guest
- OS: Debian 13.7, Linux 6.12, x86_64
- Background services and timers stopped for the concurrent run (see the top-level
  README); the sequential run had them running, and none fired during it

## Toolchains

All from `flake.nix`: SQLite 3.51.0 (C, Zig, Rust), Rust 1.99.0 with
rusqlite 0.40.2, Zig 0.16.0, Go 1.26.8 with ncruces/go-sqlite3 0.35.6 (its own
SQLite 3.53.4), Bun 1.4.3 (its embedded SQLite is also 3.51.0), Gleam 1.19.2 on
Erlang/OTP 28 with esqlite 0.9.0 (its bundled SQLite is 3.50.4).

## Sequential mode

10,000 requests per case, 5 runs, medians. Microseconds per request; lower is
better.

| Runner | Read request | vs C | Update | vs C |
| --- | ---: | ---: | ---: | ---: |
| C | 114 | 1.0x | 40 | 1.0x |
| Zig | 116 | 1.0x | 38 | 1.0x |
| Rust (`rusqlite`) | 123 | 1.1x | 43 | 1.1x |
| Bun | 145 | 1.3x | 51 | 1.3x |
| Go (`ncruces/go-sqlite3`) | 195 | 1.7x | 47 | 1.2x |
| Gleam, default BEAM | 1,147 | 10.0x | 115 | 2.9x |
| Gleam, `+SDio 2` | 432 | 3.8x | 125 | 3.1x |

The spread across runs was tight for every runner except Gleam. On the read
request, Gleam's five runs ranged from 416 to 1,291 µs with the default BEAM,
and from 426 to 1,284 µs with `+SDio 2`: the tuned setting made the fast mode
the usual one, but one of its five runs still hit the slow mode.

What the numbers say:

- Zig and Rust add almost nothing to C. Their gap is within the run-to-run
  spread on the update and about 8% on the read request.
- Bun adds about 30%, the cost of crossing from JavaScript into native code and
  building JavaScript values for each row.
- Go adds about 70% to the read request and 20% to the update. Its SQLite is
  compiled to Wasm and translated to Go, which runs slower than native code,
  but it avoids cgo, whose fixed cost per call made the other Go libraries
  slower still.
- Gleam's read request is dominated by dirty I/O scheduler handoffs. `esqlite`
  runs each SQLite call on a dirty I/O thread, and each handoff to one of the
  BEAM's 10 dirty I/O threads is slow on a 2-vCPU VM. Even the tuned run is
  3.8x C, because every query still makes two thread handoffs.

### Gleam dirty I/O scheduler scan

A separate scan on the same Droplet, with an earlier build of the Gleam runner:
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
slow, so the spinning is what produces the fast runs. One dirty I/O thread per
vCPU keeps runs fast and consistent. See the top-level README before applying
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

## Concurrent mode

Each worker count ran for 5 seconds after a 1-second warm-up, 3 runs, medians.
Background services and timers were stopped. With 2 vCPUs, 4 workers is
oversubscribed.

### Read throughput (requests/sec, higher is better)

| Runner | 1 worker | 2 workers | 4 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: |
| C | 8,505 | 11,370 | 17,759 | 2.1x |
| Zig | 8,648 | 11,232 | 17,656 | 2.0x |
| Rust | 8,017 | 9,132 | 16,097 | 2.0x |
| Bun | 7,285 | 7,732 | 13,594 | 1.9x |
| Go | 5,021 | 6,047 | 6,010 | 1.2x |
| Gleam, default BEAM | 754 | 1,099 | 2,474 | 3.3x |
| Gleam, `+SDio 2` | 2,124 | 2,887 | 4,080 | 1.9x |

### Write throughput (requests/sec)

| Runner | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| C | 24,600 | 36,252 | 36,161 |
| Zig | 25,000 | 35,232 | 35,622 |
| Rust | 24,248 | 31,110 | 32,615 |
| Bun | 22,310 | 28,063 | 27,071 |
| Go | 20,400 | 19,356 | 19,770 |
| Gleam, default BEAM | 3,230 | 2,076 | 2,177 |
| Gleam, `+SDio 2` | 9,408 | 6,104 | 0 (12 failed requests) |

The longest single write wait at 4 workers was 1.0 to 1.9 seconds in every
native runner and in Bun. With one writer it was still 60 to 180 ms, which is
SQLite's automatic WAL checkpoint flushing to disk rather than lock contention.

### Mixed throughput (every tenth request writes, requests/sec)

| Runner | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| C | 11,513 | 8,741 | 15,688 |
| Zig | 11,507 | 8,662 | 15,933 |
| Rust | 11,045 | 7,987 | 14,620 |
| Bun | 9,416 | 7,422 | 11,452 |
| Go | 6,033 | 6,924 | 5,566 |
| Gleam, default BEAM | 948 | 1,204 | 2,869 |
| Gleam, `+SDio 2` | 2,829 | 3,920 | 1,459 (5 failed requests) |

The full summary, including p99 latency tables, is in
[concurrent/summary.md](concurrent/summary.md).

### What the concurrent numbers say

- C, Zig, Rust and Bun scale alike. At 4 workers, Rust reached about 90% of C's
  throughput on every workload, and Bun about 75%. Bun's gap stays roughly
  constant as workers are added instead of widening.
- Two workers use only about two thirds of the two vCPUs on reads, in every
  native runner and Bun, while four workers keep both busy at single-thread
  speed. A likely cause is that each of the request's 26 queries runs in its
  own automatic read transaction, and each one takes a lock on SQLite's shared
  WAL index, so two workers spend time waiting on each other. That's untested;
  wrapping a request's reads in one transaction would test it.
- Mixed throughput drops from 1 worker to 2 in every native runner and Bun. A
  writer that finds the lock taken sleeps in SQLite's busy timeout, leaving its
  CPU idle; with 4 workers, another worker uses that CPU.
- Go's reads stop scaling at about 6,000 requests per second, around a third of
  C's at 4 workers. Its writes hold steady at about 55% of C's, and it never
  starved a writer: the longest single write wait at 4 workers was about 120 ms,
  against over a second for every other runner.
- Gleam with the default BEAM never failed but stayed far behind. With
  `+SDio 2`, 4 writers stalled: waiting writers held both dirty I/O threads, so
  the writer holding the lock couldn't commit until the 5-second busy timeouts
  expired. This is the hazard described in the top-level README's Gleam caveats.
- Bun's numbers come from worker threads that each run only their own
  requests. In a server, a write waiting on the lock would block every request
  on its thread; see the Bun caveat in the top-level README.

## Raw data

- [sequential/](sequential/): per-run CSVs, `metadata.txt` and `summary.md` for
  sequential mode. The run also produced Gleam probe rows, since removed from
  the runner; they were stripped from these CSVs.
- [concurrent/](concurrent/): the same for concurrent mode.
- [go-rerun/](go-rerun/): the Go rows above, from a rerun after the Go runner
  switched libraries, with C repeated for reference and the two Go variants
  compared in [go/README.md](../../go/README.md).

The concurrent run used the code in the commit that adds this report. The
sequential run used an earlier working tree with the same sequential request
code; it differed only in the Gleam probes, since removed, and in setting the
busy timeout after `journal_mode`, which makes no difference with one
connection.
