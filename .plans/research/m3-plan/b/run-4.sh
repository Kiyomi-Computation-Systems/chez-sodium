#!/bin/sh
#   scripts/guix-env sh build/m3-plan/b/run-4.sh > build/m3-plan/b/run-4.out
cd "$(dirname "$0")" || exit 2
for lib in ../../slice5/prefix-1.0.18/lib/libsodium.so.23 "$CHEZ_SODIUM_LIBRARY"; do
  echo "== $(basename "$lib")"
  "$CHEZ" --program types4.sps "$(cd "$(dirname "$lib")" && pwd)/$(basename "$lib")" 2>&1
done
