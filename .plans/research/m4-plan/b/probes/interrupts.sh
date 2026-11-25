#!/bin/sh
# Send SIGINT into each mode of interrupts.sps, at both
# libraries, inside the container, from the repository root:
#
#   scripts/guix-env sh .plans/research/m4-plan/b/probes/interrupts.sh
#
# The signal goes 300 ms after the marker, or 15 ms for the 'interactive
# modes, whose work takes about 50 ms. The shell's poll for the marker adds
# up to 10 ms.
set -u
probe=.plans/research/m4-plan/b/probes/interrupts.sps
scratch=build/m4-plan/b/interrupts
mkdir -p "$scratch"
one() {
  rm -f "$scratch/marker"
  scheme --libdirs src --program "$probe" "$1" "$scratch/marker" &
  pid=$!
  while [ ! -e "$scratch/marker" ]; do sleep 0.01; done
  sleep "$2"
  kill -INT "$pid"
  wait "$pid"
  echo "   exit $?"
}
for lib in "$CHEZ_SODIUM_LIBRARY" "$PWD/build/slice5/prefix-1.0.18/lib/libsodium.so.23"; do
  export CHEZ_SODIUM_LIBRARY="$lib"
  echo "== libsodium at $(echo "$lib" | sed "s|$PWD|<repo>|")"
  one spin 0.3
  one hash-interactive 0.015
  one verify-interactive 0.015
  one hash-sensitive 0.3
  one verify-sensitive 0.3
done
