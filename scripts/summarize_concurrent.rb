#!/usr/bin/env ruby
# frozen_string_literal: true

# Summarizes MODE=concurrent results: for each workload, median throughput and
# latency per language and worker count across runs.

require "csv"

dir = ARGV.fetch(0) { abort "usage: summarize_concurrent.rb <results-dir>" }

SUITE_ORDER = %w[c rust zig go bun gleam_sqlite gleam_sqlite_sdio].freeze
WORKLOADS = %w[read write mixed].freeze

groups = Hash.new { |hash, key| hash[key] = [] }

Dir.glob(File.join(dir, "*_run_*.csv")).sort.each do |path|
  suite = File.basename(path).sub(/_run_\d+\.csv\z/, "")
  CSV.foreach(path, headers: true) do |row|
    next unless row["case"]&.include?("/concurrent/")

    workload = row["case"].split("/").last
    groups[[suite, workload, row["workers"].to_i]] << {
      rps: row["requests_per_second"].to_f,
      p50: row["p50_us"].to_i,
      p99: row["p99_us"].to_i,
      max: row["max_us"].to_i,
      errors: row["errors"].to_i,
    }
  end
end

abort "no concurrent results in #{dir}" if groups.empty?

def median(values)
  sorted = values.sort
  mid = sorted.length / 2
  sorted.length.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
end

def format_integer(value)
  value.round.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

suites = groups.keys.map(&:first).uniq.sort_by { |suite| SUITE_ORDER.index(suite) || 99 }
workers = groups.keys.map(&:last).uniq.sort
runs = groups.values.map(&:length).max

def table(title, suites, workers, groups, workload, extra_header: nil)
  puts "### #{title}"
  puts
  header = ["Suite", *workers.map { |count| "#{count} worker#{count == 1 ? "" : "s"}" }]
  header << extra_header if extra_header
  puts "| #{header.join(" | ")} |"
  puts "| --- |#{" ---: |" * (header.length - 1)}"
  suites.each do |suite|
    cells = workers.map do |count|
      rows = groups[[suite, workload, count]]
      # Pass suite explicitly: yielding an array alone to a two-parameter block
      # would splat it.
      rows.empty? ? "" : yield(rows, suite)
    end
    cells << yield(nil, suite) if extra_header
    puts "| #{suite} | #{cells.join(" | ")} |"
  end
  puts
end

puts "# Concurrent Benchmark Summary"
puts
puts "Each worker has its own connection and runs the workload for the measured"
puts "duration. Values are medians across #{runs} run(s). Throughput is total"
puts "requests per second across all workers; latencies are per request in µs."

WORKLOADS.each do |workload|
  next unless groups.keys.any? { |(_, w, _)| w == workload }

  puts
  puts "## `#{workload}`"
  puts

  best_single = lambda do |suite|
    single = groups[[suite, workload, workers.first]]
    best = workers.filter_map do |count|
      rows = groups[[suite, workload, count]]
      median(rows.map { |row| row[:rps] }) unless rows.empty?
    end.max
    next "" if single.empty? || best.nil?

    format("%.1fx", best / median(single.map { |row| row[:rps] }))
  end

  table("Throughput (requests/sec, higher is better)", suites, workers, groups, workload,
        extra_header: "Best vs 1 worker") do |rows, suite|
    if rows.nil?
      best_single.call(suite)
    else
      format_integer(median(rows.map { |row| row[:rps] }))
    end
  end

  table("p99 latency (µs, lower is better)", suites, workers, groups, workload) do |rows|
    format_integer(median(rows.map { |row| row[:p99] }))
  end

  if groups.any? { |(_, w, _), rows| w == workload && rows.any? { |row| row[:errors].positive? } }
    table("Errors (failed requests, summed across runs)", suites, workers, groups,
          workload) do |rows|
      format_integer(rows.sum { |row| row[:errors] })
    end
  end

  next unless workload == "write"

  table("Max latency (µs): the longest any single write waited", suites, workers, groups,
        workload) do |rows|
    format_integer(median(rows.map { |row| row[:max] }))
  end
end

failures = File.join(dir, "failures.txt")
if File.exist?(failures)
  puts
  puts "## Failed suite runs"
  puts
  puts "These suite runs exited with an error, so their remaining points are missing:"
  puts
  File.readlines(failures, chomp: true).each { |line| puts "- #{line}" }
end
