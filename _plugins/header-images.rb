require 'jekyll'
require 'json'

class HeaderImages < Liquid::Tag
  def render(context)
    # require'pry';binding.pry
    JSON.generate(Dir.glob('assets/headers/*').map{|f| "#{context.registers[:site].config['baseurl']}/#{f}"})
  end
  Liquid::Template.register_tag('header_images', self)
end
