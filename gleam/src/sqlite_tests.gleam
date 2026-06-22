import generated/sql/app_request_sql
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import sqlight

const default_row_count = 5000

const benchmark_db_path = "sqlite_tests_benchmark.sqlite3"

const heartbeat_period_micros = 1000

const sendfile_baseline_millis = 500

const read_file_baseline_millis = 500

type Heartbeat

type SendfileProbe

type ReadFileProbe

@external(erlang, "sqlite_tests_ffi", "argv")
fn argv() -> List(String)

@external(erlang, "sqlite_tests_ffi", "monotonic_microsecond")
fn monotonic_microsecond() -> Int

@external(erlang, "sqlite_tests_ffi", "sleep_millisecond")
fn sleep_millisecond(milliseconds: Int) -> Nil

@external(erlang, "sqlite_tests_ffi", "start_heartbeat")
fn start_heartbeat(period_micros: Int) -> Heartbeat

@external(erlang, "sqlite_tests_ffi", "stop_heartbeat")
fn stop_heartbeat(heartbeat: Heartbeat) -> #(Int, Int, Int)

@external(erlang, "sqlite_tests_ffi", "start_sendfile_probe")
fn start_sendfile_probe() -> SendfileProbe

@external(erlang, "sqlite_tests_ffi", "stop_sendfile_probe")
fn stop_sendfile_probe(probe: SendfileProbe) -> #(Int, Int, Int, Int, Int, Int)

@external(erlang, "sqlite_tests_ffi", "start_read_file_probe")
fn start_read_file_probe() -> ReadFileProbe

@external(erlang, "sqlite_tests_ffi", "stop_read_file_probe")
fn stop_read_file_probe(probe: ReadFileProbe) -> #(Int, Int, Int, Int, Int, Int)

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

pub fn main() -> Nil {
  let rows = row_count_from_args(argv())

  case sqlight.open(benchmark_db_path) {
    Error(error) -> io.println_error("open failed: " <> sqlight_error(error))
    Ok(conn) -> {
      io.println("case,items,micros,us_per_item,check")
      measure_sendfile_baseline()
      measure_read_file_baseline()

      let benchmark = {
        use _ <- result.try(configure_connection(conn))

        use _ <- result.try(
          measure("app_request/seed_dummy_data", 1, fn() {
            seed_app_request_data(conn)
          }),
        )

        use _ <- result.try(
          measure("app_request/admin_item_edit", rows, fn() {
            app_admin_item_edit_requests(conn, rows)
          }),
        )

        use _ <- result.try(
          measure("app_request/admin_item_update", rows, fn() {
            app_admin_item_update_requests(conn, rows)
          }),
        )

        use _ <- result.try(
          measure("gleam_marmot/app_request/seed_dummy_data", 1, fn() {
            seed_app_request_data(conn)
          }),
        )

        use _ <- result.try(
          measure("gleam_marmot/app_request/admin_item_edit", rows, fn() {
            app_admin_item_edit_requests_marmot(conn, rows)
          }),
        )

        use _ <- result.try(
          measure("gleam_marmot/app_request/admin_item_update", rows, fn() {
            app_admin_item_update_requests_marmot(conn, rows)
          }),
        )

        use _ <- result.try(
          measure_with_probes("probed_app_request/seed_dummy_data", 1, fn() {
            seed_app_request_data(conn)
          }),
        )

        use _ <- result.try(
          measure_with_probes("probed_app_request/admin_item_edit", rows, fn() {
            app_admin_item_edit_requests(conn, rows)
          }),
        )

        use _ <- result.try(
          measure_with_probes(
            "probed_app_request/admin_item_update",
            rows,
            fn() { app_admin_item_update_requests(conn, rows) },
          ),
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
  use _ <- result.try(sqlight.exec("pragma journal_mode = WAL;", on: conn))
  use _ <- result.try(sqlight.exec("pragma synchronous = NORMAL;", on: conn))
  use _ <- result.try(sqlight.exec("pragma busy_timeout = 5000;", on: conn))
  use _ <- result.try(sqlight.exec("pragma foreign_keys = ON;", on: conn))
  Ok(Nil)
}

fn app_admin_item_edit_requests_marmot(
  conn: sqlight.Connection,
  rows: Int,
) -> Result(Int, sqlight.Error) {
  app_request_loop_marmot(conn, rows, app_admin_item_edit_request_marmot)
}

fn app_admin_item_update_requests_marmot(
  conn: sqlight.Connection,
  rows: Int,
) -> Result(Int, sqlight.Error) {
  app_request_loop_marmot(conn, rows, app_admin_item_update_request_marmot)
}

fn app_request_loop_marmot(
  conn: sqlight.Connection,
  rows: Int,
  work: fn(sqlight.Connection, Int, Int) -> Result(Int, sqlight.Error),
) -> Result(Int, sqlight.Error) {
  app_request_loop_marmot_go(conn, rows, work, 1, 0)
}

fn app_request_loop_marmot_go(
  conn: sqlight.Connection,
  rows: Int,
  work: fn(sqlight.Connection, Int, Int) -> Result(Int, sqlight.Error),
  i: Int,
  check: Int,
) -> Result(Int, sqlight.Error) {
  case i > rows {
    True -> Ok(check)
    False -> {
      let event_id = result.unwrap(int.modulo(i - 1, 100), or: 0) + 1
      use request_check <- result.try(work(conn, i, event_id))
      app_request_loop_marmot_go(conn, rows, work, i + 1, check + request_check)
    }
  }
}

fn app_admin_item_edit_request_marmot(
  conn: sqlight.Connection,
  _i: Int,
  event_id: Int,
) -> Result(Int, sqlight.Error) {
  use user_id <- result.try(value(app_request_sql.get_user_id(db: conn, id: 1)))
  use club_id <- result.try(
    value(app_request_sql.get_club_id_by_subdomain(db: conn, subdomain: "demo")),
  )
  use event <- result.try(
    value(app_request_sql.get_event_id(
      db: conn,
      club_id: 418,
      event_id: event_id,
    )),
  )
  use sponsors <- result.try(
    value(app_request_sql.count_sponsors(db: conn, club_id: 418)),
  )
  use tags <- result.try(
    value(app_request_sql.count_tags(db: conn, club_id: 418)),
  )
  use taxes <- result.try(
    value(app_request_sql.count_taxes(db: conn, province: "ON")),
  )
  use parents <- result.try(
    value(app_request_sql.sum_parent_chain(db: conn, id: 418)),
  )
  use fees <- result.try(
    value(app_request_sql.count_fees(
      db: conn,
      club_id: 418,
      parent_id: 411,
      grandparent_id: "403",
      active: 1,
    )),
  )
  use products <- result.try(
    value(app_request_sql.count_products(
      db: conn,
      club_id: 418,
      active: 1,
      product_type_1: "addon",
      product_type_2: "both",
    )),
  )
  use addons <- result.try(
    value(app_request_sql.count_addons(
      db: conn,
      event_id: event_id,
      addonable_type: "Event",
    )),
  )
  use fee_1 <- result.try(value(app_request_sql.get_fee_id(db: conn, id: 1)))
  use root_club <- result.try(
    value(app_request_sql.get_club_id(db: conn, id: 403)),
  )
  use leaf_club <- result.try(
    value(app_request_sql.get_club_id(db: conn, id: 418)),
  )
  use product <- result.try(
    value(app_request_sql.get_product_id(db: conn, id: 1)),
  )
  use fee_2 <- result.try(value(app_request_sql.get_fee_id(db: conn, id: 2)))
  use custom_fields_1 <- result.try(
    value(app_request_sql.count_custom_fields(db: conn, club_id: 418)),
  )
  use event_custom_fields <- result.try(
    value(app_request_sql.count_event_custom_fields(
      db: conn,
      event_id: event_id,
    )),
  )
  use custom_fields_2 <- result.try(
    value(app_request_sql.count_custom_fields(db: conn, club_id: 418)),
  )
  use discounts_1 <- result.try(
    value(app_request_sql.count_discounts(db: conn, club_id: 418, active: 1)),
  )
  use discount_items <- result.try(
    value(app_request_sql.count_discount_items(
      db: conn,
      event_id: event_id,
      item_type: "Event",
    )),
  )
  use discounts_2 <- result.try(
    value(app_request_sql.count_discounts(db: conn, club_id: 418, active: 1)),
  )
  use palette <- result.try(
    value(app_request_sql.get_branding_palette_id(db: conn, id: 1)),
  )
  use alerts <- result.try(
    value(app_request_sql.count_admin_alerts(
      db: conn,
      country: "Canada",
      club_type: "club",
    )),
  )
  use config_problems <- result.try(
    value(app_request_sql.count_config_problems(
      db: conn,
      club_id: 418,
      ignored: 0,
    )),
  )
  use events <- result.try(
    value(app_request_sql.count_events(db: conn, club_id: 418)),
  )
  use counter <- result.try(
    value(app_request_sql.get_event_counter(db: conn, event_id: event_id)),
  )

  Ok(
    user_id
    + club_id
    + event
    + sponsors
    + tags
    + taxes
    + parents
    + fees
    + products
    + addons
    + fee_1
    + root_club
    + leaf_club
    + product
    + fee_2
    + custom_fields_1
    + event_custom_fields
    + custom_fields_2
    + discounts_1
    + discount_items
    + discounts_2
    + palette
    + alerts
    + config_problems
    + events
    + counter,
  )
}

fn app_admin_item_update_request_marmot(
  conn: sqlight.Connection,
  i: Int,
  event_id: Int,
) -> Result(Int, sqlight.Error) {
  case sqlight.exec("begin transaction;", on: conn) {
    Error(error) -> Error(error)
    Ok(_) -> {
      let result = {
        use check <- result.try(app_admin_item_update_checks_marmot(
          conn,
          event_id,
        ))
        use _ <- result.try(app_request_sql.update_event(
          db: conn,
          name: "Updated Event " <> int.to_string(i),
          event_id: event_id,
        ))
        Ok(check + event_id)
      }

      case result {
        Ok(check) ->
          case sqlight.exec("commit;", on: conn) {
            Ok(_) -> Ok(check)
            Error(error) -> Error(error)
          }

        Error(error) -> {
          let _ = sqlight.exec("rollback;", on: conn)
          Error(error)
        }
      }
    }
  }
}

fn app_admin_item_update_checks_marmot(
  conn: sqlight.Connection,
  event_id: Int,
) -> Result(Int, sqlight.Error) {
  use user_id <- result.try(value(app_request_sql.get_user_id(db: conn, id: 1)))
  use club_id <- result.try(
    value(app_request_sql.get_club_id_by_subdomain(db: conn, subdomain: "demo")),
  )
  use event <- result.try(
    value(app_request_sql.get_event_id(
      db: conn,
      club_id: 418,
      event_id: event_id,
    )),
  )
  use addons <- result.try(
    value(app_request_sql.count_addons(
      db: conn,
      event_id: event_id,
      addonable_type: "Event",
    )),
  )
  use discount_items <- result.try(
    value(app_request_sql.count_discount_items(
      db: conn,
      event_id: event_id,
      item_type: "Event",
    )),
  )
  use tags <- result.try(
    value(app_request_sql.count_tags(db: conn, club_id: 418)),
  )
  Ok(user_id + club_id + event + addons + discount_items + tags)
}

fn value(
  query: Result(List(app_request_sql.ValueRow), sqlight.Error),
) -> Result(Int, sqlight.Error) {
  query
  |> result.map(fn(rows) {
    case rows {
      [row, ..] -> row.value
      [] -> 0
    }
  })
}

fn measure_read_file_baseline() -> Nil {
  let read_file_probe = start_read_file_probe()
  sleep_millisecond(read_file_baseline_millis)
  let #(attempts, failures, max_latency, avg_latency, bytes, failure_code) =
    stop_read_file_probe(read_file_probe)

  io.println(
    "io/read_file/baseline,"
    <> int.to_string(attempts)
    <> ","
    <> int.to_string(max_latency)
    <> ","
    <> int.to_string(avg_latency)
    <> ","
    <> int.to_string(failures),
  )

  io.println(
    "io/read_file/bytes/baseline,"
    <> int.to_string(attempts)
    <> ","
    <> int.to_string(max_latency)
    <> ","
    <> int.to_string(avg_latency)
    <> ","
    <> int.to_string(bytes),
  )

  io.println(
    "io/read_file/failure_code/baseline,"
    <> int.to_string(attempts)
    <> ","
    <> int.to_string(max_latency)
    <> ","
    <> int.to_string(avg_latency)
    <> ","
    <> int.to_string(failure_code),
  )
}

fn measure_sendfile_baseline() -> Nil {
  let sendfile_probe = start_sendfile_probe()
  sleep_millisecond(sendfile_baseline_millis)
  let #(attempts, failures, max_latency, avg_latency, bytes, failure_code) =
    stop_sendfile_probe(sendfile_probe)

  io.println(
    "io/sendfile/baseline,"
    <> int.to_string(attempts)
    <> ","
    <> int.to_string(max_latency)
    <> ","
    <> int.to_string(avg_latency)
    <> ","
    <> int.to_string(failures),
  )

  io.println(
    "io/sendfile/bytes/baseline,"
    <> int.to_string(attempts)
    <> ","
    <> int.to_string(max_latency)
    <> ","
    <> int.to_string(avg_latency)
    <> ","
    <> int.to_string(bytes),
  )

  io.println(
    "io/sendfile/failure_code/baseline,"
    <> int.to_string(attempts)
    <> ","
    <> int.to_string(max_latency)
    <> ","
    <> int.to_string(avg_latency)
    <> ","
    <> int.to_string(failure_code),
  )
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

fn measure_with_probes(
  name: String,
  items: Int,
  work: fn() -> Result(Int, sqlight.Error),
) -> Result(Int, sqlight.Error) {
  measure_with_extra_probe_rows(name, items, fn() {
    work()
    |> result.map(fn(check) { #(check, []) })
  })
  |> result.map(fn(stats) {
    let #(check, _) = stats
    check
  })
}

fn measure_with_extra_probe_rows(
  name: String,
  items: Int,
  work: fn() -> Result(#(Int, List(#(String, Int))), sqlight.Error),
) -> Result(#(Int, List(#(String, Int))), sqlight.Error) {
  let sendfile_probe = start_sendfile_probe()
  let read_file_probe = start_read_file_probe()
  let heartbeat = start_heartbeat(heartbeat_period_micros)
  let start = monotonic_microsecond()

  let result = work()
  let elapsed = monotonic_microsecond() - start
  let #(heartbeat_samples, heartbeat_max_delay, heartbeat_avg_delay) =
    stop_heartbeat(heartbeat)
  let #(
    sendfile_attempts,
    sendfile_failures,
    sendfile_max_latency,
    sendfile_avg_latency,
    sendfile_bytes,
    sendfile_failure_code,
  ) = stop_sendfile_probe(sendfile_probe)
  let #(
    read_file_attempts,
    read_file_failures,
    read_file_max_latency,
    read_file_avg_latency,
    read_file_bytes,
    read_file_failure_code,
  ) = stop_read_file_probe(read_file_probe)

  case result {
    Ok(stats) -> {
      let #(check, extra_rows) = stats
      let us_per_item = result.unwrap(int.divide(elapsed, by: items), or: 0)

      print_csv_row(name, items, elapsed, us_per_item, check)

      list.each(extra_rows, fn(extra_row) {
        let #(extra_name, extra_check) = extra_row
        print_csv_row(extra_name, items, elapsed, us_per_item, extra_check)
      })

      io.println(
        "scheduler/heartbeat/"
        <> name
        <> ","
        <> int.to_string(heartbeat_samples)
        <> ","
        <> int.to_string(heartbeat_max_delay)
        <> ","
        <> int.to_string(heartbeat_avg_delay)
        <> ","
        <> int.to_string(heartbeat_period_micros),
      )

      io.println(
        "io/sendfile/"
        <> name
        <> ","
        <> int.to_string(sendfile_attempts)
        <> ","
        <> int.to_string(sendfile_max_latency)
        <> ","
        <> int.to_string(sendfile_avg_latency)
        <> ","
        <> int.to_string(sendfile_failures),
      )

      io.println(
        "io/sendfile/bytes/"
        <> name
        <> ","
        <> int.to_string(sendfile_attempts)
        <> ","
        <> int.to_string(sendfile_max_latency)
        <> ","
        <> int.to_string(sendfile_avg_latency)
        <> ","
        <> int.to_string(sendfile_bytes),
      )

      io.println(
        "io/sendfile/failure_code/"
        <> name
        <> ","
        <> int.to_string(sendfile_attempts)
        <> ","
        <> int.to_string(sendfile_max_latency)
        <> ","
        <> int.to_string(sendfile_avg_latency)
        <> ","
        <> int.to_string(sendfile_failure_code),
      )

      io.println(
        "io/read_file/"
        <> name
        <> ","
        <> int.to_string(read_file_attempts)
        <> ","
        <> int.to_string(read_file_max_latency)
        <> ","
        <> int.to_string(read_file_avg_latency)
        <> ","
        <> int.to_string(read_file_failures),
      )

      io.println(
        "io/read_file/bytes/"
        <> name
        <> ","
        <> int.to_string(read_file_attempts)
        <> ","
        <> int.to_string(read_file_max_latency)
        <> ","
        <> int.to_string(read_file_avg_latency)
        <> ","
        <> int.to_string(read_file_bytes),
      )

      io.println(
        "io/read_file/failure_code/"
        <> name
        <> ","
        <> int.to_string(read_file_attempts)
        <> ","
        <> int.to_string(read_file_max_latency)
        <> ","
        <> int.to_string(read_file_avg_latency)
        <> ","
        <> int.to_string(read_file_failure_code),
      )

      Ok(stats)
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
