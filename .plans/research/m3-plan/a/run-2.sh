#!/bin/sh
# Items 2 and 3: prototypes (_Generic) and nonnull decoys, against 1.0.18 and 1.0.22 headers.
#   scripts/guix-env sh -c 'export C_INCLUDE_PATH=$PWD/build/slice5/prefix-1.0.18/include:$C_INCLUDE_PATH; sh build/m3-plan/a/run-2.sh'
set -u
cd "$(dirname "$0")" || exit 2
cc=${CC:-cc}
for v in 1.0.18 1.0.22; do
  inc=../../slice5/prefix-$v/include
  def=; [ $v = 1.0.18 ] && def=-DSTR_ARRAY
  echo "######## headers of $v"
  echo "== prototypes.c -Wall -Werror -std=c11"
  $cc -Wall -Werror -std=c11 -I$inc prototypes.c -o prototypes-$v -L../../slice5/prefix-$v/lib -lsodium && echo "compiled" && LD_LIBRARY_PATH=../../slice5/prefix-$v/lib ./prototypes-$v
  for kind in ternary volatile; do
    echo "== decoys, $kind, -Wall -Werror -shared -fPIC"
    for f in decoys/*-$kind.c; do
      out=$($cc -Wall -Werror -shared -fPIC $def -I$inc $f -o /tmp/decoy-$$.so 2>&1); st=$?
      echo "$(basename $f): exit $st $(echo "$out" | grep -o 'Werror=[a-z-]*' | sort -u | tr '\n' ' ')"
    done
  done
done
rm -f /tmp/decoy-$$.so
