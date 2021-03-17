#!/usr/bin/ruby

require "fileutils"
require 'reverse_markdown'

DB_IMPORT = true
DB_TMP_DIR = '/home/david/tmp/cheesy-import'
TARGET_DIR = '/home/david/Projects/cheesy.at'
PRE_CLEAN = DB_IMPORT
POST_CLEAN = true

if DB_IMPORT
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
  Dir.chdir(TARGET_DIR) do
    # clean import directories
    ['fotos', 'rezepte', 'about'].each {|f| FileUtils.rm_rf(f) }
    # clean post-import locations
    ['_fotos', '_rezepte', 'about', '_posts'].each {|f| FileUtils.rm_rf(Dir.glob(File.join(f, '**', '*.html'))) }
    ['_fotos', '_rezepte', 'about', '_posts'].each {|f| FileUtils.rm_rf(Dir.glob(File.join(f, '**', '*.md'))) }
  end
end

if POST_CLEAN
  Dir.chdir(TARGET_DIR) do
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
    def image_from_link(src)
      src_files = $image_map.keys.filter { |k| k.dup.force_encoding('iso-8859-1').encode('utf-8').include?(src) }
      puts "#{src} has multiple matches: #{src_files.inspect}" if src_files.length > 1
      puts "#{src} has no matches" if src_files.length <1
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
      do_fix = File.file?(File.join(TARGET_DIR, fix)) # todo: during transformation of html, not all target files might be available yet. Do a second pass?
      subst = "#{m[:prefix]}{% link #{fix} %}#{m[:postfix]}"
      if do_fix
        puts "#{src} -> #{fix}"
        subst
      else
        puts "#{fix} (from #{src}) doesn't exist"
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

    def process_file(f, is_gallery)
      target = File.join(File.dirname(f), File.basename(f, '.html')) + '.md'
      target = target.gsub(DB_TMP_DIR, TARGET_DIR)
      target = target.gsub('/fotos/', '/_fotos/')
      target = target.gsub('/rezepte/', '/_rezepte/')
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
        puts "Writing converted file #{target} (from #{f})"
        file.write(YAML.dump(data))
        file.write("---\n")
        file.write(content)
      end
    end

    count = 0
    Dir[File.join(DB_TMP_DIR, 'fotos/**/*.html'), File.join(DB_TMP_DIR, 'rezepte/**/*.html')].each do |f|
      process_file(f, true)
      # break if (count+=1) > 10
    end

    count = 0
    Dir[File.join(DB_TMP_DIR, '_posts/**/*.html'), File.join(DB_TMP_DIR, 'about/**/*.html')].each do |f|
      process_file(f, false)
      # break if (count+=1) > 10
    end

    FileUtils.mv('about/index.md', 'about.md')

    # remove conflicting, empty rl_gallery post
    FileUtils.rm_f('_posts/2020-07-08-david-in-london.md')
  end
end
