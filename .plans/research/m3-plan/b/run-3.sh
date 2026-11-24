#!/bin/sh
# Item 3: collect-safe by behaviour; cases a b c d, 5 runs each, plain and under Valgrind.
#   scripts/guix-env sh build/m3-plan/b/run-3.sh > build/m3-plan/b/run-3.out
set -u
cd "$(dirname "$0")" || exit 2
VG="valgrind --error-exitcode=9 --leak-check=full --show-leak-kinds=definite --errors-for-leak-kinds=definite --child-silent-after-fork=yes -q"
D=$(mktemp -d)
gcc -Wall -Werror -shared -fPIC -o "$D/blocker.so" blocker.c || exit 2
for mode in plain valgrind; do
  for c in a b c d; do
    for run in 1 2 3 4 5; do
      F="$D/fifo-$c-$mode-$run"; M="$D/marker-$c-$mode-$run"
      mkfifo "$F"
      (sleep 10; : >"$M"; exec 3<>"$F") </dev/null >/dev/null 2>&1 &
      W=$!
      if [ $mode = plain ]; then out=$("$CHEZ" --program blocker.sps "$D/blocker.so" $c "$F" "$M" 2>&1)
      else out=$($VG "$CHEZ" --program blocker.sps "$D/blocker.so" $c "$F" "$M" 2>&1); fi
      echo "$mode run=$run exit=$? $out"
      kill $W 2>/dev/null; rm -f "$F"
    done
  done
done
rm -rf "$D"
