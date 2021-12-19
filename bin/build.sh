#!/bin/bash

set -e

cd /srv/cheesy.at/git/

bundle check || bundle install
git annex lock .
git commit -m "lock server" || true # if no changes
JEKYLL_ENV=production bundle exec jekyll build --strict --verbose --destination /srv/cheesy.at/site 2>&1 | grep -ve '/srv/cheesy.at/gems/ruby/2.7.0|/usr/local/lib/ruby/2.7.0/bundler/cli/'

echo "Build Successful at" $(date --iso=s)
