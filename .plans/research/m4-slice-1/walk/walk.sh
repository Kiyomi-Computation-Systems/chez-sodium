#!/bin/bash
# The walk as a reader: docs/quickstart.md's steps in a fresh ubuntu:24.04,
# run as root. Deviations from the page: sudo is installed first (the image
# has none), apt-get takes -y (no one answers its prompt), version= names the
# Chez release, and the clone names the branch under test.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -q && apt-get install -y -q sudo
cd /root
sudo apt-get update
sudo apt-get install -y build-essential ca-certificates curl git libsodium23
version=10.4.0
curl -fLO https://github.com/cisco/ChezScheme/releases/download/v$version/csv$version.tar.gz
tar xzf csv$version.tar.gz
cd csv$version
./configure --disable-x11 --disable-curses
make
sudo make install
cd ..
git clone --branch "$BRANCH" https://github.com/Kiyomi-Computation-Systems/chez-sodium.git
cp /walk/app.sps /walk/which.sps .
echo "== app.sps"; scheme --libdirs chez-sodium/src --program app.sps
echo "== which.sps"; scheme --libdirs chez-sodium/src --program which.sps
echo "== which.sps, a missing override"; CHEZ_SODIUM_LIBRARY=/no/such/libsodium.so.23 scheme --libdirs chez-sodium/src --program which.sps
echo "== make build"; make -C chez-sodium build
sudo apt-get install -y libsodium-dev valgrind
cd chez-sodium
git submodule update --init --recursive
make test 2>&1 | tail -3
echo "WALK DONE"
