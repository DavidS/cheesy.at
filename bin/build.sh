#!/bin/bash

set -e

cd /srv/cheesy.at/git/

bundle check || bundle install
git annex lock .
git commit -m "lock server" || true # if no changes
JEKYLL_ENV=production bundle exec jekyll build --strict --verbose --destination /srv/cheesy.at/site 2>&1 | grep -vE '/srv/cheesy.at/gems|/usr/local/lib/ruby'

echo "Build Successful at" $(date --iso=s)
