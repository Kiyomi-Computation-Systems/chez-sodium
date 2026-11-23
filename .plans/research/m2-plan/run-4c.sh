#!/bin/sh
# Item 4: abc/empty hashes and the reference's keyed KAT through libsodium, at
# 1.0.18, 1.0.22, and the workstation package's 1.0.18.
#   scripts/guix-env sh build/m2-plan/run-4c.sh
set -u
cd "$(dirname "$0")" || exit 2
for lib in ../slice5/prefix-1.0.18/lib/libsodium.so.23 ../slice5/prefix-1.0.22/lib/libsodium.so.26 ../m1-plan/host-1.0.18/libsodium.so.23; do
  echo "######## $lib"
  "$CHEZ" --program kat.sps "$lib" vectors/blake2b-kat.txt
done
