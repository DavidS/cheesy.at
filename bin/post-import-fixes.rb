#!/usr/bin/ruby

require "yaml"

$image_map = YAML.load(File.read("image_map.yaml"))

require 'jekyll'
class Site
  def config
    {}
  end
  def file_read_opts
    {}
  end
end
class Html
  include Jekyll::Convertible
  attr_accessor :path, :data, :content, :site
  def initialize(path)
    @path = path
    @site = Site.new
  end
end

def fix_data(data)
  data
end

def fix_links(content)
  content = content.gsub(%r{(src|href)="{{ site.baseurl }}([^"]*)"}) do |m|
    attr = $2
    src = $2
    src_files = $image_map.keys.filter { |k| k.dup.force_encoding('iso-8859-1').encode('utf-8').include?(src) }
    puts "#{src} has multiple matches: #{src_files.inspect}" if src_files.length > 1
    puts "#{src} has no matches" if src_files.length <1
    if src_files.length == 1
      tgt_file = $image_map[src_files[0]].gsub(%r{/home/david/Projects/cheesy.at/},'')
      fix = "${attr}=\"{% link #{tgt_file} %}\""
      puts "#{m} -> #{fix}"
      fix
    else
      m
    end
  end
  # content = content.gsub("http://www.cheesy.at", "{{ site.baseurl }}")
  content
end

def process_file(f, is_gallery)
  puts "Processing #{f}"
  html = Html.new(f)
  data = fix_data(html.read_yaml('',''))
  # if is_gallery
  #   data['layout'] = 'gallery'
  # end
  content = fix_links(html.content)
  File.open(f, 'wb') do |file|
    file.write(YAML.dump(data))
    file.write("---\n")
    file.write(content)
  end
end

count = 0
#Dir['_fotos/**/*.html', '_rezepte/**/*.html'].each do |f|
Dir['_rezepte/**/*.html'].each do |f|
  process_file(f, true)
  # break if (count+=1) > 10
end

count = 0
Dir['_posts/**/*.html'].each do |f|
  process_file(f, false)
  # break if (count+=1) > 10
end