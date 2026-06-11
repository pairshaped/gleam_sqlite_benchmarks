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

puts "# Benchmark Summary"
puts
puts "| Suite | Case | Runs | Median Time | Median us/item | Min Time | Max Time | Check |"
puts "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |"

groups.keys.sort.each do |suite, case_name|
  rows = groups[[suite, case_name]]
  micros = rows.map { |row| row[:micros] }
  us_per_item = rows.map { |row| row[:us_per_item] }
  checks = rows.map { |row| row[:check] }.uniq
  check = checks.length == 1 ? checks.first.to_s : checks.join(",")

  puts [
    suite,
    "`#{case_name}`",
    rows.length,
    median(micros).round,
    median(us_per_item).round,
    micros.min,
    micros.max,
    check,
  ].join(" | ").prepend("| ").concat(" |")
end

