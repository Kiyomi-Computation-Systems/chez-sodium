#!/bin/sh
set -u
cd "$(dirname "$0")" || exit 2
cc=${CC:-cc}
echo "== decoy-ternary-nonnull.c: must fail under -Wall -Werror"
$cc -Wall -Werror -shared -fPIC decoy-ternary-nonnull.c -o decoy-ternary-nonnull.so 2>&1 | grep -E 'error' | head -3
$cc -Wall -Werror -shared -fPIC decoy-ternary-nonnull.c -o decoy-ternary-nonnull.so >/dev/null 2>&1; echo "exit status: $?"
echo "== decoy-volatile-nonnull.c: must compile"
$cc -Wall -Werror -shared -fPIC decoy-volatile-nonnull.c -o decoy-volatile-nonnull.so; echo "exit status: $?"
echo "== engine-invoke2.sps import"
"$CHEZ" --libdirs lib --program engine-invoke2.sps import
echo "== engine-invoke2.sps eval"
"$CHEZ" --libdirs lib --program engine-invoke2.sps eval
