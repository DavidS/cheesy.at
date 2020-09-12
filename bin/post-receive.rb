#!/usr/bin/env ruby

require "open3"

pushed_refs = $stdin.readlines

output, status = Open3.capture2e("git annex post-receive", stdin_data: pushed_refs.join("\n"))

Dir.chdir('/srv/cheesy.at/git')
system("bundle config set path /srv/cheesy.at/gems")
system("bundle install")
system("JEKYLL_ENV=production bundle exec jekyll build --strict --trace --destination /srv/cheesy.at/site --verbose --incremental")
