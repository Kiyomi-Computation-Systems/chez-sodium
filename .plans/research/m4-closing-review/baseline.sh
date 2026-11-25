#!/bin/sh
# Baseline: the suites M4 added, each timed, at the profile's libsodium.
cd "$(dirname "$0")/../.." || exit 2
for t in tests/test-reference.sps tests/test-docs.sps tests/test-manifest.sps tests/test-check-floors.sps tests/test-site-testing.sps tests/test-check-ci.sps; do
  s=$(date +%s)
  "$CHEZ" --libdirs src:tests:build/scheme-libs --program "$t" > "build/m4-closing-review/base-$(basename "$t" .sps).out" 2>&1
  rc=$?
  e=$(date +%s)
  echo "$t rc=$rc $((e - s))s $(grep -E '^# of (expected passes|unexpected failures)' "build/m4-closing-review/base-$(basename "$t" .sps).out" | tr '\n' ' ')"
done
for g in check-floors check-ci check-suites check-site; do
  s=$(date +%s); make -s $g > "build/m4-closing-review/base-$g.out" 2>&1; rc=$?; e=$(date +%s)
  echo "make $g rc=$rc $((e - s))s: $(tail -1 build/m4-closing-review/base-$g.out)"
done
