import gleeunit
import sqlite_tests

pub fn main() -> Nil {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn row_count_defaults_without_args_test() {
  assert sqlite_tests.row_count_from_args([]) == 10_000
}

pub fn row_count_uses_first_positive_arg_test() {
  assert sqlite_tests.row_count_from_args(["123", "ignored"]) == 123
}

pub fn row_count_ignores_invalid_arg_test() {
  assert sqlite_tests.row_count_from_args(["nope"]) == 10_000
}

pub fn row_count_ignores_zero_arg_test() {
  assert sqlite_tests.row_count_from_args(["0"]) == 10_000
}
