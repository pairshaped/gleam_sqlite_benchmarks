# Benchmark Summary

Timing values are average microseconds per item from each benchmark run.

## `admin_item_edit`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/admin_item_edit` | 5 | 111 | 1.0x | 8,989 | 109 | 121 |
| rust | `rust_rusqlite/app_request/admin_item_edit` | 5 | 125 | 1.1x | 7,978 | 114 | 136 |
| rust | `rust_rusqlite_query_only/app_request/admin_item_edit` | 5 | 120 | 1.1x | 8,278 | 113 | 129 |
| zig | `zig_sqlite/app_request/admin_item_edit` | 5 | 113 | 1.0x | 8,828 | 107 | 126 |
| go | `go_ncruces/app_request/admin_item_edit` | 5 | 213 | 1.9x | 4,681 | 204 | 262 |
| bun | `bun_sqlite/app_request/admin_item_edit` | 5 | 145 | 1.3x | 6,875 | 136 | 152 |
| gleam_sqlite | `gleam_esqlite/app_request/admin_item_edit` | 5 | 336 | 3.0x | 2,976 | 299 | 697 |
| gleam_sqlite_sdio | `gleam_esqlite/app_request/admin_item_edit` | 5 | 461 | 4.1x | 2,168 | 328 | 547 |


## `admin_item_update`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/admin_item_update` | 5 | 23 | 1.0x | 42,509 | 22 | 27 |
| rust | `rust_rusqlite/app_request/admin_item_update` | 5 | 26 | 1.1x | 37,234 | 24 | 34 |
| zig | `zig_sqlite/app_request/admin_item_update` | 5 | 23 | 1.0x | 41,822 | 23 | 26 |
| go | `go_ncruces/app_request/admin_item_update` | 5 | 39 | 1.7x | 25,238 | 36 | 44 |
| bun | `bun_sqlite/app_request/admin_item_update` | 5 | 36 | 1.6x | 27,068 | 35 | 38 |
| gleam_sqlite | `gleam_esqlite/app_request/admin_item_update` | 5 | 89 | 3.8x | 11,221 | 83 | 233 |
| gleam_sqlite_sdio | `gleam_esqlite/app_request/admin_item_update` | 5 | 89 | 3.8x | 11,202 | 82 | 234 |


## `seed_dummy_data`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/seed_dummy_data` | 5 | 12,317 | 1.0x | 81 | 11,049 | 19,751 |
| rust | `rust_rusqlite/app_request/seed_dummy_data` | 5 | 11,277 | 0.9x | 89 | 9,904 | 13,616 |
| zig | `zig_sqlite/app_request/seed_dummy_data` | 5 | 13,635 | 1.1x | 73 | 12,090 | 14,898 |
| go | `go_ncruces/app_request/seed_dummy_data` | 5 | 19,493 | 1.6x | 51 | 16,774 | 21,345 |
| bun | `bun_sqlite/app_request/seed_dummy_data` | 5 | 13,005 | 1.1x | 77 | 12,125 | 13,849 |
| gleam_sqlite | `gleam_esqlite/app_request/seed_dummy_data` | 5 | 5,229 | 0.4x | 191 | 4,753 | 7,321 |
| gleam_sqlite_sdio | `gleam_esqlite/app_request/seed_dummy_data` | 5 | 5,492 | 0.4x | 182 | 4,562 | 7,400 |

## CPU steal

Share of CPU time the hypervisor gave to other tenants during each suite run.
Anything above zero means neighbours competed for the CPU; compare runs with
high steal cautiously. Highest: gleam_sqlite_sdio run 1 at 0.12%.

| Suite | Run | Steal |
| --- | ---: | ---: |
| c | 1 | 0.00% |
| rust | 1 | 0.02% |
| zig | 1 | 0.01% |
| go | 1 | 0.02% |
| bun | 1 | 0.00% |
| gleam_sqlite | 1 | 0.00% |
| gleam_sqlite_sdio | 1 | 0.12% |
| c | 2 | 0.00% |
| rust | 2 | 0.00% |
| zig | 2 | 0.00% |
| go | 2 | 0.05% |
| bun | 2 | 0.00% |
| gleam_sqlite | 2 | 0.01% |
| gleam_sqlite_sdio | 2 | 0.00% |
| c | 3 | 0.00% |
| rust | 3 | 0.00% |
| zig | 3 | 0.00% |
| go | 3 | 0.10% |
| bun | 3 | 0.00% |
| gleam_sqlite | 3 | 0.00% |
| gleam_sqlite_sdio | 3 | 0.00% |
| c | 4 | 0.00% |
| rust | 4 | 0.00% |
| zig | 4 | 0.00% |
| go | 4 | 0.00% |
| bun | 4 | 0.00% |
| gleam_sqlite | 4 | 0.00% |
| gleam_sqlite_sdio | 4 | 0.03% |
| c | 5 | 0.00% |
| rust | 5 | 0.00% |
| zig | 5 | 0.00% |
| go | 5 | 0.04% |
| bun | 5 | 0.00% |
| gleam_sqlite | 5 | 0.00% |
| gleam_sqlite_sdio | 5 | 0.01% |
