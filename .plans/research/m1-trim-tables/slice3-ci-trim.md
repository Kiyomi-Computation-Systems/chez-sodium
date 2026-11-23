# Slice 3, CI's `main`: trim tables and design note

Sources read: AGENTS.md; the M1 plan (§2.3, §2.4, §4.2 items 10 and 11, §4.4, §6 slices 3 and 5,
"Every brief restates these"); ADR-0011, ADR-0002, ADR-0003; `.plans/global-constraints.md`;
`.plans/traps.md`; M0's `ci.yml`, `tests/check-ci.sh`, `tests/test-check-ci.sps` and
`.plans/m0-ci-mutation-log.md`; chez-sqlite3 v0.1.1 (`960d9f0`): `ci.yml`, `tests/check-ci.sh`,
`tests/test-check-ci.sps`, `.plans/traps.md`. v0.1.1's `ci.yml`, `check-ci.sh`,
`test-check-ci.sps` and `traps.md` are copied into
`<scratch>/v/`
for the builder to read. No project file was changed.

What v0.1.1 does for `main` (the only part this slice restores):

- `ci.yml`: step "The install check, by discovery", `env: CHEZ`, `run: make build`, placed after
  the two report steps and before "Checks and suites"; the make line holds `check-dev`.
- `check-ci.sh`: `BUILDLINE = "make build"`; main's required lines, in order, are
  `CHKT, BUILDLINE, MAKELINE, LAUNCHER` (`nreq`); `MAKELINE` names `check-dev` (between
  `check-variadic` and `check-clean`). The generic loop in `endjob` then holds count (exactly one
  step), order and no `if:`. v0.1.1 does not require `env CHEZ` on main's make steps, only its
  value where one is written (flag F3).
- `test-check-ci.sps`: `install-hdr`, `install-step`, `build-run`; eight rows at lines 2306 to 2337
  (deleted, twice, after the make line, before check-chez, an `if:`, an argument, a block scalar,
  an env key `CC`); `check-dev` in `make-words`; and two rows (lines 1497 to 1506) that put
  `CHEZ_SQLITE3_LIBRARY` and `C_INCLUDE_PATH` on the install step.

## 1. Trim table

Verdicts: T1 to T6 kept or changed, T7 and T8 dropped, T10 and T11 deferred to slice 5 (not
drops), T9 not a rule. **Drop count: 2** (T7, T8).

| # | v0.1.1 rule or piece | Guards | Verdict | Notes |
|---|---|---|---|---|
| T1 | `BUILDLINE = "make build"` is a required line of main (`nreq`), as one step's whole run line | `make build` runs in `main` at all; a changed spelling (`make build X`, a block scalar, another target) is no step check-ci reads | **Kept**, as `rq[3]` with `rqk[3] = "env"` | A required line in M0's `nreq` shape, ahead of `MAKELINE`. |
| T2 | exactly one step runs it (`c != 1`, generic) | a deleted install check; a duplicated one | **Kept** | Generic code (M0's C54, C54b). No new code. |
| T3 | position: after check-chez, before the make line (list order in `nreq`; `pos <= lastp`) | the install check runs on the Chez the job just checked, before the suites | **Kept** | M0's list is `BLDT, CHKT, MAKELINE, LAUNCHER`; the new one is `BLDT, CHKT, BUILDLINE, MAKELINE, LAUNCHER`. Nothing holds it against the two report steps, as in v0.1.1 (F6). |
| T4 | no `if:` on it (generic `else if (S_if[at] != "")`) | the install check always runs | **Kept** | M0's C56b. `rqk` is `env`, not `bld`. |
| T5 | `env: CHEZ` on it, value main's Chez | `make build` runs `$(CHEZ) ...`; without CHEZ it takes `scheme` from PATH, which the runner lacks | **Changed** (stronger than v0.1.1) | v0.1.1's check-ci holds the value where written and requires the key only on its report step and its lane steps. M0 requires `env CHEZ` of every step that runs make (`rqk = "env"`, `needenv`); the install check takes that rule. The value rule is the generic `subkey` one. |
| T6 | `MAKELINE` names `check-dev` | the `check-dev` target runs in CI | **Changed** | Its place: after `check-test-fails`, before `check-clean`, v0.1.1's place with `check-variadic` gone. New line: `make check-help check-suites check-pins check-floors check-ci test check-test-fails check-dev check-clean`. The owner's to confirm (F4). |
| T7 | `check-variadic` on the make line, its `make-words` entry, its row and the ci.yml comment about it | the variadic-binding check runs in CI, after `check-test-fails`, outside `make test` | **Dropped** (D1) | Protected `bind-optional`'s variadic check. The plan puts `bind-optional` and `check-variadic` under "Never" (§3), and the Makefile has no such target, so a line that kept it would fail at `make`. Every kept rule reads the make line as one literal; none names `check-variadic`. |
| T8 | main's "Report the runner's SQLite" must carry `env CHEZ` (`S_env`, `sql-env-msg`, row "the SQLite step's env dropped") | the report ran under the job's Chez, since `report-sqlite.sh` read SQLite through Chez's FFI | **Dropped** (D2) | Already M0's drop, listed so the trim is whole. `report-sodium.sh` compiles a C program with `cc` and uses no Chez; M0's `mainsteps` checks only the step's name, place, and run line. No kept rule reads `S_env`: M0's `needenv` reads `S_ev` through `rqk`, which the report step never has, and the `subkey` rules accept a report step with no env. Do not restore it. |
| T9 | the step's name, "The install check, by discovery" | nothing: v0.1.1 holds no rule on it (its `check-ci.sh` names "install check" only in header prose) | not a rule | A label. The step is found by its run line. |
| T10 | env keys `CHEZ_SQLITE3_LIBRARY` and `C_INCLUDE_PATH` refused on main's install check (v0.1.1 rows 1497 to 1506) | discovery is not steered: main is the one job that tests it | **Deferred**: slice 5 | The env exception is slice 5's. M0's `names` and `env key ... is not CHEZ` rules already refuse both in `main`. |
| T11 | `make build` once per lane, kind `build`, `okrun`, `attest` | the lanes | **Deferred**: slice 5 | Main's use of `make build` stays kind `env`. |

Each drop against every rule the copy keeps:

- **D1, `check-variadic`.** The kept rules that read the make line: `MAKELINE` equality (T1 to
  T6) and `check-floors`' scan of `ci.yml` for a floor's text. Neither names `check-variadic`.
  The change is the expected literal alone.
- **D2, the report step's env.** The kept report-step rules (M0's V0 to V10) read the step's name,
  position, run block and run line, none its env. The only rules that read env are the `subkey`
  rules (key is `CHEZ`, written once, value is the job's Chez) and `needenv`; they apply to
  whatever env a step writes, and accept a report step with none.

## 2. Design note

### 2.1 `ci.yml`, job `main`

Three edits, no others.

1. **The install check.** Insert between "Report the runner's libsodium" and the "CHEZ is the real
   binary" comment of "Checks and suites":

```yaml
      # ADR-0002's install check. No line here names the override, so make
      # build finds the runner's libsodium by discovery, in the FHS world, and
      # must accept it: any refusal fails this step, with build's reason. The
      # file it found is the path line of this step's log.
      - name: The install check, by discovery
        env:
          CHEZ: ${{ runner.temp }}/chez-threads/bin/scheme
        run: make build

```

   A blank line after, as every step has. The first comment line must stay exactly
   `      # ADR-0002's install check.`: the suite's `install-step` helper starts its span there.

2. **The make line.** `run: make check-help check-suites check-pins check-floors check-ci test
   check-test-fails check-dev check-clean`, on one line.

3. **Two comments.**
   - The header's `main` entry: `every action pinned to a commit, the runner's libsodium reported,
     then found by discovery and accepted (ADR-0002's install check), every check, then the
     suites.` (wrapped at 80, as the block is).
   - The comment above "Report the runner's libsodium" ends `A report only: the suites hold the
     library to its floor.` Change to `A report only: the install check below, and the suites,
     hold the library to its floor.`

Not touched: the other jobs, the `on`, `permissions` and `concurrency` blocks, every `uses:`.
No floor's text enters (`check-floors` reads this directory). Neither `make build` nor
`check-dev` is a `scripts/ci/` path, so the execute-bit rule and the stray-`scripts/` rule do not
see them. The comment must hold no tab or non-ASCII character (check-ci's own text rule).

### 2.2 `tests/check-ci.sh`

M0's `nreq` for `main` is `rq[3] = MAKELINE; rqk[3] = "env"; rq[4] = LAUNCHER; rqk[4] = "env"`,
then `return 4`.

1. **BEGIN block.** After the `PINRUN = ...` line add `BUILDLINE = "make build"`. Replace the
   `MAKELINE` literal with `"make check-help check-suites check-pins check-floors check-ci test
   check-test-fails check-dev check-clean"` (one line).
2. **`nreq`, the `main` branch**, becomes:

```awk
  if (j == "main") {
    rq[3] = BUILDLINE; rqk[3] = "env"; rq[4] = MAKELINE; rqk[4] = "env"
    rq[5] = LAUNCHER; rqk[5] = "env"
    return 5
  }
```

   Nothing else in the awk changes. Count (`c != 1`), order (`pos <= lastp`), no `if:` and the
   `needenv` CHEZ rule are the generic loop M0 kept; the install step takes all four by being a
   required line of kind `env`. The comment above `nreq` says "env (a make line, which carries the
   env CHEZ)": make it "a make line, `make build` among them".
3. **The header comment**, two places.
   - The job list: `main        the Chez build, check-chez, the two report steps, the install
     check (make build), the checks, then the launcher's tests;` (re-wrapped).
   - The paragraph that says "in job main, between its check-chez step and its make step, the
     steps ...": the install check, `make build`, is the step after them, as one step's whole run
     line, with env CHEZ like any step that runs make.
4. **No new rule beyond those.** No banned word is added: neither `make build` nor `check-dev` names
   a steering variable. `gaterun` is untouched.

Required lines of `main`, in order: Chez build, check-chez, `make build`, the make line, the
launcher. A step out of order is named at the later of the two, on its run line, as M0's rows
already show.

### 2.3 `tests/test-check-ci.sps`: constants and helpers

Add (after `make-line`):

```scheme
(define build-run "make build")
(define install-hdr "      - name: The install check, by discovery")
(define build-line "        run: make build")
(define (install-step)
  (span "      # ADR-0002's install check." "        run: make build\n"))
(define chk-step-hdr "      - name: Check the Chez this job runs\n")
(define (main-chk-step) (string-append chk-step-hdr "        run: " chk-t "\n"))
```

Change `make-line` to the new literal, and `make-words` to
`'("check-help" "check-suites" "check-pins" "check-floors" "check-ci" "test" "check-test-fails"
"check-dev" "check-clean")`.

`main-chk-step` is new: v0.1.1 used `span-after`, which M0 trimmed away. Its text occurs in both
main and memory, so its edit is `le "main"`, never a plain `e`.

### 2.4 The rows, each "as v0.1.1 plants it"

New rows go in `main-rows`, after "main's launcher step before the checks".

| Row | Edits | Expected problems (anchor, message) |
|---|---|---|
| main's install check deleted | `(e (string-append (install-step) "\n") "")` | `("  main:" (n-steps "main" build-run 0))` |
| main's install check written twice | `(e (string-append (install-step) "\n") (string-append (install-step) "\n" (install-step) "\n"))` | `("  main:" (n-steps "main" build-run 2))` |
| main's install check moved after Checks and suites | delete it; `(e (make-run) (string-append (make-run) "\n" (install-step)))` | `((string-append "        run: " make-line) (out-of-order "main" make-line build-run))` |
| main's install check moved before Check the Chez | delete it; `(le "main" (main-chk-step) (string-append (install-step) "\n" (main-chk-step)))` | `((hdr-in "main" #f build-line) (out-of-order "main" build-run chk-t))` |
| main's install check with an argument, make build X | `(le "main" "        run: make build\n" "        run: make build X\n")` | `("  main:" (n-steps "main" build-run 0))` |
| main's install check as a block scalar | `(le "main" "        run: make build\n" "        run: |\n          make build\n")` | `("  main:" (n-steps "main" build-run 0))` |

v0.1.1's rows "an if on main's install check" and "an env key CC on main's install check" are
not written again: M0's `make-step-rows` plants the same faults on every step that runs make.
Add the step to `make-steps`, before the "Checks and suites" entry:

```scheme
(list "main" install-hdr build-run chez-t)
```

That gives, named "main: the step that runs make build: ...": its env dropped (`env-missing`),
its CHEZ the other Chez's, its env gains another key, its env names CHEZ twice, an `if: always()`
on it (`if-bad`, `if-wrong`, `step-has-if`), `continue-on-error` on it, the cache's `if` on it,
and its env names CC. The `old` text of each, header plus `env-text`, occurs once in main.

The make line: `make-word-rows` is built from `make-words`, so adding `"check-dev"` is the row
"main's make line without check-dev"; `without-word` finds `" check-dev"` once.

Left to slice 5 (T10): the install check gaining `CHEZ_SODIUM_LIBRARY` or `C_INCLUDE_PATH` with a
lane's value.

### 2.5 M0 rows that change

1. **"main's make line replaced by make build: it is no step check-ci reads"** (the last row of
   `main-rows`). Today `make build` is no required line, so the one problem is the missing make
   line. After this slice it is a required line, so the row's reason is false. New meaning:
   replacing the make step's run line with `make build` leaves two steps that run it and none that
   runs the make line.

```scheme
(row "main's make line replaced by make build: the install check is then written twice, and no step runs the make line"
     (list (e (make-run) (string-append "        run: make build\n")))
     (list (list "  main:" (n-steps "main" build-run 2))
           (list "  main:" (n-steps "main" make-line 0))))
```

   The order is `nreq`'s: `make build` first, then the make line. The replaced step keeps its
   `env CHEZ`, so no env problem. (With count 2 the loop `continue`s, so no order or env check
   runs on either.)
2. **`make-line` and `make-words`** change as in 2.3. Every M0 row built from `make-line` follows
   with no edit: "main's make line with an argument", "as a block scalar", "without W" for each
   word, the "Checks and suites" rows, "the launcher step before the checks".
3. **No other M0 row changes.** By grep: `make build` occurs in the suite once (that row);
   `check-dev` not at all; `script-steps` and `script-names` hold only `scripts/ci/` steps, and
   neither new line is one.

### 2.6 `check-test-fails.sh`'s `ci` plant and the memory gate's case o

**Neither needs a change.**

- The `ci` plant puts `continue-on-error: true` in job `memory` (a `sed` over `^  memory:$` to
  `^    runs-on:`) and expects exactly one problem, `job memory has the key ...`. Nothing in it reads
  main. It passes before and after, so long as `check-ci.sh` and `ci.yml` change together.
- Case o runs `tests/check-ci.sh .github/workflows` on the real tree and expects the pass line.
  It needs only the real `ci.yml` and the new script to agree, and `scripts/ci/*` to keep their
  bits (no new script here).

## 3. The rows and mutants

Every mutant changes `tests/check-ci.sh` in place by one exact replacement that matches once; the
whole of `tests/test-check-ci.sps` runs; the file is restored and compared with `cmp`. The real
`ci.yml` must pass under each mutant: a mutant that fails the real workflow refuses the whole
input and proves no row. So the rules of position, env, `if:` and count are switched off for the
install check alone. Run the suite as `make test` runs it:
`scripts/guix-env sh -c 'make deps >/dev/null && "$CHEZ" --libdirs src:tests:build/scheme-libs --program tests/test-check-ci.sps'`.

Text is the `check-ci.sh` text as it stands after 2.2. `x` is the line a step runs, `lastx` the
required line before it, in `endjob`.

| Id | Rule turned off | Replacement | Rows that must fail |
|---|---|---|---|
| N1 | the install check is required | the new `nreq` main branch to M0's: `rq[3] = MAKELINE; rqk[3] = "env"; rq[4] = LAUNCHER; rqk[4] = "env"` and `return 4` | every row about the step: deleted, twice, both moved rows, with an argument, as a block scalar, "make line replaced by make build", and the eight "main: the step that runs make build: ..." rows |
| N2a | `make build` after check-chez | `    if (pos <= lastp) prob(` to `    if (pos <= lastp && x != BUILDLINE) prob(` | "moved before Check the Chez" only (moved after make is still named, at the make line) |
| N2b | `make build` before the make line | `    if (pos <= lastp) prob(` to `    if (pos <= lastp && lastx != BUILDLINE) prob(` | "moved after Checks and suites" only |
| N3 | env CHEZ on the install step | `    if (rqk[i] == "env") needenv(at, x, "CHEZ")` to `    if (rqk[i] == "env" && x != BUILDLINE) needenv(at, x, "CHEZ")` | "main: the step that runs make build: its env dropped" only |
| N4 | no `if:` on the install step | `    } else if (S_if[at] != "") prob(` to `    } else if (S_if[at] != "" && x != BUILDLINE) prob(` | "...: an if: always() on it" and "...: the cache's if on it" (each loses its `step-has-if` problem) |
| N5 | one install step, not two | `    if (c != 1) { prob(jln,` to `    if (c != 1 && !(x == BUILDLINE && c > 1)) { prob(jln,` | "written twice"; "make line replaced by make build" (loses its build problem) |
| N6 | the whole run line is `make build` | after `    x = substr(S_run[s], 6)` add `    if (x ~ /^make build( \|$)/) x = BUILDLINE` | "with an argument" only (a block scalar's `S_run` is `run: \|`; no replacement in this machinery isolates that row, and N1 kills it) |
| N7 | `check-dev` is on the make line | after `    x = substr(S_run[s], 6)` add `    if (x == "make check-help check-suites check-pins check-floors check-ci test check-test-fails check-clean") x = MAKELINE` | "main's make line without check-dev" only |

A literal-equality rule can't be switched off by editing `MAKELINE`: the real workflow would
then fail and every row would die with it. N7 adds a second accepted spelling instead.

The generic mutants M0 ran (C54, C54b, C55, C56b, C57, C57b) are rerun: each now fails the new
rows too, which shows the step goes through the generic rules. Rows are anchored on a line's
content: the job's header line, the step's `run: make build` line within `main`, or the make
line's own text.

Watch each row fail before it counts: write the suite's rows first, against the unchanged
`ci.yml` and script (the rows then fail by name, since `install-step`'s span marker is absent and
the guarded thunk reports it), then `ci.yml`, then `check-ci.sh`, then the mutants.

Clean rerun at the end: `make test`, `make check-test-fails`, `make check-memory-gate` (case o),
`make check-ci`, `make check-floors`.

## 4. Flags

**F1. Slice 3's "Done" overstates what `main` does at this slice.** §6 slice 3's "Done" says "CI's
`main` finding `/usr/lib/x86_64-linux-gnu/libsodium.so.23 (system)` by discovery". §2.4 and §4.2
item 10 put the assertion, `check-sodium.sh --discovery`, in slice 5. After this slice `main` runs
`make build` by discovery and the path is a line of the step's log, but nothing asserts it. Also
§2.3's `ci.yml` row, "`check-dev` on its make line; then the floor step", does not say which step
is "the floor step"; I read it as slice 5's `--discovery` step (§2.4).

**F2. `check-dev` does not exist yet.** `tests/check-dev.sh` and the Makefile's `check-dev`
target are the refusals agent's. The ci.yml line names a target the Makefile lacks until the join,
so `main` would fail at `make` until both merge, and `make check-help` needs it in `.PHONY` and
`help`. `check-ci` does not read the Makefile, so this slice's suite passes without it. After the
join, `make -n` the whole line to see it resolve.

**F3. v0.1.1 does not require `env CHEZ` on main's make steps; M0 does.** The install check takes
M0's rule (T5): stronger than v0.1.1's, not restored. Two of the eight `make-step-rows` rows
match v0.1.1's install rows by name; the other six are M0's, with the new step as subject.

**F4. `check-dev`'s place on the make line is a choice.** The plan gives none. v0.1.1's is after
`check-variadic`, before `check-clean`; with `check-variadic` dropped, after `check-test-fails`.
The literal is written in three places (`ci.yml`, `check-ci.sh`, the suite).

**F5. M0's mutation log quotes row names that begin `main: the step that runs make check-help
check-suites ...`.** They are history, not edited. The slice's own log uses the new names. No
suite reads a row's name.

**F6. Nothing holds the install check against the two report steps.** In `ci.yml` it sits after
both, as in v0.1.1, so a refusal still leaves the versions and the libsodium report in the log.
Neither v0.1.1 nor M0 holds that order, and §2.4 says "no others". A rule would be new (two
comparisons, two rows). Recommend not adding it; the caller decides.

**F7. The env exception's refusals in main are slice 5's.** M0's rules already refuse
`CHEZ_SODIUM_LIBRARY` and `C_INCLUDE_PATH` in main, so slice 5's rows will pass the day they are
written; slice 5 must still watch them fail, by switching off the exception's "main refuses" side.

**F8. The memory gate runs every suite, `test-check-ci` among them.** More rows are more
shell-outs. Measure `test-check-ci`'s time under `make test-memory` against three quarters of
`MEMORY_TIMEOUT`. I found no recorded time for it in `.plans/progress.md` or the logs.

**F9. Rows must stay job-scoped for slice 5.** Slice 5 adds `run: make build` to `floor` and
`current`. A row written with a plain `e` on `"        run: make build\n"` would then occur three
times and fail by construction. The rows above use `le "main"`, the `'in "main"` anchor or the job
header. The one plain edit, `install-step`, starts at a comment only main holds. `job-order` in
the suite must gain the lanes in slice 5.

**F10. `make build` needs no `make deps`.** It runs `$(CHEZ) --libdirs src --program
tests/preflight.sps`, which imports only `(chez-sodium private ...)`; no chez-srfi. It runs before
the make line links `deps`, which is fine as placed. `scripts/require-tools "$(GOAL)" $(CHEZ)`
takes an absolute CHEZ, as `make test` does.

**F11. Slice 4 reads `main`'s comments?** No: slice 4's Makefile comment is the caller's. Nothing
in this slice touches `tests/check-nothreads.sps`.
