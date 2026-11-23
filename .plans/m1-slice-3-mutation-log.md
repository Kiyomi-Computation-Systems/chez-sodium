# M1 slice 3 mutation log: refusals end to end, and CI's install check

Every run was in the Guix container (`scripts/guix-env`): Chez 10.4.0, threaded; libsodium
1.0.22. Two Sonnet builders worked in one tree on disjoint files, each from trim tables the
caller checked first: the refusals (the decoy, the probe, `library-loading.sls`, the six
`test-library-loading-*` suites, the raising fixture, `check-dev`, and the tie row in
`test-conventions`) and CI's `main` (`ci.yml`, `check-ci.sh`, `test-check-ci`). Slice 4's
public library was built beside them, and its log is [its own](m1-slice-4-mutation-log.md).

## Reproduced by the caller, at the join

Each in a whole copy of the tree, by one exact replacement, the copy compared with the original
after:

- **The wipe one byte short** (`call-with-block` hands `free-foreign-block!` a wipe over
  `(- n 1)` bytes): `test-library-loading-combined` fails its two wipe rows, 5 bytes and the
  empty bytevector's 1.
- **`sodium_init` answering 2 accepted** (`check-init`): `test-library-loading-decoys` fails
  "decoy control under \"init-other\"".
- **CI's install check deleted** from `ci.yml`: `check-ci` fails, `job main has 0 steps that run
  "make build", not one`.
- **Clean run at the join,** slices 3 and 4 together: `make test` 25 of 25, with `check-seam`
  (9 libraries); `make check-test-fails` all 13 cases; `make test-memory` 25 of 25, the slowest
  79 s of 450; `make check-memory-gate` all 59 cases; `make build` accepts the container's
  library and refuses a missing one as `load-failed`; `make check-dev`; `make check-help`;
  `make check-clean`. `make check-nothreads` fails, naming the nine libraries, as it must on a
  threaded Chez.

## After the review

The review ([research/m1-slice-3-review/](research/m1-slice-3-review/README.md)) found no
blocker, five majors and nine minors over slices 3 and 4. Each new assertion from slice 3's
fixes was watched to fail in a whole copy of the tree:

- **N21, the guard widened to `error?`:** "preflight, a raise that is not a refusal: … and
  stderr exactly what the same raise with no guard prints" fails alone. Its stderr names
  `sodium-library-unavailable-candidates`; `tests/fixtures/raising/unguarded.sps` names
  `loaded-libsodium`.
- **The both-sonames copy sent to a missing directory:** the new setup row "the both-sonames
  directory was made, and the library copied to libsodium.so.26" fails by name, ahead of the
  row that would otherwise read as ".so.23 tried first".
- **The eight `list` rows rewritten as `let*`** change no outcome; they pass as before.
- **Clean run after the fixes,** slices 3 and 4 together: `make test` 25 of 25; the eight
  changed suites under the gate, 8 of 8, the slowest 56 s; `make check-dev`; `make check-help`;
  `make check-clean`. Slice 3's commit alone is checked from its own tree before its PR.


## The refusals

Row names in the Guards lines are cut at 100 characters, as the builder's harness printed them.

Each mutant of `src/` or `tests/` was applied in a whole copy of the tree (`build/slice3-refusals/mut/`), the six suites (and `test-conventions` for the tie) run there, the copy discarded. Clean rerun: every suite green in the real tree afterwards (decoys 16, missing 16, combined 13, real 23, discovery 19, preflight 15, conventions 52). Harness: `mut.py`, `mutants.py`, `cdmut.py`.

### N1 check-version always #t
- Guards: decoy control under "below-floor": one patch below the floor is below-floor, detail its version; decoy control under "version-null": a NULL version string is below-floor, detail #f, and sodium; decoy control under "version-malformed": a version string that is the floor and more is below-f; decoy control under "version-bom": a version string after a byte order mark is below-floor, det; decoy control under "libtool-high": a version below the floor with libtool numbers 99.99 is bel; decoy lacks-sodium_memzero under "below-floor": the floor comes before the rest: below-floor, n; decoy lacks-sodium_init under "below-floor": the floor comes before sodium_init's binding: belo; a refusal is kept: CHEZ_SODIUM_LIBRARY changed between references loads nothing new; and 1 more
- Result: killed

### N2 floor from libtool numbers
- Guards: decoy control under "below-floor": one patch below the floor is below-floor, detail its version; decoy control under "version-null": a NULL version string is below-floor, detail #f, and sodium; decoy control under "version-malformed": a version string that is the floor and more is below-f; decoy control under "version-bom": a version string after a byte order mark is below-floor, det; decoy control under "libtool-high": a version below the floor with libtool numbers 99.99 is bel; decoy control under "libtool-low": the floor with libtool numbers 0.0 loads, and reports them: ; decoy lacks-sodium_memzero under "below-floor": the floor comes before the rest: below-floor, n; decoy lacks-sodium_init under "below-floor": the floor comes before sodium_init's binding: belo; and 2 more
- Result: killed

### N2b accept when libtool major is 99
- Guards: decoy control under "libtool-high": a version below the floor with libtool numbers 99.99 is bel
- Result: killed

### N2c refuse when libtool major is 0
- Guards: decoy control under "libtool-low": the floor with libtool numbers 0.0 loads, and reports them: 
- Result: killed

### N3 lenient parse (leading digits)
- Guards: decoy control under "version-malformed": a version string that is the floor and more is below-f
- Result: killed

### N4 BOM not restored
- Guards: decoy control under "version-bom": a version string after a byte order mark is below-floor, det
- Result: killed

### N5a check-init accepts 2
- Guards: decoy control under "init-other": sodium_init answering 2 is init-failed too, detail 2, not -1'
- Result: killed

### N5b check-init refuses 1
- Guards: decoy control under "init-already": sodium_init answering 1 is no failure: it loads, and the lo; sodium_init called first: the probe's call answers 0, the load sees 1 and loads, a direct call 
- Result: killed

### N5c check-init accepts all
- Guards: decoy control under "init-fails": sodium_init answering -1 is init-failed, detail -1, after the; decoy control under "init-other": sodium_init answering 2 is init-failed too, detail 2, not -1'; decoy lacks-sodium_memzero under "init-fails": sodium_init comes before the rest: init-failed w; preflight, sodium_init answering -1: exit 1, init-failed, detail -1, the refusal's own message 
- Result: killed

### N6 sodium_init never called
- Guards: decoy control: the floor itself is accepted: the report's four fields, and the load's calls in ; decoy control under "libtool-low": the floor with libtool numbers 0.0 loads, and reports them: ; decoy control under "init-fails": sodium_init answering -1 is init-failed, detail -1, after the; decoy control under "init-other": sodium_init answering 2 is init-failed too, detail 2, not -1'; decoy control under "init-already": sodium_init answering 1 is no failure: it loads, and the lo; decoy lacks-sodium_memzero: a library without sodium_memzero is missing-api, naming it; decoy lacks-sodium_memzero under "init-fails": sodium_init comes before the rest: init-failed w; a load is kept: CHEZ_SODIUM_LIBRARY changed between references loads nothing new; and 9 more
- Result: killed

### N7 sodium_init before the floor
- Guards: decoy control: the floor itself is accepted: the report's four fields, and the load's calls in ; decoy control under "below-floor": one patch below the floor is below-floor, detail its version; decoy control under "version-null": a NULL version string is below-floor, detail #f, and sodium; decoy control under "version-malformed": a version string that is the floor and more is below-f; decoy control under "version-bom": a version string after a byte order mark is below-floor, det; decoy control under "libtool-high": a version below the floor with libtool numbers 99.99 is bel; decoy control under "libtool-low": the floor with libtool numbers 0.0 loads, and reports them: ; decoy control under "init-fails": sodium_init answering -1 is init-failed, detail -1, after the; and 31 more
- Result: killed

### N8 memzero bound before init check
- Guards: decoy lacks-sodium_memzero under "init-fails": sodium_init comes before the rest: init-failed w
- Result: killed

### N9 memzero bound lazily
- Guards: decoy lacks-sodium_memzero: a library without sodium_memzero is missing-api, naming it
- Result: killed

### N9b required-entry skipped for memzero
- Guards: decoy lacks-sodium_memzero: a library without sodium_memzero is missing-api, naming it
- Result: killed

### N10 major bound after the string is called
- Guards: decoy control: the floor itself is accepted: the report's four fields, and the load's calls in ; decoy control under "below-floor": one patch below the floor is below-floor, detail its version; decoy control under "version-null": a NULL version string is below-floor, detail #f, and sodium; decoy control under "version-malformed": a version string that is the floor and more is below-f; decoy control under "version-bom": a version string after a byte order mark is below-floor, det; decoy control under "libtool-high": a version below the floor with libtool numbers 99.99 is bel; decoy control under "libtool-low": the floor with libtool numbers 0.0 loads, and reports them: ; decoy control under "init-fails": sodium_init answering -1 is init-failed, detail -1, after the; and 17 more
- Result: killed

### N11 major called before the string
- Guards: decoy control: the floor itself is accepted: the report's four fields, and the load's calls in ; decoy control under "below-floor": one patch below the floor is below-floor, detail its version; decoy control under "version-null": a NULL version string is below-floor, detail #f, and sodium; decoy control under "version-malformed": a version string that is the floor and more is below-f; decoy control under "version-bom": a version string after a byte order mark is below-floor, det; decoy control under "libtool-high": a version below the floor with libtool numbers 99.99 is bel; decoy control under "libtool-low": the floor with libtool numbers 0.0 loads, and reports them: ; decoy control under "init-fails": sodium_init answering -1 is init-failed, detail -1, after the; and 15 more
- Result: killed

### N12 NULL version is load-failed
- Guards: decoy control under "version-null": a NULL version string is below-floor, detail #f, and sodium
- Result: killed

### N13a step 0 dropped
- Guards: decoy control under "below-floor": one patch below the floor is below-floor, detail its version; decoy control under "version-null": a NULL version string is below-floor, detail #f, and sodium; decoy control under "version-malformed": a version string that is the floor and more is below-f; decoy control under "version-bom": a version string after a byte order mark is below-floor, det; decoy control under "libtool-high": a version below the floor with libtool numbers 99.99 is bel; decoy control under "init-fails": sodium_init answering -1 is init-failed, detail -1, after the; decoy control under "init-other": sodium_init answering 2 is init-failed too, detail 2, not -1'; decoy lacks-sodium_version_string: a library without sodium_version_string is missing-api, nami; and 16 more
- Result: killed

### N13b failure not recorded
- Guards: decoy control under "below-floor": one patch below the floor is below-floor, detail its version; decoy control under "version-null": a NULL version string is below-floor, detail #f, and sodium; decoy control under "version-malformed": a version string that is the floor and more is below-f; decoy control under "version-bom": a version string after a byte order mark is below-floor, det; decoy control under "libtool-high": a version below the floor with libtool numbers 99.99 is bel; decoy control under "init-fails": sodium_init answering -1 is init-failed, detail -1, after the; decoy control under "init-other": sodium_init answering 2 is init-failed too, detail 2, not -1'; decoy lacks-sodium_version_string: a library without sodium_version_string is missing-api, nami; and 16 more
- Result: killed

### N13c a load re-chosen at each report
- Guards: a load is kept: CHEZ_SODIUM_LIBRARY changed between references loads nothing new
- Result: killed

### N14 init recorded as 0
- Guards: decoy control under "init-already": sodium_init answering 1 is no failure: it loads, and the lo; sodium_init called first: the probe's call answers 0, the load sees 1 and loads, a direct call 
- Result: killed

### N15 init recorded from a later call
- Guards: decoy control: the floor itself is accepted: the report's four fields, and the load's calls in ; decoy control under "libtool-low": the floor with libtool numbers 0.0 loads, and reports them: ; decoy control under "init-already": sodium_init answering 1 is no failure: it loads, and the lo; a load is kept: CHEZ_SODIUM_LIBRARY changed between references loads nothing new; decoy marked: a build with DECOY_MARKER, once loaded, shows its marker to foreign-entry?; decoy control under "Below-floor": a value that is no switch behaves as the control, and the lo; decoy control under "below-floorX": a value that only begins with a switch, below-floorX, is no; decoy control under "": an empty value is no switch either; and 8 more
- Result: killed

### N16a .so.23 first
- Guards: not-found (guix world): with no profile to search, not-found lists every candidate checked, ten; not-found (guix world): a directory holding only libsodium.so is not a candidate; discovery (guix world): a directory holding both sonames loads libsodium.so.26; preflight, not-found (guix world), no profile to search: exit 1, every candidate on its own lin
- Result: killed

### N16b bare libsodium.so tried
- Guards: not-found (guix world): with no profile to search, not-found lists every candidate checked, ten; not-found (guix world): a directory holding only libsodium.so is not a candidate; preflight, not-found (guix world), no profile to search: exit 1, every candidate on its own lin
- Result: killed

### N17 world always fhs
- Guards: discovery (fhs world): with the override unset, the first standard candidate that exists loads,; not-found (fhs world): not buildable, so with no profile to search, discovery's success instead; every C oracle run ran under Valgrind exactly when the gate asked, and there were at least two
- Result: killed

### N18 empty override is unset
- Guards: an empty override is invalid-override too, carrying it
- Result: killed

### N19 loader error raised raw
- Guards: a text file is load-failed, with the loader's message; a path that does not exist is load-failed, with the loader's message; discovery (guix world): a candidate that fails to load is load-failed, and the next is never tr
- Result: killed

### N20 preflight remedy of its own
- Guards: preflight, the control decoy below the floor: exit 1, the reason and the fields, the refusal's ; preflight, a bare name: exit 1, invalid-override, the refusal's own message as the remedy, then; preflight, sodium_init answering -1: exit 1, init-failed, detail -1, the refusal's own message ; preflight, not-found (guix world), no profile to search: exit 1, every candidate on its own lin
- Result: killed

### N21 preflight guards any raise
- Guards: none in the builder's run (survived)
- Result: SURVIVED the builder's run, which called it equivalent: the same exit 255, nothing on stdout, no reason line. It is not equivalent, since stderr names the accessor in place of the bug. The review found it (S3-F1), and the row's new stderr column kills it: see "After the review", above.

### W1 wipe one byte short
- Guards: a block of 5 bytes is wiped by one sodium_memzero call over its 5 bytes; an empty bytevector's block of one byte is wiped by one call over 1 byte
- Result: killed

### W2 wipe twice
- Guards: a block of 5 bytes is wiped by one sodium_memzero call over its 5 bytes; an empty bytevector's block of one byte is wiped by one call over 1 byte
- Result: killed

### W3 wipe dropped
- Guards: a block of 5 bytes is wiped by one sodium_memzero call over its 5 bytes; an empty bytevector's block of one byte is wiped by one call over 1 byte
- Result: killed

### X1 decoy switch compared by prefix
- Guards: decoy control under "below-floorX": a value that only begins with a switch, below-floorX, is no
- Result: killed

### T1 tie: an entry dropped from every-entry
- Guards: the decoy's entry list, every-entry, is the convention table's names, whole and in order
- Result: killed

### T2 tie: two entries swapped
- Guards: the decoy's entry list, every-entry, is the convention table's names, whole and in order
- Result: killed

### X2 decoy lacks an entry native requires
- Guards: decoy control: the floor itself is accepted: the report's four fields, and the load's calls in ; decoy control under "libtool-low": the floor with libtool numbers 0.0 loads, and reports them: ; decoy control under "init-fails": sodium_init answering -1 is init-failed, detail -1, after the; decoy control under "init-other": sodium_init answering 2 is init-failed too, detail 2, not -1'; decoy control under "init-already": sodium_init answering 1 is no failure: it loads, and the lo; decoy lacks-sodium_memzero: a library without sodium_memzero is missing-api, naming it; decoy lacks-sodium_memzero under "init-fails": sodium_init comes before the rest: init-failed w; a load is kept: CHEZ_SODIUM_LIBRARY changed between references loads nothing new; and 8 more
- Result: killed

### test-conventions tie (T1, T2, run on `conventions`)
- Guards: `table: its names are (library-loading)'s every-entry ...` for both a dropped entry and two swapped; killed. (The second failing row in that copy, "every record cited ... exists", fails because the copy holds no `.plans/`: a harness artefact, not the mutant.)

### G1 gate-only: `spawn-in` without `gated-command`
- Guards: every probe row of `-decoys` (valgrind line yes expected, no actual) under `make test-memory`; 10 fail. Plain `make`-less run passes by design: only the gate sees it.
- Result: killed under the gate only.

## The refusals: check-dev (`cdmut.py`, whole-tree copies)

### clean (control)
- Result: check-dev: ok: in a fresh copy, make dev runs deps and build, then a REPL with the suites' library path and build's libsodium; a refused libsodium sto

### D1 dev without build
- Result: check-dev: repl: build's report appears 0 times, not once / check-dev: refused: make dev passed with CHEZ_SODIUM_LIBRARY naming no file

### D2 dev without deps
- Result: check-dev: repl: the line "check-dev: ok version VERSION (library MAJOR.MINOR)" appears 0 times, not once

### D3 build twice
- Result: check-dev: repl: build's report appears 2 times, not once

### D4 REPL before build
- Result: check-dev: repl: build's report, the banner and the lines are out of order / check-dev: refused: a REPL started after build refused libsodium

### D5 build's version line without libtool numbers
- Result: check-dev: repl: the REPL loaded libsodium 1.0.22 (library 26.4), but build named 1.0.22

### D6 refusal line changed
- Result: check-dev: refused: make dev did not fail with build's refusal

### D7 D6 and check-dev's refusal-line clause removed
- Result: check-dev: ok: in a fresh copy, make dev runs deps and build, then a REPL with the suites' library path and build's libsodium; a refused libsodium sto

### D8 refusal does not stop the REPL (build exits 0 on refusal)
- Result: check-dev: refused: make dev passed with CHEZ_SODIUM_LIBRARY naming no file

## The refusals: not watched
- Mutant 'the next candidate tried after a failed load' (design note's LV6): no one-line mutant of `native.sls` or `discovery.sls`, since discovery is pure and native tries one path; LV6 asserts the outcome (load-failed on the first, the real profile second never tried) and was not mutated.
- `LD_LIBRARY_PATH` read, the strict parse's leading zero: `test-discovery` and `test-verify` hold them, not these suites (as the design note says).

## CI's `main`

Every run was in the Guix container (`scripts/guix-env`). Each mutant changed `tests/check-ci.sh`
in place by one exact replacement that matched once; the whole of `tests/test-check-ci.sps` ran;
the file was restored. Before each run the real `ci.yml` was checked under the mutant: it passed
in all seven, so no mutant refuses the whole input.

### Red first

The suite's rows and `make-line` were written against the unchanged `ci.yml` and script: 32 rows
failed (every row built from `make-line`, since its text was not in the file; the install rows
by name, since `install-step`'s marker was absent). Then `ci.yml` (the real workflow failed
check-ci: `job main has 0 steps that run "<old make line>"`), then `check-ci.sh`: suite green,
374 passes, exit 0.

### Mutants

| Id | Guards | Mutation | Result: rows that failed |
|---|---|---|---|
| N1 | the install check is required | `nreq`'s main branch back to M0's two lines | 10: install check deleted, written twice, moved after, moved before, with an argument, as a block scalar; make line replaced by make build; "its env dropped", "an if: always() on it", "the cache's if on it" of the install step. KILLED |
| N2a | `make build` after check-chez | `if (pos <= lastp) prob(` to `if (pos <= lastp && x != BUILDLINE) prob(` | 1: moved before Check the Chez. KILLED |
| N2b | `make build` before the make line | `... && lastx != BUILDLINE) prob(` | 1: moved after Checks and suites. KILLED |
| N3 | env CHEZ on the install step | `needenv` guarded by `x != BUILDLINE` | 1: its env dropped. KILLED |
| N4 | no `if:` on the install step | `else if (S_if[at] != "" && x != BUILDLINE)` | 2: an if: always() on it; the cache's if on it. KILLED |
| N5 | one install step | `c != 1 && !(x == BUILDLINE && c > 1)` | 2: written twice; make line replaced by make build. KILLED |
| N6 | the whole run line is `make build` | `x` read as `make build` for any `make build ...` | 1: with an argument. KILLED |
| N7 | `check-dev` is on the make line | the line without `check-dev` accepted as the make line | 1: main's make line without check-dev. KILLED |

### Clean rerun

After restoring (`git diff` shows only the intended edits):

- `tests/test-check-ci.sps` run directly: exit 0, 374 passes.
- `make check-ci`: `check-ci: .github/workflows/ci.yml has the one shape check-ci reads`.
- `make test-memory MEMORY_SUITES=tests/test-check-ci.sps`: pass, 55 s under the gate, within
  450 s (three quarters of 600 s); ran 1, passed 1, failed 0, hung 0, slow 0.
- `make check-test-fails`: ok in all 13 cases, `ci` among them.
- Group o of the memory gate cannot be run alone (no case selector in the script); its command,
  `tests/check-ci.sh .github/workflows` on the tree, is what `make check-ci` ran.
