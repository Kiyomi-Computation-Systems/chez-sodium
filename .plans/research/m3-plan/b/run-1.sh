#!/bin/sh
# Item 1: pwhash cost, plain and under Valgrind (the gate's flags), on both libraries.
#   scripts/guix-env sh build/m3-plan/b/run-1.sh ; then python3 -I build/m3-plan/b/medians1.py
set -u
cd "$(dirname "$0")" || exit 2
VG="valgrind --error-exitcode=9 --leak-check=full --show-leak-kinds=definite --errors-for-leak-kinds=definite --child-silent-after-fork=yes -q"
FLOOR=../../slice5/prefix-1.0.18/lib/libsodium.so.23
: > run-1-raw.out
for libname in floor-1.0.18 profile-1.0.22; do
  if [ $libname = floor-1.0.18 ]; then LIB=$(cd "$(dirname $FLOOR)" && pwd)/libsodium.so.23; else LIB=$CHEZ_SODIUM_LIBRARY; fi
  # limits: name ops mem plainreps vgreps plainruns vgruns
  for spec in "min 1 8192 1000 20 7 7" "small 2 16384 1000 20 7 7" "interactive 2 67108864 5 1 7 3"; do
    set -- $spec
    for mode in plain valgrind; do
      if [ $mode = plain ]; then r=$4; n=$6; else r=$5; n=$7; fi
      i=0
      while [ $i -lt $n ]; do
        i=$((i+1))
        if [ $mode = plain ]; then "$CHEZ" --program cost1.sps "$LIB" $2 $3 $r
        else $VG "$CHEZ" --program cost1.sps "$LIB" $2 $3 $r; fi | sed "s/^/$libname $1 $mode /" >> run-1-raw.out
      done
    done
  done
done
