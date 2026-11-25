#!/bin/sh
# &sodium-failed as a caller meets it, inside the container, from the
# repository root, after load.sh has built its decoys:
#
#   scripts/guix-env sh .plans/research/m4-plan/b/probes/failed.sh
set -u
p=.plans/research/m4-plan/b/probes/failed.sps
decoy=$PWD/build/m4-plan/b/load/control/libsodium.so.23
run() { scheme --libdirs src --program "$p" "$@" 2>&1; echo "   exit $?"; }
for sw in pwhash-str-fails pwhash-str-other pwhash-str-unreadable pwhash-str-empty; do
  echo "-- decoy $sw: password-hash"
  CHEZ_SODIUM_LIBRARY=$decoy CHEZ_SODIUM_DECOY=$sw run hash
done
for sw in generichash-fails generichash-other; do
  echo "-- decoy $sw: blake2b"
  CHEZ_SODIUM_LIBRARY=$decoy CHEZ_SODIUM_DECOY=$sw run blake2b
done
echo "-- decoy pwhash-str-fails: password-hash, uncaught"
CHEZ_SODIUM_LIBRARY=$decoy CHEZ_SODIUM_DECOY=pwhash-str-fails run hash uncaught
for lib in "$CHEZ_SODIUM_LIBRARY" "$PWD/build/slice5/prefix-1.0.18/lib/libsodium.so.23"; do
  echo "-- $(echo "$lib" | sed "s|$PWD|<repo>|"): password-hash at 'sensitive under ulimit -v 524288"
  ( ulimit -v 524288; CHEZ_SODIUM_LIBRARY=$lib run hash-sensitive )
  echo "-- the same, uncaught"
  ( ulimit -v 524288; CHEZ_SODIUM_LIBRARY=$lib run hash-sensitive uncaught )
done
