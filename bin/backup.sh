#!/bin/bash

rsync -avz --delete david@hosting.edv-bus.at:/srv/cheesy/apps/www/ /home/david/Projects/cheesy.at-backup/
rsync -av --delete /home/david/Projects/cheesy.at-backup/download/ /home/david/Projects/cheesy.at/download/
