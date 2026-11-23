#!/bin/sh
# scripts/ci/build-sodium.sh PREFIX [--current]
#
# Builds libsodium from libsodium.org's release tarball and installs it into
# PREFIX, for .github/workflows/ci.yml's floor and current lanes (ADR-0003:
# CI tests the floor against a libsodium it builds itself). Without a flag it
# builds the floor, the one packaging/floors.sexp holds (ADR-0011), read by
# scripts/ci/floor.sh, which fails closed on a file that does not give exactly
# one well-formed libsodium version. With --current it builds the pinned
# current release below and reads no floors file. Nothing a workflow says, an
# env key or a matrix value, can change which: the version and its pin are set
# here, whatever the environment holds.
#
# It downloads libsodium-VERSION.tar.gz, from the releases directory of
# download.libsodium.org, then, if that fails, from its old/ directory, where
# older releases move. It checks the tarball's SHA-256 against the role's pin
# before anything is unpacked, unpacks it, requires its configure, then runs
#
#   ./configure --prefix=PREFIX     no other flag: libsodium's defaults, which
#                                   are the shared library, with pthreads
#   make
#   make install
#
# and requires that configure defined HAVE_PTHREAD: it only notes that
# threads are missing, and a libsodium built without them has no mutex in
# sodium_init. CFLAGS, CPPFLAGS and LDFLAGS are unset first, so that no
# ambient flag changes the build; CC is honoured. Afterwards
# scripts/ci/check-sodium.sh checks what was built, with CHEZ_SODIUM_LIBRARY
# and C_INCLUDE_PATH naming PREFIX's library and headers for that call only: its
# version, its soname, its header, its major and minor and that it is no minimal
# build. A build that came out other than this script asks is no build, and is
# never saved to a cache.
#
# PREFIX must be an absolute path. Nothing is installed outside PREFIX. Of the
# environment it reads CC, the C compiler, cc by default; CHEZ, the Chez
# check-sodium.sh reads the library with; TMPDIR, for its work directory; and
# C_INCLUDE_PATH, which the check gets after PREFIX/include. None of them
# names what is built.
#
# The pins are keyed by role, not by version: the floor's version is never
# written in scripts/ci (make check-floors), so its pin is the floor's,
# whatever version packaging/floors.sexp gives. Raising the floor, or changing
# current_version, is a reviewed change of that role's pin: the SHA-256 of
# libsodium-VERSION.tar.gz, as the project computed it and checked once
# against its .minisig with libsodium's published key. Raising the floor also
# moves the floor's soname here and in check-sodium.sh, check-sodium.sh's
# --discovery path, the floor lane's library path in .github/workflows/ci.yml
# (the soname in each CHEZ_SODIUM_LIBRARY there), the floor library in
# tests/check-ci.sh, the floor value in tests/test-check-ci.sps, and the
# reviewed copies in tests/test-ci-sodium.sps. Until the pin moves, the new
# floor's download fails, or fails its SHA-256 check.
set -eu

usage() {
  echo "usage: build-sodium.sh PREFIX [--current]" >&2
  exit 2
}

[ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage
prefix=$1
role=floor
if [ "$#" -eq 2 ]; then
  [ "$2" = "--current" ] || usage
  role=current
fi

case $prefix in
  -*) usage ;;
esac
case $prefix in
  /?*) ;;
  *) echo "build-sodium.sh: PREFIX must be an absolute path, not '$prefix'" >&2; exit 2 ;;
esac

fail() {
  printf 'build-sodium.sh: %s\n' "$*" >&2
  exit 1
}

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

# current_version: the current libsodium, built with --current: a recent
# release, pinned. It is no floor, so it is not in packaging/floors.sexp.
current_version=1.0.22

# The pin of each role: the SHA-256 of its tarball.
floor_archive=6f504490b342a4f8a4c4a02fc9b866cbef8622d5df4e5452b46be121e46636c1
current_archive=adbdd8f16149e81ac6078a03aca6fc03b592b89ef7b5ed83841c086191be3349

if [ "$role" = floor ]; then
  version=$(sh "$here/floor.sh" sodium) || fail "no libsodium floor to build"
  archive_pin=$floor_archive
  soname=libsodium.so.23
  check_args=
else
  version=$current_version
  archive_pin=$current_archive
  soname=libsodium.so.26
  check_args=--current
fi

name=libsodium-$version.tar.gz
dir=libsodium-$version
base=https://download.libsodium.org/libsodium
url=$base/releases/$name
old_url=$base/releases/old/$name

# The tools, each named when it is missing, before anything is downloaded.
cc=${CC:-cc}
missing=
need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "build-sodium.sh: cannot find $1, which $2" >&2
    missing=yes
  fi
}
need curl "downloads the archive"
need sha256sum "checks the SHA-256 of the archive"
need tar "unpacks the archive"
need make "builds libsodium"
need "$cc" "is the C compiler CC names, cc by default, and builds libsodium"
[ -z "$missing" ] || exit 1

work=$(mktemp -d "${TMPDIR:-/tmp}/build-sodium.XXXXXX")
trap 'rm -rf "$work"' EXIT
trap 'exit 1' HUP INT TERM

archive=$work/$name
if ! curl --proto '=https' -fsSL --retry 3 -o "$archive" "$url"; then
  echo "build-sodium.sh: could not download $url, trying $old_url" >&2
  rm -f "$archive"
  if ! curl --proto '=https' -fsSL --retry 3 -o "$archive" "$old_url"; then
    if [ "$role" = current ]; then
      fail "could not download $name from $url or $old_url: if current_version was changed, current_archive in this script may still be the old release's"
    fi
    fail "could not download $name from $url or $old_url: if the libsodium floor in packaging/floors.sexp was raised, floor_archive in this script may still be the old floor's"
  fi
fi

digest=$(sha256sum "$archive") || fail "sha256sum could not read $archive"
got=$(printf '%s\n' "$digest" | awk '{ print $1 }')
[ "$got" = "$archive_pin" ] ||
  fail "$name has SHA-256 $got, but ${role}_archive in this script pins $archive_pin"

tar xzf "$archive" -C "$work" || fail "tar could not unpack $name"
[ -f "$work/$dir/configure" ] || fail "$name holds no $dir/configure"

cd "$work/$dir"
CC=$cc
export CC
unset CFLAGS CPPFLAGS LDFLAGS

# step NAME COMMAND...: runs COMMAND, its output in the work directory, and
# on failure says so with the last 30 lines of that output.
step() {
  step_name=$1
  shift
  if ! "$@" >"$work/step.log" 2>&1; then
    printf 'build-sodium.sh: %s failed; the last 30 lines of its output:\n' "$step_name" >&2
    tail -n 30 "$work/step.log" >&2
    exit 1
  fi
}

step configure ./configure --prefix="$prefix"
grep -q -e -DHAVE_PTHREAD=1 src/libsodium/Makefile 2>/dev/null ||
  fail "configure built libsodium without pthreads: src/libsodium/Makefile has no -DHAVE_PTHREAD=1"
step make make
step "make install" make install

# Check what was built, by its own role, with the lane's env for this call
# only.
CHEZ_SODIUM_LIBRARY=$prefix/lib/$soname \
  C_INCLUDE_PATH=$prefix/include${C_INCLUDE_PATH:+:$C_INCLUDE_PATH} \
  sh "$here/check-sodium.sh" "$prefix" $check_args
echo "build-sodium.sh: libsodium $version built into $prefix"
