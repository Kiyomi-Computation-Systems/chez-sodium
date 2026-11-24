#!/bin/sh
# Item 3: codes.sps at 1.0.18 (tarball), 1.0.22 (tarball), the profile's 1.0.22, the workstation package's 1.0.18.
#   scripts/guix-env sh build/m2-plan/run-3.sh
set -u
cd "$(dirname "$0")" || exit 2
for lib in ../slice5/prefix-1.0.18/lib/libsodium.so.23 ../slice5/prefix-1.0.22/lib/libsodium.so.26 "$CHEZ_SODIUM_LIBRARY" ../m1-plan/host-1.0.18/libsodium.so.23; do
  echo "################ $lib"
  "$CHEZ" --program codes.sps "$lib"
done
