#!/usr/bin/ruby
# frozen_string_literal: true

require "cgi"
require "fileutils"
require "net/http"
require "nokogiri"
require "parallel"
require "reverse_markdown"
require "uri"
require "pathname"

DB_TMP_DIR = "/home/david/tmp/cheesy-import"
CACHE_TMP_DIR = "/home/david/tmp/cheesy-cache"
TARGET_DIR = "/home/david/Projects/cheesy.at"
BACKUP_DIR = "/home/david/Projects/cheesy.at-backup"

require "jekyll"
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


def unfigure(content)
  parsed = Nokogiri::HTML(content)
  require'pry';binding.pry
  parsed.css('figure.wp-block-embed-wordpress').to_a.map do |fig|
    # parent = fig.parent
    fig.children.reverse.each do |child|
      if child.name == 'figcaption'
        fig.add_next_sibling(child.children)
      else
        fig.add_next_sibling(child)
      end
    end
    fig.unlink
  end

  parsed.css('div.wp-block-embed__wrapper').to_a.map do |fig|
    # parent = fig.parent
    fig.children.reverse.each do |child|
      fig.add_next_sibling(child)
    end
    fig.unlink
  end
end

f = File.join(TARGET_DIR, '_test_site/_fotos/arbeit/2015-2022-puppet/2021-2/ernte/index.md')
html = Html.new(f)
html.read_yaml("", "")
puts unfigure(html.content)
