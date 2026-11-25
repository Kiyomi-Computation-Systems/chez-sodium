#!/bin/sh
# pages.yml's build steps on Ubuntu 24.04's Chez 9.5.8, in a copy, offline.
# $1: the copy's directory.
cd "$1" || exit 2
export CHEZ=chezscheme
echo "--- $1"
make -s check-site-deps >/dev/null 2>&1; echo "check-site-deps exit $?"
make -s site-deps; echo "site-deps exit $?"
SITE_REF=main make -s check-site 2>&1 | tail -1; echo "check-site main exit $?"
SITE_REF=v0.1.0 make -s check-site > ubuntu-check-site-tag.out 2>&1; echo "check-site v0.1.0 exit $?: $(tail -1 ubuntu-check-site-tag.out)"
rm -rf build/site; mkdir -p build/site
SITE_REF=v0.1.0 make -s site 2>&1 | tail -1; echo "site v0.1.0 exit $?"
grep -o 'git clone[^<]*' build/site/index.html
