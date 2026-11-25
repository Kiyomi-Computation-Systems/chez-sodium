#!/bin/sh
# Run one probe program at the container's libsodium 1.0.22, then at the
# floor's 1.0.18 build. Run it inside the container, from the repository root:
#
#   scripts/guix-env sh .plans/research/m4-plan/b/probes/both.sh PROBE.sps [ARG ...]
#
# Each run's output follows a line naming the library.
set -u
probe=$1
shift
floor="$PWD/build/slice5/prefix-1.0.18/lib/libsodium.so.23"
echo "== libsodium at $CHEZ_SODIUM_LIBRARY"
scheme --libdirs src --program "$probe" "$@"
echo "== exit $?"
echo "== libsodium at <repo>/build/slice5/prefix-1.0.18/lib/libsodium.so.23"
CHEZ_SODIUM_LIBRARY="$floor" \
C_INCLUDE_PATH="$PWD/build/slice5/prefix-1.0.18/include:${C_INCLUDE_PATH:-}" \
  scheme --libdirs src --program "$probe" "$@"
echo "== exit $?"
