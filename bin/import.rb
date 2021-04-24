#!/usr/bin/ruby

require "fileutils"
require "net/http"
require "nokogiri"
require "parallel"
require "reverse_markdown"
require "uri"

DB_IMPORT = true
DB_TMP_DIR = '/home/david/tmp/cheesy-import'
CACHE_TMP_DIR = '/home/david/tmp/cheesy-cache'
TARGET_DIR = '/home/david/Projects/cheesy.at'
BACKUP_DIR = '/home/david/Projects/cheesy.at-backup'
PRE_CLEAN = DB_IMPORT
IMG_CLEAN = true
POST_CLEAN = true

# FileUtils.rm_f('convert.log')
# LOG_FILE = File.open('convert.log', 'wb+')
LOG_FILE = File.open('convert.log', 'wb')

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

if DB_IMPORT
  puts("Starting DB import")
  FileUtils.rm_rf(DB_TMP_DIR)
  FileUtils.mkdir(DB_TMP_DIR)
  Dir.chdir(DB_TMP_DIR) do
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
  end

  # def safe_mv(glob)
  #   Dir.glob(glob).each do |f|
  #     dir = File.dirname(f)
  #     FileUtils.mkdir_p(dir)
  #     FileUtils.mv(f, '_' + f)
  #   end
  # end

  # safe_mv('fotos/**/*.html')
  # safe_mv('rezepte/**/*.html')
end

if PRE_CLEAN
  puts("pre cleaning")
  Dir.chdir(TARGET_DIR) do
    # clean import directories
    ['fotos', 'rezepte', 'about'].each {|f| FileUtils.rm_rf(f) }
    # clean post-import locations
    ['_fotos', '_rezepte', 'about', '_posts'].each {|f| FileUtils.rm_rf(Dir.glob(File.join(f, '**', '*.html'))) }
    ['_fotos', '_rezepte', 'about', '_posts'].each {|f| FileUtils.rm_rf(Dir.glob(File.join(f, '**', '*.md'))) }
  end
end

INPUT_GALLERIES = Dir[File.join(DB_TMP_DIR, 'fotos/**/*.html'), File.join(DB_TMP_DIR, 'rezepte/**/*.html')]
INPUT_POSTS = Dir[File.join(DB_TMP_DIR, '_posts/**/*.html'), File.join(DB_TMP_DIR, 'about/**/*.html')]

FILE_LIST = Dir[File.join(BACKUP_DIR, 'wp-content/uploads/**/*')]
FILE_HASH = FILE_LIST.group_by {|f| f.gsub(%r{(-\d+x\d+)?\.jpe?g$}i, '.[jJ]*') }
LOG_FILE.puts FILE_HASH.to_yaml

def backup_from_wppath(wpid, wppath)
  src_path = wppath
  src_path = URI.decode_www_form_component(src_path)
  src_path = src_path.gsub(%r{-\d+x\d+\.jpe?g$}i, '.[jJ]*')
  src_path = File.join(BACKUP_DIR, src_path)
  # require'pry';binding.pry if src_path.end_with?('IMG_3963.jpg')
  # sources = Dir.glob(src_path)
  sources = FILE_HASH[src_path]&.filter {|f| File.fnmatch(src_path, f)} || []
  # require'pry';binding.pry
  if sources.length == 1
    return sources[0]
  elsif sources.length > 1
    LOG_FILE.puts "#{wpid}: ambiguous casing - #{src_path} matches #{sources.length} files: #{sources.inspect}"
  else
    LOG_FILE.puts "#{wpid}: missing #{src_path}"
  end
end

$lift_count = 0
def lift_file(src, dst)
  FileUtils.mkdir_p(File.dirname(dst))
  unless File.exist?(dst) # don't overwrite file to avoid confusing git annex
    LOG_FILE.puts "cp(#{src}, #{dst})"
    FileUtils.cp(src, dst)
    $lift_count += 1
  end
end

def target_from_import(f)
  target = File.join(File.dirname(f), File.basename(f, '.html')) + '.md'
  target = target.gsub(DB_TMP_DIR, TARGET_DIR)
  target = target.gsub('/fotos/', '/_fotos/')
  target = target.gsub('/rezepte/', '/_rezepte/')
  return target
end

if IMG_CLEAN
  puts "Lifting images"
  # FileUtils.rm_rf(CACHE_TMP_DIR)
  FileUtils.mkdir(CACHE_TMP_DIR) unless File.exist?(CACHE_TMP_DIR)

  def images_from(wpid)
    uri = URI.parse("http://www.cheesy.at/?page_id=#{wpid}")
    cache = File.join(CACHE_TMP_DIR, "#{wpid}.html")
    content = ""
    if File.exist? cache
      # LOG_FILE.puts("#{wpid}: hit")
      content = File.read(cache)
    else
      # LOG_FILE.puts("#{wpid}: miss")
      # puts "#{wpid}: loading #{uri}"
      response = Net::HTTP.get_response(uri)
      # puts "#{wpid}: redirecting to #{response['Location']}"
      content = Net::HTTP.get(URI.parse(response['Location']))
      # puts "#{wpid}: loaded #{content.length} characters"
      File.write(cache, content)
    end
    parsed = Nokogiri::HTML(content)
    parsed.css('img').to_a
      .filter{|img| img['class'] != 'logo' && img['src'] !~ %r{timthumb.php} }
      .map {|img| img['src'] }
      .uniq
  end

  def retrieve_fotos(f)
    html = Html.new(f)
    data = html.read_yaml('','')
    wpid = data['wordpress_id']
    target = target_from_import(f)

    # puts "#{f}: #{wpid} -> #{target}"
    images = images_from(wpid)

    count = 0
    images.each do |i|
      img_uri = URI.parse(URI::DEFAULT_PARSER.escape(i))
      if img_uri.host == "www.cheesy.at"
        src_path = backup_from_wppath(wpid, i.gsub('http://www.cheesy.at', ''))
        next unless src_path
        count += 1
        tgt_path = File.join(File.dirname(target), File.basename(src_path).gsub(%r{(JPG|jpeg)$}i, 'jpg')).unicode_normalize
        lift_file(src_path, tgt_path)
      elsif img_uri.host =~ %r{gravatar.com}
        # skip
      else
        LOG_FILE.puts "#{wpid}: External image: #{img_uri}"
      end
    end
    # LOG_FILE.puts "#{wpid}: loaded #{count} images (lifted: #{$lift_count})"
  end

  count = 0
  Parallel.each(INPUT_GALLERIES, progress: 'processing gallery sources', in_threads: 16) do |f|
    count += 1
    # exit if count > 10
    retrieve_fotos(f)
  end
  LOG_FILE.puts("Processed #{count} gallery sources")
end

if POST_CLEAN
  puts("Cleaning posts")
  Dir.chdir(TARGET_DIR) do
    def fix_data(data)
      data['categories'] ||= []
      data['categories'] += (data['tags'] || [])
      data.delete('tags')

      data['categories'] = data['categories'].map {|str| fix_entities(str) }
      data['title'] = fix_entities(data['title'])

      data
    end

    # finds the image for a given link
    $image_map = YAML.load(File.read("image_map.yaml"))
    def image_from_link(src)
      src_files = $image_map.keys.filter { |k| k.dup.force_encoding('iso-8859-1').encode('utf-8').include?(src) }
      LOG_FILE.puts "#{src} has multiple matches: #{src_files.inspect}" if src_files.length > 1
      LOG_FILE.puts "#{src} has no matches" if src_files.length <1
      if src_files.length == 1
        src = $image_map[src_files[0]].gsub(%r{/home/david/Projects/cheesy.at/},'')
      end
      src
    end

    def fix_link_match(m)
      src = m[:path]
      fix = src
      fix = image_from_link(fix) if fix.end_with?('.jpg')
      fix = fix.gsub(%r{\.html$}, '.md')
      fix = fix.gsub(%r{/$}, '/index.md')
      fix = fix.gsub(%r{^/en/}, '/')
      fix = fix.gsub(%r{^/(fotos|rezepte)/}, '_\1/')
      fix = fix.unicode_normalize
      do_fix = File.file?(File.join(TARGET_DIR, fix)) # todo: during transformation of html, not all target files might be available yet. Do a second pass?
      subst = "#{m[:prefix]}{% link #{fix} %}#{m[:postfix]}"
      if do_fix
        LOG_FILE.puts "#{src} -> #{fix}"
        subst
      else
        LOG_FILE.puts "#{fix} (from #{src}) doesn't exist"
        m
      end
    end

    def fix_links(content)
      content = content.gsub(%r{(?<prefix>\]\()http://www.cheesy.at(?<path>/[^)"]+)(?<postfix>\))}) {|m| fix_link_match(Regexp.last_match) }
      content = content.gsub(%r{(?<prefix>src=")http://www.cheesy.at(?<path>/[^)"]+)(?<postfix>")}) {|m| fix_link_match(Regexp.last_match) }
      # rebase all links to jekyll links
      # content = content.gsub(%r{http://www.cheesy.at([^) \n]*).html}, "{% link \\1.md %}")
      # content = content.gsub(%r{http://www.cheesy.at([^) \n]*)/}, "{% link \\1/index.md %}")
      # content = content.gsub(%r{http://www.cheesy.at([^) \n]*)/}, "{% link \\1/index.md %}")
      # content = content.gsub(%r{http://www.cheesy.at([^) \n]*)}, "{% link \\1/index.md %}")
      # manual fixes
      content = content.gsub(%r{{% link /fotos.php\?lang=de&dir=fotos/alben/ShortTrips/2007-05-14-Tagebau-Hambach %}}, "{% link _fotos/arbeit/2006-2010-schlumberger/2007-2/juelich/otzenrath/index.md %}")
      # remove trailing whitespace
      content = content.gsub(%r{\s*\n}, "\n")
      content
    end

    # translate a file from Jekyll's importer HTML to markdown; cleaning up links etc in the process
    def process_file(f, is_gallery)
      target = target_from_import(f)
      raise "#{target} (from #{f}) already exists" if PRE_CLEAN && File.exist?(target)
      html = Html.new(f)
      data = fix_data(html.read_yaml('',''))
      if data['layout'] == 'rl_gallery' && html.content == ''
        # FileUtils.rm_f(f)
        return
      end
      if is_gallery
        data['layout'] = 'gallery'
      end
      # content = ReverseMarkdown.convert(fix_links(html.content))
      content = html.content.gsub('alt="" title="2007-08-Austria_tn"', '')
      content = ReverseMarkdown.convert(content)
      content = fix_links(content)
      FileUtils.mkdir_p(File.dirname(target))
      File.open(target, 'wb') do |file|
        LOG_FILE.puts "Writing converted file #{target} (from #{f})"
        file.write(YAML.dump(data))
        file.write("---\n")
        file.write(content)
      end
    end

    count = 0
    Parallel.each(Dir[File.join(DB_TMP_DIR, 'fotos/**/*.html'), File.join(DB_TMP_DIR, 'rezepte/**/*.html')], progress: 'processing galleries') do |f|
      process_file(f, true)
      count += 1
      # break if count > 10
    end
    LOG_FILE.puts("Processed #{count} files")

    count = 0
    Parallel.each(Dir[File.join(DB_TMP_DIR, '_posts/**/*.html'), File.join(DB_TMP_DIR, 'about/**/*.html')], progress: 'processing posts') do |f|
      process_file(f, false)
      count += 1
      # break if count > 10
    end
    LOG_FILE.puts("Processed #{count} files")

    # repair some overlap
    FileUtils.mv('about/index.md', 'about.md')

    # remove conflicting, empty rl_gallery post
    FileUtils.rm_f('_posts/2020-07-08-david-in-london.md')
  end
end
