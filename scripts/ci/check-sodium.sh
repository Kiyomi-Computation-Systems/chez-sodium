#!/bin/sh
# scripts/ci/check-sodium.sh PREFIX [--current]
# scripts/ci/check-sodium.sh --discovery
#
# Fails unless the libsodium a CI job needs is the one its environment points
# at. With PREFIX, the floor, read from packaging/floors.sexp by
# scripts/ci/floor.sh (ADR-0011), for the floor lane; with --current, the
# pinned current release, which reads no floors file. scripts/ci/build-sodium.sh
# runs it on what it built, before a cache saves it, and each lane runs it
# again after restoring libsodium from a cache, so a cache that serves another
# build is caught before any suite runs on it. With --discovery alone, the
# job that loads libsodium by discovery: it must have loaded the floor, from
# the system's own library (ADR-0002, ADR-0003).
#
# With PREFIX it checks, in order, stopping at the first problem:
#
#   1. PREFIX/lib/libsodium.so.23 (the floor) or libsodium.so.26 (current) and
#      PREFIX/include/sodium.h are regular files;
#   2. CHEZ_SODIUM_LIBRARY is exactly that library, so that make build and
#      make test load the library checked here (ADR-0002's override, loaded as
#      given);
#   3. the compiler, in this environment, finds <sodium.h> at exactly
#      PREFIX/include/sodium.h, as $CC -E -M lists it: the header the
#      constants check compiles against (-M, not -MM, since C_INCLUDE_PATH's
#      directories count as system ones). It uses the environment it is
#      given and never sets C_INCLUDE_PATH: in a Guix container the variable
#      also holds the kernel headers' directory, so PREFIX/include must come
#      first and the old value after it, as build-sodium.sh gives it;
#   4. that header defines SODIUM_VERSION_STRING as the release's version, and
#      SODIUM_LIBRARY_VERSION_MAJOR and _MINOR as naturals;
#   5. the library, read through Chez's FFI by a probe of its own, never
#      through chez-sodium, answers the release's version from
#      sodium_version_string(), major and minor equal to the header's, and 0
#      from sodium_library_minimal(): no minimal build, which drops functions.
#
# Major and minor are libtool numbers, not the release (ADR-0003). They are
# compared with the header's, never with the floor.
#
# --discovery needs CHEZ_SODIUM_LIBRARY unset. It runs tests/preflight.sps, the
# program make build runs, and requires its stdout to be exactly: the
# accepted line; the path /usr/lib/x86_64-linux-gnu/libsodium.so.23 and its
# source (system); the floor with (library M.N), M and N the header's; and a
# counts line in which every count is 0. Its stderr must be empty. The
# compiler must find /usr/include/sodium.h, which declares the floor.
#
# The floor is read from packaging/floors.sexp, and the current release,
# current_version, is written here, in build-sodium.sh and in
# tests/test-ci-sodium.sps: a change to one that misses another fails at
# build-sodium.sh's own call to this script, before any cache is saved. Raising
# the floor also moves the floor's soname here and in build-sodium.sh,
# floor_archive in build-sodium.sh, --discovery's path here, the floor lane's
# library path in .github/workflows/ci.yml (the soname in each
# CHEZ_SODIUM_LIBRARY there), the floor library in tests/check-ci.sh, the
# floor value in tests/test-check-ci.sps, and the reviewed copies in
# tests/test-ci-sodium.sps.
#
# CHEZ and CC name the Chez binary and the C compiler, scheme and cc by
# default. It prints what it checked on stdout and exits 0, or says what is
# wrong on stderr and exits 1, or 2 on a usage error.
set -eu

usage() {
  echo "usage: check-sodium.sh PREFIX [--current] | --discovery" >&2
  exit 2
}

role=floor
prefix=
if [ "$#" -eq 1 ] && [ "$1" = "--discovery" ]; then
  role=discovery
else
  [ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage
  prefix=$1
  case $prefix in
    -*) usage ;;
  esac
  if [ "$#" -eq 2 ]; then
    [ "$2" = "--current" ] || usage
    role=current
  fi
  case $prefix in
    /?*) ;;
    *) echo "check-sodium.sh: PREFIX must be an absolute path, not '$prefix'" >&2; exit 2 ;;
  esac
fi

fail() {
  printf 'check-sodium.sh: %s\n' "$*" >&2
  exit 1
}

# Bytes, not characters, in every sed and grep below.
LC_ALL=C
export LC_ALL

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH='' cd -- "$here/../.." && pwd)

# current_version: the current libsodium, built with --current: a recent
# release, pinned. It is no floor, so it is not in packaging/floors.sexp.
current_version=1.0.22

case $role in
  current)
    version=$current_version
    soname=libsodium.so.26
    what="the pinned current libsodium" ;;
  *)
    version=$(sh "$here/floor.sh" sodium) || fail "no libsodium floor to check against"
    soname=libsodium.so.23
    what="the libsodium floor" ;;
esac

cc=${CC:-cc}
chez=${CHEZ:-scheme}

work=$(mktemp -d "${TMPDIR:-/tmp}/check-sodium.XXXXXX")
trap 'rm -rf "$work"' EXIT
trap 'exit 1' HUP INT TERM

# cc_failed WHAT: says the compiler could not do WHAT, then the compiler's
# own words, whole, and exits 1.
cc_failed() {
  echo "check-sodium.sh: $cc could not $1:" >&2
  cat "$work/cc.err" >&2
  exit 1
}

# check_header HEADER HINT: the compiler finds <sodium.h> at HEADER, and it
# declares the release. Sets header_major and header_minor.
check_header() {
  expected_header=$1
  hint=$2
  printf '#include <sodium.h>\n' >"$work/find.c"
  # -M lists the source, then each header in the order it is read, as make
  # rules: a backslash ends each line but the last, and a space in a path is
  # written "\ ". The first sodium.h listed is the one <sodium.h> names.
  "$cc" -E -M "$work/find.c" >"$work/find.d" 2>"$work/cc.err" ||
    cc_failed "preprocess a file that includes <sodium.h>"
  found=$(awk '
    { text = text $0 "\n" }
    END {
      gsub(/\\\n/, " ", text)
      gsub(/\\ /, "\001", text)
      n = split(text, words, /[ \t\n]+/)
      for (i = 1; i <= n; i++) {
        word = words[i]
        gsub(/\001/, " ", word)
        if (word ~ /(^|\/)sodium\.h$/) { print word; exit }
      }
    }' "$work/find.d")
  [ -n "$found" ] || fail "$cc lists no sodium.h among the files #include <sodium.h> reads"
  [ "$found" = "$expected_header" ] ||
    fail "$cc finds <sodium.h> at $found, not $expected_header: $hint"
  # -dM lists each macro's definition once, its body's white space made single
  # spaces.
  "$cc" -dM -E "$work/find.c" >"$work/macros" 2>"$work/cc.err" ||
    cc_failed "list the macros <sodium.h> defines"
  header_version=$(sed -n 's/^#define SODIUM_VERSION_STRING //p' "$work/macros")
  header_major=$(sed -n 's/^#define SODIUM_LIBRARY_VERSION_MAJOR //p' "$work/macros")
  header_minor=$(sed -n 's/^#define SODIUM_LIBRARY_VERSION_MINOR //p' "$work/macros")
  if [ "$header_version" != "\"$version\"" ]; then
    fail "$expected_header defines SODIUM_VERSION_STRING $header_version, but $what is \"$version\""
  fi
  nat='^(0|[1-9][0-9]*)$'
  if ! printf '%s\n' "$header_major" | grep -q -E "$nat" ||
     ! printf '%s\n' "$header_minor" | grep -q -E "$nat"; then
    fail "$expected_header defines SODIUM_LIBRARY_VERSION_MAJOR '$header_major' and SODIUM_LIBRARY_VERSION_MINOR '$header_minor', which are not both naturals"
  fi
}

if [ "$role" = discovery ]; then
  [ -z "${CHEZ_SODIUM_LIBRARY+set}" ] ||
    fail "CHEZ_SODIUM_LIBRARY is set, but this job loads libsodium by discovery, and must load the system's"
  system_path=/usr/lib/x86_64-linux-gnu/libsodium.so.23
  system_header=/usr/include/sodium.h

  if ! "$chez" --libdirs "$root/src" --program "$root/tests/preflight.sps" \
       >"$work/report" 2>"$work/report.err"; then
    echo "check-sodium.sh: make build's program, $chez --libdirs $root/src --program $root/tests/preflight.sps, refused or failed; its stderr:" >&2
    cat "$work/report.err" >&2
    exit 1
  fi
  if [ -s "$work/report.err" ]; then
    echo "check-sodium.sh: make build's program wrote to stderr, though it exited 0:" >&2
    cat "$work/report.err" >&2
    exit 1
  fi

  check_header "$system_header" "the system's header must be the one found, so that the suites compile against it"

  {
    echo "chez-sodium: libsodium loaded and accepted"
    echo "  path:       $system_path (system)"
    echo "  version:    $version (library $header_major.$header_minor)"
  } >"$work/expected"
  lines=$(grep -c '' "$work/report" || true)
  head -n 3 "$work/report" >"$work/head"
  zero='\(\([a-z][a-z0-9-]* \. 0\)( \([a-z][a-z0-9-]* \. 0\))*\)'
  if [ "$lines" -ne 4 ] || ! cmp -s "$work/expected" "$work/head" ||
     ! sed -n 4p "$work/report" | grep -q -E "^  counts:     $zero\$"; then
    echo "check-sodium.sh: make build's report is not, line for line, these three lines and then a counts line whose every count is 0:" >&2
    sed 's/^/  expected: /' "$work/expected" >&2
    echo "  expected: (counts line: a list of (kind . 0))" >&2
    sed 's/^/  read:     /' "$work/report" >&2
    exit 1
  fi
  echo "check-sodium.sh: make build loaded $system_path (system), libsodium $version (library $header_major.$header_minor), $what"
  echo "check-sodium.sh: $cc finds <sodium.h> at $system_header, which declares the same release, and CHEZ_SODIUM_LIBRARY is unset"
  exit 0
fi

lib=$prefix/lib/$soname
header=$prefix/include/sodium.h

# 1. The files.
[ -f "$lib" ] || fail "no library at $lib: it is not a regular file"
[ -f "$header" ] || fail "no header at $header: it is not a regular file"

# 2. The override names that library.
why="the library this checks, so that make build and make test load it"
[ -n "${CHEZ_SODIUM_LIBRARY+set}" ] || fail "CHEZ_SODIUM_LIBRARY is unset, but must be $lib, $why"
[ "$CHEZ_SODIUM_LIBRARY" = "$lib" ] ||
  fail "CHEZ_SODIUM_LIBRARY is '$CHEZ_SODIUM_LIBRARY', but must be $lib, $why"

# 3 and 4. The header the compiler finds, and what it defines.
check_header "$header" "C_INCLUDE_PATH must name $prefix/include first, so that the suites compile against the library's own header"

# 5. The library, through the FFI.
cat >"$work/read.ss" <<'PROBE'
(let ((lib (car (command-line-arguments))))
  (load-shared-object lib)
  (let ((version (foreign-procedure "sodium_version_string" () string))
        (major (foreign-procedure "sodium_library_version_major" () int))
        (minor (foreign-procedure "sodium_library_version_minor" () int))
        (minimal (foreign-procedure "sodium_library_minimal" () int)))
    (printf "version ~a~%major ~a~%minor ~a~%minimal ~a~%" (version) (major) (minor) (minimal))))
PROBE
if ! "$chez" -q --script "$work/read.ss" "$lib" >"$work/library" 2>"$work/library.err"; then
  echo "check-sodium.sh: $chez could not read $lib:" >&2
  cat "$work/library.err" >&2
  exit 1
fi
lib_version=$(sed -n 's/^version //p' "$work/library")
lib_major=$(sed -n 's/^major //p' "$work/library")
lib_minor=$(sed -n 's/^minor //p' "$work/library")
lib_minimal=$(sed -n 's/^minimal //p' "$work/library")

[ "$lib_version" = "$version" ] ||
  fail "$lib answers \"$lib_version\" to sodium_version_string(), but $what is \"$version\""
if [ "$lib_major" != "$header_major" ] || [ "$lib_minor" != "$header_minor" ]; then
  fail "$lib answers $lib_major.$lib_minor to sodium_library_version_major() and _minor(), but $header declares $header_major.$header_minor"
fi
[ "$lib_minimal" = 0 ] ||
  fail "$lib answers $lib_minimal to sodium_library_minimal(), but a lane's libsodium must answer 0: no minimal build"

echo "check-sodium.sh: $lib is libsodium $version (library $lib_major.$lib_minor), $what, and no minimal build"
echo "check-sodium.sh: $cc finds <sodium.h> at $header, which declares the same release, and CHEZ_SODIUM_LIBRARY names the library"
