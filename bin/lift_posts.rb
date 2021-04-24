#!/usr/bin/ruby

# - [x] sort and download images that are linked in blogposts
# - [x] sort and download images that are linked in blogposts
# - [x] re-use gallery images
# - [ ] detect and rewrite thumbnails

require 'fileutils'
require 'nokogiri'
require 'parallel'
require 'yaml'

DB_TMP_DIR = '/home/david/tmp/cheesy-import'
TARGET_DIR = '/home/david/Projects/cheesy.at'

LOG_FILE = File.open('lift.log', 'wb')

$image_map = YAML.load(File.read("image_map.yaml"))
def image_map_has?(src)
  src_files = $image_map.keys.filter { |k| k.dup.force_encoding('iso-8859-1').encode('utf-8').include?(src) }
  LOG_FILE.puts "#{src} has multiple matches: #{src_files.inspect}" if src_files.length > 1
  LOG_FILE.puts "#{src} has no matches" if src_files.length <1
  return src_files.length == 1
end

def image_map_missing?(src)
  !image_map_has?(src)
end

results = Parallel.map(Dir[File.join(DB_TMP_DIR, '_posts/**/*.html')], progress: 'crunching') do |post|
  result = {lifted: 0, reused: 0}
  LOG_FILE.puts post
  page = Nokogiri.parse(File.open(post, 'rb'))
  page.css('img').each do |img|
    src = img['src']
    next unless src =~ %r{www.cheesy.at}
    src = src.gsub(%r{-\d+x\d+\.jpg$}, '.jpg')

    if image_map_missing?(src)
      LOG_FILE.puts "need to lift #{src}"
      result[:lifted] += 1
    else
      LOG_FILE.puts "reuse #{src}"
      result[:reused] += 1
    end
  end
  result
end

results = results.reduce({lifted: 0, reused: 0}) do |agg, item|
  agg[:lifted] += item[:lifted]
  agg[:reused] += item[:reused]
  agg
end

pp(results)
LOG_FILE.puts(results.inspect)
