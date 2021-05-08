#!/usr/bin/ruby

require "cgi"
require "fileutils"
require "net/http"
require "nokogiri"
require "parallel"
require "reverse_markdown"
require "uri"
require 'pathname'

DB_IMPORT = false
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
  start = Time.new
  Dir.chdir(DB_TMP_DIR) do
    require "jekyll-import"
    JekyllImport::Importers::WordPress.run({
                                             "dbname" => "cheesy_wp",
                                             "user" => "cheesy",
                                             "password" => ENV["DB_PASS"],
                                             "host" => "127.0.0.1",
                                             "port" => "3306",
                                             "socket" => "",
                                             "table_prefix" => "",
                                             "site_prefix" => "",
                                             "clean_entities" => true,
                                             "comments" => true,
                                             "categories" => true,
                                             "tags" => true,
                                             "more_excerpt" => true,
                                             "more_anchor" => true,
                                             "extension" => "html",
                                             "status" => ["publish"]
                                           })
  end
  puts "Finished db import in #{Time.new - start} seconds"

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
    ['fotos', 'rezepte', 'about'].each { |f| FileUtils.rm_rf(f) }
    # clean post-import locations
    ['_fotos', '_rezepte', 'about', '_posts'].each { |f| FileUtils.rm_rf(Dir.glob(File.join(f, '**', '*.html'))) }
    ['_fotos', '_rezepte', 'about', '_posts'].each { |f| FileUtils.rm_rf(Dir.glob(File.join(f, '**', '*.md'))) }
  end
end

INPUT_GALLERIES = Dir[File.join(DB_TMP_DIR, 'fotos/**/*.html'), File.join(DB_TMP_DIR, 'rezepte/**/*.html')]
INPUT_POSTS = Dir[File.join(DB_TMP_DIR, '_posts/**/*.html'), File.join(DB_TMP_DIR, 'about/**/*.html')]
INPUT_DOWNLOADS = Dir[File.join(BACKUP_DIR, 'download/**')].filter { |f| Dir.exist?(f) }

def base_img(f)
  f.gsub(%r{(-\d+x\d+)?\.jpe?g$}i, '.jpg')
end

def uncompressed_img(f)
  f.gsub(%r{-\d+x\d+\.}i, '.')
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
  target = Dir.exist?(f) ? f : File.join(File.dirname(f), File.basename(f, '.html')) + '.md'
  target = target.gsub(DB_TMP_DIR, TARGET_DIR)
  target = target.gsub(BACKUP_DIR, TARGET_DIR)
  target = target.gsub('/fotos/', '/_fotos/')
  target = target.gsub('/rezepte/', '/_rezepte/')
  return target
end

def fetch_content(uri, count = 1)
  if count > 10
    raise "loop detected: #{uri}"
  end

  response = Net::HTTP.get_response(uri)
  if response['Location'].nil?
    if response.content_type == 'text/html'
      return response.body
    else
      return ""
    end
  else
    return fetch_content(URI.parse(response['Location']), count + 1)
  end
end

def get_content(uri, cache_key)
  cache = File.join(CACHE_TMP_DIR, cache_key.to_s)
  content = ""
  if File.exist?(cache)
    # LOG_FILE.puts("#{cache_key}: hit")
    content = File.read(cache)
  else
    content = fetch_content(uri)
    # puts "#{cache_key}: loaded #{content.length} characters"
    File.write(cache, content)
  end
  content
end

def get_content_from_wpid(wpid)
  uri = URI.parse("http://www.cheesy.at/?page_id=#{wpid}")
  content = get_content(uri, "#{wpid}.html")
  content
end

if IMG_CLEAN
  FILE_LIST = Dir[File.join(BACKUP_DIR, 'wp-content/uploads/**/*')]
  # # compute a hash of all files, pointing to their uncompressed
  # FILE_HASH = FILE_LIST.map {|f| {f => uncompressed_img(f)} }.reduce({}) {|memo, obj| memo.merge(obj)}
  # LOG_FILE.puts FILE_HASH.to_yaml
  FILE_HASH = {}
  FILE_LIST.each do |f|
    key = f.downcase
    key = key.gsub(BACKUP_DIR, '')
    FILE_HASH[key] = f
    key = key.gsub(%r{.jpe?g$}i, '')
    FILE_HASH[key] = f
  end

  def backup_from_wppath(wpid, wppath)
    src_path = wppath
    src_path = URI.decode_www_form_component(src_path)
    src_path = uncompressed_img(src_path)
    src_path = File.join(BACKUP_DIR, src_path)
    # require'pry';binding.pry if src_path =~ %r{IMG_2409}i
    # sources = Dir.glob(src_path)
    # sources = FILE_HASH[src_path]&.filter {|f| File.fnmatch(src_path, f)} || []
    # require'pry';binding.pry
    if File.exist?(src_path)
      return src_path
    else
      # LOG_FILE.puts "#{wpid}: missing #{src_path}"
      # require'pry';binding.pry if wpid == 2022
      fuzzy_matches = FILE_HASH[src_path.downcase.gsub(%r{.jpe?g$}i, '')]
      if fuzzy_matches
        # LOG_FILE.puts "#{wpid}: missing #{src_path} found replacement #{fuzzy_matches}"
        return fuzzy_matches
      else
        LOG_FILE.puts "#{wpid}: missing #{src_path}, replacement invalid: #{fuzzy_matches.inspect}"
        return nil
      end
    end
  end

  puts "Identifying images"
  # FileUtils.rm_rf(CACHE_TMP_DIR)
  FileUtils.mkdir(CACHE_TMP_DIR) unless File.exist?(CACHE_TMP_DIR)

  def images_from(wpid)
    content = get_content_from_wpid(wpid)
    parsed = Nokogiri::HTML(content)
    parsed.css('img')
          .to_a
          .filter { |img| img['class'] != 'logo' && img['src'] !~ %r{timthumb.php|responsive-lightbox-thumbnail-960x540.png} }
          .map { |img| img['src'] }
          .uniq
  end

  def retrieve_fotos(f, type, lift = false)
    target = target_from_import(f)

    images = if type == :downloads
               Dir["#{f}/**"].filter { |f| File.file?(f) }.map { |f| f.gsub(BACKUP_DIR, 'http://www.cheesy.at') }
             else
               html = Html.new(f)
               data = html.read_yaml('', '')
               wpid = data['wordpress_id']
               # puts "#{f}: #{wpid} -> #{target}"
               images_from(wpid)
             end

    # require'pry';binding.pry

    # dirname = File.dirname(f).gsub(DB_TMP_DIR, '')
    # # puts dirname
    # potential_tns = [ 'thumbnail.jpg', 'thumb.jpg', 'thumb1.jpg', 'thumb2.jpg', 'thumb3.jpg', 'thumb4.jpg', 'thumb5.jpg', 'thumb6.jpg', 'thumb7.jpg', 'thumb8.jpg', 'thumb9.jpg']
    # thumbnails = potential_tns.map { |f| backup_from_wppath(wpid, File.join(dirname, f))}.compact.filter { |f| File.exist?(f) }
    # LOG_FILE.puts "thumbnails for #{f}: #{thumbnails.inspect}" unless thumbnails.empty?
    # # LOG_FILE.flush
    # images += thumbnails

    count = 0
    return images.map do |i|
      img_uri = URI.parse(URI::DEFAULT_PARSER.escape(i))
      if img_uri.host == "www.cheesy.at"
        src_path = backup_from_wppath(wpid, i.gsub('http://www.cheesy.at', ''))
        next unless src_path

        count += 1
        tgt_path = if type == :gallery
                     File.join(File.dirname(target), File.basename(src_path).gsub(%r{(JPG|jpeg)$}i, 'jpg')).unicode_normalize
                   else
                     File.join(File.dirname(target), File.basename(f, '.html'), File.basename(src_path).gsub(%r{(JPG|jpeg)$}i, 'jpg')).unicode_normalize
                   end

        FileUtils.mkdir_p(File.dirname(tgt_path)) unless File.exist?(File.dirname(tgt_path))

        if $image_map.key?(src_path)
          nil
        elsif src_path =~ %r{/wp-content/uploads/(.*?_tn|thumbnail|thumb)\d*.jpg} && tgt_path.start_with?(TARGET_DIR)
          nil # skip lifting thumbnails
        else
          lift_file(src_path, tgt_path) if lift
          [src_path, tgt_path]
        end
      elsif img_uri.host =~ %r{gravatar.com}
        # skip
        nil
      else
        LOG_FILE.puts "#{wpid}: External image: #{img_uri}"
        nil
      end
    end.compact
    # LOG_FILE.puts "#{wpid}: loaded #{count} images (lifted: #{$lift_count})"
  end

  $image_map = {}
  images = Parallel.map(INPUT_GALLERIES, progress: 'processing gallery sources') do |f|
    retrieve_fotos(f, :gallery, false)
  end.reduce(&:+)
  $image_map.merge!(Hash[images])
  images = Parallel.map(INPUT_POSTS, progress: 'processing post sources') do |f|
    retrieve_fotos(f, :post, false)
  end.reduce(&:+)
  $image_map.merge!(Hash[images])
  images = Parallel.map(INPUT_DOWNLOADS, progress: 'processing downloads', in_processes: 0) do |f|
    retrieve_fotos(f, :downloads, false)
  end.reduce(&:+)
  # require'pry';binding.pry
  $image_map.merge!(Hash[images])
  $image_map = Hash[$image_map.map { |k, v| [k.gsub(BACKUP_DIR, ''), v] }.sort { |a, b| a.first <=> b.first }]
  LOG_FILE.puts("Processed gallery sources")
  File.write("image_map.yaml", $image_map.to_yaml)

  puts "Lifting images"
  Parallel.each(INPUT_GALLERIES, progress: 'Lifting galleries') do |f|
    retrieve_fotos(f, :gallery, true)
  end
  Parallel.each(INPUT_POSTS, progress: 'Lifting posts') do |f|
    retrieve_fotos(f, :post, true)
  end
  Parallel.each(INPUT_DOWNLOADS, progress: 'Lifting downloads', in_processes: 0) do |f|
    retrieve_fotos(f, :downloads, true)
  end
else
  $image_map = YAML.load(File.read("image_map.yaml"))
end

if POST_CLEAN
  puts("Cleaning posts")
  Dir.chdir(TARGET_DIR) do
    $wpid_map = Hash[Parallel.map(INPUT_GALLERIES + INPUT_POSTS, progress: 'wpid mapping') { |f|
      html = Html.new(f)
      data = html.read_yaml('', '')
      [data['wordpress_id'], target_from_import(f)]
    }]

    def fix_data(data)
      data['categories'] ||= []
      data['categories'] += (data['tags'] || [])
      data.delete('tags')

      data['categories'] = data['categories'].map { |str| fix_entities(str) }
      data['title'] = fix_entities(data['title'])

      data
    end

    # finds the image for a given link
    # $image_map = YAML.load(File.read("image_map.yaml"))
    def image_from_link(src)
      src_files = $image_map[uncompressed_img(URI.decode_www_form_component(src))]
      # LOG_FILE.puts "#{src} has multiple matches: #{src_files.inspect}" if src_files.length > 1
      LOG_FILE.puts "#{src} has no matches (tried #{uncompressed_img(URI.decode_www_form_component(src))})" if src_files.nil?
      src_files || src
    end

    def get_wpid(path)
      uri = URI.parse("http://www.cheesy.at#{URI::DEFAULT_PARSER.escape(path)}")
      cache_key = "#{path.gsub(%r{[^a-z0-9]}i, '_')}.wpid"
      content = get_content(uri, cache_key)

      # puts "starting parse for #{uri} (#{content.length} bytes)"
      parsed = Nokogiri::HTML(content)
      shortlinks = parsed.css('link[rel=shortlink]')
                         .to_a
                         .map { |link| URI.parse(link['href']) }
                         .uniq

      # puts "#{uri} => #{shortlinks.inspect}" if shortlinks.length > 0
      if shortlinks.length == 1
        wpid = CGI.parse(shortlinks[0].query)['p'].first.to_i
      end

      wpid = nil if wpid == 0 || wpid == ""
      return wpid
    end

    def fix_link_match(m)
      src = m[:path]
      fix = src
      fix = image_from_link(fix) if fix.downcase.end_with?('.jpg') || fix.downcase.end_with?('.jpeg')
      fix = fix.gsub(%r{\.html$}, '.md')
      fix = fix.gsub(%r{/$}, '/index.md')
      fix = fix.gsub(%r{^/en/}, '/')
      fix = fix.gsub(%r{^/(fotos|rezepte)/}, '_\1/')
      # TODO: fix links to /download/
      unless File.exist?(fix)
        wpid = get_wpid(src)
        canonical = $wpid_map[get_wpid(src)] unless wpid.nil?
        fix = canonical unless canonical.nil?
      end
      fix = fix.unicode_normalize
      do_fix = File.exist?(fix) # todo: during transformation of html, not all target files might be available yet. Do a second pass?
      fix = fix.gsub("#{TARGET_DIR}/", '')
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
      content = content.gsub(%r{(?<prefix>\]\()http://www.cheesy.at(?<path>/[^)"]+)(?<postfix>( ".*?")?\))}) { |m| fix_link_match(Regexp.last_match) }
      content = content.gsub(%r{(?<prefix>src=")http://www.cheesy.at(?<path>/[^)"]+)(?<postfix>")}) { |m| fix_link_match(Regexp.last_match) }
      # rebase all links to jekyll links
      # content = content.gsub(%r{http://www.cheesy.at([^) \n]*).html}, "{% link \\1.md %}")
      # content = content.gsub(%r{http://www.cheesy.at([^) \n]*)/}, "{% link \\1/index.md %}")
      # content = content.gsub(%r{http://www.cheesy.at([^) \n]*)/}, "{% link \\1/index.md %}")
      # content = content.gsub(%r{http://www.cheesy.at([^) \n]*)}, "{% link \\1/index.md %}")
      # fix thumbnail links
      # [![](http://www.cheesy.at/wp-content/uploads/*_tn.jpg)]({% link _fotos/**/index.md %})
      content = content.gsub(%r{(?<prefix>\[!\[\]\()(?<thumbpath>http://www.cheesy.at/wp-content/uploads/.*?_tn.jpg)(?<postfix>( ".*?")?\)\]\({% link (?<gallerypath>_fotos/.*?)/index.md %})}) do |match|
        m = Regexp.last_match
        # thumbpath = m[:thumbpath]
        gallerypath = m[:gallerypath]
        "#{m[:prefix]}{% link #{gallerypath}/thumbnail.jpg }#{m[:postfix]}"
      end
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
      data = fix_data(html.read_yaml('', ''))
      if data['layout'] == 'rl_gallery' && html.content == ''
        # just don't create it in the new place # FileUtils.rm_f(f)
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

    # count = 0
    Parallel.each(INPUT_GALLERIES, progress: 'processing galleries') do |f|
      process_file(f, true)
      # count += 1
      # break if count > 10
    end
    # LOG_FILE.puts("Processed #{count} files")

    count = 0
    Parallel.each(INPUT_POSTS, progress: 'processing posts') do |f|
      process_file(f, false)
      # count += 1
      # break if count > 10
    end
    # LOG_FILE.puts("Processed #{count} files")

    # repair some overlap
    FileUtils.mv('about/index.md', 'about.md')

    # remove conflicting, empty rl_gallery post
    FileUtils.rm_f('_posts/2020-07-08-david-in-london.md')
  end
end
