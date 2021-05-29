#!/bin/bash

set -e

git annex lock .
git commit -m "lock server" || true # if no changes
JEKYLL_ENV=production bundle exec jekyll build --strict --verbose --destination /srv/cheesy.at/site --incremental

echo "Build Successful"