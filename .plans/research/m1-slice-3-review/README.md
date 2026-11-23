# M1 slices 3 and 4's review

Read-only and adversarial, on Opus, over slice 3 (refusals end to end, and CI's install check)
and slice 4 (the public library), built side by side in one tree. Its line numbers are those of
the tree it read. How each finding was resolved is at the end. Slice 3's findings are fixed in
slice 3's PR, and slice 4's in slice 4's.

Read-only and adversarial, on `m1-slice-3`'s working tree over `35a26d8`. No project file was
changed. Every probe ran on a copy of the tree outside it, inside the container unless named,
and the copies are now removed. No command was denied.

**Counts: 0 blockers, 5 majors, 9 minors.**

## Slice 3

### S3-F1 (major): N21 is not equivalent, and the raise row cannot tell

- **Where:** `tests/test-library-loading-preflight.sps:244-255`, the row "preflight, a raise that
  is not a refusal…". `tests/preflight.sps:40-42` is what the mutant reaches.
- **Evidence:** the probe ran preflight on the raising fixture
  (`--libdirs tests/fixtures/raising:src`), clean and with N21 (the guard widened to
  `(error? e)`):
  - clean: exit 255, stdout empty, stderr
    `Exception in loaded-libsodium: the raising fixture raises a plain error, not a refusal`;
  - N21: exit 255, stdout empty, stderr
    `Exception in sodium-library-unavailable-candidates: not a &sodium-library-unavailable with irritants (not-a-sodium-library-unavailable (kind other))`.
- **Why it matters:**
  - The handler's `let` calls a checked accessor before it prints anything. A too-wide guard
    therefore trades the bug's own report for the accessor's complaint, so a person running
    `make build` sees the wrong error.
  - The row reads only the exit status, stdout and the absence of a `(reason ` line. All three
    are the same under N21.
  - The refusals builder's design note (§3.5, LP6) expected this row to kill exactly this mutant.
    The log then calls the mutant "equivalent". That is true only of what the suite reads.
- **Fix:**
  - Add a column to the row: preflight's stderr must equal the stderr of a bare program that runs
    `(eval '(loaded-libsodium) (environment '(chez-sodium private native)))` with the same libdirs
    and no guard, so that Chez's default handler meets the same raise.
  - This compares two outputs and writes no message, which is how the remedy rows already treat
    `--message`.
  - Update the mutation log's N21 entry.

### S3-F2 (major): rows depend on argument evaluation order

- **Where:**
  - `tests/test-library-loading-discovery.sps:223-224` and `:248-249`:
    `(list (make-directory D/lib) (copy-file … D/lib/…))`. The copy needs the directory, and
    `cp` into a directory that does not exist fails.
  - Every suite's "the scratch directory is removed":
    - `decoys:190-195`, `missing:166-171`, `combined:207-212`;
    - `real:308-313`, `discovery:297-302`, `preflight:278-283`.

    Each is `(list (… (remove-temp-directory scratch) 'done) (if (file-directory? scratch) …))`.
    The pattern is inherited from v0.1.1.
- **Evidence:**
  - AGENTS.md: "Chez fixes no order for a call's arguments … No assertion may depend on any
    order … `let*` when one init must follow another".
  - chez-sqlite3's `.plans/research/evaluation-order/README.md` measured `cab`, `bca` and `cba`
    outside compiled library code.
  - These rows pass today only because a `--program` is compiled left to right.
  - The two discovery rows are new in this slice. v0.1.1 put "made" and "written" in separate
    rows.
- **Fix:** run the effects in a `let*`, then `list` their results. Apply this to all eight rows.

### S3-F3 (major): `progress.md`'s M2 item says the decoy rule gets a check it will not get

- **Where:** `.plans/progress.md:77-81`.
- **Evidence:** the line says the rule "gains its check: `randombytes_buf` is `nonnull`, so its
  decoy entry compiled under `-Werror` fails if a pointer is tested directly". The 1.0.22
  headers say otherwise:
  - `crypto_generichash` is `nonnull(1)`, so only `out`;
  - `sodium_memcmp` has no `nonnull`;
  - `sodium_memzero` has no `nonnull`.

  So in M2 a direct test of `in`, `key`, `b1_`, `b2_` or `pnt` still compiles under `-Werror`,
  and only `randombytes_buf`'s `buf` and generichash's `out` are held. `traps.md`'s own lesson
  is "`nonnull` is per function". Read as written, the line tells M2's planner that compiling
  the decoy is the check.
- **Also:**
  - "(slice 3's tables, F7)" and "(…, F9)" cite builder trim tables that live only in the
    builder's scratch space, not in the repository.
  - "F7" also collides with the brief review's P-F7.
- **Fix:**
  - Owe a check that does not depend on `nonnull`. For example, a source scan of
    `decoy-libsodium.c` that requires every pointer parameter's only use to be its
    `volatile uintptr_t` read.
  - Note that `randombytes_buf`'s compile only shows the trap for `nonnull` parameters.
  - Cite the slice 3 mutation log or the close-out instead of the trim tables.

### S3-F4 (minor): the decoy has a switch the plan does not list

- **Where:**
  - `tests/decoy-libsodium.c:37, 106, 121, 165-167`: `version-bom`;
  - its row is `tests/test-library-loading-decoys.sps:156-160`.
- **Evidence:** plan §2.2's switch list has eight values, and `version-bom` is not among them.
  The brief's decided items do not cover it either. The trim table (1.1, row 11) justifies it:
  it replaces v0.1.1's `sourceid-utf8`, and it is the end-to-end row for the U+FEFF restore.
- **Fix:** record it in the plan's §2.2 row, or in slice 3's close-out.

### S3-F5 (minor): a macOS rule in a Linux-only tree

- **Where:** `tests/check-dev.sh:47-50`.
- **Evidence:** "a bare mktemp -d ignores it on macOS, where TMPDIR ends in a slash". ADR-0010
  makes the project Linux only. M0's `check-test-fails.sh:85` and `check-memory-gate.sh:204` use
  a plain `mktemp -d`.
- **Fix:** use `mktemp -d` as the M0 scripts do, or drop the macOS reason.

### S3-F6 (minor): slice 3's PR names a library that does not exist yet

- **Where:** `tests/check-dev.sh:16-17`: "The forms import native, not the public (chez-sodium),
  to read what it loaded."
- **Evidence:** slice 3 is committed without `src/chez-sodium.sls` (brief).
- **Fix:**
  - Drop the clause from slice 3, or add it with slice 4.
  - Optional at the join: the Makefile's `dev` comment could then name `(chez-sodium)` and
    `sodium-version` as the plain way in.

### S3-F7 (minor): the "both sonames" row's setup is not asserted

- **Where:** `tests/test-library-loading-discovery.sps:231-235`.
- **Evidence:** `copy-oracle (begin (make-directory …) (copy-file … newer) (oracle-of newer))`
  throws away both results. If the copy fails, the next row fails as `load-failed` on the
  `.so.23` text file, which reads like ".so.23 was tried first". The only-link and older rows
  assert `(made copied)`.
- **Fix:** add the same setup row here.

### S3-F8 (minor): the Makefile holds both slices' hunks

- **Where:**
  - `Makefile:303`, the `check-nothreads` comment, belongs to slice 4.
  - `tests/check-nothreads.sps:13-14` is also slice 4's.
- **Evidence:** `git diff 35a26d8 -- Makefile`. If the whole Makefile goes into slice 3's commit,
  slice 3 claims "(chez-sodium) too" before the library exists.
- **Fix:** split the hunks. Slice 3 takes `.PHONY`, `dev` and `check-dev`; slice 4 takes the
  comment.

### S3-F9 (minor): a row that only the gate can fail, unnamed in its header

- **Where:** `tests/test-library-loading-combined.sps:174-198`, the wipe rows, and the header at
  `:1-33`.
- **Evidence:** the probe moved `foreign-free` before the wipe in `free-foreign-block!`:
  - `-combined` run plain: 13 of 13 pass, because the decoy's log is identical;
  - `make test-memory MEMORY_SUITES=tests/test-library-loading-combined.sps`: FAIL, with
    `Invalid write of size 1 at sodium_memzero (in …/control.so)` and "0 bytes inside a block of
    size 5 free'd";
  - `test-wipe` plain: FAIL, so the property is held without the gate.

  `traps.md` ("A wipe over a freed block passes a plain run") gives the rule: "a row that only
  the gate can fail says so in its suite's header".
- **Fix:** one sentence in `-combined`'s header, pointing to `test-wipe` for the plain run.

### S3-F10 (minor): wording and wraps

- **Where:**
  - `tests/library-loading.sls:508`: `text`'s comment says "no string or number", but the code
    also accepts symbols.
  - Overlong comment lines:
    - `tests/test-library-loading-discovery.sps:79` (114 characters);
    - `tests/check-dev.sh:18` (95);
    - the second line of the `-decoys`, `-missing`, `-combined` and `-preflight` headers, which
      were re-filled unevenly after the rename.
- **Fix:** reword the comment and re-wrap the lines.

## Slice 4

### S4-F1 (major): a top-level definition that can raise, unguarded

- **Where:** `tests/test-never-loads.sps:400`: `(define absent-directory (make-process-temp-directory))`.
- **Evidence:** AGENTS.md: SRFI-64 does not catch a raise "in a suite's top-level definitions:
  the suite dies and no test is named. Compute anything that can raise under a guard."
  - The six library-loading suites guard the same call.
  - v0.1.1's `test-never-loads` has no such definition. The condition children are new here.
- **Fix:** guard it with a sentinel. If it fails, make the condition children's rows fail by
  name.

### S4-F2 (major): the engine row reads the counts in no fixed order

- **Where:** `tests/test-public.sps:209-212`:
  `(list (guard … (version-sweep)) (native-counts))`.
- **Evidence:**
  - The row says "and no block is left", which is only true if the counts are read after the
    sweep. `list` fixes no order: read first, the counts are zero whatever the sweep did.
  - v0.1.1's engine row computes its runs before the `list` that reads `native-counts`.
  - `suite-exit-status` still checks the counts at exit, so a leak would not go unseen. The
    problem is that this row's claim depends on order.
- **Fix:** `(let* ((sweep …) (counts (native-counts))) (list sweep counts))`.

### S4-F3 (minor): the reason's type alias reuses `Symbol`

- **Where:** `src/chez-sodium.sls:24-25`.
- **Evidence:**
  - `;;   Symbol = (U 'invalid-override …)` redefines a base type name. Typed Racket rejects
    that, and the comments are what `test-reference` will hold in M4.
  - `SodiumLibraryUnavailable` is defined nowhere.
  - Line 25 is 101 characters.
- **Fix:** use `-> Reason` with `;;   Reason = (U …)` on its own wrapped line.

### S4-F4 (minor): the sweep's comment claims more than the row shows

- **Where:** `tests/test-public.sps:192-194`: "an expiry can fall inside it; that one did shows the
  sweep interrupted it".
- **Evidence:** "some run expired" counts any expiry inside `(attempt sodium-version)`,
  including `attempt`'s guard. Nothing shows an expiry fell inside `sodium-version`.
- **Fix:** say "some run expired", which is what the row asserts.

## What was checked and found sound

1. **Slice 3 alone** (a copy without `src/chez-sodium.sls`, `test-public` and
   `test-never-loads`):
   - `make test`: ran 23, passed 23;
   - `check-seam`: "8 libraries in 8 files";
   - `check-ci`, `check-help` and `check-suites` (23) pass;
   - `check-nothreads` on the threaded Chez names 8 libraries, its expected red run.

   Slice 4 uses nothing slice 3 adds. Counts are computed, never written, so `check-seam`
   reports 9 with slice 4. CI's `nothreads` job refuses 8 or 9 libraries: `(chez-sodium)`
   imports `require-threaded` first, as native does.
2. **The baseline copy** passes, plain:
   - library-loading suites: decoys 16, missing 16, combined 13, real 23, discovery 19,
     preflight 15;
   - `test-public` 8, `test-never-loads` 7, `test-conventions` 52.
3. **CI's FHS world, which no container run reaches.** The container exports
   `CHEZ_SODIUM_LIBRARY`, so these were simulated in a copy:
   - **Setup:** `libsodium-world` was forced to `fhs`, and a scratch directory holding the host's
     Ubuntu `libsodium.so.23` (1.0.18) was put first in the FHS list. The override was unset.
   - **`make build`:** accepted, `1.0.18 (library 10.3)`, `(system)`.
   - **Suites:**
     - `-discovery` 10 (the FHS arm), `-real` 23, `-preflight` 14;
     - `test-public` 8, `test-never-loads` 7, `test-native` 66.
   - **`check-dev`:** passes.

   So the FHS arms' expected values agree with what the probe prints.
4. **mawk 1.3.4** (the runner's `awk`), on the host:
   - `check-ci.sh`: ok;
   - `test-check-ci`: 374 of 374;
   - `check-dev.sh` with `CHEZ_SODIUM_LIBRARY` at the host's 1.0.18: ok, so its `make deps`
     works in a fresh copy.
5. **The decoy's compile.** All eight builds compile with Ubuntu's GCC 11.4 and GCC 12 under
   `-Wall -Werror -shared -fPIC`. They compile against 1.0.18's headers, with `version.h`
   generated from 1.0.18's `version.h.in`. They are also clean under `-O2 -Wextra -Wformat=2`.
   GCC 16 passes in the container. GCC 13 itself was not available.
6. **The decoy's C:**
   - the log stays inside its buffer;
   - the constructor reads the switch once and compares it whole;
   - the BOM literal is split so `\xBF` does not swallow the version;
   - the only logged pointer, `sodium_memzero`'s `pnt`, is read through a `volatile uintptr_t`.

   Builds and switches match plan §2.2, apart from S3-F4. The call log proves each order row:
   - the three version entries are bound before any is called (`decoy(control)` alone);
   - the floor comes before `sodium_init` and its binding;
   - init comes before the rest;
   - `sodium_memzero` is bound and never called at the load;
   - a refusal before any load has no `calls` line.
7. **"The next candidate is never tried", unmutated until now:**
   - Mutant: `choose-libsodium` given an `exists?` that also requires the file to load.
   - Result: the broken-profile row fails, loading the real library from `guix-profile`.
   - That row is Guix-only. The FHS directories cannot be planted on CI, so the container
     holds it.
8. **The not-found rows:**
   - The expected list is hand-written, never derived from discovery.
   - It has ten candidates, `/run/current-system/profile` included.
   - N16a and N16b are killed.
   - Preflight's candidate lines are built under a guard.
9. **Slice 4 mutants, spot-checked.** `chez-sodium-error?` wrapped by a local `define`, with
   `(only (rnrs) define)` imported:
   - `test-public` fails exactly the no-body and `eq?` rows;
   - `test-never-loads`, `test-require-threaded` and `check-seam` pass, as the design says.

   A body without an `(rnrs)` import fails to load at all.
10. **`(chez-sodium)` against ADR-0012:**
    - it defines nothing;
    - it imports `require-threaded` first;
    - it exports exactly decision 2's M1 names, which are **eight**, not ten as the brief says:
      `sodium-version`, the predicate, the five accessors and `chez-sodium-error?`. The three
      `sodium-failed` names join in M3;
    - no `&` name and no constructor is exported;
    - `check-seam` holds it.

    Both suites cover every item on slice 4's "watched to fail" list. P11a/b (via
    `test-require-threaded`) and P10b (the child) are in the builder's log.
11. **`ci.yml` and `check-ci`:**
    - The install step comes after the packages, the Chez build and check, and both report
      steps, and before the make line.
    - `make build` needs no `deps`.
    - The step has env `CHEZ`. M0's rule already refuses `CHEZ_SODIUM_LIBRARY` and
      `C_INCLUDE_PATH` in any env, so discovery cannot be steered.
    - The step matches v0.1.1's `main`. v0.1.1's env-exception rows are rightly left to slice 5.
12. **CI time:**
    - Slice 2's run: memory job 10m24s; `test-native` 12 s on CI against 8 s in the container,
      the heaviest suite 68 s.
    - Estimate: the six new suites (at most 11 children, ≈ 3.85 s each here) add roughly 5
      minutes.
    - That is far below 450 s a suite and the job's 120 minutes.
    - `main` runs every child plain, at about 0.1 s each.
13. **Rows against plan §6, slice 3, and v0.1.1's suites:** every row for a reason this load has
    is present. The SRFI-64 traps are clear:
    - every computed expected value is under a guard or cannot raise;
    - no expected value is `#f`;
    - no test runs inside another;
    - each suite ends with the exit form;
    - message probes in expected expressions answer data.
14. **AGENTS.md's comment, secrets and leftover rules** hold across the new files and added lines:
    - grep finds no milestone, slice, date, research path, "maintainer", SQLite, connection,
      statement or shard;
    - the decoy logs `p`, not addresses;
    - the wipe bytes are `A`.

## What the records need

- **Mutation logs:** `.plans/m1-slice-3-mutation-log.md` and `-4-` are not in the tree. N21's
  entry should no longer say "equivalent" (S3-F1).
- **Close-out:** slice 3's should record:
  - the per-child time under the gate, 3.85 s, not the plan's 2.6 s, and the 14-child budget;
  - the ten-candidate not-found world (the builder's F10);
  - CI's first measured times, owed by plan §5.2;
  - `version-bom` (S3-F4).
- **Trap candidates:**
  - A row that asserts only an exit status and a missing line cannot tell which raise reached
    the default handler (S3-F1).
  - The container exports `CHEZ_SODIUM_LIBRARY`. So `make build`, `check-dev`, the ambient rows
    and discovery's FHS arm run by discovery for the first time on CI.
- **progress.md:** the M2 owe needs rewording (S3-F3).

---

## How each finding was resolved

The caller reproduced S3-F1 (the two stderr lines above), S3-F2 (the eight `list` rows), S3-F3
(the `nonnull` attributes in 1.0.22's headers: `crypto_generichash` `nonnull(1)`,
`sodium_memcmp` `warn_unused_result` only, `sodium_memzero` none), S4-F1 and S4-F2 by reading
the code, before fixing them. Each new assertion was watched to fail in a copy of the tree.

### Slice 3, fixed in slice 3's PR

- **S3-F1:** the row now requires preflight's stderr to equal that of
  `tests/fixtures/raising/unguarded.sps`, a new program that evaluates `(loaded-libsodium)` in
  native's environment with no guard. It also requires that program to exit 255 with an empty
  stdout and a non-empty stderr. N21 is now killed: that row alone fails, showing the accessor's
  complaint against the bug's own line. `traps.md` gains "An exit status cannot tell which raise
  reached the default handler".
- **S3-F2:** all eight rows run their effects in a `let*` and then list the results.
- **S3-F3:** `progress.md`'s M2 item now owes a check that reads the decoy's source, because a
  `-Werror` compile holds the rule only for a `nonnull` parameter. It cites this review, not the
  trim tables.
- **S3-F4:** plan §2.2 now records `version-bom`, and the probe's `--init-after yes` and
  `--wipe N`, each as added in slice 3.
- **S3-F5:** `check-dev.sh` makes its directory with a plain `mktemp -d`, as M0's scripts do.
- **S3-F6:** the clause naming `(chez-sodium)` is dropped from `check-dev.sh`.
- **S3-F7:** the both-sonames block gains the setup row "the both-sonames directory was made,
  and the library copied to libsodium.so.26", `'(made copied)`. A copy into a missing directory
  fails it by name.
- **S3-F8:** the Makefile's `check-nothreads` comment and `tests/check-nothreads.sps`'s comment
  go in slice 4's commit; slice 3's commit takes `.PHONY`, `dev` and `check-dev`.
- **S3-F9:** `-combined`'s header says its wipe rows can't fail a wipe over a freed block in a
  plain run, and that `test-wipe` holds it there.
- **S3-F10:** `text`'s comment names symbols. The discovery suite's 114-character line, the
  headers of `-decoys`, `-missing`, `-combined` and `-preflight`, and `check-dev.sh`'s comment
  are re-wrapped.

### Slice 4, fixed in slice 4's PR

- **S4-F1:** `absent-directory` is made under a guard. On a raise, the path is the sentinel,
  and the child's row fails by name while the suite runs on. Watched: a raising
  `make-process-temp-directory` fails that row alone, and 6 pass.
- **S4-F2:** the engine row reads the counts in a `let*` after the sweep.
- **S4-F3:** the reason's type is `Reason`, defined on its own wrapped lines.
  `SodiumLibraryUnavailable` stays undefined, as chez-sqlite3 v0.1.1's `SqliteLibraryUnavailable`
  is.
- **S4-F4:** the sweep's comment says only that some run expired.

### For the records

- **The brief's "ten names"** was the caller's miscount. ADR-0012 decision 2 lists eight for
  M1, and `(chez-sodium)` exports those eight.
- **The trap candidate on the FHS world** is recorded in slice 3's close-out and PR rather than
  in `traps.md`. Nothing went wrong, but discovery's FHS arm, `make build` by discovery and
  `check-dev` run by discovery for the first time on CI's `main`, because the container always
  exports `CHEZ_SODIUM_LIBRARY`.
