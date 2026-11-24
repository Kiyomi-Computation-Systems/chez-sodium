#!/bin/sh
# Item 6: out of memory vs wrong password, at both tarball builds, under ulimit -v.
#   scripts/guix-env sh -c 'export C_INCLUDE_PATH=$PWD/build/slice5/prefix-1.0.18/include:$C_INCLUDE_PATH; sh build/m3-plan/a/run-5.sh'
set -u
cd "$(dirname "$0")" || exit 2
LIMIT_KB=${LIMIT_KB:-49152}     # 48 MiB of address space: 64 MiB cannot be had
for v in 1.0.18 1.0.22; do
  echo "######## libsodium $v (tarball build)"
  ${CC:-cc} -Wall -std=c11 -D_DEFAULT_SOURCE -I../../slice5/prefix-$v/include oom.c -o oom-$v -L../../slice5/prefix-$v/lib -lsodium || exit 1
  export LD_LIBRARY_PATH=../../slice5/prefix-$v/lib
  ./oom-$v mk hash64-$v.txt && echo "64 MiB hash made without a limit: $(cat hash64-$v.txt)"
  echo "== no limit (controls)"
  for c in str64 verify-big-right verify-big-wrong verify-decode-fail; do ./oom-$v $c hash64-$v.txt; done
  echo "== ulimit -v $LIMIT_KB KiB"
  for c in str-small verify-small-right str64 verify-big-right verify-small-wrong verify-big-wrong verify-garbage verify-decode-fail verify-m-huge; do
    ( ulimit -v $LIMIT_KB; ./oom-$v $c hash64-$v.txt ) || echo "$c: exit status $?"
  done
done
