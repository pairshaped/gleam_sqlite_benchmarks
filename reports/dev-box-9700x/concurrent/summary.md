# Concurrent Benchmark Summary

Each worker has its own connection and runs the workload for the measured
duration. Values are medians across 3 run(s). Throughput is total
requests per second across all workers; latencies are per request in µs.

## `read`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | 16 workers | 32 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| c | 43,576 | 68,468 | 193,063 | 202,618 | 168,540 | 145,148 | 4.6x |
| rust | 38,315 | 60,800 | 170,117 | 192,688 | 166,203 | 143,574 | 5.0x |
| zig | 43,710 | 68,020 | 192,850 | 202,954 | 168,268 | 144,338 | 4.6x |
| go | 22,554 | 43,466 | 78,696 | 80,164 | 56,512 | 36,061 | 3.6x |
| bun | 35,640 | 59,938 | 163,623 | 202,105 | 174,824 | 177,849 | 5.7x |
| gleam_sqlite | 14,797 | 21,290 | 21,659 | 25,709 | 25,759 | 25,751 | 1.7x |
| gleam_sqlite_sdio | 12,996 | 20,980 | 21,859 | 25,987 | 25,720 | 26,403 | 2.0x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | 16 workers | 32 workers |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | 24 | 46 | 32 | 67 | 149 | 328 |
| rust | 27 | 48 | 35 | 68 | 154 | 333 |
| zig | 24 | 47 | 32 | 67 | 154 | 328 |
| go | 45 | 48 | 54 | 107 | 292 | 7,489 |
| bun | 30 | 50 | 38 | 62 | 165 | 348 |
| gleam_sqlite | 70 | 130 | 229 | 357 | 787 | 1,414 |
| gleam_sqlite_sdio | 166 | 130 | 227 | 354 | 780 | 1,511 |


## `write`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | 16 workers | 32 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| c | 42,000 | 204,145 | 197,640 | 194,102 | 193,066 | 199,187 | 4.9x |
| rust | 40,107 | 179,906 | 168,059 | 168,215 | 168,734 | 169,510 | 4.5x |
| zig | 42,200 | 202,047 | 196,754 | 193,871 | 201,392 | 193,854 | 4.8x |
| go | 54,593 | 106,948 | 106,876 | 106,073 | 106,139 | 103,874 | 2.0x |
| bun | 39,252 | 135,791 | 138,181 | 134,254 | 131,761 | 131,924 | 3.5x |
| gleam_sqlite | 25,075 | 48,797 | 48,324 | 48,575 | 1 | 0 | 1.9x |
| gleam_sqlite_sdio | 25,013 | 48,674 | 49,369 | 49,045 | 51,778 | 3 | 2.1x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | 16 workers | 32 workers |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | 9 | 6 | 9 | 10 | 10 | 7 |
| rust | 10 | 6 | 11 | 11 | 11 | 11 |
| zig | 9 | 7 | 9 | 10 | 7 | 10 |
| go | 9 | 18 | 18 | 20 | 46 | 8,788 |
| bun | 13 | 13 | 13 | 14 | 14 | 15 |
| gleam_sqlite | 34 | 30 | 31 | 31 | 5,057,491 | 15,100,788 |
| gleam_sqlite_sdio | 34 | 30 | 30 | 32 | 30 | 6,052,985 |

### Errors (failed requests, summed across runs)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | 16 workers | 32 workers |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | 0 | 0 | 0 | 2 | 2 | 27 |
| rust | 0 | 0 | 0 | 0 | 1 | 15 |
| zig | 0 | 0 | 1 | 3 | 8 | 15 |
| go | 0 | 0 | 0 | 0 | 0 | 0 |
| bun | 0 | 0 | 3 | 4 | 3 | 16 |
| gleam_sqlite | 0 | 0 | 0 | 0 | 58 | 120 |
| gleam_sqlite_sdio | 0 | 0 | 0 | 0 | 0 | 96 |

### Max latency (µs): the longest any single write waited

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | 16 workers | 32 workers |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | 31,838 | 1,097,292 | 3,247,992 | 3,130,160 | 4,230,902 | 4,531,310 |
| rust | 32,253 | 1,250,521 | 2,730,162 | 4,231,224 | 3,030,290 | 4,330,645 |
| zig | 31,855 | 1,199,531 | 2,930,236 | 3,630,721 | 4,331,407 | 4,431,396 |
| go | 30,401 | 33,470 | 85,402 | 110,948 | 131,088 | 147,743 |
| bun | 21,279 | 66,781 | 2,229,971 | 2,546,966 | 3,330,354 | 4,931,863 |
| gleam_sqlite | 24,727 | 27,062 | 1,729,353 | 2,229,358 | 5,071,279 | 15,100,788 |
| gleam_sqlite_sdio | 32,134 | 26,621 | 1,329,192 | 3,030,209 | 2,830,181 | 6,153,365 |


## `mixed`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | 16 workers | 32 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| c | 47,176 | 49,963 | 96,108 | 163,491 | 160,767 | 145,514 | 3.5x |
| rust | 41,853 | 43,621 | 81,832 | 145,120 | 158,607 | 142,870 | 3.8x |
| zig | 47,563 | 50,153 | 97,462 | 162,937 | 166,965 | 142,868 | 3.5x |
| go | 23,641 | 23,909 | 59,735 | 87,830 | 87,137 | 40,223 | 3.7x |
| bun | 38,280 | 39,835 | 74,108 | 130,011 | 156,478 | 140,963 | 4.1x |
| gleam_sqlite | 15,357 | 15,991 | 23,362 | 24,166 | 23 | 19 | 1.6x |
| gleam_sqlite_sdio | 15,529 | 16,039 | 23,196 | 24,092 | 24,935 | 37 | 1.6x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | 16 workers | 32 workers |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | 21 | 56 | 86 | 1,060 | 1,072 | 1,119 |
| rust | 24 | 65 | 95 | 1,062 | 1,074 | 1,135 |
| zig | 21 | 54 | 85 | 1,060 | 1,071 | 1,118 |
| go | 44 | 138 | 113 | 146 | 782 | 8,006 |
| bun | 28 | 74 | 115 | 1,067 | 1,081 | 3,145 |
| gleam_sqlite | 68 | 5,506 | 236 | 1,130 | 5,017,992 | 5,018,656 |
| gleam_sqlite_sdio | 67 | 5,508 | 237 | 1,135 | 3,275 | 5,030,806 |

### Errors (failed requests, summed across runs)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | 16 workers | 32 workers |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | 0 | 0 | 0 | 0 | 0 | 0 |
| rust | 0 | 0 | 0 | 0 | 0 | 0 |
| zig | 0 | 0 | 0 | 0 | 0 | 0 |
| go | 0 | 0 | 0 | 0 | 0 | 0 |
| bun | 0 | 0 | 0 | 0 | 0 | 0 |
| gleam_sqlite | 0 | 0 | 0 | 0 | 58 | 56 |
| gleam_sqlite_sdio | 0 | 0 | 0 | 0 | 0 | 95 |

