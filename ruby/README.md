# Ruby ActiveRecord SQLite

This bucket runs the request-shaped SQLite benchmark through ActiveRecord.

Install and run:

```sh
asdf exec bundle install
asdf exec bundle exec ruby benchmark.rb 5000
```

The runner creates `ruby_benchmark.sqlite3` in this directory and prints:

```text
case,items,micros,us_per_item,check
```

Cases:

- `active_record/app_request/seed_dummy_data`
- `active_record/app_request/admin_item_edit`
- `active_record/app_request/admin_item_update`

The measured request work uses ActiveRecord models and relations. Raw SQL is
used only for schema and seed setup. ActiveRecord logging and verbose query logs
are disabled.
