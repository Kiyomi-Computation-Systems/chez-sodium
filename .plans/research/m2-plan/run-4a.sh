#!/bin/sh
# Item 4, RFC 7693 Appendix E self-test through libsodium at both versions.
#   scripts/guix-env sh build/m2-plan/run-4a.sh
set -u
cd "$(dirname "$0")" || exit 2
for v in 1.0.18 1.0.22; do
  p=../slice5/prefix-$v
  ${CC:-cc} -Wall -Werror -std=c11 -I$p/include selftest.c -o selftest-$v -L$p/lib -lsodium || exit 1
  for var in ok oneshot size inlen keylen nokey; do LD_LIBRARY_PATH=$p/lib ./selftest-$v $var; done
done
echo "published result: c23a7800d98123bd10f506c61e29da5603d763b8bbad2e737f5e765a7bccd475"
