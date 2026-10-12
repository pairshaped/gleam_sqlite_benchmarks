import gleam/int
import gleam/io
import gleam/result
import sqlight

const default_row_count = 5000

const benchmark_db_path = "sqlite_tests_benchmark.sqlite3"

@external(erlang, "sqlite_tests_ffi", "argv")
fn argv() -> List(String)

@external(erlang, "sqlite_tests_ffi", "monotonic_microsecond")
fn monotonic_microsecond() -> Int

@external(erlang, "sqlite_tests_ffi", "seed_app_request_data")
fn seed_app_request_data(conn: sqlight.Connection) -> Result(Int, sqlight.Error)

@external(erlang, "sqlite_tests_ffi", "app_admin_item_edit_requests")
fn app_admin_item_edit_requests(
  conn: sqlight.Connection,
  rows: Int,
) -> Result(Int, sqlight.Error)

@external(erlang, "sqlite_tests_ffi", "app_admin_item_update_requests")
fn app_admin_item_update_requests(
  conn: sqlight.Connection,
  rows: Int,
) -> Result(Int, sqlight.Error)

@external(erlang, "sqlite_tests_ffi", "concurrent_main")
fn concurrent_main(
  path: String,
  duration: String,
  warmup: String,
  workers: String,
) -> Nil

pub fn main() -> Nil {
  case argv() {
    ["concurrent", duration, warmup, workers] ->
      concurrent_main(benchmark_db_path, duration, warmup, workers)
    args -> sequential_main(args)
  }
}

fn sequential_main(args: List(String)) -> Nil {
  let rows = row_count_from_args(args)

  case sqlight.open(benchmark_db_path) {
    Error(error) -> io.println_error("open failed: " <> sqlight_error(error))
    Ok(conn) -> {
      io.println("case,items,micros,us_per_item,check")

      let benchmark = {
        use _ <- result.try(configure_connection(conn))

        use _ <- result.try(
          measure("gleam_esqlite/app_request/seed_dummy_data", 1, fn() {
            seed_app_request_data(conn)
          }),
        )

        use _ <- result.try(
          measure("gleam_esqlite/app_request/admin_item_edit", rows, fn() {
            app_admin_item_edit_requests(conn, rows)
          }),
        )

        use _ <- result.try(
          measure("gleam_esqlite/app_request/admin_item_update", rows, fn() {
            app_admin_item_update_requests(conn, rows)
          }),
        )

        Ok(0)
      }

      let close_result = sqlight.close(conn)

      case benchmark, close_result {
        Ok(_), Ok(_) -> Nil
        Error(error), _ ->
          io.println_error("benchmark failed: " <> sqlight_error(error))
        _, Error(error) ->
          io.println_error("close failed: " <> sqlight_error(error))
      }
    }
  }
}

fn configure_connection(
  conn: sqlight.Connection,
) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(sqlight.exec("pragma busy_timeout = 5000;", on: conn))
  use _ <- result.try(sqlight.exec("pragma journal_mode = WAL;", on: conn))
  use _ <- result.try(sqlight.exec("pragma synchronous = NORMAL;", on: conn))
  use _ <- result.try(sqlight.exec("pragma foreign_keys = ON;", on: conn))
  Ok(Nil)
}

pub fn row_count_from_args(args: List(String)) -> Int {
  case args {
    [first, ..] ->
      case int.parse(first) {
        Ok(count) if count > 0 -> count
        _ -> default_row_count
      }

    _ -> default_row_count
  }
}

fn measure(
  name: String,
  items: Int,
  work: fn() -> Result(Int, sqlight.Error),
) -> Result(Int, sqlight.Error) {
  let start = monotonic_microsecond()
  let result = work()
  let elapsed = monotonic_microsecond() - start

  case result {
    Ok(check) -> {
      let us_per_item = result.unwrap(int.divide(elapsed, by: items), or: 0)
      print_csv_row(name, items, elapsed, us_per_item, check)
      Ok(check)
    }

    Error(error) -> Error(error)
  }
}

fn print_csv_row(
  name: String,
  items: Int,
  micros: Int,
  us_per_item: Int,
  check: Int,
) -> Nil {
  io.println(
    name
    <> ","
    <> int.to_string(items)
    <> ","
    <> int.to_string(micros)
    <> ","
    <> int.to_string(us_per_item)
    <> ","
    <> int.to_string(check),
  )
}

fn sqlight_error(error: sqlight.Error) -> String {
  let sqlight.SqlightError(code:, message:, offset:) = error

  "code="
  <> int.to_string(sqlight.error_code_to_int(code))
  <> " offset="
  <> int.to_string(offset)
  <> " message="
  <> message
}
