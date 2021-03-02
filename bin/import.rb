#!/usr/bin/ruby

require "fileutils"
require 'reverse_markdown'

pre_clean = true
db_import = true
post_clean = true

if pre_clean
  # clean import directories
  ['fotos', 'rezepte', 'about'].each {|f| FileUtils.rm_rf(f) }
  # clean post-import locations
  ['_fotos', '_rezepte', 'about', '_posts'].each {|f| FileUtils.rm_rf(Dir.glob(File.join(f, '**', '*.html'))) }
  ['_fotos', '_rezepte', 'about', '_posts'].each {|f| FileUtils.rm_rf(Dir.glob(File.join(f, '**', '*.md'))) }
end

if db_import
  require "jekyll-import"
  JekyllImport::Importers::WordPress.run({
    "dbname"         => "cheesy_wp",
    "user"           => "cheesy",
    "password"       => ENV["DB_PASS"],
    "host"           => "127.0.0.1",
    "port"           => "3306",
    "socket"         => "",
    "table_prefix"   => "",
    "site_prefix"    => "",
    "clean_entities" => true,
    "comments"       => true,
    "categories"     => true,
    "tags"           => true,
    "more_excerpt"   => true,
    "more_anchor"    => true,
    "extension"      => "html",
    "status"         => ["publish"]
  })

  FileUtils.mv(Dir.glob('fotos/*'), '_fotos')
  FileUtils.mv(Dir.glob('rezepte/*'), '_rezepte')
end

if post_clean
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

    def relative_path
      @path
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

  $image_map = YAML.load(File.read("image_map.yaml"))
  def fix_links(content)
    content = content.gsub(%r{(src|href)="http://www.cheesy.at([^"]*)"}) do |m|
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
    target = File.join(File.dirname(f), File.basename(f, '.html')) + '.md'
    raise "#{target} (from #{f}) already exists" if File.exist?(target)
    html = Html.new(f)
    data = fix_data(html.read_yaml('',''))
    if is_gallery
      data['layout'] = 'gallery'
    end
    content = ReverseMarkdown.convert(fix_links(html.content))
    File.open(target, 'wb') do |file|
      file.write(YAML.dump(data))
      file.write("---\n")
      file.write(content)
    end
    FileUtils.rm_f(f)
  end

  count = 0
  Dir['_fotos/**/*.html', '_rezepte/**/*.html'].each do |f|
    process_file(f, true)
    # break if (count+=1) > 10
  end

  count = 0
  Dir['_posts/**/*.html'].each do |f|
    process_file(f, false)
    # break if (count+=1) > 10
  end
end
