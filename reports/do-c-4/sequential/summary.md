# Benchmark Summary

Timing values are average microseconds per item from each benchmark run.

## `admin_item_edit`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/admin_item_edit` | 5 | 120 | 1.0x | 8,302 | 115 | 149 |
| rust | `rust_rusqlite/app_request/admin_item_edit` | 5 | 124 | 1.0x | 8,062 | 122 | 128 |
| rust | `rust_rusqlite_query_only/app_request/admin_item_edit` | 5 | 125 | 1.0x | 7,973 | 122 | 136 |
| zig | `zig_sqlite/app_request/admin_item_edit` | 5 | 120 | 1.0x | 8,296 | 118 | 122 |
| go | `go_ncruces/app_request/admin_item_edit` | 5 | 199 | 1.7x | 5,021 | 194 | 205 |
| bun | `bun_sqlite/app_request/admin_item_edit` | 5 | 144 | 1.2x | 6,916 | 137 | 149 |
| gleam_sqlite | `gleam_esqlite/app_request/admin_item_edit` | 5 | 333 | 2.8x | 3,001 | 318 | 700 |
| gleam_sqlite_sdio | `gleam_esqlite/app_request/admin_item_edit` | 5 | 332 | 2.8x | 3,007 | 318 | 568 |


## `admin_item_update`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/admin_item_update` | 5 | 40 | 1.0x | 24,638 | 34 | 42 |
| rust | `rust_rusqlite/app_request/admin_item_update` | 5 | 41 | 1.0x | 24,074 | 39 | 45 |
| zig | `zig_sqlite/app_request/admin_item_update` | 5 | 41 | 1.0x | 24,181 | 40 | 46 |
| go | `go_ncruces/app_request/admin_item_update` | 5 | 46 | 1.1x | 21,515 | 43 | 48 |
| bun | `bun_sqlite/app_request/admin_item_update` | 5 | 51 | 1.3x | 19,324 | 46 | 60 |
| gleam_sqlite | `gleam_esqlite/app_request/admin_item_update` | 5 | 108 | 2.7x | 9,182 | 103 | 266 |
| gleam_sqlite_sdio | `gleam_esqlite/app_request/admin_item_update` | 5 | 104 | 2.6x | 9,528 | 99 | 263 |


## `seed_dummy_data`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/seed_dummy_data` | 5 | 24,181 | 1.0x | 41 | 22,813 | 125,743 |
| rust | `rust_rusqlite/app_request/seed_dummy_data` | 5 | 25,282 | 1.0x | 40 | 19,303 | 26,997 |
| zig | `zig_sqlite/app_request/seed_dummy_data` | 5 | 35,963 | 1.5x | 28 | 27,185 | 111,482 |
| go | `go_ncruces/app_request/seed_dummy_data` | 5 | 27,771 | 1.1x | 36 | 24,332 | 41,055 |
| bun | `bun_sqlite/app_request/seed_dummy_data` | 5 | 23,506 | 1.0x | 43 | 20,255 | 34,784 |
| gleam_sqlite | `gleam_esqlite/app_request/seed_dummy_data` | 5 | 7,687 | 0.3x | 130 | 6,296 | 9,276 |
| gleam_sqlite_sdio | `gleam_esqlite/app_request/seed_dummy_data` | 5 | 8,073 | 0.3x | 124 | 6,165 | 12,092 |
