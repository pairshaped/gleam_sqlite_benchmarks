# Concurrent Benchmark Summary

Each worker has its own connection and runs the workload for the measured
duration. Values are medians across 3 run(s). Throughput is total
requests per second across all workers; latencies are per request in µs.

## `read`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: |
| c | 17,404 | 18,485 | 28,892 | 1.7x |
| rust | 15,949 | 14,801 | 25,252 | 1.6x |
| zig | 17,716 | 18,106 | 28,977 | 1.6x |
| go | 8,206 | 8,838 | 8,803 | 1.1x |
| bun | 13,215 | 12,539 | 19,672 | 1.5x |
| gleam_sqlite | 1,456 | 2,016 | 4,422 | 3.0x |
| gleam_sqlite_sdio | 1,418 | 4,806 | 6,656 | 4.7x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| c | 78 | 157 | 4,075 |
| rust | 82 | 185 | 4,090 |
| zig | 74 | 156 | 4,075 |
| go | 167 | 285 | 5,164 |
| bun | 125 | 218 | 4,128 |
| gleam_sqlite | 874 | 1,266 | 1,290 |
| gleam_sqlite_sdio | 867 | 565 | 887 |


## `write`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: |
| c | 80,937 | 78,535 | 78,587 | 1.0x |
| rust | 71,600 | 71,609 | 70,987 | 1.0x |
| zig | 79,027 | 78,309 | 81,118 | 1.0x |
| go | 43,560 | 43,023 | 43,994 | 1.0x |
| bun | 56,753 | 55,420 | 54,956 | 1.0x |
| gleam_sqlite | 6,057 | 5,615 | 5,862 | 1.0x |
| gleam_sqlite_sdio | 16,284 | 16,216 | 0 | 1.0x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| c | 21 | 22 | 25 |
| rust | 22 | 24 | 28 |
| zig | 23 | 24 | 22 |
| go | 38 | 53 | 102 |
| bun | 32 | 34 | 37 |
| gleam_sqlite | 218 | 216 | 224 |
| gleam_sqlite_sdio | 81 | 86 | 5,009,548 |

### Errors (failed requests, summed across runs)

| Suite | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| c | 0 | 0 | 0 |
| rust | 0 | 0 | 0 |
| zig | 0 | 0 | 0 |
| go | 0 | 0 | 0 |
| bun | 0 | 0 | 0 |
| gleam_sqlite | 0 | 0 | 0 |
| gleam_sqlite_sdio | 0 | 0 | 12 |

### Max latency (µs): the longest any single write waited

| Suite | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| c | 5,400 | 1,230,271 | 1,330,023 |
| rust | 17,720 | 1,130,102 | 1,334,847 |
| zig | 4,352 | 929,790 | 1,934,319 |
| go | 10,007 | 36,118 | 99,083 |
| bun | 3,584 | 929,844 | 1,137,831 |
| gleam_sqlite | 8,686 | 1,630,306 | 1,530,025 |
| gleam_sqlite_sdio | 6,518 | 1,329,985 | 5,009,548 |


## `mixed`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: |
| c | 20,927 | 17,318 | 25,969 | 1.2x |
| rust | 18,034 | 14,810 | 24,723 | 1.4x |
| zig | 21,961 | 18,307 | 27,325 | 1.2x |
| go | 9,569 | 9,766 | 9,461 | 1.0x |
| bun | 16,633 | 13,367 | 18,412 | 1.1x |
| gleam_sqlite | 1,589 | 2,163 | 4,678 | 2.9x |
| gleam_sqlite_sdio | 4,402 | 2,922 | 5,756 | 1.3x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| c | 72 | 200 | 1,272 |
| rust | 77 | 216 | 1,269 |
| zig | 68 | 198 | 1,237 |
| go | 150 | 284 | 4,989 |
| bun | 110 | 238 | 1,970 |
| gleam_sqlite | 798 | 1,328 | 1,352 |
| gleam_sqlite_sdio | 283 | 1,290 | 1,109 |

### Errors (failed requests, summed across runs)

| Suite | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| c | 0 | 0 | 0 |
| rust | 0 | 0 | 0 |
| zig | 0 | 0 | 0 |
| go | 0 | 0 | 0 |
| bun | 0 | 0 | 0 |
| gleam_sqlite | 0 | 0 | 0 |
| gleam_sqlite_sdio | 0 | 0 | 2 |

