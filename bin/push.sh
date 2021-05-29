#!/bin/bash

set -e

git add -A .
git annex lock .
git annex sync --content