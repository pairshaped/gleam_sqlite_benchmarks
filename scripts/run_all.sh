#!/usr/bin/env bash
set -euo pipefail

# MODE=sequential (default) runs each request one at a time on one connection;
# the argument is the request count. MODE=concurrent runs W workers at once for
# DURATION seconds after WARMUP seconds, for each worker count in WORKERS.
mode="${MODE:-sequential}"
rows="${1:-5000}"
runs="${RUNS:-3}"
out_dir="${OUT_DIR:-benchmark-results/$(date -u +%Y%m%dT%H%M%SZ)}"
suites="${SUITES:-c rust zig go bun gleam_sqlite gleam_sqlite_sdio}"
cpus="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
duration="${DURATION:-5}"
warmup="${WARMUP:-1}"

default_workers() {
  local list="" count=1
  while [ "$count" -le "$cpus" ]; do
    list="${list:+$list,}$count"
    count=$((count * 2))
  done
  # Always include the CPU count itself, then twice it to show oversubscription.
  case ",$list," in *",$cpus,"*) ;; *) list="$list,$cpus" ;; esac
  echo "$list,$((cpus * 2))"
}
workers="${WORKERS:-$(default_workers)}"

case "$mode" in
  sequential) args=("$rows") ;;
  concurrent) args=(concurrent "$duration" "$warmup" "$workers") ;;
  *)
    echo "MODE must be sequential or concurrent" >&2
    exit 1
    ;;
esac

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
  echo "mode=$mode"
  if [ "$mode" = concurrent ]; then
    echo "duration=$duration"
    echo "warmup=$warmup"
    echo "workers=$workers"
  fi
  echo "suites=$suites"
  echo "cpus=$cpus"
  echo "git_rev=${BENCHMARK_GIT_REV:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"
  echo
  uname -a || true
  echo
  command -v lscpu >/dev/null && lscpu || true
  echo
  command -v free >/dev/null && free -h || true
  echo
  nix --version || true
  gleam --version || true
  erl -noshell -eval 'io:format("Erlang/OTP ~s~n", [erlang:system_info(otp_release)]), halt().' || true
  cc --version 2>/dev/null | head -1 || true
  pkg-config --modversion sqlite3 2>/dev/null | sed 's/^/shared sqlite /' || true
  rustc --version || true
  cargo --version || true
  zig version 2>/dev/null | sed 's/^/zig /' || true
  go version || true
  bun --version || true
} > "$metadata_file"

clean_sqlite_files() {
  rm -f gleam/*.sqlite3 gleam/*.sqlite3-*
  rm -f rust/*.sqlite3 rust/*.sqlite3-*
  rm -f bun/*.sqlite3 bun/*.sqlite3-*
  rm -f c/*.sqlite3 c/*.sqlite3-*
  rm -f zig/*.sqlite3 zig/*.sqlite3-*
  rm -f go/*.sqlite3 go/*.sqlite3-*
}

# CPU time the hypervisor gave to other tenants ("steal"), from /proc/stat on
# Linux. Prints "steal total" in clock ticks, or nothing elsewhere.
cpu_ticks() {
  [ -r /proc/stat ] || return 0
  # Fields 2-9 are user, nice, system, idle, iowait, irq, softirq and steal. The
  # guest columns after them are already counted in user, so leave them out.
  awk '/^cpu / { total = 0; for (i = 2; i <= 9; i++) total += $i; print $9, total }' /proc/stat
}

run_suite() {
  local suite="$1"
  local run="$2"
  shift 2

  case " $suites " in
    *" $suite "*) ;;
    *) return ;;
  esac

  local file="$out_dir/${suite}_run_${run}.csv"
  echo "==> ${suite} run ${run}/${runs}"
  clean_sqlite_files
  local before after
  before="$(cpu_ticks)"
  # Keep going if one suite fails, so the other suites and runs still finish.
  # The summary lists failures from failures.txt.
  if ! "$@" | tee "$file"; then
    echo "${suite} run ${run} failed" | tee -a "$out_dir/failures.txt" >&2
  fi
  after="$(cpu_ticks)"
  if [ -n "$before" ] && [ -n "$after" ]; then
    [ -f "$out_dir/steal.csv" ] || echo "suite,run,steal_percent" > "$out_dir/steal.csv"
    echo "$before $after" | awk -v suite="$suite" -v run="$run" '{
      total = $4 - $2
      printf "%s,%s,%.2f\n", suite, run, (total > 0 ? 100 * ($3 - $1) / total : 0)
    }' >> "$out_dir/steal.csv"
  fi
}

# esqlite runs every SQLite call on a dirty I/O scheduler thread. The BEAM starts
# 10 of them regardless of CPU count, and on small VMs the thread handoffs make
# Gleam slow and bimodal. The gleam_sqlite_sdio suite caps them at the CPU count.
export SDIO_ERL_FLAGS="+SDio $cpus"

for run in $(seq 1 "$runs"); do
  run_suite c "$run" bash -c \
    'make -s -C c && cd c && ./benchmark "$@"' _ "${args[@]}"
  run_suite rust "$run" bash -c \
    'cd rust && cargo run --release --quiet -- "$@"' _ "${args[@]}"
  run_suite zig "$run" bash -c \
    'zig/build.sh && cd zig && ./benchmark "$@"' _ "${args[@]}"
  run_suite go "$run" bash -c \
    'go/build.sh && cd go && ./benchmark "$@"' _ "${args[@]}"
  run_suite bun "$run" bash -c \
    'cd bun && bun run benchmark.ts "$@"' _ "${args[@]}"
  run_suite gleam_sqlite "$run" bash -c \
    'cd gleam && gleam run "$@"' _ "${args[@]}"
  run_suite gleam_sqlite_sdio "$run" bash -c \
    'cd gleam && ERL_FLAGS="$SDIO_ERL_FLAGS" gleam run "$@"' _ "${args[@]}"
done

if [ "$mode" = concurrent ]; then
  ruby scripts/summarize_concurrent.rb "$out_dir" | tee "$out_dir/summary.md"
else
  ruby scripts/summarize_benchmarks.rb "$out_dir" | tee "$out_dir/summary.md"
fi

echo
echo "Wrote benchmark results to $out_dir"
