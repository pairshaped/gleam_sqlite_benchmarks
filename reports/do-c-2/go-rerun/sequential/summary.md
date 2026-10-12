# Benchmark Summary

Timing values are average microseconds per item from each benchmark run.

## `admin_item_edit`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/admin_item_edit` | 5 | 114 | 1.0x | 8,766 | 111 | 118 |
| go | `go_sqlite/app_request/admin_item_edit` | 5 | 222 | 2.0x | 4,484 | 216 | 224 |
| go_ncruces | `go_ncruces/app_request/admin_item_edit` | 5 | 195 | 1.7x | 5,123 | 190 | 200 |
| go_cgo | `go_cgo/app_request/admin_item_edit` | 5 | 143 | 1.3x | 6,971 | 142 | 145 |


## `admin_item_update`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/admin_item_update` | 5 | 36 | 1.0x | 27,082 | 34 | 63 |
| go | `go_sqlite/app_request/admin_item_update` | 5 | 64 | 1.8x | 15,401 | 58 | 66 |
| go_ncruces | `go_ncruces/app_request/admin_item_update` | 5 | 47 | 1.3x | 21,060 | 45 | 58 |
| go_cgo | `go_cgo/app_request/admin_item_update` | 5 | 55 | 1.5x | 18,051 | 49 | 63 |


## `seed_dummy_data`

| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| c | `c_sqlite/app_request/seed_dummy_data` | 5 | 25,837 | 1.0x | 39 | 21,403 | 35,443 |
| go | `go_sqlite/app_request/seed_dummy_data` | 5 | 28,425 | 1.1x | 35 | 24,877 | 30,538 |
| go_ncruces | `go_ncruces/app_request/seed_dummy_data` | 5 | 34,090 | 1.3x | 29 | 26,522 | 41,925 |
| go_cgo | `go_cgo/app_request/seed_dummy_data` | 5 | 23,640 | 0.9x | 42 | 17,952 | 25,999 |
