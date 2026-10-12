# Concurrent Benchmark Summary

Each worker has its own connection and runs the workload for the measured
duration. Values are medians across 3 run(s). Throughput is total
requests per second across all workers; latencies are per request in µs.

## `read`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: | ---: |
| c | 8,096 | 17,471 | 24,611 | 27,266 | 3.4x |
| rust | 7,838 | 13,367 | 21,296 | 25,164 | 3.2x |
| zig | 7,852 | 15,123 | 25,424 | 27,094 | 3.5x |
| go | 5,194 | 9,237 | 11,515 | 11,163 | 2.2x |
| bun | 7,048 | 11,354 | 18,872 | 22,124 | 3.1x |
| gleam_sqlite | 1,512 | 3,415 | 3,725 | 5,556 | 3.7x |
| gleam_sqlite_sdio | 1,191 | 3,207 | 4,877 | 6,198 | 5.2x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers |
| --- | ---: | ---: | ---: | ---: |
| c | 176 | 244 | 246 | 4,202 |
| rust | 190 | 316 | 284 | 4,355 |
| zig | 177 | 263 | 240 | 4,239 |
| go | 270 | 304 | 387 | 9,205 |
| bun | 208 | 332 | 333 | 5,553 |
| gleam_sqlite | 1,022 | 752 | 1,447 | 1,966 |
| gleam_sqlite_sdio | 1,193 | 1,206 | 1,129 | 1,569 |


## `write`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: | ---: |
| c | 22,624 | 36,379 | 36,749 | 36,654 | 1.6x |
| rust | 23,170 | 33,069 | 33,029 | 33,123 | 1.4x |
| zig | 25,431 | 36,581 | 36,641 | 35,268 | 1.4x |
| go | 21,313 | 22,919 | 21,458 | 21,076 | 1.1x |
| bun | 19,706 | 29,453 | 29,150 | 29,496 | 1.5x |
| gleam_sqlite | 9,574 | 7,702 | 8,330 | 8,137 | 1.0x |
| gleam_sqlite_sdio | 9,200 | 3,110 | 2,758 | 1 | 1.0x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers |
| --- | ---: | ---: | ---: | ---: |
| c | 35 | 50 | 50 | 52 |
| rust | 39 | 54 | 61 | 63 |
| zig | 35 | 49 | 49 | 53 |
| go | 55 | 136 | 5,173 | 11,363 |
| bun | 49 | 81 | 80 | 85 |
| gleam_sqlite | 116 | 4,848 | 5,955 | 7,872 |
| gleam_sqlite_sdio | 114 | 5,693 | 8,643 | 5,029,054 |

### Errors (failed requests, summed across runs)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers |
| --- | ---: | ---: | ---: | ---: |
| c | 0 | 0 | 0 | 0 |
| rust | 0 | 0 | 0 | 0 |
| zig | 0 | 0 | 0 | 0 |
| go | 0 | 0 | 0 | 0 |
| bun | 0 | 0 | 0 | 0 |
| gleam_sqlite | 0 | 0 | 0 | 0 |
| gleam_sqlite_sdio | 0 | 0 | 0 | 24 |

### Max latency (µs): the longest any single write waited

| Suite | 1 worker | 2 workers | 4 workers | 8 workers |
| --- | ---: | ---: | ---: | ---: |
| c | 64,481 | 113,591 | 1,758,136 | 3,142,229 |
| rust | 178,857 | 117,363 | 1,651,590 | 2,743,183 |
| zig | 76,786 | 253,993 | 2,776,029 | 3,039,533 |
| go | 93,514 | 170,428 | 121,544 | 157,353 |
| bun | 129,467 | 124,052 | 1,646,715 | 2,736,173 |
| gleam_sqlite | 52,803 | 106,043 | 930,365 | 1,743,446 |
| gleam_sqlite_sdio | 65,337 | 193,363 | 930,181 | 5,055,111 |


## `mixed`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: | ---: |
| c | 11,125 | 8,862 | 17,943 | 23,001 | 2.1x |
| rust | 10,395 | 7,966 | 14,044 | 20,849 | 2.0x |
| zig | 10,765 | 8,718 | 17,599 | 23,001 | 2.1x |
| go | 6,046 | 9,411 | 10,001 | 10,309 | 1.7x |
| bun | 9,168 | 8,140 | 12,756 | 17,642 | 1.9x |
| gleam_sqlite | 3,402 | 3,547 | 3,970 | 5,732 | 1.7x |
| gleam_sqlite_sdio | 3,405 | 2,455 | 4,366 | 6,152 | 1.8x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers |
| --- | ---: | ---: | ---: | ---: |
| c | 148 | 2,762 | 2,668 | 3,303 |
| rust | 160 | 2,896 | 2,823 | 3,340 |
| zig | 153 | 2,812 | 2,618 | 3,281 |
| go | 249 | 363 | 3,872 | 10,066 |
| bun | 188 | 2,933 | 3,110 | 3,767 |
| gleam_sqlite | 403 | 2,054 | 1,477 | 2,084 |
| gleam_sqlite_sdio | 411 | 1,134 | 1,418 | 3,272 |

