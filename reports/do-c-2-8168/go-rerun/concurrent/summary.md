# Concurrent Benchmark Summary

Each worker has its own connection and runs the workload for the measured
duration. Values are medians across 3 run(s). Throughput is total
requests per second across all workers; latencies are per request in µs.

## `read`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: |
| c | 8,396 | 11,320 | 17,801 | 2.1x |
| go | 4,441 | 4,712 | 6,049 | 1.4x |
| go_cgo | 6,920 | 7,262 | 13,230 | 1.9x |
| go_ncruces | 5,021 | 6,047 | 6,010 | 1.2x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| c | 172 | 243 | 4,135 |
| go | 445 | 2,685 | 15,373 |
| go_cgo | 277 | 2,264 | 4,923 |
| go_ncruces | 276 | 386 | 8,044 |


## `write`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: |
| c | 23,400 | 35,452 | 36,085 | 1.5x |
| go | 15,929 | 13,267 | 12,477 | 1.0x |
| go_cgo | 20,400 | 24,369 | 25,219 | 1.2x |
| go_ncruces | 20,400 | 19,356 | 19,770 | 1.0x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| c | 35 | 63 | 64 |
| go | 98 | 3,100 | 3,974 |
| go_cgo | 56 | 402 | 188 |
| go_ncruces | 63 | 1,306 | 4,102 |

### Max latency (µs): the longest any single write waited

| Suite | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| c | 144,126 | 126,121 | 1,655,716 |
| go | 45,571 | 153,698 | 1,632,693 |
| go_cgo | 157,467 | 176,286 | 1,133,668 |
| go_ncruces | 105,841 | 107,423 | 121,173 |


## `mixed`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: |
| c | 11,205 | 8,552 | 15,667 | 1.4x |
| go | 5,299 | 5,157 | 5,441 | 1.0x |
| go_cgo | 8,902 | 6,078 | 9,199 | 1.0x |
| go_ncruces | 6,033 | 6,924 | 5,566 | 1.1x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers |
| --- | ---: | ---: | ---: |
| c | 143 | 3,608 | 3,017 |
| go | 411 | 2,670 | 14,713 |
| go_cgo | 244 | 3,395 | 5,206 |
| go_ncruces | 256 | 403 | 9,048 |

