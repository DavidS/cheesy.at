#!/usr/bin/ruby

require "fileutils"
# require "jekyll-import"

# ['_fotos', 'fotos', '_rezepte', 'rezepte', 'about', '_posts'].each {|f| FileUtils.rm_rf(f) }

# JekyllImport::Importers::WordPress.run({
#   "dbname"         => "cheesy_wp",
#   "user"           => "cheesy",
#   "password"       => ENV["DB_PASS"],
#   "host"           => "127.0.0.1",
#   "port"           => "3306",
#   "socket"         => "",
#   "table_prefix"   => "",
#   "site_prefix"    => "",
#   "clean_entities" => true,
#   "comments"       => true,
#   "categories"     => true,
#   "tags"           => true,
#   "more_excerpt"   => true,
#   "more_anchor"    => true,
#   "extension"      => "html",
#   "status"         => ["publish"]
# })

# FileUtils.mv('fotos', '_fotos')
# FileUtils.mv('rezepte', '_rezepte')

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

require 'htmlentities'
coder = HTMLEntities.new

define_method(:fix_entities) do |str|
  coder.decode(str)
end

def fix_data(data)
  data['categories'] ||= []
  data['categories'] += (data['tags'] || [])
  data.delete('tags')

  data['categories'] = data['categories'].map {|str| fix_entities(str) }
  data['title'] = fix_entities(data['title'])

  data
end

def fix_links(content)
  content = content.gsub("http://www.cheesy.at", "{{ site.baseurl }}")
  content
end

count = 0
Dir['_fotos/**/*.html', '_posts/**/*.html', '_rezepte/**/*.html'].each do |f|
  html = Html.new(f)
  data = html.read_yaml('','')
  File.open(f, 'wb') do |file|
    file.write(YAML.dump(fix_data(data)))
    file.write("---\n")
    file.write(fix_links(html.content))
  end
  # break if (count+=1) > 10
end
