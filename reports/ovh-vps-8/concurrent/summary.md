# Concurrent Benchmark Summary

Each worker has its own connection and runs the workload for the measured
duration. Values are medians across 3 run(s). Throughput is total
requests per second across all workers; latencies are per request in µs.

## `read`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | 16 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | 8,622 | 14,042 | 37,781 | 53,612 | 47,623 | 6.2x |
| rust | 7,274 | 8,991 | 29,484 | 44,942 | 43,698 | 6.2x |
| zig | 8,202 | 14,384 | 37,558 | 48,179 | 39,425 | 5.9x |
| go | 4,742 | 8,306 | 15,505 | 25,607 | 21,556 | 5.4x |
| bun | 6,431 | 7,551 | 24,870 | 42,279 | 44,085 | 6.9x |
| gleam_sqlite | 2,979 | 3,737 | 5,657 | 6,742 | 7,821 | 2.6x |
| gleam_sqlite_sdio | 2,864 | 4,299 | 5,670 | 7,582 | 8,744 | 3.1x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | 16 workers |
| --- | ---: | ---: | ---: | ---: | ---: |
| c | 203 | 327 | 208 | 261 | 894 |
| rust | 224 | 393 | 264 | 286 | 1,081 |
| zig | 209 | 305 | 209 | 282 | 1,063 |
| go | 395 | 476 | 422 | 556 | 9,199 |
| bun | 269 | 524 | 333 | 394 | 1,979 |
| gleam_sqlite | 491 | 817 | 1,114 | 1,647 | 2,968 |
| gleam_sqlite_sdio | 528 | 684 | 994 | 1,371 | 2,577 |


## `write`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | 16 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | 42,462 | 39,207 | 39,154 | 40,923 | 38,830 | 1.0x |
| rust | 33,684 | 34,454 | 30,888 | 32,208 | 32,667 | 1.0x |
| zig | 36,851 | 38,689 | 38,388 | 39,575 | 29,964 | 1.1x |
| go | 23,455 | 23,731 | 21,064 | 21,876 | 21,864 | 1.0x |
| bun | 26,960 | 26,289 | 25,564 | 22,929 | 17,994 | 1.0x |
| gleam_sqlite | 11,166 | 10,506 | 10,794 | 11,018 | 1 | 1.0x |
| gleam_sqlite_sdio | 10,559 | 10,008 | 10,973 | 11,449 | 1 | 1.1x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | 16 workers |
| --- | ---: | ---: | ---: | ---: | ---: |
| c | 49 | 52 | 58 | 72 | 1,009 |
| rust | 53 | 53 | 66 | 138 | 1,181 |
| zig | 51 | 52 | 56 | 71 | 1,966 |
| go | 89 | 118 | 3,416 | 11,727 | 24,190 |
| bun | 74 | 80 | 89 | 1,207 | 8,326 |
| gleam_sqlite | 138 | 148 | 153 | 153 | 5,062,949 |
| gleam_sqlite_sdio | 145 | 312 | 177 | 157 | 5,113,973 |

### Errors (failed requests, summed across runs)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | 16 workers |
| --- | ---: | ---: | ---: | ---: | ---: |
| c | 0 | 0 | 0 | 0 | 0 |
| rust | 0 | 0 | 0 | 0 | 0 |
| zig | 0 | 0 | 0 | 0 | 0 |
| go | 0 | 0 | 0 | 0 | 0 |
| bun | 0 | 0 | 0 | 0 | 0 |
| gleam_sqlite | 0 | 0 | 0 | 1 | 60 |
| gleam_sqlite_sdio | 0 | 2 | 1 | 0 | 48 |

### Max latency (µs): the longest any single write waited

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | 16 workers |
| --- | ---: | ---: | ---: | ---: | ---: |
| c | 6,404 | 1,230,880 | 1,431,412 | 1,732,645 | 1,734,468 |
| rust | 11,532 | 1,030,698 | 1,030,788 | 1,430,621 | 1,843,629 |
| zig | 9,261 | 830,746 | 2,232,383 | 1,834,396 | 1,633,940 |
| go | 5,213 | 57,235 | 79,229 | 99,480 | 140,763 |
| bun | 12,781 | 930,845 | 1,932,088 | 1,631,752 | 1,831,805 |
| gleam_sqlite | 6,211 | 2,533,185 | 1,932,483 | 2,832,914 | 5,088,431 |
| gleam_sqlite_sdio | 6,467 | 1,031,572 | 1,731,777 | 3,333,968 | 5,139,207 |


## `mixed`

### Throughput (requests/sec, higher is better)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | 16 workers | Best vs 1 worker |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | 11,047 | 13,259 | 26,379 | 32,864 | 32,083 | 3.0x |
| rust | 9,972 | 9,206 | 21,963 | 27,155 | 27,373 | 2.7x |
| zig | 11,346 | 12,815 | 27,173 | 30,858 | 30,873 | 2.7x |
| go | 5,663 | 9,196 | 15,524 | 21,143 | 19,263 | 3.7x |
| bun | 8,148 | 8,400 | 19,934 | 23,509 | 26,781 | 3.3x |
| gleam_sqlite | 3,256 | 4,773 | 6,091 | 6,633 | 8,565 | 2.6x |
| gleam_sqlite_sdio | 3,176 | 4,703 | 6,468 | 6,639 | 6,971 | 2.2x |

### p99 latency (µs, lower is better)

| Suite | 1 worker | 2 workers | 4 workers | 8 workers | 16 workers |
| --- | ---: | ---: | ---: | ---: | ---: |
| c | 167 | 374 | 807 | 1,306 | 3,201 |
| rust | 193 | 502 | 468 | 1,971 | 3,265 |
| zig | 168 | 418 | 815 | 1,320 | 2,578 |
| go | 350 | 494 | 547 | 2,170 | 9,857 |
| bun | 242 | 547 | 1,164 | 2,119 | 3,439 |
| gleam_sqlite | 536 | 638 | 995 | 1,695 | 3,645 |
| gleam_sqlite_sdio | 515 | 669 | 885 | 1,693 | 3,384 |


## CPU steal

Share of CPU time the hypervisor gave to other tenants during each suite run.
Anything above zero means neighbours competed for the CPU; compare runs with
high steal cautiously. Highest: gleam_sqlite run 2 at 0.38%.

| Suite | Run | Steal |
| --- | ---: | ---: |
| c | 1 | 0.21% |
| rust | 1 | 0.04% |
| zig | 1 | 0.04% |
| go | 1 | 0.11% |
| bun | 1 | 0.03% |
| gleam_sqlite | 1 | 0.02% |
| gleam_sqlite_sdio | 1 | 0.05% |
| c | 2 | 0.02% |
| rust | 2 | 0.02% |
| zig | 2 | 0.02% |
| go | 2 | 0.16% |
| bun | 2 | 0.16% |
| gleam_sqlite | 2 | 0.38% |
| gleam_sqlite_sdio | 2 | 0.03% |
| c | 3 | 0.02% |
| rust | 3 | 0.05% |
| zig | 3 | 0.08% |
| go | 3 | 0.03% |
| bun | 3 | 0.03% |
| gleam_sqlite | 3 | 0.05% |
| gleam_sqlite_sdio | 3 | 0.01% |
