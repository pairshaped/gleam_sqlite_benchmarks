#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"

out_dir = ARGV.fetch(0)
files = Dir.glob(File.join(out_dir, "*_run_*.csv")).sort

groups = Hash.new { |hash, key| hash[key] = [] }

files.each do |path|
  suite = File.basename(path).sub(/_run_\d+\.csv\z/, "")

  File.foreach(path) do |line|
    line = line.strip
    next if line.empty? || line == "case,items,micros,us_per_item,check"

    fields = CSV.parse_line(line) rescue nil
    next unless fields&.length == 5

    case_name, items, micros, us_per_item, check = fields
    next unless micros&.match?(/\A\d+\z/)

    groups[[suite, case_name]] << {
      items: items.to_i,
      micros: micros.to_i,
      us_per_item: us_per_item.to_i,
      check: check.to_i,
    }
  end
end

def median(values)
  sorted = values.sort
  mid = sorted.length / 2

  if sorted.length.odd?
    sorted[mid]
  else
    (sorted[mid - 1] + sorted[mid]) / 2.0
  end
end

def case_type(case_name)
  case_name.split("/").last
end

def suite_rank(suite)
  {
    "rust" => 0,
    "gleam_sqlite" => 1,
    "gleam_postgres" => 2,
    "ruby" => 3,
  }.fetch(suite, 9)
end

def case_rank(case_name, type)
  order = [
    "rust_rusqlite/app_request/#{type}",
    "rust_marmot/app_request/#{type}",
    "rust_sqlx/app_request/#{type}",
    "rust_sqlx_pool1/app_request/#{type}",
    "rust_sqlx_conn/app_request/#{type}",
    "rust_sqlx_direct/app_request/#{type}",
    "rust_sqlx_direct_tuned/app_request/#{type}",
    "rust_sqlx_manual_tx/app_request/#{type}",
    "app_request/#{type}",
    "gleam_marmot/app_request/#{type}",
    "batched_request/#{type}",
    "active_record/app_request/#{type}",
  ]

  order.index(case_name) || (case_name.start_with?("probed_") ? 80 : 50)
end

def benchmark_case?(case_name)
  !case_name.start_with?("io/", "scheduler/")
end

def multiplier(value, baseline)
  return "" unless baseline

  ratio = value.to_f / baseline
  return "<0.1x" if ratio.positive? && ratio < 0.05

  format("%.1fx", ratio)
end

def format_integer(value)
  value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

def format_requests_per_second(items, micros)
  format_integer((items * 1_000_000.0 / micros).round)
end

summaries = groups.keys.sort.map do |suite, case_name|
  rows = groups[[suite, case_name]]
  items = rows.map { |row| row[:items] }
  micros = rows.map { |row| row[:micros] }
  us_per_item = rows.map { |row| row[:us_per_item] }
  checks = rows.map { |row| row[:check] }.uniq

  if benchmark_case?(case_name) && checks.length > 1
    warn "check mismatch for #{suite} #{case_name}: #{checks.join(",")}"
  end

  {
    suite: suite,
    case_name: case_name,
    type: case_type(case_name),
    runs: rows.length,
    median_items: median(items).round,
    median_micros: median(micros).round,
    median_us_per_item: median(us_per_item).round,
    min_us_per_item: us_per_item.min,
    max_us_per_item: us_per_item.max,
  }
end

puts "# Benchmark Summary"
puts
puts "Timing values are average microseconds per item from each benchmark run."

benchmark_summaries = summaries.select { |row| benchmark_case?(row[:case_name]) }

benchmark_summaries.group_by { |row| row[:type] }.sort.each_with_index do |(type, rows), index|
  puts unless index.zero?
  puts
  puts "## `#{type}`"
  puts
  puts "| Suite | Case | Runs | Median Time (us/item) | vs `rusqlite` | req/sec | Min Time (us/item) | Max Time (us/item) |"
  puts "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |"

  baseline = rows.find do |row|
    row[:suite] == "rust" && row[:case_name] == "rust_rusqlite/app_request/#{type}"
  end&.fetch(:median_micros)

  rows.sort_by { |row|
    [suite_rank(row[:suite]), case_rank(row[:case_name], type), row[:case_name]]
  }.each do |row|
    puts [
      row[:suite],
      "`#{row[:case_name]}`",
      row[:runs],
      format_integer(row[:median_us_per_item]),
      benchmark_case?(row[:case_name]) ? multiplier(row[:median_micros], baseline) : "",
      format_requests_per_second(row[:median_items], row[:median_micros]),
      format_integer(row[:min_us_per_item]),
      format_integer(row[:max_us_per_item]),
    ].join(" | ").prepend("| ").concat(" |")
  end
end
