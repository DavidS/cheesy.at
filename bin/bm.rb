#!/usr/bin/env ruby
# frozen_string_literal: true

BACKUP_DIR = "/home/david/Projects/cheesy.at-backup"
FILE_LIST = Dir[File.join(BACKUP_DIR, "wp-content/uploads/**/*")]

TARGET = File.join(BACKUP_DIR, "wp-content/uploads/28.[jJ]*")

def key(f)
  f.gsub(%r{-\d+x\d+\.jpe?g$}i, ".[jJ]*")
end

FILE_HASH = FILE_LIST.group_by { |f| f.gsub(%r{(-\d+x\d+)?\.jpe?g$}i, ".[jJ]*") }

require "benchmark"
Benchmark.bm(7) do |x|
  x.report("glob:") { puts Dir.glob(TARGET).inspect }
  # x.report("fnmatch:") { FILE_LIST.filter {|f| File.fnmatch(TARGET, f) } }
  # x.report("filter:") { FILE_LIST.filter {|f| f =~ %r{#{File.join(BACKUP_DIR, 'wp-content/uploads/28.[jJ].*')}} } }
  x.report("key:") { puts FILE_HASH[TARGET]&.filter { |f| File.fnmatch(TARGET, f) }.inspect }
end

# if Dir.glob(TARGET) == FILE_HASH[TARGET]
#   puts "correct"
# else
#   puts "feck"
# end

# require'pry';binding.pry
