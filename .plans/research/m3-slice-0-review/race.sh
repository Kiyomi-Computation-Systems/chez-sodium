#!/bin/sh
set -u
cd "$(dirname "$0")" || exit 2
D=$(mktemp -d)
gcc -Wall -Werror -shared -fPIC -o "$D/blocker.so" blocker.c || exit 2
for kind in plain safe; do
  for run in 1 2 3 4 5 6 7 8; do
    F="$D/fifo-$kind-$run"; M="$D/marker-$kind-$run"
    mkfifo "$F"
    (sleep 5; : >"$M"; exec 3<>"$F") </dev/null >/dev/null 2>&1 &
    W=$!
    out=$("$CHEZ" --program race.sps "$D/blocker.so" $kind "$F" "$M" 2>&1)
    echo "run=$run $out"
    kill $W 2>/dev/null; rm -f "$F"
  done
done
rm -rf "$D"
