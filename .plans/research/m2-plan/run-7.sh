#!/bin/sh
# Keyed hashes whose key length is not their size, on all four libraries.
#   scripts/guix-env sh build/m2-plan/run-7.sh
set -u
cd "$(dirname "$0")" || exit 2
for lib in ../slice5/prefix-1.0.18/lib/libsodium.so.23 ../slice5/prefix-1.0.22/lib/libsodium.so.26 "$CHEZ_SODIUM_LIBRARY" ../m1-plan/host-1.0.18/libsodium.so.23; do
  "$CHEZ" --program keyed.sps "$lib"
done
exit 0
