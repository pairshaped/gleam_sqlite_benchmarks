# Concurrent Benchmark Summary

Each worker has its own connection and runs the workload for the measured
duration. Values are medians across 3 run(s). Throughput is total
requests per second across all workers; latencies are per request in µs.

## `read`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: |
| c | 7,764 | 11,189 | 17,635 | 2.3x |
| rust | 7,145 | 9,096 | 15,960 | 2.2x |
| zig | 7,833 | 11,022 | 17,529 | 2.2x |
| go | 4,683 | 6,096 | 6,080 | 1.3x |
| bun | 6,593 | 7,624 | 13,745 | 2.1x |
| gleam_sqlite | 2,053 | 1,950 | 2,410 | 1.2x |
| gleam_sqlite_sdio | 797 | 2,806 | 3,953 | 5.0x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| c | 191 | 246 | 4,134 |
| rust | 198 | 296 | 4,148 |
| zig | 179 | 252 | 4,134 |
| go | 277 | 373 | 7,679 |
| bun | 240 | 385 | 4,188 |
| gleam_sqlite | 589 | 1,394 | 2,343 |
| gleam_sqlite_sdio | 1,485 | 985 | 1,752 |


## `write`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: |
| c | 25,800 | 32,489 | 32,273 | 1.3x |
| rust | 23,871 | 29,910 | 30,131 | 1.3x |
| zig | 25,808 | 32,039 | 32,573 | 1.3x |
| go | 20,634 | 20,916 | 18,949 | 1.0x |
| bun | 21,821 | 26,129 | 24,473 | 1.2x |
| gleam_sqlite | 9,497 | 5,746 | 5,959 | 1.0x |
| gleam_sqlite_sdio | 9,200 | 6,020 | 0 | 1.0x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| c | 36 | 79 | 94 |
| rust | 41 | 106 | 111 |
| zig | 36 | 88 | 82 |
| go | 61 | 1,198 | 4,931 |
| bun | 51 | 197 | 1,149 |
| gleam_sqlite | 130 | 4,252 | 7,199 |
| gleam_sqlite_sdio | 130 | 4,594 | 5,013,234 |

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
| c | 73,144 | 106,558 | 1,340,174 |
| rust | 114,708 | 94,280 | 1,439,367 |
| zig | 65,183 | 72,620 | 1,135,511 |
| go | 62,981 | 69,568 | 140,021 |
| bun | 117,926 | 280,004 | 1,637,275 |
| gleam_sqlite | 99,015 | 87,791 | 629,439 |
| gleam_sqlite_sdio | 24,450 | 79,105 | 5,014,668 |


## `mixed`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: |
| c | 10,681 | 8,367 | 15,662 | 1.5x |
| rust | 9,717 | 7,566 | 14,283 | 1.5x |
| zig | 10,569 | 8,322 | 15,774 | 1.5x |
| go | 5,671 | 6,799 | 5,711 | 1.2x |
| bun | 8,565 | 7,079 | 11,514 | 1.3x |
| gleam_sqlite | 2,820 | 2,245 | 2,792 | 1.0x |
| gleam_sqlite_sdio | 946 | 2,676 | 3,851 | 4.1x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| c | 155 | 3,867 | 2,992 |
| rust | 169 | 4,058 | 3,154 |
| zig | 157 | 3,879 | 2,973 |
| go | 256 | 435 | 8,938 |
| bun | 196 | 3,757 | 3,698 |
| gleam_sqlite | 454 | 1,350 | 2,332 |
| gleam_sqlite_sdio | 1,254 | 2,322 | 2,094 |

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

