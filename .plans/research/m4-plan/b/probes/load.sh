#!/bin/sh
# Every way the load answers, inside the container, from the repository root:
#
#   scripts/guix-env sh .plans/research/m4-plan/b/probes/load.sh
#
# It builds tests/decoy-libsodium.c, unchanged, into build/m4-plan/b/load/ as
# tests/library-loading.sls builds it (-Wall -Werror -shared -fPIC, the floor
# and one below it), against the floor's headers, named libsodium.so.23. Each
# case runs load-report.sps, which reaches the load through eval inside a
# guard; the refusals also run load-uncaught.sps, which names a verb directly.
# Paths under the repository print as <repo>.
set -u
here=.plans/research/m4-plan/b/probes
s=$PWD/build/m4-plan/b/load
rm -rf "$s"
mkdir -p "$s/empty" "$s/only23/lib" "$s/both/lib" "$s/home"
floor=$PWD/build/slice5/prefix-1.0.18/lib/libsodium.so.23
current=$CHEZ_SODIUM_LIBRARY
ln -s "$floor" "$s/only23/lib/libsodium.so.23"
ln -s "$floor" "$s/both/lib/libsodium.so.23"
ln -s "$current" "$s/both/lib/libsodium.so.26"
inc="$PWD/build/slice5/prefix-1.0.18/include:${C_INCLUDE_PATH:-}"
build() { # NAME EXTRA-FLAGS...
  name=$1; shift
  mkdir -p "$s/$name"
  C_INCLUDE_PATH="$inc" gcc -Wall -Werror -shared -fPIC -o "$s/$name/libsodium.so.23" \
    tests/decoy-libsodium.c -DDECOY_VERSION='"1.0.18"' -DDECOY_BELOW='"1.0.17"' "$@" \
    || echo "build $name failed"
}
build control
build lacks-pwhash-str -DDECOY_LACKS_crypto_pwhash_str
build not-sodium -DDECOY_NOT_SODIUM
mask() { sed -e "s|$PWD|<repo>|g" -e "s|$current|<guix-profile>/lib/libsodium.so.26|g"; }
report() { # LABEL, then env assignments via the caller
  echo "-- $1"
  scheme --libdirs src --program "$here/load-report.sps" 2>&1 | mask
}
uncaught() {
  echo "   uncaught:"
  scheme --libdirs src --program "$here/load-uncaught.sps" 2>&1 | mask | sed 's/^/   | /'
  echo "   | exit status of the uncaught program: $(scheme --libdirs src --program "$here/load-uncaught.sps" >/dev/null 2>&1; echo $?)"
}

CHEZ_SODIUM_LIBRARY="$current" report "override: the container's 1.0.22"
CHEZ_SODIUM_LIBRARY="$floor" report "override: the floor's 1.0.18"
export CHEZ_SODIUM_LIBRARY=libsodium.so.23; report "override: a bare soname"; uncaught
export CHEZ_SODIUM_LIBRARY=; report "override: set to the empty string"; uncaught
export CHEZ_SODIUM_LIBRARY=lib/libsodium.so.23; report "override: a relative path"
export CHEZ_SODIUM_LIBRARY=/no/such/libsodium.so.23; report "override: no such file"; uncaught
export CHEZ_SODIUM_LIBRARY=$PWD/README.org; report "override: a text file"
export CHEZ_SODIUM_LIBRARY="$s/control/libsodium.so.23"
CHEZ_SODIUM_DECOY=below-floor report "decoy at 1.0.17"; CHEZ_SODIUM_DECOY=below-floor uncaught
CHEZ_SODIUM_DECOY=version-null report "decoy whose version string is NULL"
CHEZ_SODIUM_DECOY=version-malformed report "decoy whose version reads 1.0.18-stable"
CHEZ_SODIUM_DECOY=init-fails report "decoy whose sodium_init answers -1"; CHEZ_SODIUM_DECOY=init-fails uncaught
CHEZ_SODIUM_DECOY=init-already report "decoy whose sodium_init answers 1"
export CHEZ_SODIUM_LIBRARY="$s/lacks-pwhash-str/libsodium.so.23"
report "decoy without crypto_pwhash_str"; uncaught
export CHEZ_SODIUM_LIBRARY="$s/not-sodium/libsodium.so.23"
report "a shared object with no libsodium function"
unset CHEZ_SODIUM_LIBRARY
report "unset: discovery in the container"
GUIX_ENVIRONMENT="$s/empty" HOME="$s/home" report "unset: empty profiles"
GUIX_ENVIRONMENT="$s/empty" HOME="$s/home" uncaught
GUIX_ENVIRONMENT="$s/only23" HOME="$s/home" report "unset: a profile holding libsodium.so.23 alone"
GUIX_ENVIRONMENT="$s/both" HOME="$s/home" report "unset: a profile holding both sonames"
GUIX_ENVIRONMENT= GUIX_PROFILE="$s/both" HOME="$s/home" report "unset: GUIX_ENVIRONMENT empty, GUIX_PROFILE holding both"
echo "-- discovery's candidate lists, from the pure procedure"
scheme --libdirs src --program "$here/candidates.sps" 2>&1
