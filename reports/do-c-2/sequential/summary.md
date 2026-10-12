# Benchmark Summary

Timing values are average microseconds per item from each benchmark run.

## `admin_item_edit`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/admin_item_edit` | 5 | 56 | 1.0x | 17,805 | 54 | 57 |
| rust | `rust_rusqlite/app_request/admin_item_edit` | 5 | 62 | 1.1x | 16,071 | 60 | 62 |
| rust | `rust_rusqlite_query_only/app_request/admin_item_edit` | 5 | 61 | 1.1x | 16,205 | 60 | 63 |
| zig | `zig_sqlite/app_request/admin_item_edit` | 5 | 58 | 1.0x | 17,103 | 55 | 59 |
| go | `go_ncruces/app_request/admin_item_edit` | 5 | 122 | 2.2x | 8,133 | 117 | 124 |
| bun | `bun_sqlite/app_request/admin_item_edit` | 5 | 83 | 1.5x | 11,936 | 81 | 85 |
| gleam_sqlite | `gleam_esqlite/app_request/admin_item_edit` | 5 | 229 | 4.1x | 4,366 | 228 | 676 |
| gleam_sqlite_sdio | `gleam_esqlite/app_request/admin_item_edit` | 5 | 290 | 5.2x | 3,440 | 229 | 492 |


## `admin_item_update`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/admin_item_update` | 5 | 14 | 1.0x | 71,290 | 12 | 15 |
| rust | `rust_rusqlite/app_request/admin_item_update` | 5 | 14 | 1.1x | 67,389 | 14 | 15 |
| zig | `zig_sqlite/app_request/admin_item_update` | 5 | 12 | 0.9x | 77,876 | 12 | 13 |
| go | `go_ncruces/app_request/admin_item_update` | 5 | 22 | 1.6x | 43,515 | 21 | 25 |
| bun | `bun_sqlite/app_request/admin_item_update` | 5 | 20 | 1.5x | 47,647 | 19 | 22 |
| gleam_sqlite | `gleam_esqlite/app_request/admin_item_update` | 5 | 62 | 4.4x | 16,027 | 57 | 176 |
| gleam_sqlite_sdio | `gleam_esqlite/app_request/admin_item_update` | 5 | 59 | 4.3x | 16,707 | 58 | 172 |


## `seed_dummy_data`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/seed_dummy_data` | 5 | 7,057 | 1.0x | 142 | 5,820 | 9,695 |
| rust | `rust_rusqlite/app_request/seed_dummy_data` | 5 | 6,516 | 0.9x | 153 | 6,243 | 6,954 |
| zig | `zig_sqlite/app_request/seed_dummy_data` | 5 | 6,426 | 0.9x | 156 | 6,232 | 7,628 |
| go | `go_ncruces/app_request/seed_dummy_data` | 5 | 10,120 | 1.4x | 99 | 9,681 | 10,493 |
| bun | `bun_sqlite/app_request/seed_dummy_data` | 5 | 6,735 | 1.0x | 148 | 6,550 | 14,653 |
| gleam_sqlite | `gleam_esqlite/app_request/seed_dummy_data` | 5 | 3,267 | 0.5x | 306 | 3,122 | 3,570 |
| gleam_sqlite_sdio | `gleam_esqlite/app_request/seed_dummy_data` | 5 | 3,258 | 0.5x | 307 | 3,021 | 3,510 |
