#!/bin/sh
# build/m4s1-1b/programs.sh: run each whole program blocks.sps wrote, from a
# fresh directory of its own, with src alone on Chez's library path, at the
# library the environment names. Run in the container from the repository
# root: sh build/m4s1-1b/programs.sh LABEL
# Each must exit 0 with nothing on stderr. One with a .expected file must
# print exactly it. A guarded one runs again with CHEZ_SODIUM_LIBRARY naming
# a file that is not there, and must print one datum whose first element is
# refused.
repo=$PWD
label=$1
progs=$repo/build/m4s1-1b/progs
fails=0
for p in "$progs"/*.sps; do
  name=$(basename "$p" .sps)
  dir=$repo/build/m4s1-1b/run-$label-$name
  rm -rf "$dir"; mkdir -p "$dir"; cp "$p" "$dir/prog.sps"
  ( cd "$dir" && scheme --libdirs "$repo/src" --program prog.sps >out 2>err; echo $? >rc )
  rc=$(cat "$dir/rc")
  if [ "$rc" != 0 ] || [ -s "$dir/err" ]; then
    echo "FAIL $label $name: exit $rc, stderr:"; cat "$dir/err"; fails=$((fails + 1))
  elif [ -f "$progs/$name.expected" ]; then
    if cmp -s "$dir/out" "$progs/$name.expected"; then
      echo "ok $label $name: prints its text block:"; sed 's/^/    /' "$dir/out"
    else
      echo "FAIL $label $name: printed"; cat "$dir/out"; echo "expected"; cat "$progs/$name.expected"
      fails=$((fails + 1))
    fi
  else
    echo "ok $label $name: exit 0, no stderr, printed:"; sed 's/^/    /' "$dir/out"
  fi
  if [ -f "$progs/$name.guarded" ]; then
    ( cd "$dir" && CHEZ_SODIUM_LIBRARY=/no/such/libsodium.so.26 scheme --libdirs "$repo/src" --program prog.sps >gout 2>gerr; echo $? >grc )
    grc=$(cat "$dir/grc")
    datums=$(printf '(import (chezscheme)) (let ((p (open-input-file "%s"))) (let loop ((n 0) (first #f)) (let ((d (read p))) (if (eof-object? d) (begin (write (list n (and (pair? first) (car first)))) (newline)) (loop (+ n 1) (or first d))))))' "$dir/gout" > "$dir/count.sps"; scheme --program "$dir/count.sps")
    if [ "$grc" = 0 ] && [ ! -s "$dir/gerr" ] && [ "$datums" = "(1 refused)" ]; then
      echo "ok $label $name refused: exit 0, no stderr, one refused datum:"; sed 's/^/    /' "$dir/gout"
    else
      echo "FAIL $label $name refused: exit $grc, datums $datums, out:"; cat "$dir/gout"; cat "$dir/gerr"
      fails=$((fails + 1))
    fi
  fi
done
echo "$label: failures $fails"
[ "$fails" = 0 ]
