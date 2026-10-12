# Benchmark Summary

Timing values are average microseconds per item from each benchmark run.

## `admin_item_edit`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/admin_item_edit` | 5 | 126 | 1.0x | 7,912 | 119 | 140 |
| rust | `rust_rusqlite/app_request/admin_item_edit` | 5 | 129 | 1.0x | 7,712 | 125 | 133 |
| rust | `rust_rusqlite_query_only/app_request/admin_item_edit` | 5 | 132 | 1.0x | 7,571 | 127 | 133 |
| zig | `zig_sqlite/app_request/admin_item_edit` | 5 | 124 | 1.0x | 8,038 | 122 | 127 |
| go | `go_ncruces/app_request/admin_item_edit` | 5 | 211 | 1.7x | 4,724 | 208 | 216 |
| bun | `bun_sqlite/app_request/admin_item_edit` | 5 | 156 | 1.2x | 6,381 | 154 | 161 |
| gleam_sqlite | `gleam_esqlite/app_request/admin_item_edit` | 5 | 995 | 7.9x | 1,004 | 433 | 1,297 |
| gleam_sqlite_sdio | `gleam_esqlite/app_request/admin_item_edit` | 5 | 1,281 | 10.1x | 780 | 430 | 1,296 |


## `admin_item_update`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/admin_item_update` | 5 | 37 | 1.0x | 26,460 | 34 | 47 |
| rust | `rust_rusqlite/app_request/admin_item_update` | 5 | 41 | 1.1x | 23,921 | 37 | 43 |
| zig | `zig_sqlite/app_request/admin_item_update` | 5 | 38 | 1.0x | 26,019 | 35 | 39 |
| go | `go_ncruces/app_request/admin_item_update` | 5 | 46 | 1.2x | 21,637 | 44 | 49 |
| bun | `bun_sqlite/app_request/admin_item_update` | 5 | 46 | 1.2x | 21,628 | 44 | 51 |
| gleam_sqlite | `gleam_esqlite/app_request/admin_item_update` | 5 | 306 | 8.1x | 3,259 | 113 | 311 |
| gleam_sqlite_sdio | `gleam_esqlite/app_request/admin_item_update` | 5 | 306 | 8.1x | 3,260 | 112 | 314 |


## `seed_dummy_data`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/seed_dummy_data` | 5 | 20,614 | 1.0x | 49 | 18,815 | 34,787 |
| rust | `rust_rusqlite/app_request/seed_dummy_data` | 5 | 26,895 | 1.3x | 37 | 19,204 | 385,746 |
| zig | `zig_sqlite/app_request/seed_dummy_data` | 5 | 28,113 | 1.4x | 36 | 20,748 | 58,301 |
| go | `go_ncruces/app_request/seed_dummy_data` | 5 | 26,343 | 1.3x | 38 | 24,315 | 36,133 |
| bun | `bun_sqlite/app_request/seed_dummy_data` | 5 | 19,654 | 1.0x | 51 | 18,387 | 30,362 |
| gleam_sqlite | `gleam_esqlite/app_request/seed_dummy_data` | 5 | 7,085 | 0.3x | 141 | 6,698 | 7,355 |
| gleam_sqlite_sdio | `gleam_esqlite/app_request/seed_dummy_data` | 5 | 7,122 | 0.3x | 140 | 5,668 | 7,456 |
