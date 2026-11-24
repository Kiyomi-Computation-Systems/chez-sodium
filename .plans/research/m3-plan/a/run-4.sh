#!/bin/sh
# Item 5: return codes through Chez's FFI on four libraries; argon2i string made in C first.
#   scripts/guix-env sh -c 'export C_INCLUDE_PATH=$PWD/build/slice5/prefix-1.0.18/include:$C_INCLUDE_PATH; sh build/m3-plan/a/run-4.sh'
set -u
cd "$(dirname "$0")" || exit 2
for v in 1.0.18 1.0.22; do
  ${CC:-cc} -Wall -Werror -std=c11 -I../../slice5/prefix-$v/include mk-argon2i.c -o mk-argon2i-$v -L../../slice5/prefix-$v/lib -lsodium || exit 1
  LD_LIBRARY_PATH=../../slice5/prefix-$v/lib ./mk-argon2i-$v argon2i-string-$v.txt || exit 1
done
cp argon2i-string-1.0.18.txt argon2i-string.txt   # the string is the same format at both
for lib in ../../slice5/prefix-1.0.18/lib/libsodium.so.23 ../../slice5/prefix-1.0.22/lib/libsodium.so.26 "$CHEZ_SODIUM_LIBRARY" ../../m1-plan/host-1.0.18/libsodium.so.23; do
  echo "################ $lib"
  "$CHEZ" --program codes.sps "$lib" argon2i-string.txt
done
