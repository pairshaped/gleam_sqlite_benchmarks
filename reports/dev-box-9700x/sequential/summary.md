# Benchmark Summary

Timing values are average microseconds per item from each benchmark run.

## `admin_item_edit`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/admin_item_edit` | 5 | 25 | 1.0x | 39,003 | 22 | 26 |
| rust | `rust_rusqlite/app_request/admin_item_edit` | 5 | 25 | 1.0x | 39,251 | 25 | 25 |
| rust | `rust_rusqlite_query_only/app_request/admin_item_edit` | 5 | 25 | 1.0x | 39,230 | 25 | 25 |
| zig | `zig_sqlite/app_request/admin_item_edit` | 5 | 22 | 0.9x | 43,788 | 22 | 22 |
| go | `go_ncruces/app_request/admin_item_edit` | 5 | 44 | 1.7x | 22,503 | 44 | 44 |
| bun | `bun_sqlite/app_request/admin_item_edit` | 5 | 28 | 1.1x | 34,712 | 28 | 29 |
| gleam_sqlite | `gleam_esqlite/app_request/admin_item_edit` | 5 | 65 | 2.6x | 15,224 | 65 | 66 |
| gleam_sqlite_sdio | `gleam_esqlite/app_request/admin_item_edit` | 5 | 65 | 2.6x | 15,169 | 65 | 66 |


## `admin_item_update`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/admin_item_update` | 5 | 19 | 1.0x | 51,620 | 19 | 24 |
| rust | `rust_rusqlite/app_request/admin_item_update` | 5 | 20 | 1.1x | 48,127 | 19 | 24 |
| zig | `zig_sqlite/app_request/admin_item_update` | 5 | 19 | 1.0x | 51,904 | 19 | 25 |
| go | `go_ncruces/app_request/admin_item_update` | 5 | 15 | 0.8x | 66,089 | 14 | 21 |
| bun | `bun_sqlite/app_request/admin_item_update` | 5 | 21 | 1.1x | 45,750 | 21 | 25 |
| gleam_sqlite | `gleam_esqlite/app_request/admin_item_update` | 5 | 33 | 1.7x | 30,114 | 33 | 37 |
| gleam_sqlite_sdio | `gleam_esqlite/app_request/admin_item_update` | 5 | 33 | 1.7x | 29,862 | 33 | 38 |


## `seed_dummy_data`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/seed_dummy_data` | 5 | 53,458 | 1.0x | 19 | 48,880 | 56,241 |
| rust | `rust_rusqlite/app_request/seed_dummy_data` | 5 | 35,968 | 0.7x | 28 | 31,277 | 59,242 |
| zig | `zig_sqlite/app_request/seed_dummy_data` | 5 | 55,874 | 1.0x | 18 | 48,691 | 78,057 |
| go | `go_ncruces/app_request/seed_dummy_data` | 5 | 38,964 | 0.7x | 26 | 29,456 | 56,714 |
| bun | `bun_sqlite/app_request/seed_dummy_data` | 5 | 35,968 | 0.7x | 28 | 34,746 | 45,408 |
| gleam_sqlite | `gleam_esqlite/app_request/seed_dummy_data` | 5 | 5,995 | 0.1x | 167 | 5,246 | 6,962 |
| gleam_sqlite_sdio | `gleam_esqlite/app_request/seed_dummy_data` | 5 | 6,078 | 0.1x | 165 | 5,345 | 7,156 |
