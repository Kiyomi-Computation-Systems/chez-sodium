#!/bin/sh
# Short memory at both libraries, inside the container, from the repository
# root:
#
#   scripts/guix-env sh .plans/research/m4-plan/b/probes/oom.sh
#
# The cap is ulimit -v 524288 (512 MiB), as tests/test-no-memory.sps uses:
# Chez and libsodium load under it, 'interactive (64 MiB) hashes, and
# 'sensitive (1 GiB) cannot get its memory.
set -u
probe=.plans/research/m4-plan/b/probes/oom.sps
scratch=build/m4-plan/b/oom
mkdir -p "$scratch"
cap=524288
run() { scheme --libdirs src --program "$probe" "$@"; echo "   exit $?"; }
capped() { ( ulimit -v $cap; scheme --libdirs src --program "$probe" "$@"; echo "   exit $?" ); }
for lib in "$CHEZ_SODIUM_LIBRARY" "$PWD/build/slice5/prefix-1.0.18/lib/libsodium.so.23"; do
  export CHEZ_SODIUM_LIBRARY="$lib"
  echo "== libsodium at $(echo "$lib" | sed "s|$PWD|<repo>|")"
  rm -f "$scratch/i.hash" "$scratch/s.hash" "$scratch/g.hash"
  echo "-- uncapped: make an 'interactive and a 'sensitive hash"
  run make interactive "$scratch/i.hash"
  run make sensitive "$scratch/s.hash"
  echo "-- capped: the login pattern on an 'interactive hash, rehashing to 'sensitive"
  capped login "$scratch/i.hash" sensitive
  echo "-- uncapped: the same"
  run login "$scratch/i.hash" sensitive
  echo "-- capped: a 'sensitive hash, the right password, fallback at 'sensitive"
  capped fallback "$scratch/s.hash" "correct horse" sensitive
  echo "-- capped: a 'sensitive hash, a wrong password, fallback at 'sensitive"
  capped fallback "$scratch/s.hash" "battery staple" sensitive
  echo "-- capped: a 'sensitive hash, the right password, fallback at 'interactive (not the hash's limits)"
  capped fallback "$scratch/s.hash" "correct horse" interactive
  echo "-- uncapped: a 'sensitive hash, a wrong password, fallback at 'sensitive"
  run fallback "$scratch/s.hash" "battery staple" sensitive
  echo "-- uncapped: a 'sensitive hash, the right password"
  run fallback "$scratch/s.hash" "correct horse" sensitive
  printf 'garbage\n' > "$scratch/g.hash"
  echo "-- uncapped: an unreadable stored hash, the right password, fallback at 'interactive"
  run fallback "$scratch/g.hash" "correct horse" interactive
done
