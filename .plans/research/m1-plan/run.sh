#!/bin/sh
# Runs every probe in this directory, inside the container:
#   scripts/guix-env sh build/m1-plan/run.sh
set -u
cd "$(dirname "$0")" || exit 2
cc=${CC:-cc}
echo "== version.c (linked against the container's libsodium)"
$cc -Wall -Werror version.c -o version -lsodium && LD_LIBRARY_PATH=$(dirname "$CHEZ_SODIUM_LIBRARY") ./version
echo "== prototypes.c"
$cc -Wall -Werror -std=c11 prototypes.c -o prototypes && ./prototypes
echo "== decoy-ternary.c: must fail under -Wall -Werror"
$cc -Wall -Werror -shared -fPIC decoy-ternary.c -o decoy-ternary.so 2>&1 | grep -E 'error|warning' | head -3
echo "exit status of that compile: $($cc -Wall -Werror -shared -fPIC decoy-ternary.c -o decoy-ternary.so >/dev/null 2>&1; echo $?)"
echo "== decoy-volatile.c: must compile"
$cc -Wall -Werror -shared -fPIC '-DDECOY_INIT=1' '-DDECOY_VERSION="1.0.18"' decoy-volatile.c -o decoy-volatile.so; echo "exit status: $?"
echo "== ffi.sps on the container's libsodium"
"$CHEZ" --program ffi.sps
echo "== ffi.sps on the decoy"
"$CHEZ" --program ffi.sps "$PWD/decoy-volatile.so"
echo "== engine-invoke.sps abandon"
"$CHEZ" --libdirs lib --program engine-invoke.sps abandon
echo "== engine-invoke.sps resume"
"$CHEZ" --libdirs lib --program engine-invoke.sps resume
