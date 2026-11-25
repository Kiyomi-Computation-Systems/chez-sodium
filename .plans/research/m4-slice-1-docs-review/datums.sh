#!/bin/sh
# The comment pass reads as the same datums: each Scheme file the slice
# edited, at 1d4b8c1 and at 7928da4, read whole by Chez's read and compared
# with equal?. floors.sls and check-floors.sps changed code on purpose: they
# are the controls, and must say DIFF. Run on the host from the repository
# root; it calls the container for Chez.
set -eu
out=build/m4s1-review-docs/datums
mkdir -p "$out/before" "$out/after"
args=""
for f in src/chez-sodium.sls src/chez-sodium/private/byte-verbs.sls \
         src/chez-sodium/private/cap.sls src/chez-sodium/private/conditions.sls \
         src/chez-sodium/private/native.sls src/chez-sodium/private/password-text.sls \
         src/chez-sodium/private/password-verbs.sls tests/check-seam.sps \
         tests/foreign-conventions.sls tests/test-conditions.sps tests/test-constants.sps \
         tests/test-conventions.sps tests/test-decoy-source.sps \
         tests/test-library-loading-passwords.sps tests/test-library-loading-verbs.sps \
         tests/test-native-codes.sps tests/test-native.sps tests/test-password-verbs.sps \
         tests/test-wipe.sps tests/floors.sls tests/check-floors.sps; do
  n=$(echo "$f" | tr / _)
  git show "1d4b8c1:$f" > "$out/before/$n"
  git show "7928da4:$f" > "$out/after/$n"
  args="$args $out/before/$n $out/after/$n"
done
scripts/guix-env sh -c "scheme --program .plans/research/m4-slice-1-docs-review/datums.sps $args"
