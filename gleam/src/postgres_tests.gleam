import gleam/int
import gleam/result

const default_row_count = 10_000

@external(erlang, "postgres_tests_ffi", "argv")
fn argv() -> List(String)

@external(erlang, "postgres_tests_ffi", "run")
fn run(rows: Int) -> Nil

pub fn main() -> Nil {
  run(row_count_from_args(argv()))
}

pub fn row_count_from_args(args: List(String)) -> Int {
  case args {
    [first, ..] ->
      first
      |> int.parse
      |> result.try_recover(fn(_) { Ok(default_row_count) })
      |> result.map(fn(rows) {
        case rows > 0 {
          True -> rows
          False -> default_row_count
        }
      })
      |> result.unwrap(or: default_row_count)

    [] -> default_row_count
  }
}
