#!/usr/bin/ruby

require 'cgi'
require 'fileutils'
require 'net/http'
require 'nokogiri'
require 'scrapi'
require 'uri'
require 'yaml'
Scraper::Base.parser :html_parser

def src_path_from_url(url)
  url.gsub(%r{http://www.cheesy.at}, "/home/david/Projects/cheesy.at-backup")
end

def dst_path_from_path(path)
  File.join("/home/david/Projects/cheesy.at", "_#{path.gsub(%r{^/},"")}")
end

def lift_file(src, dst, original_source)
  $image_count += 1

  FileUtils.mkdir_p(File.dirname(dst))
  puts "cp(#{src}, #{dst}) #{$image_count}"
  FileUtils.cp(src, dst) unless File.exist?(dst) # don't overwrite file to avoid confusing git annex
  $image_map[original_source] = dst
end

$image_count = 0
$image_map = {}
at_exit { File.open('image_map.yaml', 'w') {|f| f.write(YAML.dump($image_map))} }

def gallery_scraper
  return @gallery_scraper if @gallery_scraper

  image = Scraper.define do
    process "img", img_url: "@src"
    process "a", a_url: "@href"

    result :img_url, :a_url
  end

  @gallery_scraper = Scraper.define do
    array :images
    process "li>figure", images: image
    process "div.rl-gallery-item-content", images: image

    result :images
  end

  @gallery_scraper
end

def scrape_gallery(path, page=nil)
  unless page
    url = "http://www.cheesy.at#{path}"
    puts "loading #{url}"
    page ||= Net::HTTP.get(URI.parse(url))
  end

  dst_path = dst_path_from_path(path)

  # File.open("/home/david/tmp/tmp.html", "w") {|f| f.write(page)}

  # puts "loaded #{page.length} characters"

  entries = gallery_scraper.scrape(page)

  entries&.each do |e|
    # puts "Original source: #{e.inspect}"

    img_url = e.img_url || ''
    a_url = e.a_url || img_url # init to img_url if empty to not confuse the check below

    # if one of the URLs is empty, use the other. otherwise use the shorter - assuming it's not a thumbnail render
    original_source = (img_url.empty? ? a_url : ((img_url.length < a_url.length) ? img_url : a_url ))
    e = URI.decode_www_form_component(original_source)
    # puts "Decoded: '#{e}'"
    e = src_path_from_url(e)

    lift_file(e, File.join(dst_path, File.basename(e)).gsub(%r{\.(JPG|jpeg)$}i, '.jpg'), original_source)

    # exit 1 if $image_count > 40
  end
end

def parse_index(page)
  parsed = Nokogiri::HTML(page)
  parsed.css('div.childlinkouter').map do |div|
    {
      url: div.css('a').first['href'],
      tn: div.css('img').first['src'],
    }
  end
end

def fetch_tn(e)
  return unless e && e[:url] && e[:tn]
  url = URI.parse(e[:url])
  tn = URI.parse(e[:tn])
  return unless tn.query
  tn_src = CGI::parse(tn.query)['src']
  src_url = File.join("http://www.cheesy.at", tn_src)
  src_path = src_path_from_url(src_url)
  dst_path = dst_path_from_path(File.join(url.path,'thumbnail.jpg'))

  lift_file(src_path, dst_path, src_url)
end

def scrape_index(url, visited = Set.new)
  return if visited.include? url
  visited << url

  puts "loading #{url}"
  uri = URI.parse(url)
  page = Net::HTTP.get(uri)
  puts "loaded #{page.length} characters"
  begin
    scrape_gallery(uri.path, page)
  # rescue StandardError => err
  #   puts "Failed #{uri.path} with #{err}"
  #   puts err.backtrace
  end

  entries = parse_index(page)

  # require'pry';binding.pry
  folders = entries.find_all{|e| e[:url].start_with?(url) && e[:url] !~ %r{/#comment} }.uniq
  folders.each do |e|
    scrape_index(e[:url], visited)
    fetch_tn(e)
  end
end

path = ARGV[0]
scrape_index('http://www.cheesy.at/rezepte/')
scrape_index('http://www.cheesy.at/fotos/')
# scrape_index('http://www.cheesy.at/fotos/ausfluege/2021-2/')
# require "pry"; binding.pry
