#!/bin/sh
# Item 2: encoder check (2a, 2b, 2d), then 2c's cost, plain and under Valgrind, 7 runs each.
# M2's cost.sps (the byte copy) is rerun beside it. Medians: python3 -I build/m3-plan/b/medians2.py
#   scripts/guix-env sh build/m3-plan/b/run-2.sh
set -u
cd "$(dirname "$0")" || exit 2
VG="valgrind --error-exitcode=9 --leak-check=full --show-leak-kinds=definite --errors-for-leak-kinds=definite --child-silent-after-fork=yes -q"
"$CHEZ" --program enc.sps > run-2ab.out 2>&1
: > run-2c-raw.out
for mode in plain valgrind; do
  if [ $mode = plain ]; then r=200; else r=3; fi
  for run in 1 2 3 4 5 6 7; do
    if [ $mode = plain ]; then
      "$CHEZ" --program cost2.sps $r
      "$CHEZ" --program ../../m2-plan/cost.sps "$CHEZ_SODIUM_LIBRARY" 65536 $r | grep foreign-set
    else
      $VG "$CHEZ" --program cost2.sps $r
      $VG "$CHEZ" --program ../../m2-plan/cost.sps "$CHEZ_SODIUM_LIBRARY" 65536 $r | grep foreign-set
    fi | sed "s/^/$mode /" >> run-2c-raw.out
  done
done
