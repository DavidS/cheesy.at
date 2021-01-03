#!/usr/bin/ruby

require 'fileutils'
require 'net/http'
require 'scrapi'
require 'uri'
require 'yaml'
Scraper::Base.parser :html_parser

$image_count = 0
$image_map = {}
at_exit { File.open('image_map.yaml', 'w') {|f| f.write(YAML.dump($image_map))} }

def gallery_scraper
  return @gallery_scraper if @gallery_scraper

  image = Scraper.define do
    process "a", url: "@href"
    process "img", url: "@src"

    result :url
  end

  @gallery_scraper = Scraper.define do
    array :images
    process "div.rl-gallery-item-content", images: image
    process "li>figure", images: image

    result :images
  end

  @gallery_scraper
end

def scrape_gallery(path, page=nil)
  unless page
    url = "https://test.cheesy.at#{path}"
    puts "loading #{url}"
    page ||= Net::HTTP.get(URI.parse(url))
  end

  src_path = "/home/david/Projects/cheesy.at-backup"
  dst_path = File.join("/home/david/Projects/cheesy.at", "_#{path.gsub(%r{^/},"")}")

  # File.open("/home/david/tmp/tmp.html", "w") {|f| f.write(page)}

  # puts "loaded #{page.length} characters"

  entries = gallery_scraper.scrape(page)

  entries&.each do |e|
    # puts "Original source: #{e}"
    original_source = e
    e = URI.decode(e)
    e.gsub!(%r{http://www.cheesy.at}, src_path)

    $image_count += 1

    tgt = File.join(dst_path, File.basename(e)).gsub(%r{\.(JPG|jpeg)$}i, '.jpg')

    FileUtils.mkdir_p(File.dirname(tgt))
    puts "cp(#{e}, #{tgt}) #{$image_count}"
    FileUtils.cp(e, tgt)
    $image_map[original_source] = tgt
    # exit 1 if $image_count > 40
  end
end

def index_scraper
  return @index_scraper if @index_scraper

  # link = Scraper.define do
  #   process "a", url: "@href",
  #                title: "@title"

  #   result :url, :title
  # end

  @index_scraper = Scraper.define do
    # array :folder
    # array :texts
    # process "div.childlinkouter>div.childlinkinner", folder: link, texts: :text

    # result :folder, :texts

    array :url
    # array :title
    process "a", url: "@href"

    result :url
  end

  @index_scraper
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
  rescue StandardError => err
    puts "Failed #{uri.path} with #{err}"
  end

  entries = index_scraper.scrape(page)

  folders = entries.find_all{|e| e.start_with?(url) && e !~ %r{/#comment} }.uniq
  folders.each do |e|
    scrape_index(e, visited)
  end
end

path = ARGV[0]
scrape_index('http://www.cheesy.at/rezepte/')
scrape_index('http://www.cheesy.at/fotos/')
# require "pry"; binding.pry
