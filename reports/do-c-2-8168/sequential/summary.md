# Benchmark Summary

Timing values are average microseconds per item from each benchmark run.

## `admin_item_edit`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/admin_item_edit` | 5 | 114 | 1.0x | 8,736 | 113 | 118 |
| rust | `rust_rusqlite/app_request/admin_item_edit` | 5 | 123 | 1.1x | 8,088 | 119 | 127 |
| rust | `rust_rusqlite_query_only/app_request/admin_item_edit` | 5 | 122 | 1.1x | 8,144 | 119 | 127 |
| zig | `zig_sqlite/app_request/admin_item_edit` | 5 | 116 | 1.0x | 8,602 | 111 | 120 |
| go | `go_sqlite/app_request/admin_item_edit` | 5 | 225 | 2.0x | 4,436 | 223 | 230 |
| bun | `bun_sqlite/app_request/admin_item_edit` | 5 | 145 | 1.3x | 6,872 | 144 | 152 |
| gleam_sqlite | `gleam_esqlite/app_request/admin_item_edit` | 5 | 1,147 | 10.0x | 872 | 416 | 1,291 |
| gleam_sqlite_sdio | `gleam_esqlite/app_request/admin_item_edit` | 5 | 432 | 3.8x | 2,310 | 426 | 1,284 |


## `admin_item_update`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/admin_item_update` | 5 | 40 | 1.0x | 24,982 | 38 | 71 |
| rust | `rust_rusqlite/app_request/admin_item_update` | 5 | 43 | 1.1x | 23,104 | 40 | 49 |
| zig | `zig_sqlite/app_request/admin_item_update` | 5 | 38 | 1.0x | 25,905 | 36 | 58 |
| go | `go_sqlite/app_request/admin_item_update` | 5 | 64 | 1.6x | 15,505 | 62 | 79 |
| bun | `bun_sqlite/app_request/admin_item_update` | 5 | 51 | 1.3x | 19,423 | 49 | 75 |
| gleam_sqlite | `gleam_esqlite/app_request/admin_item_update` | 5 | 115 | 2.9x | 8,639 | 111 | 359 |
| gleam_sqlite_sdio | `gleam_esqlite/app_request/admin_item_update` | 5 | 125 | 3.1x | 7,995 | 119 | 325 |


## `seed_dummy_data`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/seed_dummy_data` | 5 | 33,731 | 1.0x | 30 | 25,629 | 40,474 |
| rust | `rust_rusqlite/app_request/seed_dummy_data` | 5 | 19,848 | 0.6x | 50 | 18,875 | 33,537 |
| zig | `zig_sqlite/app_request/seed_dummy_data` | 5 | 32,775 | 1.0x | 31 | 19,589 | 64,924 |
| go | `go_sqlite/app_request/seed_dummy_data` | 5 | 26,662 | 0.8x | 38 | 20,542 | 31,542 |
| bun | `bun_sqlite/app_request/seed_dummy_data` | 5 | 29,229 | 0.9x | 34 | 26,169 | 33,962 |
| gleam_sqlite | `gleam_esqlite/app_request/seed_dummy_data` | 5 | 7,446 | 0.2x | 134 | 6,093 | 9,818 |
| gleam_sqlite_sdio | `gleam_esqlite/app_request/seed_dummy_data` | 5 | 6,760 | 0.2x | 148 | 6,627 | 7,922 |
