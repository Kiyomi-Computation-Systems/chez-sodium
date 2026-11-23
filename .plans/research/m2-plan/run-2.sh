#!/bin/sh
# Item 2: the size functions at each version, the header's macros, and every
# randombytes* symbol each library exports.
#   scripts/guix-env sh build/m2-plan/run-2.sh
set -u
cd "$(dirname "$0")" || exit 2
for v in 1.0.18 1.0.22; do
  p=../slice5/prefix-$v
  lib=$(ls $p/lib/libsodium.so.2?)
  echo "######## $v ($lib)"
  echo "== macros.c (header of $v)"
  ${CC:-cc} -Wall -Werror -I$p/include macros.c -o macros-$v -L$p/lib -lsodium && LD_LIBRARY_PATH=$p/lib ./macros-$v
  echo "== sizes.sps"
  "$CHEZ" --program sizes.sps "$PWD/$lib"
  echo "== exported symbols matching randombytes (readelf)"
  readelf -Ws --dyn-syms $lib | awk '$4=="FUNC" && $7!="UND" {print $8}' | grep -i randombytes | sort
done
echo "######## the container's profile library and the workstation package's 1.0.18"
for lib in "$CHEZ_SODIUM_LIBRARY" "$PWD/../m1-plan/host-1.0.18/libsodium.so.23"; do
  echo "== $lib"; "$CHEZ" --program sizes.sps "$lib" | head -8
done
