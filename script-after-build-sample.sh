#!/bin/sh

# $1: new build folder
# $2: current build folder

echo copy env files from "$2" to "$1"...
[ -r "$2/.env" ] \
  && cp "$2/.env" "$1/"
[ -r "$2/.htaccess" ] \
  && cp "$2/.htaccess" "$1/"

echo done after-build cleanup
