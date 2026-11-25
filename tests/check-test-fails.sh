#!/bin/sh
# `make check-test-fails`: proves that `make test` fails on a bad suite, by
# planting one in a copy of the tree (ADR-0011). One case per plant:
#
#   fails        a suite with a failing test   make test names it FAIL
#   no-tests     a suite that runs no test     make test names it FAIL
#   hangs        a suite that never ends       make test names it HUNG
#   exit-line    a suite that ends with the    check-suites names it, and
#                siblings' exit line           no suite runs
#   early-exit   a suite with a failing test   check-suites names it, and
#                that exits 0 before its       no suite runs
#                verdict
#   nested-exit  the same, with the exit 0     check-suites names it, and
#                inside a when                 no suite runs
#   empty        an empty file (Chez fails     check-suites names it, and
#                it, exit 255, unexplained)    no suite runs
#   site-exit-   a docs site suite that ends   check-suites names it, and
#   line         with the test suites' exit    no suite runs
#                form
#   site-no-exit a docs site suite with no     check-suites names it, and
#                exit form                     no suite runs
#   leaks        a suite whose tests pass,     make test names it FAIL, and
#                but which counts a block      suite-exit-status names the
#                up and never down             block left (ADR-0011)
#   seam         a private library that        check-seam names the import,
#                imports foreign-alloc, a      and no suite runs
#                name only (chez-sodium
#                private memory) may import
#   floors       README's Chez line says       check-floors names the line,
#                10.3.0, not the floor         and no suite runs
#   floors-      a script under scripts/ci     check-floors names the line,
#   script       writes the libsodium floor    and no suite runs
#   ci         job memory given a            check-ci names the key, and
#                continue-on-error key         no suite runs
#   no-suites    every suite deleted           make test refuses to pass
#
# The copy holds no real suite, so no slow one can run into the 5 s
# TEST_TIMEOUT. The plant is tests/test-0-plant.sps, or, in the two site
# cases, tests/site-0-plant.sps beside the tree's own docs site suites. After
# it sorts tests/test-1-after.sps, a suite that passes: in the first three
# cases its pass line shows that make test runs the suites after a failure.
# Each plant but no-tests and site-no-exit has a passing test of its own, so
# only the planted fault can fail it.
#
# A case requires a non-zero exit, and compares the lines starting
# "check-suites: " or "test: " as a whole: check-suites' verdict, the plant's
# outcome, the after-suite's pass line, and the count. The leaks case also
# compares the lines starting "suite-exit-status: ", whole, the seam case those
# starting "check-seam: ", the floors and floors-script cases those starting
# "check-floors: ", and the ci case those starting "check-ci: ".
#
# The copy is the working tree without .git, build/ and .claude/ (Claude
# Code's local state, which can hold whole worktrees), and with the
# chez-srfi checkout, so make deps works there and nothing is fetched.
# Nothing in the copy runs git. make deps relinks build/ in the copy. Its
# src/ holds two of the tree's own libraries, whatever else the tree
# holds: (chez-sodium private counters), which every suite's
# (chez-sodium-testing) imports, and (chez-sodium private
# require-threaded), which it imports first. So those cases also show that
# check-suites and the testing library need no other, and load no libsodium.
# README.org and packaging/floors.sexp are the tree's own, and agree, so
# check-floors passes in every case but floors, and the tree's own workflow
# and scripts/ci, copied with it, pass check-ci in every case but ci.
#
# Every case also runs check-seam on the copy's two libraries, which pass.
#
# The leaks plant counts a block up through (chez-sodium private counters)
# and never down, as a verb that allocated a block and lost it would. The
# counter names it.
#
# `make check-test-fails` passes MAKE and TIMEOUT, the tools it found. Run
# directly, the script takes make and timeout from PATH.
set -u

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

# The copy's make starts afresh: nothing of an outer make's flags or
# command-line variables reaches it.
unset MAKEFLAGS MFLAGS MAKELEVEL
# Sort file names byte by byte, as make's $(sort) does.
LC_ALL=C
export LC_ALL

# Every case runs make test with this TEST_TIMEOUT, in seconds, so the
# hanging plant is killed soon. The two suites in the copy finish at once.
suite_timeout=5
# The plant and the after-suite each run for at most suite_timeout seconds.
# A make test that runs much longer has lost its per-suite timeout.
make_timeout=$(( 2 * suite_timeout + 60 ))

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

copy=$tmp/tree
mkdir "$copy"
for entry in "$root"/* "$root"/.[!.]* "$root"/..?*; do
  [ -e "$entry" ] || [ -L "$entry" ] || continue
  case "$entry" in "$root/.git" | "$root/build" | "$root/.claude") continue ;; esac
  cp -a "$entry" "$copy/" || { echo "check-test-fails: could not copy $entry" >&2; exit 2; }
done
# No real suite: the plant and the after-suite are the only two.
rm -f "$copy"/tests/test-*.sps
# No library but the two every suite needs: the tree's own counters, and what
# they import first.
two_libraries() {
  rm -rf "$copy/src"
  mkdir -p "$copy/src/chez-sodium/private"
  for lib in require-threaded counters; do
    cp "$root/src/chez-sodium/private/$lib.sls" "$copy/src/chez-sodium/private/$lib.sls" ||
      { echo "check-test-fails: could not copy (chez-sodium private $lib)" >&2; exit 2; }
  done
}
two_libraries

# ---- the plants ----
plant_dir=$tmp/plants
mkdir "$plant_dir"

cat >"$plant_dir/fails" <<'EOF'
#!r6rs
;;; Planted by tests/check-test-fails.sh: a suite with a failing test.
(import (rnrs) (srfi :64) (chez-sodium-testing))
(define runner (test-runner-simple))
(test-runner-current runner)
(test-begin "plant-fails")
(test-assert "passes, so only the failure below can fail this suite" #t)
(test-equal "the planted failure" 1 2)
(test-end "plant-fails")
(exit (suite-exit-status runner))
EOF

cat >"$plant_dir/no-tests" <<'EOF'
#!r6rs
;;; Planted by tests/check-test-fails.sh: a suite that runs no test.
(import (rnrs) (srfi :64) (chez-sodium-testing))
(define runner (test-runner-simple))
(test-runner-current runner)
(test-begin "plant-no-tests")
(test-end "plant-no-tests")
(exit (suite-exit-status runner))
EOF

cat >"$plant_dir/hangs" <<'EOF'
#!r6rs
;;; Planted by tests/check-test-fails.sh: a suite that never ends.
(import (rnrs) (srfi :64) (only (chezscheme) sleep make-time) (chez-sodium-testing))
(define runner (test-runner-simple))
(test-runner-current runner)
(test-begin "plant-hangs")
(test-assert "passes, so only the hang below can fail this suite" #t)
(sleep (make-time 'time-duration 0 3600))
(test-end "plant-hangs")
(exit (suite-exit-status runner))
EOF

cat >"$plant_dir/exit-line" <<'EOF'
#!r6rs
;;; Planted by tests/check-test-fails.sh: a suite that ends with the
;;; siblings' exit line, which lets a suite that ran no test pass.
(import (rnrs) (srfi :64) (chez-sodium-testing))
(define runner (test-runner-simple))
(test-runner-current runner)
(test-begin "plant-exit-line")
(test-assert "passes, so only check-suites can fail this suite" #t)
(test-end "plant-exit-line")
(exit (if (zero? (test-runner-fail-count runner)) 0 1))
EOF

cat >"$plant_dir/early-exit" <<'EOF'
#!r6rs
;;; Planted by tests/check-test-fails.sh: a suite with a failing test that
;;; exits 0 before its verdict. The shared exit form after it never runs.
(import (rnrs) (srfi :64) (chez-sodium-testing))
(define runner (test-runner-simple))
(test-runner-current runner)
(test-begin "plant-early-exit")
(test-assert "passes, so only the failure below can fail this suite" #t)
(test-equal "the planted failure" 1 2)
(test-end "plant-early-exit")
(exit 0)
(exit (suite-exit-status runner))
EOF

cat >"$plant_dir/nested-exit" <<'EOF'
#!r6rs
;;; Planted by tests/check-test-fails.sh: a suite with a failing test whose
;;; exit 0, inside a when, comes before the shared exit form.
(import (rnrs) (srfi :64) (chez-sodium-testing))
(define runner (test-runner-simple))
(test-runner-current runner)
(test-begin "plant-nested-exit")
(test-assert "passes, so only the failure below can fail this suite" #t)
(test-equal "the planted failure" 1 2)
(test-end "plant-nested-exit")
(when (positive? (test-runner-fail-count runner))
  (exit 0))
(exit (suite-exit-status runner))
EOF

cat >"$plant_dir/leaks" <<'EOF'
#!r6rs
;;; Planted by tests/check-test-fails.sh: a suite whose tests all pass, but
;;; which counts a block up and never down, as a verb that allocated a block
;;; and lost it would (ADR-0011).
(import (rnrs) (srfi :64) (chez-sodium private counters) (chez-sodium-testing))
(define runner (test-runner-simple))
(test-runner-current runner)
(test-begin "plant-leaks")
(count-up! 'block)
(test-assert "passes, so only the block left uncounted can fail this suite" #t)
(test-end "plant-leaks")
(exit (suite-exit-status runner))
EOF

cat >"$plant_dir/after" <<'EOF'
#!r6rs
;;; Planted by tests/check-test-fails.sh: a suite that passes, sorted after
;;; the plant, so its pass line shows that make test went on after a failure.
(import (rnrs) (srfi :64) (chez-sodium-testing))
(define runner (test-runner-simple))
(test-runner-current runner)
(test-begin "after")
(test-assert "passes" #t)
(test-end "after")
(exit (suite-exit-status runner))
EOF

plant=tests/test-0-plant.sps
after=tests/test-1-after.sps
cp "$plant_dir/after" "$copy/$after"

pass=0
fail=0
ok()  { pass=$((pass + 1)); printf 'check-test-fails: ok %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'check-test-fails: FAILED %s\n' "$1" >&2; }

# checked N: check-suites' line for a copy holding N tests/test-*.sps, and
# the tree's docs site suites, every tests/site-*.sps, which the Makefile
# always names to it.
site_suites=$(cd "$copy" && ls tests/site-*.sps 2>/dev/null | wc -l)
checked() {
  printf 'check-suites: every suite ends with (exit (suite-exit-status runner)), and every site suite with (exit (site-exit-status runner)) (%d checked)\n' "$(($1 + site_suites))"
}

# expected PLANT-LINE FAILED HUNG: the lines a run must print with a plant
# that check-suites accepts. The after-suite passes.
expected() {
  checked 2
  printf '%s\n' "$1"
  printf 'test: pass %s\n' "$after"
  printf 'test: ran 2, passed 1, failed %d, hung %d\n' "$2" "$3"
}

# run_case NAME WANTED [LINES]: runs make test in the copy, then requires a
# non-zero exit and exactly the WANTED lines: those matching the egrep pattern
# LINES, by default the check-suites and test lines. On a failure it prints
# make test's whole output.
run_case() {
  run_make
  judge "$@"
}

# run_make [VAR=VALUE ...]: runs make test in the copy, with any variables
# given on its command line, its output to $tmp/out and its exit status to
# status.
run_make() {
  ( cd "$copy" &&
      "${TIMEOUT:-timeout}" "$make_timeout" "${MAKE:-make}" --no-print-directory test \
        TEST_TIMEOUT="$suite_timeout" "$@" ) \
    >"$tmp/out" 2>&1
  status=$?
}

# judge NAME WANTED [LINES]: run_case's requirements, of the run_make before.
judge() {
  name=$1 wanted=$2 lines=${3:-'^(check-suites|test): '}
  got=$(grep -E "$lines" "$tmp/out")
  wrong=0
  if [ "$status" -eq 124 ]; then
    bad "$name: make test did not finish within ${make_timeout}s, so no per-suite timeout is stopping its suites"
    wrong=1
  elif [ "$status" -eq 0 ]; then
    bad "$name: make test exited 0"
    wrong=1
  fi
  if [ "$got" != "$wanted" ]; then
    bad "$name: make test's lines differ"
    printf '%s\n' "$wanted" | sed 's/^/  wanted: /' >&2
    printf '%s\n' "$got" | sed 's/^/  got:    /' >&2
    wrong=1
  fi
  if [ "$wrong" -eq 0 ]; then
    ok "$name"
  else
    sed 's/^/  | /' "$tmp/out" >&2
  fi
}

cp "$plant_dir/fails" "$copy/$plant"
run_case "fails: a failing suite is named FAIL, and the suites after it run" \
  "$(expected "test: FAIL $plant (exit 1)" 1 0)"

cp "$plant_dir/no-tests" "$copy/$plant"
run_case "no-tests: a suite that runs no test is named FAIL, and the suites after it run" \
  "$(expected "test: FAIL $plant (exit 1)" 1 0)"

cp "$plant_dir/hangs" "$copy/$plant"
run_case "hangs: a suite that never ends is named HUNG, and the suites after it run" \
  "$(expected "test: HUNG $plant (no exit within ${suite_timeout}s)" 0 1)"

cp "$plant_dir/exit-line" "$copy/$plant"
run_case "exit-line: check-suites names a suite without the shared exit form, and no suite runs" \
  "check-suites: $plant: its last datum is (exit (if (zero? (test-runner-fail-count runner)) 0 1)), not (exit (suite-exit-status runner))"

cp "$plant_dir/early-exit" "$copy/$plant"
run_case "early-exit: check-suites names a suite that exits before its verdict, and no suite runs" \
  "check-suites: $plant: (exit 0) before the last datum would end the suite before its verdict; only (exit 1) may exit early"

cp "$plant_dir/nested-exit" "$copy/$plant"
run_case "nested-exit: check-suites names an exit inside a form before the verdict, and no suite runs" \
  "check-suites: $plant: (exit 0) before the last datum would end the suite before its verdict; only (exit 1) may exit early"

: >"$copy/$plant"
run_case "empty: check-suites names a suite with no datum, and no suite runs" \
  "check-suites: $plant: it holds no datum, so it cannot end with (exit (suite-exit-status runner))"

cp "$plant_dir/leaks" "$copy/$plant"
run_case "leaks: a suite whose tests pass, but which counts a block up and never down, is named FAIL through the counters' line, and the suites after it run" \
  "$(checked 2
     echo 'suite-exit-status: exit 1 (native objects left: block 1): every native object a suite makes must be freed by its end'
     echo "test: FAIL $plant (exit 1)"
     echo "test: pass $after"
     echo 'test: ran 2, passed 1, failed 1, hung 0')" \
  '^(check-suites|test|suite-exit-status): '

# The plant is gone, so only the after-suite is left to check.
rm -f "${copy:?}/${plant:?}"

# The site cases: a docs site suite, tests/site-0-plant.sps, beside the
# tree's own. A site suite runs on a Chez below the floor, so it ends with
# (site-testing)'s form, never the test suites', whose counters that Chez
# refuses. Without the Makefile naming every tests/site-*.sps to
# check-suites, or check-suites holding a site suite to its own form, no
# check sees either plant and make test passes: the case fails then. Each
# plant is removed after its case.
site_plant=tests/site-0-plant.sps
cat >"$plant_dir/site-exit-line" <<'EOF'
#!r6rs
;;; Planted by tests/check-test-fails.sh: a docs site suite that ends with
;;; the test suites' exit form, not its own.
(import (rnrs) (srfi :64) (site-testing))
(define runner (test-runner-simple))
(test-runner-current runner)
(test-begin "plant-site-exit-line")
(test-assert "passes, so only check-suites can fail this suite" #t)
(test-end "plant-site-exit-line")
(exit (suite-exit-status runner))
EOF
cp "$plant_dir/site-exit-line" "$copy/$site_plant"
run_case "site-exit-line: check-suites names a site suite that ends with the test suites' exit form, and no suite runs" \
  "check-suites: $site_plant: its last datum is (exit (suite-exit-status runner)), not (exit (site-exit-status runner))"

cat >"$plant_dir/site-no-exit" <<'EOF'
#!r6rs
;;; Planted by tests/check-test-fails.sh: a docs site suite with no exit
;;; form, whose run would exit 0 whatever its tests did.
(import (rnrs) (srfi :64) (site-testing))
(define runner (test-runner-simple))
(test-runner-current runner)
(test-begin "plant-site-no-exit")
(test-assert "fails" #f)
(test-end "plant-site-no-exit")
EOF
cp "$plant_dir/site-no-exit" "$copy/$site_plant"
run_case "site-no-exit: check-suites names a site suite with no exit form, and no suite runs" \
  "check-suites: $site_plant: its last datum is (test-end \"plant-site-no-exit\"), not (exit (site-exit-status runner))"
rm -f "${copy:?}/${site_plant:?}"

# The seam case: a library under the copy's src/ imports a name from
# (chezscheme) that only (chez-sodium private memory) may, and
# check-seam names it by rule (f). The copy's src/ holds no memory library,
# and the rule needs none. Without check-seam among make test's prerequisites,
# or with it reading a directory but src/, no check sees the plant and make
# test passes: the case fails then (each new prerequisite comes with its
# plant). check-seam passes before and after: the plant is removed.
cat >"$plant_dir/seam" <<'EOF'
#!r6rs
;;; Planted by tests/check-test-fails.sh: a private library that allocates
;;; foreign memory itself, which only (chez-sodium private memory) may.
(library (chez-sodium private planted)
  (export planted)
  (import (chez-sodium private require-threaded)
          (rnrs)
          (only (chezscheme) foreign-alloc))
  (define planted 1))
EOF
cp "$plant_dir/seam" "$copy/src/chez-sodium/private/planted.sls"
run_case "seam: check-seam names a private library that imports foreign-alloc, and no suite runs" \
  "$(checked 1
     echo 'check-seam: src/chez-sodium/private/planted.sls: (chez-sodium private planted) imports foreign-alloc from (chezscheme), but library-only-chez-names in tests/check-seam.sps allows it only in (chez-sodium private memory)'
     echo 'check-seam: FAILED (problems: 1)')" \
  '^(check-suites|check-seam|test): '
rm -f "${copy:?}/src/chez-sodium/private/planted.sls"

# The floors case: the copy's README states an older Chez than the floors
# file does. The file's floor is read from the file, so this script is no
# third place that writes it. check-floors passes before and after: the
# README is restored.
chez_floor=$(sed -n 's/^ *((chez "\([0-9.]*\)").*$/\1/p' "$root/packaging/floors.sexp")
case "$chez_floor" in
  "" | *[!0-9.]*) bad "floors: could not read the Chez floor from packaging/floors.sexp"; chez_floor=0.0.0 ;;
esac
sed 's/^- Chez Scheme .* or later, built with threads$/- Chez Scheme 10.3.0 or later, built with threads/' \
  "$root/README.org" >"$copy/README.org"
if cmp -s "$root/README.org" "$copy/README.org"; then
  bad "floors: the plant did not change README.org, so it plants nothing"
fi
run_case "floors: check-floors names a README that states another Chez floor, and no suite runs" \
  "$(checked 1
     echo "check-floors: README.org: list line 1 under \"** Requirements\" is \"- Chez Scheme 10.3.0 or later, built with threads\", but packaging/floors.sexp gives \"- Chez Scheme $chez_floor or later, built with threads\""
     echo 'check-floors: FAILED (problems: 1)')" \
  '^(check-suites|check-floors|test): '
cp "$root/README.org" "$copy/README.org"

# The floors-script case: a script in the copy's scripts/ci writes the
# libsodium floor, read from the copy's floors file. check-floors reads every
# file under scripts/ci, so it names the line. Without scripts/ci among the
# directories check-floors is run on (the Makefile's fourth argument), no
# check sees the plant and make test passes: the case fails then (each new
# prerequisite comes with its plant). check-floors passes before and after:
# the plant is removed.
sodium_floor=$(sed -n 's/^ *(sodium "\([0-9.]*\)").*$/\1/p' "$root/packaging/floors.sexp")
case "$sodium_floor" in
  "" | *[!0-9.]*) bad "floors-script: could not read the libsodium floor from packaging/floors.sexp"; sodium_floor=0.0.0 ;;
esac
printf '#!/bin/sh\n# the floor is %s\n' "$sodium_floor" >"$copy/scripts/ci/plant.sh"
run_case "floors-script: check-floors names a script under scripts/ci that writes the libsodium floor, and no suite runs" \
  "$(checked 1
     echo "check-floors: scripts/ci/plant.sh: line 2 contains the libsodium floor $sodium_floor, which no CI script may write: they read it from packaging/floors.sexp"
     echo 'check-floors: FAILED (problems: 1)')" \
  '^(check-suites|check-floors|test): '
rm -f "${copy:?}/scripts/ci/plant.sh"

# The ci case: the copy's workflow gives job memory, the Valgrind gate, a
# job-level continue-on-error key, which would let the gate fail and the run
# pass. check-ci refuses any key outside the job's four. Without check-ci
# among make test's prerequisites, or reading a directory but
# .github/workflows, no check sees the plant and make test passes: the case
# fails then (each new prerequisite comes with its plant). check-ci passes
# before and after: the workflow is restored.
ci_yml=.github/workflows/ci.yml
sed '/^  memory:$/,/^    runs-on:/ s/^    runs-on: ubuntu-24.04$/    continue-on-error: true\
    runs-on: ubuntu-24.04/' "$root/$ci_yml" >"$copy/$ci_yml"
if cmp -s "$root/$ci_yml" "$copy/$ci_yml"; then
  bad "ci: the plant did not change $ci_yml, so it plants nothing"
fi
ci_line=$(grep -n '^    continue-on-error: true$' "$copy/$ci_yml" | cut -d: -f1)
run_case "ci: check-ci names a workflow whose job memory may fail without failing the run, and no suite runs" \
  "$(checked 1
     echo "check-ci: $ci_yml:$ci_line: job memory has the key \"continue-on-error\", which is not one of name, runs-on, timeout-minutes, steps"
     echo 'check-ci: FAILED (problems: 1)')" \
  '^(check-suites|check-ci|test): '
cp "$root/$ci_yml" "$copy/$ci_yml"

# No suite.
rm -f "$copy"/tests/test-*.sps
run_case "no-suites: make test refuses to pass with no suite to run" \
  "$(checked 0; echo 'test: no suites: nothing matches tests/test-*.sps')"

if [ "$fail" -eq 0 ]; then
  printf 'check-test-fails: make test failed, as it must, in all %d cases\n' "$pass"
fi
[ "$fail" -eq 0 ]
