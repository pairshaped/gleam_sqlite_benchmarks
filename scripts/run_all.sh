#!/usr/bin/env bash
set -euo pipefail

rows="${1:-5000}"
runs="${RUNS:-3}"
out_dir="${OUT_DIR:-benchmark-results/$(date -u +%Y%m%dT%H%M%SZ)}"

if ! [[ "$rows" =~ ^[0-9]+$ ]]; then
  echo "Row count must be a positive integer" >&2
  exit 1
fi

if ! [[ "$runs" =~ ^[0-9]+$ ]]; then
  echo "RUNS must be a positive integer" >&2
  exit 1
fi

mkdir -p "$out_dir"

metadata_file="$out_dir/metadata.txt"
{
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "rows=$rows"
  echo "runs=$runs"
  echo "git_rev=${BENCHMARK_GIT_REV:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"
  echo
  uname -a || true
  echo
  command -v lscpu >/dev/null && lscpu || true
  echo
  command -v free >/dev/null && free -h || true
  echo
  gleam --version || true
  rustc --version || true
  cargo --version || true
  ruby -v || true
  bundle -v || true
  psql --version || true
  pg_config --version || true
} > "$metadata_file"

start_postgres() {
  if ! command -v pg_lsclusters >/dev/null; then
    return
  fi

  local cluster
  cluster="$(pg_lsclusters --no-header | awk 'NR == 1 { print $1 " " $2 }')"
  if [ -z "$cluster" ]; then
    echo "No PostgreSQL cluster found" >&2
    return 1
  fi

  local version name
  version="$(printf '%s\n' "$cluster" | awk '{ print $1 }')"
  name="$(printf '%s\n' "$cluster" | awk '{ print $2 }')"

  pg_ctlcluster "$version" "$name" start >/dev/null 2>&1 || true

  # Debian's default local auth is peer. The benchmark runs as root in the
  # container, so create a matching database role for local socket access.
  su postgres -c "createuser root --superuser" >/dev/null 2>&1 || true
}

clean_sqlite_files() {
  rm -f gleam/*.sqlite3 gleam/*.sqlite3-* gleam/*_probe.bin
  rm -f rust/*.sqlite3 rust/*.sqlite3-*
  rm -f ruby/*.sqlite3 ruby/*.sqlite3-*
}

run_suite() {
  local suite="$1"
  local run="$2"
  shift 2

  local file="$out_dir/${suite}_run_${run}.csv"
  echo "==> ${suite} run ${run}/${runs}"
  clean_sqlite_files
  "$@" | tee "$file"
}

start_postgres

for run in $(seq 1 "$runs"); do
  run_suite gleam_sqlite "$run" bash -c \
    'cd gleam && gleam run "$1"' _ "$rows"
  run_suite gleam_postgres "$run" bash -c \
    'cd gleam && PGHOST=/var/run/postgresql PGUSER=root PGDATABASE=postgres gleam run -m postgres_tests "$1"' _ "$rows"
  run_suite rust "$run" bash -c \
    'cd rust && cargo run --release --quiet -- "$1"' _ "$rows"
  run_suite ruby "$run" bash -c \
    'cd ruby && bundle exec ruby benchmark.rb "$1"' _ "$rows"
done

ruby scripts/summarize_benchmarks.rb "$out_dir" | tee "$out_dir/summary.md"

echo
echo "Wrote benchmark results to $out_dir"
