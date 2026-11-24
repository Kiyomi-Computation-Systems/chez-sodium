#!/bin/sh
# Item 4: constants, bound in Chez on four libraries; header macros in C at both releases.
#   scripts/guix-env sh -c 'export C_INCLUDE_PATH=$PWD/build/slice5/prefix-1.0.18/include:$C_INCLUDE_PATH; sh build/m3-plan/a/run-3.sh'
set -u
cd "$(dirname "$0")" || exit 2
for lib in ../../slice5/prefix-1.0.18/lib/libsodium.so.23 ../../slice5/prefix-1.0.22/lib/libsodium.so.26 "$CHEZ_SODIUM_LIBRARY" ../../m1-plan/host-1.0.18/libsodium.so.23; do
  echo "################ $lib"
  "$CHEZ" --program consts.sps "$lib"
done
for v in 1.0.18 1.0.22; do
  echo "################ macros at $v"
  ${CC:-cc} -Wall -Werror -std=c11 -I../../slice5/prefix-$v/include macros.c -o macros-$v -L../../slice5/prefix-$v/lib -lsodium && LD_LIBRARY_PATH=../../slice5/prefix-$v/lib ./macros-$v
done
