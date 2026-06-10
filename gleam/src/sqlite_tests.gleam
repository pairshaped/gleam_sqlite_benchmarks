import gleam/int
import gleam/io
import gleam/list
import gleam/result
import sqlight

const default_row_count = 10_000

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
