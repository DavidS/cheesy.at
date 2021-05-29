#!/bin/bash

set -e

git annex lock .

JEKYLL_ENV=production bundle exec jekyll build --strict --verbose --destination /srv/cheesy.at/site --incremental