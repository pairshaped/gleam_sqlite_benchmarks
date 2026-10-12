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
    "c" => 0,
    "rust" => 1,
    "zig" => 2,
    "go" => 3,
    "bun" => 4,
    "gleam_sqlite" => 5,
    "gleam_sqlite_sdio" => 6,
  }.fetch(suite, 9)
end

def case_rank(case_name, type)
  order = [
    "c_sqlite/app_request/#{type}",
    "rust_rusqlite/app_request/#{type}",
    "rust_rusqlite_query_only/app_request/#{type}",
    "zig_sqlite/app_request/#{type}",
    "go_ncruces/app_request/#{type}",
    "gleam_esqlite/app_request/#{type}",
    "bun_sqlite/app_request/#{type}",
  ]

  order.index(case_name) || 50
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

  if checks.length > 1
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

benchmark_summaries = summaries

benchmark_summaries.group_by { |row| row[:type] }.sort.each_with_index do |(type, rows), index|
  puts unless index.zero?
  puts
  puts "## `#{type}`"
  puts
  puts "| Suite | Case | Runs | Median Time (us/item) | vs C | req/sec | Min Time (us/item) | Max Time (us/item) |"
  puts "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |"

  baseline = rows.find do |row|
    row[:suite] == "c" && row[:case_name] == "c_sqlite/app_request/#{type}"
  end&.fetch(:median_micros)

  rows.sort_by { |row|
    [suite_rank(row[:suite]), case_rank(row[:case_name], type), row[:case_name]]
  }.each do |row|
    puts [
      row[:suite],
      "`#{row[:case_name]}`",
      row[:runs],
      format_integer(row[:median_us_per_item]),
      multiplier(row[:median_micros], baseline),
      format_requests_per_second(row[:median_items], row[:median_micros]),
      format_integer(row[:min_us_per_item]),
      format_integer(row[:max_us_per_item]),
    ].join(" | ").prepend("| ").concat(" |")
  end
end

steal = File.join(out_dir, "steal.csv")
if File.exist?(steal)
  rows = CSV.read(steal, headers: true)
  worst = rows.max_by { |row| row["steal_percent"].to_f }
  if worst && worst["steal_percent"].to_f.positive?
    puts
    puts "## CPU steal"
    puts
    puts "Share of CPU time the hypervisor gave to other tenants during each suite run."
    puts "Anything above zero means neighbours competed for the CPU; compare runs with"
    puts "high steal cautiously. Highest: #{worst["suite"]} run #{worst["run"]} at #{worst["steal_percent"]}%."
    puts
    puts "| Suite | Run | Steal |"
    puts "| --- | ---: | ---: |"
    rows.each { |row| puts "| #{row["suite"]} | #{row["run"]} | #{row["steal_percent"]}% |" }
  end
end
