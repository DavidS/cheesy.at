#!/bin/bash

set -ex

rsync -avz --delete david@hosting.edv-bus.at:/srv/cheesy/apps/www/ /home/david/Projects/cheesy.at-backup/
