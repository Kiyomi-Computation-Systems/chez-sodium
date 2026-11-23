# M1 slice 5 mutation log: the `floor` and `current` lanes

Every run was in the Guix container (`scripts/guix-env`): Chez 10.4.0, threaded; libsodium
1.0.22, and the two source builds the slice measured, 1.0.18 and 1.0.22
([research/m1-slice-5-measurements/](research/m1-slice-5-measurements/README.md)). Two Sonnet
builders worked in one tree, on disjoint files. Each built from trim tables the caller checked
first: the libsodium scripts (`build-sodium.sh`, `check-sodium.sh`, `test-ci-sodium`) and the
lanes (`ci.yml`, `check-ci.sh`, `test-check-ci`). Every mutant was applied in a whole copy of the
tree, never in place.

## Reproduced by the caller, at the join

Each in a whole copy of the tree, by one exact replacement, the copy compared with the original
after:

- **The discovery step dropped from `main`'s required lines in `check-ci.sh`:** the real
  `ci.yml` still passes `check-ci`, and `test-check-ci` fails "main's discovery step deleted",
  with its env, `if:` and order rows.
- **`build-sodium.sh` without `unset CFLAGS CPPFLAGS LDFLAGS`:** `test-ci-sodium` fails
  "build-sodium.sh: CFLAGS, CPPFLAGS and LDFLAGS in the env never reach configure".
- **`--discovery`'s counts check loosened to the line's prefix:** `test-ci-sodium` fails its four
  refusal rows: a nonzero count, an empty list, an unclosed list, and one nonzero count among
  zeros.
- **`check-sodium.sh` by hand against the real builds:** it passes for the floor's 1.0.18 and,
  with `--current`, for 1.0.22. It refuses each of these, naming what is wrong:
  - an override naming the other library;
  - the current release's header first for the floor's prefix;
  - `--discovery` with the override set.
- **Clean run at the join, rerun after the review's fixes:**
  - `make test` 26 of 26, with `check-seam` (9 libraries), `check-floors` (now reading
    `build-sodium.sh` and `check-sodium.sh`) and `check-ci`;
  - `make check-test-fails` all 13 cases;
  - `make test-memory` 26 of 26, the slowest 116 s of 450 (118 s before the fixes);
  - `make check-memory-gate` all 59 cases;
  - `make build` both ways, `make check-dev`, `make check-help` and `make check-clean`;
  - `make check-nothreads` fails, naming the nine libraries, as it must on a threaded Chez.

## After the review

The review ([research/m1-slice-5-review/](research/m1-slice-5-review/README.md)) found no
blocker, two majors and ten minors. The scripts builder's fixes, each watched to fail, are in
"The libsodium scripts: After the review", below. The caller reproduced one: the soname
default, `soname=${soname:-libsodium.so.23}`, survived all 144 rows before the fix. After it,
the floor's env row fails, "floor_archive, current_archive, version, current_version, role, pins
and soname set in the env move nothing".

## The libsodium scripts

Container (scripts/guix-env), Chez 10.4.0 threaded, libsodium 1.0.22. One Sonnet builder wrote
build-sodium.sh, check-sodium.sh and test-ci-sodium.sps from the phase 1 trim table.

### Guards
- Red first: against stub scripts that exit 0, in a copy: 6 rows pass (harness rows), 136 fail.
- Positive control by hand (container, real builds), whole outputs in build/slice5-scripts/f14.out:
    ## sh scripts/ci/check-sodium.sh <repo>/build/slice5/prefix-1.0.18
    check-sodium.sh: <repo>/build/slice5/prefix-1.0.18/lib/libsodium.so.23 is libsodium 1.0.18 (library 10.3), the libsodium floor, and no minimal build
    check-sodium.sh: <profile>/bin/gcc finds <sodium.h> at <repo>/build/slice5/prefix-1.0.18/include/sodium.h, which declares the same release, and CHEZ_SODIUM_LIBRARY names the library
    exit 0
    ## sh scripts/ci/check-sodium.sh <repo>/build/slice5/prefix-1.0.22 --current
    check-sodium.sh: <repo>/build/slice5/prefix-1.0.22/lib/libsodium.so.26 is libsodium 1.0.22 (library 26.4), the pinned current libsodium, and no minimal build
    check-sodium.sh: <profile>/bin/gcc finds <sodium.h> at <repo>/build/slice5/prefix-1.0.22/include/sodium.h, which declares the same release, and CHEZ_SODIUM_LIBRARY names the library
    exit 0
    ## refusal: floor prefix as --current
    ## sh scripts/ci/check-sodium.sh <repo>/build/slice5/prefix-1.0.18 --current
    check-sodium.sh: no library at <repo>/build/slice5/prefix-1.0.18/lib/libsodium.so.26: it is not a regular file
    exit 1

### Mutation
Each mutant is one exact replacement, applied alone in a whole copy of the tree under
build/slice5-scripts/mut/w*, the copy restored after (harness: mut/run.py). Killed means at least one
row FAILs. Results, id, verdict, number of failing rows and the first rows:

    B-p1 KILLED (19, ["FAIL build-sodium.sh: the floor's pin is the floor's tarball's SHA-256: the real digest reaches the build", "FAIL build-sodium.sh: an archive whose SHA-256 is no pin's is refused, naming both, and nothing is unpacked", "FAIL build-sodium.sh:
    B-p2 KILLED (10, ["FAIL build-sodium.sh: --current: the current pin is the current tarball's SHA-256: the real digest reaches the", "FAIL build-sodium.sh: --current: the current tarball with the floor pin's digest is refused, naming current_ar", 'FAIL build-so
    B-p3 KILLED (19, ["FAIL build-sodium.sh: the floor's pin is the floor's tarball's SHA-256: the real digest reaches the build", "FAIL build-sodium.sh: an archive whose SHA-256 is no pin's is refused, naming both, and nothing is unpacked", "FAIL build-sodium.sh:
    B-p4 KILLED (10, ["FAIL build-sodium.sh: --current: the current pin is the current tarball's SHA-256: the real digest reaches the", "FAIL build-sodium.sh: --current: the current tarball with the floor pin's digest is refused, naming current_ar", 'FAIL build-so
    B-p5 KILLED (3, ["FAIL build-sodium.sh: an archive whose SHA-256 is no pin's is refused, naming both, and nothing is unpacked", "FAIL build-sodium.sh: the floor's tarball with the current pin's digest is refused, naming floor_archive", "FAIL build-sodium.sh: -
    B-p6 KILLED (1, ['FAIL build-sodium.sh: floor_archive, current_archive, version, current_version, role and pins set in the env m'])
    B-d1 KILLED (5, ["FAIL build-sodium.sh: releases/ fails and releases/old/ serves: the floor's tarball is fetched from old/, and ", 'FAIL build-sodium.sh: neither directory serves: both URLs are named, nothing else runs, and PREFIX is not made', "FAIL build-sod
    B-d2 KILLED (32, ["FAIL build-sodium.sh: the floor's pin is the floor's tarball's SHA-256: the real digest reaches the build", "FAIL build-sodium.sh: --current: the current pin is the current tarball's SHA-256: the real digest reaches the", "FAIL build-sodium.
    B-d3 KILLED (5, ["FAIL build-sodium.sh: releases/ fails and releases/old/ serves: the floor's tarball is fetched from old/, and ", 'FAIL build-sodium.sh: neither directory serves: both URLs are named, nothing else runs, and PREFIX is not made', "FAIL build-sod
    B-d4 KILLED (3, ['FAIL build-sodium.sh: neither directory serves: both URLs are named, nothing else runs, and PREFIX is not made', "FAIL build-sodium.sh: --current: neither directory serves: the current release's hint, both URLs named", "FAIL build-sodium.sh: 
    B-d5 KILLED (32, ["FAIL build-sodium.sh: the floor's pin is the floor's tarball's SHA-256: the real digest reaches the build", "FAIL build-sodium.sh: --current: the current pin is the current tarball's SHA-256: the real digest reaches the", "FAIL build-sodium.
    B-f1 KILLED (21, ["FAIL build-sodium.sh: the floor's pin is the floor's tarball's SHA-256: the real digest reaches the build", "FAIL build-sodium.sh: an archive whose SHA-256 is no pin's is refused, naming both, and nothing is unpacked", "FAIL build-sodium.sh:
    B-f3 KILLED (32, ["FAIL build-sodium.sh: the floor's pin is the floor's tarball's SHA-256: the real digest reaches the build", "FAIL build-sodium.sh: --current: the current pin is the current tarball's SHA-256: the real digest reaches the", "FAIL build-sodium.
    B-f4 KILLED (1, ["FAIL build-sodium.sh: a malformed floor fails before any download, with floor.sh's line, then the script's"])
    B-c1 KILLED (11, ["FAIL build-sodium.sh: --current: the current pin is the current tarball's SHA-256: the real digest reaches the", "FAIL build-sodium.sh: --current: the current tarball with the floor pin's digest is refused, naming current_ar", 'FAIL build-so
    B-c2 KILLED (11, ["FAIL build-sodium.sh: --current: the current pin is the current tarball's SHA-256: the real digest reaches the", "FAIL build-sodium.sh: --current: the current tarball with the floor pin's digest is refused, naming current_ar", 'FAIL build-so
    B-c3 KILLED (2, ['FAIL build-sodium.sh: --current: current_archive, current_version and version set in the env move nothing', 'FAIL build-sodium.sh: current_version in the env moves nothing: the pinned release is still reached'])
    B-t1-curl KILLED (2, ['FAIL build-sodium.sh: no curl is named before any download', 'FAIL build-sodium.sh: none of the five: each is named, in order, before any download'])
    B-t1-sha256sum KILLED (2, ['FAIL build-sodium.sh: no sha256sum is named before any download', 'FAIL build-sodium.sh: none of the five: each is named, in order, before any download'])
    B-t1-tar KILLED (2, ['FAIL build-sodium.sh: no tar is named before any download', 'FAIL build-sodium.sh: none of the five: each is named, in order, before any download'])
    B-t1-make KILLED (2, ['FAIL build-sodium.sh: no make is named before any download', 'FAIL build-sodium.sh: none of the five: each is named, in order, before any download'])
    B-t1-cc KILLED (2, ['FAIL build-sodium.sh: no cc is named before any download', 'FAIL build-sodium.sh: none of the five: each is named, in order, before any download'])
    B-t2 KILLED (6, ['FAIL build-sodium.sh: no curl is named before any download', 'FAIL build-sodium.sh: no sha256sum is named before any download', 'FAIL build-sodium.sh: no tar is named before any download'])
    B-t3 KILLED (1, ['FAIL build-sodium.sh: an archive that holds no configure is refused after the unpack'])
    B-t4 KILLED (1, ['FAIL build-sodium.sh: a tar that fails is refused, naming the archive, and nothing is built'])
    B-t5 KILLED (29, ["FAIL build-sodium.sh: the floor's pin is the floor's tarball's SHA-256: the real digest reaches the build", "FAIL build-sodium.sh: --current: the current pin is the current tarball's SHA-256: the real digest reaches the", "FAIL build-sodium.
    B-b1a KILLED (24, ["FAIL build-sodium.sh: the floor's pin is the floor's tarball's SHA-256: the real digest reaches the build", "FAIL build-sodium.sh: --current: the current pin is the current tarball's SHA-256: the real digest reaches the", 'FAIL build-sodium
    B-b1b KILLED (24, ["FAIL build-sodium.sh: the floor's pin is the floor's tarball's SHA-256: the real digest reaches the build", "FAIL build-sodium.sh: --current: the current pin is the current tarball's SHA-256: the real digest reaches the", 'FAIL build-sodium
    B-b1c KILLED (22, ["FAIL build-sodium.sh: the floor's pin is the floor's tarball's SHA-256: the real digest reaches the build", "FAIL build-sodium.sh: --current: the current pin is the current tarball's SHA-256: the real digest reaches the", 'FAIL build-sodium
    B-b1d KILLED (21, ["FAIL build-sodium.sh: the floor's pin is the floor's tarball's SHA-256: the real digest reaches the build", "FAIL build-sodium.sh: --current: the current pin is the current tarball's SHA-256: the real digest reaches the", 'FAIL build-sodium
    B-b1e KILLED (24, ["FAIL build-sodium.sh: the floor's pin is the floor's tarball's SHA-256: the real digest reaches the build", "FAIL build-sodium.sh: --current: the current pin is the current tarball's SHA-256: the real digest reaches the", 'FAIL build-sodium
    B-b2 KILLED (23, ["FAIL build-sodium.sh: the floor's pin is the floor's tarball's SHA-256: the real digest reaches the build", "FAIL build-sodium.sh: --current: the current pin is the current tarball's SHA-256: the real digest reaches the", 'FAIL build-sodium.
    B-b3 KILLED (3, ['FAIL build-sodium.sh: configure that fails shows its last lines, make never runs, and PREFIX is not made', 'FAIL build-sodium.sh: make that fails shows its last lines, make install never runs, and PREFIX is not made', 'FAIL build-sodium.sh: m
    B-b7 KILLED (12, ["FAIL build-sodium.sh: an archive whose SHA-256 is no pin's is refused, naming both, and nothing is unpacked", "FAIL build-sodium.sh: the floor's tarball with the current pin's digest is refused, naming floor_archive", "FAIL build-sodium.sh: 
    B-e1 KILLED (3, ["FAIL build-sodium.sh: both right and a library that is the floor's: built, checked with the floor's soname, th", 'FAIL build-sodium.sh: C_INCLUDE_PATH in the env: the build passes it on after PREFIX/include, and the check pa', "FAIL build-sod
    B-e2 KILLED (9, ["FAIL build-sodium.sh: --current: the current pin is the current tarball's SHA-256: the real digest reaches the", 'FAIL build-sodium.sh: --current: current_archive, current_version and version set in the env move nothing', 'FAIL build-sodium.s
    B-e3 KILLED (5, ["FAIL build-sodium.sh: both right and a library that is the floor's: built, checked with the floor's soname, th", 'FAIL build-sodium.sh: --current, in a tree with no floors file: built the same way, checked with --current, ex', 'FAIL build-sod
    B-e4 KILLED (3, ["FAIL build-sodium.sh: both right and a library that is the floor's: built, checked with the floor's soname, th", 'FAIL build-sodium.sh: --current, in a tree with no floors file: built the same way, checked with --current, ex', 'FAIL build-sod
    B-e6 KILLED (32, ["FAIL build-sodium.sh: the floor's pin is the floor's tarball's SHA-256: the real digest reaches the build", "FAIL build-sodium.sh: --current: the current pin is the current tarball's SHA-256: the real digest reaches the", "FAIL build-sodium.
    B-pt KILLED (1, ['FAIL build-sodium.sh: a configure that left out HAVE_PTHREAD is refused, and make never runs'])
    B-fl KILLED (1, ['FAIL build-sodium.sh: CFLAGS, CPPFLAGS and LDFLAGS in the env never reach configure'])
    B-u1 KILLED (4, ['FAIL build-sodium.sh: two prefixes are a usage error', "FAIL build-sodium.sh: --nothreads, build-chez.sh's flag, is a usage error", 'FAIL build-sodium.sh: --no-load, a flag libsodium has no use for, is a usage error'])
    B-u2 KILLED (1, ['FAIL build-sodium.sh: --no-load, a flag libsodium has no use for, is a usage error'])
    B-u3 KILLED (1, ['FAIL build-sodium.sh: a relative prefix is refused, naming it, before any download'])
    B-u4 KILLED (1, ['FAIL build-sodium.sh: --current --current is a usage error'])
    B-x1 KILLED (1, ['FAIL both scripts are executable, as CI runs them by their names'])
    C-s1 KILLED (50, ["FAIL check-sodium.sh: the floor's library, its header and the lane's env pass, with the identity named", 'FAIL check-sodium.sh: the env names no version: version, current_version, soname and what set to the other rel', "FAIL check-sodium.sh:
    C-s2 KILLED (16, ["FAIL check-sodium.sh: --current: the pinned release's library passes, in a tree with no floors file", 'FAIL check-sodium.sh: --current: it passes whatever floor the tree has: the floors file is not read', 'FAIL check-sodium.sh: --current giv
    C-s3 KILLED (3, ['FAIL check-sodium.sh: the floor with both sonames present and the override naming .26 is refused at the overri', 'FAIL check-sodium.sh: CHEZ_SODIUM_LIBRARY relative, lib/libsodium.so.23, is refused', 'FAIL check-sodium.sh: CHEZ_SODIUM_LIBRARY
    C-s4 KILLED (1, ['FAIL check-sodium.sh: a library that is a directory is refused'])
    C-f1 KILLED (1, ['FAIL check-sodium.sh: no header file is refused, naming its path'])
    C-o1 KILLED (1, ['FAIL check-sodium.sh: CHEZ_SODIUM_LIBRARY unset is refused'])
    C-o2 KILLED (1, ['FAIL check-sodium.sh: CHEZ_SODIUM_LIBRARY set but empty is refused'])
    C-o3 KILLED (2, ['FAIL check-sodium.sh: CHEZ_SODIUM_LIBRARY set but empty is refused', 'FAIL check-sodium.sh: CHEZ_SODIUM_LIBRARY relative, lib/libsodium.so.23, is refused'])
    C-o4 KILLED (3, ['FAIL check-sodium.sh: the floor with both sonames present and the override naming .26 is refused at the overri', 'FAIL check-sodium.sh: CHEZ_SODIUM_LIBRARY naming a copy of the same library elsewhere is refused', 'FAIL check-sodium.sh: CHEZ_S
    C-o5 KILLED (6, ['FAIL check-sodium.sh: CHEZ_SODIUM_LIBRARY naming the bare libsodium.so link is refused', "FAIL build-sodium.sh: both right and a library that is the floor's: built, checked with the floor's soname, th", 'FAIL build-sodium.sh: --current, in a 
    C-h1 KILLED (3, ['FAIL check-sodium.sh: C_INCLUDE_PATH naming another sodium.h first, PREFIX/include second, is refused, naming ', 'FAIL check-sodium.sh: C_INCLUDE_PATH without PREFIX/include, so the compiler finds another sodium.h, is refuse', 'FAIL check-sod
    C-h3 KILLED (63, ["FAIL check-sodium.sh: the floor's library, its header and the lane's env pass, with the identity named", "FAIL check-sodium.sh: --current: the pinned release's library passes, in a tree with no floors file", 'FAIL check-sodium.sh: --current:
    C-h4 KILLED (2, ['FAIL check-sodium.sh: a compiler that lists no sodium.h is refused', 'FAIL check-sodium.sh --discovery: a compiler that lists no sodium.h is refused'])
    C-h5 KILLED (2, ['FAIL check-sodium.sh: a compiler that fails is refused with its own words, whole', 'FAIL check-sodium.sh --discovery: a compiler that fails is refused with its words'])
    C-v1 KILLED (10, ['FAIL check-sodium.sh: a header whose SODIUM_VERSION_STRING is 8.1.3 is refused', "FAIL check-sodium.sh: a header whose version is the floor's with a digit after it is refused", 'FAIL check-sodium.sh: a header and a library both 8.1.3, agreei
    C-v2 KILLED (2, ["FAIL check-sodium.sh: a header whose version is the floor's with a digit after it is refused", 'FAIL check-sodium.sh --discovery: a header of the floor with a digit after it is refused'])
    C-v5 KILLED (3, ['FAIL check-sodium.sh: a header without SODIUM_LIBRARY_VERSION_MAJOR is refused', 'FAIL check-sodium.sh: a header without SODIUM_LIBRARY_VERSION_MINOR is refused', 'FAIL check-sodium.sh: a header whose major is not a natural is refused'])
    C-l1 KILLED (5, ['FAIL check-sodium.sh: a library answering 8.1.3 is refused', 'FAIL check-sodium.sh: a library answering the floor with a digit after it is refused', 'FAIL check-sodium.sh: a library answering NULL for its version is refused'])
    C-l2 KILLED (1, ['FAIL check-sodium.sh: a library answering the floor with a digit after it is refused'])
    C-mm1 KILLED (1, ["FAIL check-sodium.sh: a library whose major differs from the header's is refused"])
    C-mm2 KILLED (2, ["FAIL check-sodium.sh: a library whose minor differs from the header's is refused", 'FAIL check-sodium.sh: a library whose major is right and minor wrong, in a header of 9 and 7, is refused'])
    C-mm3 KILLED (5, ["FAIL check-sodium.sh: --current: the pinned release's library passes, in a tree with no floors file", 'FAIL check-sodium.sh: --current: it passes whatever floor the tree has: the floors file is not read', "FAIL check-sodium.sh: major and min
    C-mm4 KILLED (3, ["FAIL check-sodium.sh: a library whose major differs from the header's is refused", "FAIL check-sodium.sh: a library whose minor differs from the header's is refused", 'FAIL check-sodium.sh: a library whose major is right and minor wrong, in 
    C-m1 KILLED (3, ['FAIL check-sodium.sh: a minimal build, answering 1 to sodium_library_minimal, is refused though all else is ri', 'FAIL check-sodium.sh: a library answering 2 to sodium_library_minimal is refused', "FAIL build-sodium.sh: the floor's build made
    C-m2 KILLED (1, ['FAIL check-sodium.sh: a library answering 2 to sodium_library_minimal is refused'])
    C-p1 KILLED (24, ["FAIL check-sodium.sh: the floor's library, its header and the lane's env pass, with the identity named", "FAIL check-sodium.sh: --current: the pinned release's library passes, in a tree with no floors file", 'FAIL check-sodium.sh: --current:
    C-p2 KILLED (2, ["FAIL check-sodium.sh: a library file that is no shared object is refused with the probe's own words naming it", 'FAIL check-sodium.sh: a CHEZ that fails is refused with its own words, whole'])
    C-p3 KILLED (23, ["FAIL check-sodium.sh: the floor's library, its header and the lane's env pass, with the identity named", "FAIL check-sodium.sh: --current: the pinned release's library passes, in a tree with no floors file", 'FAIL check-sodium.sh: --current:
    C-p4 KILLED (1, ["FAIL check-sodium.sh: the probe is Chez's own script on the library: the arguments are -q, --script, the scrip"])
    C-r1 KILLED (3, ["FAIL check-sodium.sh: a malformed floor is refused, with floor.sh's line and then the script's", 'FAIL check-sodium.sh: no floors file, without --current, is refused', "FAIL check-sodium.sh --discovery: a malformed floors file is refused with
    C-r5 KILLED (1, ["FAIL check-sodium.sh: --current: current_version and version set to the floor's in the env, with the floor's l"])
    C-c1 KILLED (15, ["FAIL check-sodium.sh: --current: the pinned release's library passes, in a tree with no floors file", 'FAIL check-sodium.sh: --current: it passes whatever floor the tree has: the floors file is not read', 'FAIL check-sodium.sh: --current giv
    C-u1 KILLED (4, ['FAIL check-sodium.sh: two prefixes are a usage error', "FAIL check-sodium.sh: --nothreads, check-chez.sh's flag, is a usage error", 'FAIL check-sodium.sh: --no-load, a flag libsodium has no use for, is a usage error'])
    C-u2 KILLED (2, ['FAIL check-sodium.sh: no prefix is a usage error', 'FAIL check-sodium.sh: --discovery given a prefix is a usage error'])
    C-u3 KILLED (1, ['FAIL check-sodium.sh: a relative prefix is refused, naming it'])
    C-u4 KILLED (2, ['FAIL check-sodium.sh: --current alone is a usage error', 'FAIL check-sodium.sh: --current --current is a usage error'])
    C-u5 KILLED (2, ['FAIL check-sodium.sh: no prefix is a usage error', 'FAIL check-sodium.sh: three arguments are a usage error'])
    D-o1 KILLED (3, ['FAIL check-sodium.sh --discovery: CHEZ_SODIUM_LIBRARY set to a library is refused, and no program ran', "FAIL check-sodium.sh --discovery: CHEZ_SODIUM_LIBRARY set to the system's own path is refused", 'FAIL check-sodium.sh --discovery: CHEZ_S
    D-o2 KILLED (1, ['FAIL check-sodium.sh --discovery: CHEZ_SODIUM_LIBRARY set but empty is refused'])
    D-r1 KILLED (1, ['FAIL check-sodium.sh --discovery: a preflight that refuses, though its stdout is the accepted report, is refus'])
    D-r2 KILLED (1, ['FAIL check-sodium.sh --discovery: a preflight that exits 0 and writes to stderr is refused'])
    D-w1 KILLED (1, ['FAIL check-sodium.sh --discovery: a report with an extra line is refused'])
    D-w1b KILLED (9, ["FAIL check-sodium.sh --discovery: another path, /usr/local/lib's, is refused", "FAIL check-sodium.sh --discovery: the newer soname's path is refused", 'FAIL check-sodium.sh --discovery: the right path from another source is refused'])
    D-v KILLED (5, ['FAIL check-sodium.sh --discovery: another version, 8.1.3, is refused', 'FAIL check-sodium.sh --discovery: the floor with a digit after it is refused', "FAIL check-sodium.sh --discovery: another minor, 10.4 against the header's 10.3, is refused
    D-w2 KILLED (4, ['FAIL check-sodium.sh --discovery: a counts line of a nonzero count is refused', 'FAIL check-sodium.sh --discovery: a counts line of an empty list is refused', 'FAIL check-sodium.sh --discovery: a counts line with an unclosed list is refused']
    D-x KILLED (29, ["FAIL check-sodium.sh --discovery: the floor's report and header pass, with the one preflight call and the two ", 'FAIL check-sodium.sh --discovery: a floor of 9.0.1 and a report and header of it pass: the floor is read, not ', "FAIL check-sod
    D-v5 KILLED (54, ["FAIL check-sodium.sh: the floor's library, its header and the lane's env pass, with the identity named", 'FAIL check-sodium.sh: the env names no version: version, current_version, soname and what set to the other rel', "FAIL check-sodium.sh:
    D-hlit KILLED (25, ["FAIL check-sodium.sh --discovery: the floor's report and header pass, with the one preflight call and the two ", 'FAIL check-sodium.sh --discovery: a floor of 9.0.1 and a report and header of it pass: the floor is read, not ', "FAIL check-
    D-plit KILLED (21, ["FAIL check-sodium.sh --discovery: the floor's report and header pass, with the one preflight call and the two ", 'FAIL check-sodium.sh --discovery: a floor of 9.0.1 and a report and header of it pass: the floor is read, not ', "FAIL check-
    X-mk KILLED (1, ["FAIL check-sodium.sh --discovery: the preflight call is make build's recipe, its paths made absolute"])

First draft of D-p and D-src named text that was not in the script (BAD-MUTANT, nothing run); fixed and rerun:
D-p killed (5 rows), D-src killed (21), D-mn (the minor not compared in the report) killed (2).

The floor's text in scripts/ci, by hand in a copy, make check-floors: 1.0.18 written in code and in a
comment, in each script (4 runs): each fails naming "scripts/ci/<script>: line N contains the libsodium floor 1.0.18".
Survivors: none. No mutant was judged equivalent.

### Result
- test-ci-sodium: 144 rows pass, plain about 11 s; under the gate 46 s (limit 450 s).
- make check-floors passes; make check-suites passes (26); make check-test-fails passes, 13 of 13, floors-script among them.
- Not run: whole make test (the lanes builder is editing ci.yml, check-ci.sh and test-check-ci.sps).

### Clean rerun
Suite run directly with the Makefile's library path (src:tests:build/scheme-libs), tree unchanged: 144 passes, 0 failures.

### Differences from the design
- build-sodium.sh also treats an argument starting with - as a usage error (so --current --current is usage, not a relative prefix).
- Added rows: a failing tar; the probe's own argv (a logging CHEZ stand-in); the CHEZ that fails with words.
- Not made: a row for each tool left out of tools/ (PATH narrowing is proved by the five missing-shim rows); C-r4, C-m3 are covered by other rows; D-r3 (CHEZ absent) dropped since the shell's message differs by sh.
- cworks counts only check work directories named in cc calls, so refusals before the compiler show 0.
- Mutants run: 98 plus 3 reruns.

### After the review

Each mutant below was run alone in a whole copy of the tree under build/slice5-scripts/mut/.

- **S5-F1.** `real-floor` is read under a guard with its own sentinel (`floors-file-unreadable`), and a row
  "packaging/floors.sexp gives a libsodium floor" names it. Watched, in a copy with two `sodium` entries in
  `packaging/floors.sexp`: before the fix the suite exits 255 after "Starting test ci-sodium" and names no test;
  after it, 2 rows fail by name (that row and "the real floors file: the tarball's name and URLs come from it"),
  the suite runs on, 142 pass, exit 1.
- **S5-F2.** The env row now runs to the check, with a stub library and header, and expects the whole success
  output and every call, so its `cc` calls show `[CHEZ_SODIUM_LIBRARY=PREFIX/lib/libsodium.so.23]`. The same for the
  `--current` env row (soname .26). The row that ended before the compiler, "C_INCLUDE_PATH in the env: the check
  gets PREFIX/include before it", is dropped: the success row with the same env already shows
  `C_INCLUDE_PATH=PREFIX/include:<env value>` in the check's calls. Watched: `soname=${soname:-libsodium.so.23}` now
  killed (1 row, the floor env row); `C_INCLUDE_PATH=$prefix/include` alone killed (7 rows). Row count 144.
- **S5-F3.** Both curl calls carry `--proto '=https'`; the stand-in's expected call (`curl --proto =https -fsSL ...`)
  matches. Watched: dropped from the first call, 31 rows fail; from the second, 5 rows fail.
- **S5-F12.** `trap 'exit 1' HUP INT TERM` beside the EXIT trap in both scripts. Unheld: no row, as logged.
- **S5-F5.** Both scripts' floor-raise comments now name ci.yml's floor lane library path (the soname in each
  CHEZ_SODIUM_LIBRARY there, lines 381, 388, 395 today), tests/check-ci.sh's floor library (sodso["floor"], line 622)
  and tests/test-check-ci.sps's floor value (sod-so, line 1322); the lines were checked against today's files.

Clean rerun (container): test-ci-sodium 144 pass plain; under the gate 40 s (limit 450 s); make check-floors passes;
make check-test-fails passes, 13 of 13; make check-suites passes (26).

## The lanes

Files: `.github/workflows/ci.yml`, `tests/check-ci.sh`, `tests/test-check-ci.sps`.

Every mutant was one exact replacement in `tests/check-ci.sh`, whose old text matched exactly once,
applied in a whole copy of the tree under `build/slice5-lanes/mut0` to `mut3` (the container sees only
the copy; stub `build-sodium.sh` and `check-sodium.sh` stood in the copies until the real scripts
landed). Before each mutant's suite ran, the real `ci.yml` was checked under the mutant with the
host's mawk: it passed in all of them, so no mutant refuses the whole input. The suite ran in the
container, one run per mutant; the copy's script was then restored and compared with the original.
Harness: `build/slice5-lanes/mutants.py`, `runmut.py`, `runall.py`, `mkcopy.sh`.

### Red first

1. The rows were written against the unchanged `check-ci.sh`, with the new `ci.yml` in place: 667
   rows failed (every row built from a lane, or from the discovery step, or over the five jobs) and
   8 passed. The real workflow failed `check-ci`: `job "floor" is not one of main, memory,
   nothreads`, and each lane env line named the two names. No row raised in its own construction.
2. Then `check-ci.sh`. First green run: 9 rows failed, each for a reason in the rows, not the script:
   `main's install check moved after Checks and suites` (the discovery step is out of order too,
   expected list gained it); three `written twice` rows per lane for the check, `make build` and
   `make test` (the env exception's "only for" loop ran before the step counted, so each copy of a
   duplicated step was named; fixed in the script: the three kinds are exempt before the count);
   `a with value names CHEZ_SODIUM_LIBRARY` (a restore at no libsodium path counts as a Chez restore,
   after the Chez build: expected list gained the two consequences).
3. Green: 675 passes, exit 0.

### Mutants

A mutant "guards" the rule it turns off; "Result" is killed when at least one row failed. The rows
that failed are in `build/slice5-lanes/mut-ID.out` (the suite's output per mutant).


#### S1 lane's first step is the checkout
- Guards: rows that plant the rule "lane's first step is the checkout":
  floor: the checkout without submodules; floor: the checkout with submodules: false; current: the checkout without submodules; current: the checkout with submodules: false
- Mutation: `if (job == "main" || job == "memory" || isl(job)) {` -> `if (job == "main" || job == "memory") {`
- Result: killed (4 rows failed)

#### S2a lane's Chez build line required
- Guards: rows that plant the rule "lane's Chez build line required":
  floor: the Chez build deleted; floor: the Chez build written twice; current: the Chez build deleted; current: the Chez build written twice
- Mutation: `if (c != 1) { prob(jln, "job " job " has " c " steps that run \"" x "\", not one"); continue }` -> `if (c != 1) { if (!(isl(job) && x == BLDT)) prob(jln, "job " job " has " c " steps that run \"" x "\", not one"); continue }`
- Result: killed (4 rows failed)

#### S2b lane's check-chez line required
- Guards: rows that plant the rule "lane's check-chez line required":
  floor: the check-chez step deleted; current: the check-chez step deleted; floor: the step that runs scripts/ci/check-chez.sh "$RUNNER_TEMP/chez-threads" deleted; floor: the step that runs scripts/ci/check-chez.sh "$RUNNER_TEMP/chez-threads" written twice; floor: check-chez with --nothreads; current: the step that runs scripts/ci/check-chez.sh "$RUNNER_TEMP/chez-threads" deleted; current: the step that runs scripts/ci/check-chez.sh "$RUNNER_TEMP/chez-threads" written twice; current: check-chez with --nothreads
- Mutation: `if (c != 1) { prob(jln, "job " job " has " c " steps that run \"" x "\", not one"); continue }` -> `if (c != 1) { if (!(isl(job) && x == CHKT)) prob(jln, "job " job " has " c " steps that run \"" x "\", not one"); continue }`
- Result: killed (8 rows failed)

#### S2c lane's compiler line required
- Guards: rows that plant the rule "lane's compiler line required":
  floor: the step that runs echo "id=$(cc --version | head -n 1 | tr -c '[:alnum:].' '-')" >> "$GITHUB; floor: the step that runs echo "id=$(cc --version | head -n 1 | tr -c '[:alnum:].' '-')" >> "$GITHUB; floor: the compiler step's line changed; current: the step that runs echo "id=$(cc --version | head -n 1 | tr -c '[:alnum:].' '-')" >> "$GITH; current: the step that runs echo "id=$(cc --version | head -n 1 | tr -c '[:alnum:].' '-')" >> "$GITH; current: the compiler step's line changed
- Mutation: `if (c != 1) { prob(jln, "job " job " has " c " steps that run \"" x "\", not one"); continue }` -> `if (c != 1) { if (!(isl(job) && x == CCLINE)) prob(jln, "job " job " has " c " steps that run \"" x "\", not one"); continue }`
- Result: killed (6 rows failed)

#### S2d lane's libsodium build line required
- Guards: rows that plant the rule "lane's libsodium build line required":
  floor: the step that runs scripts/ci/build-sodium.sh "$RUNNER_TEMP/sodium-floor" deleted; floor: the step that runs scripts/ci/build-sodium.sh "$RUNNER_TEMP/sodium-floor" written twice; floor: the build with the other lane's flag; floor: the build into another directory; current: the step that runs scripts/ci/build-sodium.sh "$RUNNER_TEMP/sodium-current" --current delet; current: the step that runs scripts/ci/build-sodium.sh "$RUNNER_TEMP/sodium-current" --current writt; current: the build with the other lane's flag; current: the build into another directory
- Mutation: `if (c != 1) { prob(jln, "job " job " has " c " steps that run \"" x "\", not one"); continue }` -> `if (c != 1) { if (!(isl(job) && x == sodbld[job])) prob(jln, "job " job " has " c " steps that run \"" x "\", not one"); continue }`
- Result: killed (8 rows failed)

#### S2e lane's libsodium check line required
- Guards: rows that plant the rule "lane's libsodium check line required":
  floor: the step that runs scripts/ci/check-sodium.sh "$RUNNER_TEMP/sodium-floor" deleted; floor: the step that runs scripts/ci/check-sodium.sh "$RUNNER_TEMP/sodium-floor" written twice; floor: the check with --current; current: the step that runs scripts/ci/check-sodium.sh "$RUNNER_TEMP/sodium-current" --current delet; current: the step that runs scripts/ci/check-sodium.sh "$RUNNER_TEMP/sodium-current" --current writt; current: the check without --current
- Mutation: `if (c != 1) { prob(jln, "job " job " has " c " steps that run \"" x "\", not one"); continue }` -> `if (c != 1) { if (!(isl(job) && x == sodchk[job])) prob(jln, "job " job " has " c " steps that run \"" x "\", not one"); continue }`
- Result: killed (6 rows failed)

#### S2f lane's make build line required
- Guards: rows that plant the rule "lane's make build line required":
  floor: the step that runs make build deleted; floor: the step that runs make build written twice; floor: make build with an argument; floor: a run line names C_INCLUDE_PATH; current: the step that runs make build deleted; current: the step that runs make build written twice; current: make build with an argument; current: a run line names C_INCLUDE_PATH
- Mutation: `if (c != 1) { prob(jln, "job " job " has " c " steps that run \"" x "\", not one"); continue }` -> `if (c != 1) { if (!(isl(job) && x == BUILDLINE)) prob(jln, "job " job " has " c " steps that run \"" x "\", not one"); continue }`
- Result: killed (8 rows failed)

#### S2g lane's make test line required
- Guards: rows that plant the rule "lane's make test line required":
  floor: the step that runs make test deleted; floor: the step that runs make test written twice; floor: make test X; floor: make test as a block scalar; current: the step that runs make test deleted; current: the step that runs make test written twice; current: make test X; current: make test as a block scalar
- Mutation: `if (c != 1) { prob(jln, "job " job " has " c " steps that run \"" x "\", not one"); continue }` -> `if (c != 1) { if (!(isl(job) && x == TESTLINE)) prob(jln, "job " job " has " c " steps that run \"" x "\", not one"); continue }`
- Result: killed (8 rows failed)

#### S3 a lane's required line is run once, not twice
- Guards: rows that plant the rule "a lane's required line is run once, not twice":
  floor: the Chez build written twice; current: the Chez build written twice; floor: the step that runs scripts/ci/check-chez.sh "$RUNNER_TEMP/chez-threads" written twice; floor: the step that runs echo "id=$(cc --version | head -n 1 | tr -c '[:alnum:].' '-')" >> "$GITHUB; floor: the step that runs scripts/ci/build-sodium.sh "$RUNNER_TEMP/sodium-floor" written twice; floor: the step that runs scripts/ci/check-sodium.sh "$RUNNER_TEMP/sodium-floor" written twice; floor: the step that runs make build written twice; floor: the step that runs make test written twice; current: the step that runs scripts/ci/check-chez.sh "$RUNNER_TEMP/chez-threads" written twice; current: the step that runs echo "id=$(cc --version | head -n 1 | tr -c '[:alnum:].' '-')" >> "$GITH ; and 4 more
- Mutation: `if (c != 1) { prob(jln, "job " job " has " c " steps that run` -> `if (c != 1 && !(isl(job) && c > 1)) { prob(jln, "job " job " has " c " steps that run`
- Result: killed (14 rows failed)

#### S4 a lane's steps run in order
- Guards: rows that plant the rule "a lane's steps run in order":
  floor: the check after make build; floor: make test before make build; floor: the libsodium build before check-chez; current: the check after make build; current: make test before make build; current: the libsodium build before check-chez
- Mutation: `if (pos <= lastp) prob(` -> `if (pos <= lastp && !isl(job)) prob(`
- Result: killed (6 rows failed)

#### S5 the libsodium build carries its if
- Guards: rows that plant the rule "the libsodium build carries its if":
  floor: the libsodium build without its if; current: the libsodium build without its if
- Mutation: `if (S_if[at] == "") prob(S_ln[at]` -> `if (S_if[at] == "" && k != "sbld") prob(S_ln[at]`
- Result: killed (2 rows failed)

#### S6 a lane's if is one of two
- Guards: rows that plant the rule "a lane's if is one of two":
  floor: the Chez build with another if; current: the Chez build with another if; floor: an if with another value on the libsodium build; floor: an if: always() on the libsodium check; floor: an if: always() on make build; floor: an if: always() on make test; current: an if with another value on the libsodium build; current: an if: always() on the libsodium check; current: an if: always() on make build; current: an if: always() on make test
- Mutation: `if (S_if[sn] != IFLINE && S_if[sn] != IFSOD)` -> `if (0)`
- Result: killed (10 rows failed)

#### S7 the lane's other steps carry no if
- Guards: rows that plant the rule "the lane's other steps carry no if":
  floor: an if: always() on the libsodium check; floor: an if: always() on make build; floor: an if: always() on make test; floor: the libsodium if on make test; floor: the Chez if on make test; current: an if: always() on the libsodium check; current: an if: always() on make build; current: an if: always() on make test; current: the libsodium if on make test; current: the Chez if on make test
- Mutation: `} else if (S_if[at] != "") prob(S_ifln[at]` -> `} else if (S_if[at] != "" && !isl(job)) prob(S_ifln[at]`
- Result: killed (10 rows failed)

#### S8 the Chez if only on the Chez build and save
- Guards: rows that plant the rule "the Chez if only on the Chez build and save":
  floor: the Chez if on the libsodium build; floor: the Chez if on the libsodium save; floor: the Chez if on make test; current: the Chez if on the libsodium build; current: the Chez if on the libsodium save; current: the Chez if on make test
- Mutation: `else if (S_if[sn] == IFLINE && !(` -> `else if (0 && S_if[sn] == IFLINE && !(`
- Result: killed (6 rows failed)

#### S9 the libsodium if only on its build and save
- Guards: rows that plant the rule "the libsodium if only on its build and save":
  floor: the build into another directory; floor: the libsodium if on the Chez build; floor: the libsodium if on the Chez save; floor: the libsodium if on make test; floor: the libsodium save's path is the other lane's; current: the build into another directory; current: the libsodium if on the Chez build; current: the libsodium if on the Chez save; current: the libsodium if on make test; current: the libsodium save's path is the other lane's
- Mutation: `else if (S_if[sn] == IFSOD && !(` -> `else if (0 && S_if[sn] == IFSOD && !(`
- Result: killed (10 rows failed)

#### S10 the libsodium restore's key, whole
- Guards: rows that plant the rule "the libsodium restore's key, whole":
  floor: the libsodium key drops 'packaging/floors.sexp',; floor: the libsodium key drops , 'scripts/ci/floor.sh'; floor: the libsodium key drops , 'scripts/ci/build-sodium.sh'; floor: the libsodium key drops , 'scripts/ci/check-sodium.sh'; floor: the libsodium key hashes one file more; floor: the libsodium key drops the compiler; floor: the libsodium key drops the image; floor: the libsodium key takes the other lane's prefix; floor: the libsodium key takes the other lane's whole key; floor: the libsodium key has a tail ; and 10 more
- Mutation: `if (S_key[sn] != sodkey[job])` -> `if (0 && S_key[sn] != sodkey[job])`
- Result: killed (20 rows failed)

#### S10b the libsodium restore's key, past its hashed files
- Guards: rows that plant the rule "the libsodium restore's key, past its hashed files":
  floor: the libsodium key drops the compiler; floor: the libsodium key drops the image; floor: the libsodium key has a tail; current: the libsodium key drops the compiler; current: the libsodium key drops the image; current: the libsodium key has a tail
- Mutation: `if (S_key[sn] != sodkey[job])` -> `if (substr(S_key[sn], 1, index(S_key[sn], ") }}")) != substr(sodkey[job], 1, index(sodkey[job], ") }}")))`
- Result: killed (6 rows failed)

#### S11 a lane's Chez restore key
- Guards: rows that plant the rule "a lane's Chez restore key":
  floor: the restore's key drops the prefix; floor: the restore's key has a tail that is no suffix; floor: the restore's key is no expression at all; floor: the restore's key hashes one file more; floor: the restore's key takes the other Chez's prefix; current: the restore's key drops the prefix; current: the restore's key has a tail that is no suffix; current: the restore's key is no expression at all; current: the restore's key hashes one file more; current: the restore's key takes the other Chez's prefix ; and 2 more
- Mutation: `if (!keyok(S_key[sn]))` -> `if (!isl(job) && !keyok(S_key[sn]))`
- Result: killed (12 rows failed)

#### S12 the libsodium restore's id
- Guards: rows that plant the rule "the libsodium restore's id":
  floor: the libsodium restore without its id; floor: the libsodium restore's id is another; floor: the Chez cache's path is the libsodium cache's; current: the libsodium restore without its id; current: the libsodium restore's id is another; current: the Chez cache's path is the libsodium cache's
- Mutation: `if (S_id[sn] != "sodium")` -> `if (0 && S_id[sn] != "sodium")`
- Result: killed (6 rows failed)

#### S13 the libsodium save's key
- Guards: rows that plant the rule "the libsodium save's key":
  floor: the libsodium save is keyed by the Chez cache; floor: the libsodium save is keyed as a restore is; current: the libsodium save is keyed by the Chez cache; current: the libsodium save is keyed as a restore is
- Mutation: `want = "${{ steps.sodium.outputs.cache-primary-key }}" /       if (S_key[sn] != want)` -> `want = "${{ steps.sodium.outputs.cache-primary-key }}" /       if (0 && S_key[sn] != want)`
- Result: killed (4 rows failed)

#### S13b a lane's Chez save key
- Guards: rows that plant the rule "a lane's Chez save key":
  floor: the save is keyed as a restore is; floor: the save has no key; current: the save is keyed as a restore is; current: the save has no key; floor: the Chez save is keyed by the libsodium cache; current: the Chez save is keyed by the libsodium cache
- Mutation: `want = "${{ steps.chez.outputs.cache-primary-key }}" /     if (S_key[sn] != want)` -> `want = "${{ steps.chez.outputs.cache-primary-key }}" /     if (!isl(job) && S_key[sn] != want)`
- Result: killed (6 rows failed)

#### S14 a lane's cache path is one of two
- Guards: rows that plant the rule "a lane's cache path is one of two":
  floor: the restore's path is another; floor: the save's path is another; current: the restore's path is another; current: the save's path is another; floor: the libsodium restore's path is the other lane's; floor: the libsodium save's path is the other lane's; floor: a with value names CHEZ_SODIUM_LIBRARY; current: the libsodium restore's path is the other lane's; current: the libsodium save's path is the other lane's; current: a with value names CHEZ_SODIUM_LIBRARY
- Mutation: `prob(S_pathln[sn] ? S_pathln[sn] : S_ln[sn], "the cache path in job " job " is not one of " cachepath[job] " or " sodp[job]) /       return` -> `return`
- Result: killed (10 rows failed)

#### S15a one libsodium restore
- Guards: rows that plant the rule "one libsodium restore":
  floor: the libsodium restore's path is the other lane's; floor: the libsodium restore deleted; floor: the libsodium restore written twice; floor: the Chez cache's path is the libsodium cache's; floor: a with value names CHEZ_SODIUM_LIBRARY; floor: the libsodium restore uses actions/cache, not actions/cache/restore; current: the libsodium restore's path is the other lane's; current: the libsodium restore deleted; current: the libsodium restore written twice; current: the Chez cache's path is the libsodium cache's ; and 2 more
- Mutation: `if (sr != 1) prob(` -> `if (0 && sr != 1) prob(`
- Result: killed (12 rows failed)

#### S15c one libsodium save
- Guards: rows that plant the rule "one libsodium save":
  floor: the libsodium save's path is the other lane's; floor: the libsodium save deleted; current: the libsodium save's path is the other lane's; current: the libsodium save deleted
- Mutation: `if (ss != 1) prob(` -> `if (0 && ss != 1) prob(`
- Result: killed (4 rows failed)

#### S15d a lane's one Chez restore and save
- Guards: rows that plant the rule "a lane's one Chez restore and save":
  floor: the Chez restore deleted; floor: the Chez restore written twice; floor: the restore uses actions/cache, not actions/cache/restore; current: the Chez restore deleted; current: the Chez restore written twice; current: the restore uses actions/cache, not actions/cache/restore; floor: the Chez cache's path is the libsodium cache's; floor: a with value names CHEZ_SODIUM_LIBRARY; current: the Chez cache's path is the libsodium cache's; current: a with value names CHEZ_SODIUM_LIBRARY
- Mutation: `if (nr != 1) prob(jln` -> `if (nr != 1 && !isl(job)) prob(jln`
- Result: killed (10 rows failed)

#### S15e a lane's one Chez save
- Guards: rows that plant the rule "a lane's one Chez save":
  floor: the Chez save deleted; floor: the Chez save written twice; current: the Chez save deleted; current: the Chez save written twice
- Mutation: `if (ns != 1) prob(jln` -> `if (ns != 1 && !isl(job)) prob(jln`
- Result: killed (4 rows failed)

#### S16 the libsodium restore before its build
- Guards: rows that plant the rule "the libsodium restore before its build":
  floor: the libsodium build before check-chez; floor: the libsodium restore moved below the check; current: the libsodium build before check-chez; current: the libsodium restore moved below the check
- Mutation: `if (restore && s > t) prob(S_ln[s], "job " job " restores the libsodium` -> `if (0 && restore && s > t) prob(S_ln[s], "job " job " restores the libsodium`
- Result: killed (4 rows failed)

#### S17 the libsodium save after its build
- Guards: rows that plant the rule "the libsodium save after its build":
  floor: the libsodium save moved above the build; current: the libsodium save moved above the build
- Mutation: `if (!restore && s < t) prob(S_ln[s], "job " job " saves the libsodium` -> `if (0 && !restore && s < t) prob(S_ln[s], "job " job " saves the libsodium`
- Result: killed (2 rows failed)

#### S18 the libsodium save before its check
- Guards: rows that plant the rule "the libsodium save before its check":
  floor: the libsodium save moved below the check; current: the libsodium save moved below the check
- Mutation: `if (!restore && argof(t, "check-sodium.sh") && s > t)` -> `if (0 && !restore && argof(t, "check-sodium.sh") && s > t)`
- Result: killed (2 rows failed)

#### S19 the libsodium restore after the compiler step
- Guards: rows that plant the rule "the libsodium restore after the compiler step":
  floor: the Chez cache's path is the libsodium cache's; floor: the compiler step moved below the libsodium restore; current: the Chez cache's path is the libsodium cache's; current: the compiler step moved below the libsodium restore
- Mutation: `if (restore && atrun[CCLINE] && s < atrun[CCLINE])` -> `if (0 && restore && atrun[CCLINE] && s < atrun[CCLINE])`
- Result: killed (4 rows failed)

#### S21 a lane's uses are checkout, restore, save
- Guards: rows that plant the rule "a lane's uses are checkout, restore, save":
  floor: the restore uses actions/cache, not actions/cache/restore; floor: a step that uses another action; current: the restore uses actions/cache, not actions/cache/restore; current: a step that uses another action; floor: the libsodium restore uses actions/cache, not actions/cache/restore; current: the libsodium restore uses actions/cache, not actions/cache/restore
- Mutation: `if (S_uses[s] != "" && !(S_uses[s] ~ /^actions\/(checkout` -> `if (!isl(job) && S_uses[s] != "" && !(S_uses[s] ~ /^actions\/(checkout`
- Result: killed (6 rows failed)

#### S22 the compiler step has id cc
- Guards: rows that plant the rule "the compiler step has id cc":
  floor: the compiler step without its id; current: the compiler step without its id
- Mutation: `if (k == "cc" && S_id[at] != "cc")` -> `if (0 && k == "cc" && S_id[at] != "cc")`
- Result: killed (2 rows failed)

#### S23 a lane's required line is the whole run line
- Guards: rows that plant the rule "a lane's required line is the whole run line":
  floor: make test X; floor: make build with an argument; floor: the check with --current; floor: the build with the other lane's flag; floor: check-chez with --nothreads; floor: a run line names C_INCLUDE_PATH; current: make test X; current: make build with an argument; current: check-chez with --nothreads; current: a run line names C_INCLUDE_PATH
- Mutation: `x = substr(S_run[s], 6)` -> `x = substr(S_run[s], 6) /     if (isl(job)) for (i2 = 1; i2 <= m; i2++) if (substr(x, 1, length(rq[i2])) == rq[i2]) x = rq[i2]`
- Result: killed (10 rows failed)

#### S24 a lane's env keys are three
- Guards: rows that plant the rule "a lane's env keys are three":
  floor: the suites' env gains CPATH; floor: the suites' env gains LD_LIBRARY_PATH; floor: the suites' env gains CC; floor: the suites' env gains MAKEFLAGS; floor: the suites' env gains CHEZ_SODIUM_GATE_CHILD; current: the suites' env gains CPATH; current: the suites' env gains LD_LIBRARY_PATH; current: the suites' env gains CC; current: the suites' env gains MAKEFLAGS; current: the suites' env gains CHEZ_SODIUM_GATE_CHILD
- Mutation: `if (!(key in laneenv)) {` -> `if (0 && !(key in laneenv)) {`
- Result: killed (10 rows failed)

#### S25 a lane's CHEZ is its Chez
- Guards: rows that plant the rule "a lane's CHEZ is its Chez":
  floor: the check's CHEZ is the nothreads Chez; current: the check's CHEZ is the nothreads Chez
- Mutation: `if (key == "CHEZ" && val != want)` -> `if (key == "CHEZ" && !isl(job) && val != want)`
- Result: killed (2 rows failed)

#### S26 the lane's steps carry CHEZ
- Guards: rows that plant the rule "the lane's steps carry CHEZ":
  floor: the check without CHEZ; floor: the check without any env; floor: the libsodium build without CHEZ; current: the check without CHEZ; current: the check without any env; current: the libsodium build without CHEZ
- Mutation: `if (k == "sbld" || k == "schk" || k == "sbuild" || k == "stest") needenv(at, x, "CHEZ")` -> `if (0) needenv(at, x, "CHEZ")`
- Result: killed (6 rows failed)

#### S27 the lane's steps carry the library
- Guards: rows that plant the rule "the lane's steps carry the library":
  floor: make build without CHEZ_SODIUM_LIBRARY; floor: the check without any env; current: make build without CHEZ_SODIUM_LIBRARY; current: the check without any env
- Mutation: `needenv(at, x, "CHEZ_SODIUM_LIBRARY"); needenv(at, x, "C_INCLUDE_PATH")` -> `needenv(at, x, "C_INCLUDE_PATH")`
- Result: killed (4 rows failed)

#### S28 the lane's steps carry the header directory
- Guards: rows that plant the rule "the lane's steps carry the header directory":
  floor: make test without C_INCLUDE_PATH; floor: the check without any env; current: make test without C_INCLUDE_PATH; current: the check without any env
- Mutation: `needenv(at, x, "CHEZ_SODIUM_LIBRARY"); needenv(at, x, "C_INCLUDE_PATH")` -> `needenv(at, x, "CHEZ_SODIUM_LIBRARY")`
- Result: killed (4 rows failed)

#### S29 the library's value
- Guards: rows that plant the rule "the library's value":
  floor: the check's library is the other lane's; floor: the check's library is this lane's directory with the other release's soname; floor: the library's value is relative; current: the check's library is the other lane's; current: the check's library is this lane's directory with the other release's soname; current: the library's value is relative
- Mutation: `envval(at, "CHEZ_SODIUM_LIBRARY", sodlib[job]); envval(at, "C_INCLUDE_PATH", sodinc[job])` -> `envval(at, "C_INCLUDE_PATH", sodinc[job])`
- Result: killed (6 rows failed)

#### S29b the library's value, soname included
- Guards: rows that plant the rule "the library's value, soname included":
  floor: the check's library is this lane's directory with the other release's soname; current: the check's library is this lane's directory with the other release's soname
- Mutation: `envval(at, "CHEZ_SODIUM_LIBRARY", sodlib[job]);` -> `if (((at, "CHEZ_SODIUM_LIBRARY") in S_ev) && substr(S_evv[at, "CHEZ_SODIUM_LIBRARY"], 1, length(sodp[job]) + 5) != substr(sodlib[job], 1, length(sodp[job]) + 5)) prob(S_evln[at, "CHEZ_SODIUM_LIBRARY"], "env CHEZ_SODIUM_LIBRARY in job " job " is not " sodlib[jo`
- Result: killed (2 rows failed)

#### S30 the header directory's value
- Guards: rows that plant the rule "the header directory's value":
  floor: the suites' header directory has a second directory; floor: the header directory's value names CPATH; current: the suites' header directory has a second directory; current: the header directory's value names CPATH
- Mutation: `envval(at, "CHEZ_SODIUM_LIBRARY", sodlib[job]); envval(at, "C_INCLUDE_PATH", sodinc[job])` -> `envval(at, "CHEZ_SODIUM_LIBRARY", sodlib[job])`
- Result: killed (4 rows failed)

#### S31 the names only on the three steps
- Guards: rows that plant the rule "the names only on the three steps":
  floor: make test X; floor: make test as a block scalar; floor: make build with an argument; floor: the check with --current; floor: the libsodium build with the override; floor: the libsodium restore with the header directory; floor: the Chez build with the override; floor: a run line names C_INCLUDE_PATH; current: make test X; current: make test as a block scalar ; and 6 more
- Mutation: `if (S_run[s] in okrun) continue` -> `continue`
- Result: killed (16 rows failed)

#### S32 the names exception, in a lane alone
- Guards: rows that plant the rule "the names exception, in a lane alone":
  CHEZ_SODIUM_LIBRARY in a step's env; main's install check gains CHEZ_SODIUM_LIBRARY, with floor's exact value; main's discovery step gains CHEZ_SODIUM_LIBRARY, with floor's exact value; memory's gate step gains CHEZ_SODIUM_LIBRARY, with floor's exact value; memory's test-memory step gains CHEZ_SODIUM_LIBRARY, with floor's exact value; nothreads's step gains CHEZ_SODIUM_LIBRARY, with floor's exact value; main's install check gains C_INCLUDE_PATH, with floor's exact value; main's discovery step gains C_INCLUDE_PATH, with floor's exact value; memory's gate step gains C_INCLUDE_PATH, with floor's exact value; memory's test-memory step gains C_INCLUDE_PATH, with floor's exact value ; and 1 more
- Mutation: `&& subk == "env" && isl(job)) {` -> `&& subk == "env") {`
- Result: killed (11 rows failed)

#### S33 the names exception, for the name alone
- Guards: rows that plant the rule "the names exception, for the name alone":
  floor: the header directory's value names CPATH; current: the header directory's value names CPATH
- Mutation: `if (k == 1 && ealk != "" && x == ealk) continue` -> `if (ealk != "" && (x in banned)) continue`
- Result: killed (2 rows failed)

#### S34 the names exception, for an env key alone
- Guards: rows that plant the rule "the names exception, for an env key alone":
  floor: a with key of the restore is C_INCLUDE_PATH; current: a with key of the restore is C_INCLUDE_PATH
- Mutation: `&& instep && subk == "env" && isl(job)) {` -> `&& instep && isl(job)) {`
- Result: killed (2 rows failed)

#### S35a the names exception, for a plain key: quotes stripped
- Guards: rows that plant the rule "the names exception, for a plain key: quotes stripped":
  floor: a quoted key, "C_INCLUDE_PATH", in the suites' env; current: a quoted key, "C_INCLUDE_PATH", in the suites' env
- Mutation: `if (substr(rest, 1, 21) == "CHEZ_SODIUM_LIBRARY: ") ealk = "CHEZ_SODIUM_LIBRARY" /     else if (substr(rest, 1, 16) == "C_INCLUDE_PATH: ") ealk = "C_INCLUDE_PATH"` -> `qs = rest; gsub(/"/, "", qs) /     if (substr(qs, 1, 21) == "CHEZ_SODIUM_LIBRARY: ") ealk = "CHEZ_SODIUM_LIBRARY" /     else if (substr(qs, 1, 16) == "C_INCLUDE_PATH: ") ealk = "C_INCLUDE_PATH"`
- Result: killed (2 rows failed)

#### S35b the names exception, for a plain key: a leading ? stripped
- Guards: rows that plant the rule "the names exception, for a plain key: a leading ? stripped":
  floor: an explicit key, ? C_INCLUDE_PATH: x, in the suites' env; current: an explicit key, ? C_INCLUDE_PATH: x, in the suites' env
- Mutation: `if (substr(rest, 1, 21) == "CHEZ_SODIUM_LIBRARY: ") ealk = "CHEZ_SODIUM_LIBRARY" /     else if (substr(rest, 1, 16) == "C_INCLUDE_PATH: ") ealk = "C_INCLUDE_PATH"` -> `qs = rest; sub(/^\? +/, "", qs) /     if (substr(qs, 1, 21) == "CHEZ_SODIUM_LIBRARY: ") ealk = "CHEZ_SODIUM_LIBRARY" /     else if (substr(qs, 1, 16) == "C_INCLUDE_PATH: ") ealk = "C_INCLUDE_PATH"`
- Result: killed (2 rows failed)

#### S36 the lanes are required jobs
- Guards: rows that plant the rule "the lanes are required jobs":
  the floor job deleted; the current job deleted
- Mutation: `for (i = 1; i <= 5; i++) /       if (!(jn[i] in jobseen))` -> `for (i = 1; i <= 3; i++) /       if (!(jn[i] in jobseen))`
- Result: killed (2 rows failed)

#### S37 no job beside the five
- Guards: rows that plant the rule "no job beside the five":
  a job added; a job beside the five
- Mutation: `for (i = 1; i <= 5; i++) wantjob[jn[i]] = 1` -> `for (i = 1; i <= 5; i++) wantjob[jn[i]] = 1; wantjob["extra"] = 1`
- Result: killed (2 rows failed)

#### D1 main's discovery step is required
- Guards: rows that plant the rule "main's discovery step is required":
  main: the step that runs scripts/ci/check-sodium.sh --discovery: its env dropped; main: the step that runs scripts/ci/check-sodium.sh --discovery: an if: always() on it; main: the step that runs scripts/ci/check-sodium.sh --discovery: the cache's if on it; main's install check moved after Checks and suites; main's discovery step deleted; main's discovery step written twice; main's discovery step moved before the install check; main's discovery step moved after Checks and suites; main's discovery step with an argument, --discovery X; main's discovery step with a prefix, as a lane's check has it ; and 1 more
- Mutation: `rq[3] = BUILDLINE; rqk[3] = "env"; rq[4] = DISCOVERY; rqk[4] = "env" /     rq[5] = MAKELINE; rqk[5] = "env"; rq[6] = LAUNCHER; rqk[6] = "env" /     return 6` -> `rq[3] = BUILDLINE; rqk[3] = "env" /     rq[4] = MAKELINE; rqk[4] = "env"; rq[5] = LAUNCHER; rqk[5] = "env" /     return 5`
- Result: killed (11 rows failed)

#### D2 the discovery step after the install check
- Guards: rows that plant the rule "the discovery step after the install check":
  main's install check moved after Checks and suites; main's discovery step moved before the install check
- Mutation: `if (pos <= lastp) prob(` -> `if (pos <= lastp && !(x == DISCOVERY && lastx == BUILDLINE)) prob(`
- Result: killed (2 rows failed)

#### D3 the make line after the discovery step
- Guards: rows that plant the rule "the make line after the discovery step":
  main's discovery step moved after Checks and suites
- Mutation: `if (pos <= lastp) prob(` -> `if (pos <= lastp && lastx != DISCOVERY) prob(`
- Result: killed (1 rows failed)

#### D4 the discovery step carries CHEZ
- Guards: rows that plant the rule "the discovery step carries CHEZ":
  main: the step that runs scripts/ci/check-sodium.sh --discovery: its env dropped
- Mutation: `if (k == "env") needenv(at, x, "CHEZ")` -> `if (k == "env" && x != DISCOVERY) needenv(at, x, "CHEZ")`
- Result: killed (1 rows failed)

#### D5 the discovery step carries no if
- Guards: rows that plant the rule "the discovery step carries no if":
  main: the step that runs scripts/ci/check-sodium.sh --discovery: an if: always() on it; main: the step that runs scripts/ci/check-sodium.sh --discovery: the cache's if on it
- Mutation: `} else if (S_if[at] != "") prob(S_ifln[at]` -> `} else if (S_if[at] != "" && x != DISCOVERY) prob(S_ifln[at]`
- Result: killed (2 rows failed)

#### D6 the discovery step is its whole run line
- Guards: rows that plant the rule "the discovery step is its whole run line":
  main's discovery step with an argument, --discovery X; main's discovery step with a prefix, as a lane's check has it
- Mutation: `x = substr(S_run[s], 6)` -> `x = substr(S_run[s], 6) /     if (job == "main" && substr(x, 1, 26) == "scripts/ci/check-sodium.sh") x = DISCOVERY`
- Result: killed (2 rows failed)

#### X1 build-sodium.sh is held
- Guards: rows that plant the rule "build-sodium.sh is held":
  build-sodium.sh without its execute bit: every step that runs it is named
- Mutation: `name=${cmd%% *}` -> `name=${cmd%% *} /       case $name in scripts/ci/build-sodium.sh) continue ;; esac`
- Result: killed (1 rows failed)

#### X2 check-sodium.sh is held
- Guards: rows that plant the rule "check-sodium.sh is held":
  check-sodium.sh without its execute bit: every step that runs it is named; check-sodium.sh missing: every step that runs it is named
- Mutation: `name=${cmd%% *}` -> `name=${cmd%% *} /       case $name in scripts/ci/check-sodium.sh) continue ;; esac`
- Result: killed (2 rows failed)

### Clean rerun

After restoring (each copy's script compared with its original; the real tree's `tests/check-ci.sh`
differs from the first copies only in its header comment, edited while the mutants ran):

- `tests/test-check-ci.sps` in a fresh copy with stubs, in the container: exit 0, 675 passes, 30 s
  (wall, including the container's start).
- The same under the gate, `make test-memory MEMORY_SUITES=tests/test-check-ci.sps`: pass, 144 s
  under the gate, within the 450 s ceiling and under the 225 s the caller set. Ran 1, passed 1.
- In the real tree, once the scripts builder's `build-sodium.sh` and `check-sodium.sh` landed:
  suite exit 0 and 675 passes; `make check-ci`: `check-ci: .github/workflows/ci.yml has the one shape
  check-ci reads`; `sh tests/check-ci.sh .github/workflows` on the host under mawk 1.3.4: the same line,
  exit 0; `make check-test-fails`: ok in all 13 cases, `ci` among them. `check-action-pins.sh`:
  all 19 lines name a commit. Before those two scripts landed, `check-ci` in the real tree failed
  only on the execute-bit rule, once per step that runs one (five steps), as expected (F3).
- `make test` as a whole was not run in the real tree, as asked.

### What differs from the design note

- **Generic rows over lanes.** `job-key-rows` and the generic `cache-rows` run over the five jobs. The
  lane path message lists two paths, so `cache-path` takes the job; `if-bad-for` gives a lane's
  `if is not one of ... or ...`. The Chez `if` is allowed on the Chez build and on any cache save not at
  the job's libsodium path (so a Chez save at a wrong path draws its path problem alone); the libsodium
  `if` on the build into the job's directory and on the save at the job's path.
- **Counting by path.** The Chez cache's restore and save counts skip steps at either lane's libsodium
  path; a restore at no known path counts as a Chez restore, which is why `a with value names
  CHEZ_SODIUM_LIBRARY` lists the restore-order and count problems.
- **S15b of the design** (the Chez count counting the libsodium steps) is not a valid mutant and was not
  run; it is replaced by S15d and S15e (the Chez counts off in lanes). The real file passing is its
  guard.
- **Coordinator's rule 9 mutant** is S35a and S35b: `ealk` read after stripping quotes, and after a
  leading `? `. Rows: `a quoted key, "C_INCLUDE_PATH"` and `an explicit key, ? C_INCLUDE_PATH: x`, in
  each lane's suites env; the explicit row is one line, since a `?` line takes no `:` line to name the
  word. The two `"if"` and `? if` rows of the lanes are kept too.
- **Rows with no mutant of their own,** controls of global code or of a rule another row already
  kills: the generic `job-key-rows` over the lanes; `a quoted key "if"` and `? if` in a lane; the lane
  rows of the names rule on other lines (a run block, `GITHUB_ENV`, a step name, a with value, a run
  line), which hold the global names rule, no lane code; the discovery step's block-scalar and
  other-prefix rows (D6 kills the argument form); and the generic `make-steps` env rows for the
  discovery step except `env dropped` (D4) and `an if` (D5). A mutant for the names rule on lane lines
  was designed (S35 of the note) and not run: the rule is one code path for every job.
- `check-ci.sh`'s header comment describes the five jobs, the lanes and the exception.
- Not done differently: the build step carries `CHEZ` alone.
