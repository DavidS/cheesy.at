#!/bin/bash

set -e

cd /srv/cheesy.at/git/

git annex lock .
git commit -m "lock server" || true # if no changes
touch index.html
JEKYLL_ENV=production bundle exec jekyll build --strict --verbose --destination /srv/cheesy.at/site --incremental

echo "Build Successful"
