#!/usr/bin/ruby

require 'fileutils'
require 'net/http'
require 'scrapi'
require 'uri'
Scraper::Base.parser :html_parser

def gallery_scraper
  return @gallery_scraper if @gallery_scraper

  image = Scraper.define do
    process "a", url: "@href"

    result :url
  end

  @gallery_scraper = Scraper.define do
    array :images
    process "figure", images: image

    result :images
  end

  @gallery_scraper
end

def scrape_gallery(path, page=nil)
  url = "http://www.cheesy.at#{path}"
  puts "loading #{url}"

  src_path = "/home/david/Projects/cheesy.at-backup"
  dst_path = File.join("/home/david/Projects/cheesy.at", path)

  page ||= Net::HTTP.get(URI.parse(url))

  # File.open("/home/david/tmp/tmp.html", "w") {|f| f.write(page)}

  puts "loaded #{page.length} characters"

  entries = gallery_scraper.scrape(page)

  entries&.each do |e|
    e.gsub!(%r{http://www.cheesy.at}, src_path)

    puts "cp(#{e}, #{dst_path})"
    # FileUtils.cp(e, dst_path)
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

def scrape_index(url = 'http://www.cheesy.at/fotos/', visited = Set.new)
  return if visited.include? url
  visited << url

  puts "loading #{url}"
  uri = URI.parse(url)
  page = Net::HTTP.get(uri)
  puts "loaded #{page.length} characters"
  scrape_gallery(uri.path, page)

  entries = index_scraper.scrape(page)

  folders = entries.find_all{|e| e.start_with?(url) && e !~ %r{/#comment} }.uniq
  folders.each do |e|
    scrape_index(e, visited)
  end
end

path = ARGV[0]
scrape_index()

# require "pry"; binding.pry
