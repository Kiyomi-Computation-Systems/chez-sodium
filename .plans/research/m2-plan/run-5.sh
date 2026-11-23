#!/bin/sh
# Item 5: costs, plain and under Valgrind (the memory gate's flags), 7 runs each,
# on the container's libsodium (1.0.22). Raw lines to run-5-raw.out, medians to run-5.out.
#   scripts/guix-env sh build/m2-plan/run-5.sh
set -u
cd "$(dirname "$0")" || exit 2
VG="valgrind --error-exitcode=9 --leak-check=full --show-leak-kinds=definite --errors-for-leak-kinds=definite --child-silent-after-fork=yes -q"
: > run-5-raw.out
for size in 65536 32; do
  # reps: plain 200 (64 KiB) / 20000 (32); valgrind 3 / 200
  if [ $size = 65536 ]; then pr=200; vr=3; else pr=20000; vr=200; fi
  for mode in plain valgrind; do
    r=$pr; [ $mode = valgrind ] && r=$vr
    for run in 1 2 3 4 5 6 7; do
      if [ $mode = plain ]; then "$CHEZ" --program cost.sps "$CHEZ_SODIUM_LIBRARY" $size $r
      else $VG "$CHEZ" --program cost.sps "$CHEZ_SODIUM_LIBRARY" $size $r; fi | sed "s/^/$size $mode /" >> run-5-raw.out
    done
  done
done
echo 'medians: python3 -I build/m2-plan/medians.py (host; the container has no python)'
