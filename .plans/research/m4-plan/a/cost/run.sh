#!/bin/sh
# Run inside scripts/guix-env, from the repository root:
#   scripts/guix-env sh .plans/research/m4-plan/a/cost/run.sh
# Copies the probes into build/m4-plan/a/cost, where Valgrind's logs go,
# then runs each plain and under the memory gate's Valgrind options, each
# timed by the shell.
set -u
d=build/m4-plan/a/cost
mkdir -p $d
cp .plans/research/m4-plan/a/cost/*.sps $d/
opts="-v --command-line-only=yes --error-exitcode=9 --leak-check=full --show-leak-kinds=definite --errors-for-leak-kinds=definite --child-silent-after-fork=yes"
ms() { echo $(( $(date +%s%N) / 1000000 )); }
echo "## in process, plain"
"$CHEZ" --libdirs src --program $d/inproc.sps
echo "## in process, under the gate's Valgrind"
t0=$(ms)
valgrind $opts --log-file=$d/inproc.valgrind "$CHEZ" --libdirs src --program $d/inproc.sps
echo "exit $? wall $(( $(ms) - t0 )) ms"
grep 'ERROR SUMMARY' $d/inproc.valgrind | sed 's/^==[0-9]*== //'
for p in whole whole-min whole-none; do
  for mode in plain gate; do
    t0=$(ms)
    if [ $mode = plain ]; then
      out=$("$CHEZ" --libdirs src --program $d/$p.sps); rc=$?
    else
      out=$(valgrind $opts --log-file=$d/$p.valgrind "$CHEZ" --libdirs src --program $d/$p.sps); rc=$?
    fi
    echo "$p $mode: exit $rc out $out wall $(( $(ms) - t0 )) ms"
  done
  grep 'ERROR SUMMARY' $d/$p.valgrind | sed 's/^==[0-9]*== //'
done
