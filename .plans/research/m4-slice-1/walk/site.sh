#!/bin/bash
# The site job's steps, then pages.yml's build job with SITE_REF=v0.1.0, in a
# fresh ubuntu:24.04 with Ubuntu's Chez, as CI's site job and pages.yml run.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -q && apt-get install -y -q git
cd /root
git clone --recursive --branch "$BRANCH" https://github.com/Kiyomi-Computation-Systems/chez-sodium.git
cd chez-sodium
packages=$(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' packaging/debian-site-prereqs.txt)
apt-get install -y --no-install-recommends $packages
export CHEZ=chezscheme
chezscheme --version
make check-site-deps
make site-deps
make check-site
make site
echo "== pages.yml build, SITE_REF=v0.1.0"
SITE_REF=v0.1.0 make check-site
SITE_REF=v0.1.0 make site
grep -o 'blob/v0.1.0/[^"]*' build/site/*.html | sort -u | head
echo "SITE DONE"
