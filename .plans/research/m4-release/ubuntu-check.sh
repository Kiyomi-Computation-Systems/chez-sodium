#!/bin/bash
# pages.yml's build steps on Ubuntu 24.04's Chez, on the release branch's tree,
# copied from /src without build/: the packages from the site's list, then
# make site-deps, then check-site and site with SITE_REF=v0.1.0.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -q >/dev/null
packages=$(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' /src/packaging/debian-site-prereqs.txt)
apt-get install -y -q --no-install-recommends $packages >/dev/null
mkdir /w && cd /src && tar --exclude=./build --exclude=./.git -cf - . | tar -C /w -xf -
cd /w
export CHEZ=chezscheme
chezscheme --version
make -s site-deps
SITE_REF=v0.1.0 make -s check-site 2>&1 | tail -1
SITE_REF=v0.1.0 make -s site 2>&1 | tail -1
grep -o 'git clone[^<]*' build/site/index.html
grep -o 'blob/v0.1.0/[^"]*' build/site/*.html | sort -u | head -3
echo "UBUNTU DONE"
