#!/bin/sh
# NULL pointers into crypto_generichash and sodium_memcmp, one process per case.
#   scripts/guix-env sh build/m2-plan/run-6.sh
cd "$(dirname "$0")" || exit 2
for lib in ../slice5/prefix-1.0.18/lib/libsodium.so.23 ../slice5/prefix-1.0.22/lib/libsodium.so.26; do
  echo "######## $lib"
  for c in key0 in0 key16 in3 cmp0 cmp4; do
    out=$("$CHEZ" --program nullptr.sps "$lib" $c 2>&1); st=$?
    echo "$c: exit $st; $(echo "$out" | head -2 | tr '\n' ' ')"
  done
done
