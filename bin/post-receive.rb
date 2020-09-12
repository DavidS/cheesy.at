#!/usr/bin/env ruby

require "open3"

pushed_refs = $stdin.readlines

output, status = Open3.capture2e("git annex post-receive", stdin_data: pushed_refs.join("\n"))

system("bundle install")
system("JEKYLL_ENV=production bundle exec jekyll build --strict --trace --destination /srv/cheesy.at/site --verbose --incremental")
