# M1's closing fixes: mutation log

The fixes from [M1's closing review](research/m1-closing-review/README.md). Every run was in the
Guix container (`scripts/guix-env`), Chez 10.4.0 threaded and libsodium 1.0.22, unless named.
Two Sonnet builders worked in one tree, on disjoint files. Every mutant was applied in a whole
copy of the tree, never in place.

## Reproduced by the caller

- **M1-F10, the two-thread trap,** on a toy library whose body sleeps 1 s, in the container:
  `#(ready (raised "cyclic dependency involving invocation of library ~s") (later ready))`
  (`traps.md`).
- **An `if:` on the image step** is refused by `check-ci`'s general `if:` rule, naming its line:
  `if is not exactly "if: steps.chez.outputs.cache-hit != 'true'"`, and `if is on a step that
  neither runs scripts/ci/build-chez.sh nor uses actions/cache/save`.
- **The records' claims,** before they were written:
  - ADR-0001 decision 10 was rewritten in place in slice 0, with no amendment section, as
    `git diff 0b800ed main` shows;
  - `test-conventions`' row holds the argument list as every type used as an argument or a
    non-void result;
  - `test-native`'s E11 holds the plain import of memory;
  - the CI run ids the close-outs cite are each the slice's own, with `gh run view`.

## The join

The fixes together, in the main tree, rerun after the second review's fixes:
- `make test` 26 of 26, with `check-seam` (9 libraries), `check-floors` and `check-ci`;
- `make check-test-fails` all 13 cases;
- `make test-memory` 26 of 26, the slowest `test-check-ci` at 117 s of 450 (115 s before);
- `make check-memory-gate` all 59 cases;
- `make build` both ways, `make check-dev`, `make check-help` and `make check-clean`;
- `make check-nothreads` fails, naming the nine libraries, as it must on a threaded Chez.

## The second review

The fixes' second review, on Opus ([research/m1-closing-review/second-review.md](research/m1-closing-review/second-review.md)),
found no blocker, 5 majors and 7 minors. The code fixes it asked for are logged below, each
watched to fail: R2-F1 under "After the second review" in M1-F4's section, and R2-F6 in the
tests' section. The caller reproduced two of its findings before fixing the records:
- **R2-F2:** the committed `engine-section.sps`, rerun, gives 45,158 and 45,159 again, as
  `run-engine-section.out` records.
- **R2-F5:** a body in one critical section refuses a main thread that does not allocate, and
  stalls one that allocates first until the section ends, which then answers `ready`
  (`research/m1-closing-review/run-two-threads-section.out`).

The caller also checked R2-F1 on the host: a copy of `ci.yml` without the image id in `main`'s
Chez key fails `check-ci`, "the cache key in job main is not exactly chez-threads-…".

## M1-F4: the runner-image step and each job's timeout

Files: `tests/check-ci.sh`, `tests/test-check-ci.sps`. `.github/workflows/ci.yml` was not changed
(an edit of its header comment was denied by the permission classifier, and was not made).

### The rules

- `imagestep()`: in every job, exactly one step named "Identify the runner image", `id: image`, `run: |`
  with exactly its two lines, before the job's first `actions/cache/restore` step. Each fault names the
  job and the line.
- `endjob()`: `timeout-minutes` equals the string "120" for `memory`, "60" for the other four. Today's
  `ci.yml` already held exactly these values; nothing differed.

### Guards (rows added: 70, in `image-rows` and `timeout-rows`, per job x 5)

Runner-image step, per job: deleted; id renamed; id deleted; first run line changed; echo made
`echo "id=fixed"`; second run line deleted; a third run line; the run one line, not a block; moved after
the first restore; written twice. Timeout, per job: four wrong values (memory: 60, 5, 600, 0120; the
others: 120, 5, 600, 060). "timeout-minutes deleted" already had a row per job (`job-key-rows`).

The rows that planted lines in main's runner-image block (tab, non-ASCII, injected lines; two lane rows)
now plant them in main's / each lane's "Install the packages" block, which is held to no line, since the
image block is now held line for line.

### Red first

1. Baseline before any change: 675 passes, 0 fails (the moved plant spot costs nothing).
2. New rows against today's `check-ci.sh`: 70 failed, 675 passed, no row raised in its construction
   (one did at first, nothreads' restore step is named "Restore Chez without threads"; fixed in the row).
   `build/m1fix-red.out`.
3. After the rules: 745 passes, 0 fails, first run. `build/m1fix-green.out`.

### Mutants

Every mutant is one exact replacement in `tests/check-ci.sh`, whose old text matches exactly once, run in
a whole copy of the tree under `build/m1fix-ci/mut/tree`. Before each suite run the real `ci.yml` was
checked under the mutant with the host's mawk: it passed in all 17. The suite ran in the container.
Harness: `build/m1fix-ci/mutants.py`, `runall.py`, `mkcopy.sh`, `runsuite.sh`; results in
`results-1.md` and `results-I7.md`, suite output in `mut-ID.out`. (I7's first old text matched twice,
once in `mainsteps`; it was narrowed to `bln[at, n]` and rerun alone.)

| Mutant | Guards (the rule it turns off) | Rows failed |
|---|---|---|
| I1a | none of the step is a problem | 5 (deleted, each job) |
| I1b | two of the step is a problem | 5 (written twice) |
| I2 | id: image | 10 (id renamed, id deleted) |
| I3 | step before the first restore | 5 |
| I4 | the run is a block | 5 |
| I5a | first run line held | 5 |
| I5b | second run line held (echo "id=fixed") | 5 |
| I6 | no third run line | 5 |
| I7 | block not short | 5 |
| J1 | main holds the step | 10 |
| J2 | each lane holds the step | 20 |
| J3 | memory and nothreads hold the step | 20 |
| T1 | each job's timeout | 20 |
| T2 | memory's timeout | 4 |
| T3 | floor's timeout | 4 |
| T4 | timeout compared as a number, not its spelling | 5 (060, 0120) |
| T5 | main, nothreads, current's timeout | 12 |

Result: 17 of 17 killed. The copy's `check-ci.sh` was restored and compared with the original after the run.

### Clean rerun (real tree)

- `make test SUITES=tests/test-check-ci.sps` (container; prerequisites skipped with -o): 745 passes, exit 0.
- `make test-memory MEMORY_SUITES=tests/test-check-ci.sps`: pass, 115 s under the gate (450 s is the SLOW line).
- `sh tests/check-ci.sh .github/workflows` on the host, mawk 1.3.4: "has the one shape check-ci reads", exit 0.
- `make check-ci` (container): pass. `make check-test-fails`: "failed, as it must, in all 13 cases".

### After the second review (R2-F1: the Chez restore keys)

Rule: `cachestep()` holds each Chez restore key whole, by `chezkey()`:
`PREFIX${{ hashFiles(<the four files>) }}-${{ steps.image.outputs.id }}`, with `chez-threads-` in main,
memory, floor and current and `chez-nothreads-` in nothreads (read from today's ci.yml; all five equal
it). The old "does not begin with" check stays first, so its 7 existing rows are unchanged; the new
"is not exactly" problem fires when the prefix and list are right and the rest is not. The header
comment of `check-ci.sh` says so. `ci.yml` untouched.

Rows added (21): per job (x5) the image id dropped, a tail `-x` after it, `-ubuntu` in its place, and
`steps.cc.outputs.id` in its place; plus one row that drops the id from all five jobs' keys at once.
Whole expected output on each, anchored at the key line.

Red first: the rules were written before the rows, so red was shown by turning the new rule off in a
whole copy (mutant K1): 21 rows failed, the 745 older rows passed. With the rule: 766 passes, 0 fails.

Mutants (whole copies under `build/m1fix-ci/mut/tree`; the real ci.yml passed under each, mawk;
results in `build/m1fix-ci/results-R2.md`): K1 whole rule off, 21 killed; K3 nothreads exempt, 5;
K4 main exempt, 5; K5 lanes exempt, 9; K6 memory exempt, 5; K7 tail allowed, 5; K8 `steps.cc` id
allowed, 5; K9 `-ubuntu` allowed, 5; K10 any key containing `steps.image` allowed, 16. 9 of 9 killed;
the copy's script was restored and compared.

Final: plain suite 766 passes, exit 0; under the gate 118 s (pass); `sh tests/check-ci.sh
.github/workflows` under host mawk passes; `make check-ci` passes; `make check-test-fails` "failed, as
it must, in all 13 cases".

## M1-F5, M1-F6 and M1-F7: the scripts, `test-never-loads` and the discovery rows

Container (scripts/guix-env), Chez 10.4.0 threaded. One builder. Every mutant is one exact
replacement in a whole copy of the tree, build/m1fix-tests/mut/<name>/, run there with
`scheme --libdirs src:tests:build/scheme-libs --program <suite>`.

### M1-F6: tests/test-never-loads.sps

#### Guards
- `verb-names` = `(sodium-version)`; `condition-names` = `(library-exports '(chez-sodium))` less it,
  sorted, under a guard whose sentinel is a one-symbol list. `(chez-sodium)` is imported with
  `(only (chez-sodium))`: no name, so no body runs, but `library-exports` needs the library loaded
  (without it: "library (chez-sodium) is not loaded"; watched, before the import was added).
- The conditions child references every `condition-names` entry through `eval` before its first
  scan (`(define referenced (map pub '(...)))`). Its output is unchanged: the same 11 lines.
- New row: the seven names the child's lines call (`checked-names`, written out) equal
  `condition-names`.
- Suite: 8 of 8 (was 7).

#### Mutation
- f6a, `(chez-sodium)` also exports `sodium-failed?` (conditions): KILLED, 1 row, the new one
  (7 pass, 1 fail). Before: 7 of 7 pass. expected the seven names; actual those and `sodium-failed?`.
- f6b, `verb-names` emptied: KILLED, 3 rows: the new one (actual lists `sodium-version`), and both
  children (sodium-version referenced, so the load runs: the override child dies loading, the
  control child maps libsodium before its first line).

#### Result
8 of 8; under the gate 15 s.

### M1-F7: tests/test-library-loading-discovery.sps

#### Guards
- `discovery.sls`'s `linux-triple` maps the machine type itself, and `choose-libsodium` is given
  `machine-type` as an argument. So the suite writes its own `fhs-triple` (ta6le, a6le to
  x86_64-linux-gnu; tarm64le, arm64le to aarch64-linux-gnu; else none), and passes `(machine-type)`
  only to say which one to use.
- `fhs-candidate-paths` is written out: `/usr/local/lib`, `/usr/lib/<triple>`, `/usr/lib64`,
  `/usr/lib`, each `.so.26` then `.so.23`. `first-standard` finds the first existing path in it.
- New row, every world: `fhs-candidate-paths` equals `(map car (libsodium-candidates 'fhs
  (machine-type) getenv))`, under a guard.
- Suite: 21 of 21 (was 20). The two FHS rows are skipped by world here (this is a Guix world), so
  their use of the new list is not exercised in the container; only CI's `main` runs them.

#### Mutation
- f7a, `'("/usr/lib64" "/usr/lib")` swapped to `'("/usr/lib" "/usr/lib64")` in discovery.sls:
  KILLED, the new row (20 pass, 1 fail); expected ends `/usr/lib64 ... /usr/lib`, actual
  `/usr/lib ... /usr/lib64`. test-discovery also holds this (not run here).

#### Result
21 of 21; under the gate 34 s.

### M1-F5: scripts

- `build-chez.sh`: `curl -fsSL --proto '=https' --retry 3 -o`; `sha256_of` is `sha256sum "$1" | awk
  '{ print $1 }'` alone, the `shasum` branch and "elsewhere" gone.
- `trap 'exit 1' HUP INT TERM` after the `EXIT` trap in build-chez.sh, check-chez.sh,
  report-sodium.sh, check-action-pins.sh and scripts/guix-env-selftest.
- `sh -n` on all eight scripts under scripts/ci and scripts/guix-env-selftest: ok.
- Tests that read these scripts: grep of tests/ and Makefile finds no suite that reads the text of
  the five, or runs build-chez.sh with stand-ins (test-ci-sodium has one build-chez usage row about
  `--nothreads`, which is build-sodium's own usage). check-ci's HASHLIST names the files in the
  cache key, not their content. `make check-floors` passes, listing the scripts it reads.
  Nothing to update.
- `sh scripts/ci/check-action-pins.sh .github/workflows`: "check-action-pins: all 19 lines with a
  uses key under .github/workflows name a full commit SHA, with its tag in a comment", exit 0.
- `scripts/guix-env-selftest` run bare on the host: "check-guix: FAILED not-in-environment: this is
  the self-test, not the launcher; use make check-guix", exit 2 (by design). `make check-guix` on
  the host: ALL CHECKS PASSED (it also ran the 26 suites, 26 of 26).
- No row holds build-chez.sh (the review says so): record it in the PR.

### Clean rerun
- tests/test-never-loads.sps 8 of 8; tests/test-library-loading-discovery.sps 21 of 21, plain.
- `make test-memory MEMORY_SUITES="tests/test-never-loads.sps tests/test-library-loading-discovery.sps"`:
  2 of 2, 15 s and 34 s.
- `make check-floors`: ok. `make check-test-fails`: all 13 cases.

### After the second review (R2-F6)

The `(only (chez-sodium))` import is dropped. `condition-names` now calls `(environment
'(chez-sodium))` inside its existing guard, before `library-exports`, with `(only (rnrs eval)
environment)` imported. A failure to expand is the sentinel, so rows fail by name.

#### Mutation (whole copies)
- f6d, the old import kept and `src/chez-sodium.sls` exporting a nonexistent name: the suite dies
  at import, exit 255, no row named (the reviewer's R2-F6).
- f6c, the same `src/chez-sodium.sls`, the fix in place: the suite runs to its end, 3 rows fail by
  name (the condition-names row and both children), 5 pass, exit 1.
- f6a, `sodium-failed?` exported again: only the new row fails (7 pass, 1 fail).
- f6b, `verb-names` emptied: 3 rows fail (the new row and both children).

#### Clean rerun
- tests/test-never-loads.sps 8 of 8, plain. Its "no libsodium mapped before" child rows hold, so
  `environment` ran no body.
- `scripts/guix-env make test-memory MEMORY_SUITES="tests/test-never-loads.sps"`: see below.
    test-memory: pass tests/test-never-loads.sps
      time: 15s under the gate, within 450s, three quarters of MEMORY_TIMEOUT's 600s
    test-memory: ran 1, passed 1, failed 0, hung 0, slow 0
