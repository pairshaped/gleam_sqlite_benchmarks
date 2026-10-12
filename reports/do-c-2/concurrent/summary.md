# Concurrent Benchmark Summary

Each worker has its own connection and runs the workload for the measured
duration. Values are medians across 3 run(s). Throughput is total
requests per second across all workers; latencies are per request in µs.

## `read`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: |
| c | 8,505 | 11,370 | 17,759 | 2.1x |
| rust | 8,017 | 9,132 | 16,097 | 2.0x |
| zig | 8,648 | 11,232 | 17,656 | 2.0x |
| go | 4,588 | 4,774 | 6,198 | 1.4x |
| bun | 7,285 | 7,732 | 13,594 | 1.9x |
| gleam_sqlite | 754 | 1,099 | 2,474 | 3.3x |
| gleam_sqlite_sdio | 2,124 | 2,887 | 4,080 | 1.9x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| c | 173 | 242 | 4,134 |
| rust | 198 | 298 | 4,149 |
| zig | 170 | 249 | 4,135 |
| go | 437 | 2,699 | 15,034 |
| bun | 226 | 379 | 4,223 |
| gleam_sqlite | 1,495 | 2,197 | 2,250 |
| gleam_sqlite_sdio | 588 | 992 | 1,592 |


## `write`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: |
| c | 24,600 | 36,252 | 36,161 | 1.5x |
| rust | 24,248 | 31,110 | 32,615 | 1.3x |
| zig | 25,000 | 35,232 | 35,622 | 1.4x |
| go | 15,336 | 13,342 | 13,150 | 1.0x |
| bun | 22,310 | 28,063 | 27,071 | 1.3x |
| gleam_sqlite | 3,230 | 2,076 | 2,177 | 1.0x |
| gleam_sqlite_sdio | 9,408 | 6,104 | 0 | 1.0x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| c | 35 | 66 | 61 |
| rust | 38 | 85 | 82 |
| zig | 34 | 65 | 71 |
| go | 98 | 3,115 | 3,982 |
| bun | 53 | 137 | 181 |
| gleam_sqlite | 357 | 5,628 | 18,784 |
| gleam_sqlite_sdio | 133 | 4,168 | 5,011,656 |

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
| c | 133,091 | 152,508 | 1,839,984 |
| rust | 105,011 | 134,030 | 1,437,530 |
| zig | 176,200 | 160,884 | 1,938,375 |
| go | 125,042 | 121,519 | 1,034,357 |
| bun | 112,978 | 96,735 | 1,847,383 |
| gleam_sqlite | 146,207 | 86,913 | 634,764 |
| gleam_sqlite_sdio | 62,290 | 128,927 | 5,017,982 |


## `mixed`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: |
| c | 11,513 | 8,741 | 15,688 | 1.4x |
| rust | 11,045 | 7,987 | 14,620 | 1.3x |
| zig | 11,507 | 8,662 | 15,933 | 1.4x |
| go | 5,481 | 5,321 | 5,390 | 1.0x |
| bun | 9,416 | 7,422 | 11,452 | 1.2x |
| gleam_sqlite | 948 | 1,204 | 2,869 | 3.0x |
| gleam_sqlite_sdio | 2,829 | 3,920 | 1,459 | 1.4x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| c | 144 | 3,712 | 3,043 |
| rust | 155 | 3,620 | 3,089 |
| zig | 145 | 3,680 | 2,986 |
| go | 391 | 2,445 | 13,601 |
| bun | 189 | 3,444 | 3,837 |
| gleam_sqlite | 1,273 | 2,222 | 2,259 |
| gleam_sqlite_sdio | 468 | 964 | 2,536 |

### Errors (failed requests, summed across runs)

| Suite | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| c | 0 | 0 | 0 |
| rust | 0 | 0 | 0 |
| zig | 0 | 0 | 0 |
| go | 0 | 0 | 0 |
| bun | 0 | 0 | 0 |
| gleam_sqlite | 0 | 0 | 0 |
| gleam_sqlite_sdio | 0 | 0 | 5 |

