#!/bin/bash

set -xe

rm -Rf /home/david/tmp/cheesy-import /home/david/tmp/cheesy-cache

rm -Rf /home/david/Projects/cheesy.at/{_fotos,_rezepte,_posts,about,download,gaestebuch}*

./bin/backup.sh

bundle exec ./bin/import.rb

git add -A .

git annex lock .

git status
