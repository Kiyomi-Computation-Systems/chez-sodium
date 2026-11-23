#!/bin/sh
# scripts/ci/report-sodium.sh
#
# Reports the libsodium a CI lane tests: CI's main job runs it on the runner's
# own libsodium, so each run records it. It prints the versions of the
# libsodium packages dpkg lists, then the version string of the sodium.h the
# compiler finds (SODIUM_VERSION_STRING) and the one the linked library
# answers (sodium_version_string()), from a small program compiled against the
# header and linked with -lsodium.
#
# It reports and checks nothing: the two strings may differ, and no floor is
# read.
#
# It fails, saying why on stderr, only when it cannot make the report:
# dpkg-query lists no libsodium package, or cannot run; or the compiler cannot
# build, or the program cannot run, a program against sodium.h and -lsodium.
#
# CC names the C compiler, cc by default. It exits 0 or 1, or 2 on a usage
# error.
set -eu

[ "$#" -eq 0 ] || { echo "usage: report-sodium.sh" >&2; exit 2; }

fail() {
  printf 'report-sodium: %s\n' "$*" >&2
  exit 1
}

cc=${CC:-cc}

work=$(mktemp -d "${TMPDIR:-/tmp}/report-sodium.XXXXXX")
trap 'rm -rf "$work"' EXIT

dpkg-query -W -f '${Package} ${Version}\n' 'libsodium*' >"$work/packages" 2>"$work/dpkg.err" ||
  fail "dpkg-query cannot list a libsodium package: $(head -n 1 "$work/dpkg.err")"
[ -s "$work/packages" ] || fail "dpkg-query lists no libsodium package"

cat >"$work/version.c" <<'PROGRAM'
#include <stdio.h>
#include <sodium.h>
int main(void) {
  printf("%s\n%s\n", SODIUM_VERSION_STRING, sodium_version_string());
  return 0;
}
PROGRAM
"$cc" -o "$work/version" "$work/version.c" -lsodium 2>"$work/cc.err" ||
  fail "$cc could not compile and link a program against sodium.h and -lsodium: $(head -n 1 "$work/cc.err")"
"$work/version" >"$work/out" 2>"$work/run.err" ||
  fail "the program linked against libsodium did not run: $(head -n 1 "$work/run.err")"
header=$(sed -n 1p "$work/out")
library=$(sed -n 2p "$work/out")
[ -n "$header" ] && [ -n "$library" ] || fail "the program printed no version"

echo "packages:"
sed 's/^/  /' "$work/packages"
echo "SODIUM_VERSION_STRING (sodium.h): $header"
echo "sodium_version_string() (the library): $library"
