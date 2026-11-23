# M0 harness mutation log

Evidence that each rule the harness's libraries, suites and checks claim to guard fails through the
property it names. Format of chez-sqlite3's `m4-slice-5-mutation-log.md`: Guards, Mutation, Result.
These are in addition to `check-test-fails`' own plants, which the last section runs.

Every run was in the Guix container (`scripts/guix-env`): Chez 10.4.0 (threaded), libsodium 1.0.22, gcc
16.2.0, Valgrind 3.27.0, x86_64. The three host runs (`make check-guix`, `make check-pins`, the
launcher) say so. Each mutant changed one file in place, by one exact replacement that matched once;
the file was restored after the run, and the clean rerun below shows nothing stayed changed.

## Libraries

| Mutation | Guards | Result |
|---|---|---|
| R1: `require-threaded.sls`, `minimum` `(10 4 0)` to `(10 3 0)` | the library's floor is the one `floors.sexp` writes | `test-require-threaded` fails on the refusal rows at 10.3.0, 9.5.9, 10.3.9 and both pre-releases |
| R2: `require-threaded.sls`, `((not (threaded?))` to `(#f` | a Chez that is not threaded is refused, by name | fails "the refusal asks (threaded?)" and "where (threaded?) is #f, the refusal raises its whole message" |
| C1: `counters.sls`, `(when (= was 0)` to `(when #f` | a count-down below zero is a double free and raises | fails "a count-down below zero ... raises" and "count-down! of block at zero raises" |
| C2: `counters.sls`, `locked` without the mutex | every count is read and written under the mutex | fails the 8-thread row; the suite also reports `native objects left: block 14282` |
| C3: `counters.sls`, `exit-checks` not reversed | the exit checks come back in the order registered | fails "exit-checks answers every check registered, in the order registered" |
| C4: `counters.sls`, `native-kinds` `(block)` to `(block bloc)` | `block` is the one kind | fails `native-kinds` and `native-counts`, and five more rows |
| C5: `counters.sls`, `locked`'s `(critical-section (with-mutex lock (thunk)))` to `(with-mutex lock (thunk))` | no interrupt that escapes can leave the mutex held | The closing review found it survived, with 13 passes (R-F4). The critical-section row was added after the review. Now it fails: `((after-fuel 5 never-answered) #t ((block . 0)))`. An engine abandoned at fuel 5 left the mutex held, and another thread's count never answered. On the real code the engine completes at fuel 6, after 5 expiries, and the suite passes 14 rows. |
| T1: `chez-sodium-testing.sls`, `left` always `'()` | `suite-exit-status` fails a suite that leaves a block | fails the three native-object rows, each naming the missing line |
| T2: same, `shell-quote` never escapes a single quote | `capture-command` passes each argument as one word | fails "each argument arrives as one word" and the temp-directory row |
| T3: same, `gated-command` drops the gate's words | the gate prefix comes before the command | fails the "its words come first" row |
| T4: same, `remove-temp-directory` without its absolute-path refusal | only an absolute path is removed | fails "only an absolute path other than /, and it runs no rm for any other" |
| F1: `floors.sls`, `requirement-lines` says `- sodium` | the README states libsodium, by that name | `make check-floors` fails on the real README; `test-check-floors` fails 50 rows |
| F2: same, key-order test off | the floors file's keys are in the order chez, sodium | fails "floors file: sodium before chez" |
| F3: same, `floor-complaints` never complains | no README line outside the Requirements' list holds a floor | fails the "in the Status section", "before the first heading" and "in a prose line" rows, for both floors |

## Checks

| Mutation | Guards | Result |
|---|---|---|
| F4: `check-floors.sps`, the failing branch exits 0 | `check-floors` exits 1 on a problem | fails the program rows `readme-altered`, `no-section` and the rest: expected exit 1, actual 0 |
| F5: `packaging/floors.sexp`, sodium `1.0.18` to `1.0.19` | README.org states the floors the file gives | `make check-floors` fails: list line 2 is "libsodium 1.0.18", the file gives "1.0.19" |
| F6: `README.org`, `1.0.18` to `1.0.17` | the same, from the README's side | `make check-floors` fails, naming list line 2 |
| N1: `check-nothreads.sps`, `refusal?` without its `who` test | only a refusal from chez-sodium counts as refused | fails the `wrong-who` row |
| N2: same, `import-verdict` answers `'refused` for a library that loaded | a library whose import loads fails the check | fails `mixed`, `private-loads` and the `src/` row |
| S1: `check-suites.sps`, exits 0 whatever it found | `check-suites` exits 1 on a complaint | `check-test-fails` fails `exit-line`, `early-exit` and the other check-suites cases ("make test exited 0") |
| K1: Makefile, `clean` also removes `tests/fixtures` | `make clean` removes `build/` and nothing else | `check-clean` fails: "make clean changed the tree outside build/" |
| K2: Makefile, `test` takes a `TEST_TIMEOUT` of `0` or a leading zero | `make test` refuses a `TEST_TIMEOUT` that is not a positive whole number | host launcher suite fails T11b for `0` and `007`, three rows each |
| K3: Makefile, `check-nothreads` loses its `## ` text | `make help` lists every `.PHONY` target | `check-help` fails, naming `check-nothreads` |
| A1: `Akku.manifest`, a second `depends/dev` entry | `depends/dev` is chez-srfi alone | `test-manifest` fails the `depends/dev` row |
| A2: `CHANGELOG.md`, a release heading with no manifest bump | the manifest's version is the changelog's latest release | fails the version row and the "has a body and both link references" row |
| A3: `Akku.lock`, the commit `7879b52` to `7879b53` | the lock, the gitlink and the checkout name one commit | host `make check-pins` fails: PIN DRIFT, the lock names 7879b53, the checkout 7879b52... |
| A4: `.gitattributes`, a third `export-ignore` line | `.gitattributes` marks `/.plans` and `/AGENTS.md` alone | `test-manifest` fails the `.gitattributes` row |

## The container

| Mutation | Guards | Result |
|---|---|---|
| G1: `scripts/guix-env`, `--container` removed | the launcher enters a container | host launcher suite fails "T1 container flag" and "T1 the whole command" |
| G2: `scripts/guix-env-enter`, `CHEZ_SODIUM_LIBRARY` names `libsodium.so` | the override names `libsodium.so.26` | launcher fails "T7a CHEZ_SODIUM_LIBRARY is the profile's libsodium.so.26" |
| G3: `manifest.scm`, `"valgrind"` removed | the container holds Valgrind, and it instruments Chez | host `make check-guix` fails `tool-path[-lc]`, `tool-path[-lic]` and `valgrind-instruments-chez` |
| G4: `guix-env-selftest`, the interface list expected to be `lo xx` | the container has the loopback interface alone | `make check-guix` fails `interfaces` |

## Not mutated

- `check-help`'s other direction, a target listed and not `.PHONY`: K3 covers the first; the second is the
  same script, one `for` loop.
- `guix-env-selftest`'s other assertions: G3 and G4 cover the two kinds, a tool resolved from the profile and
  a fact read from `/proc`.
- `tests/floors.sls`' list-line parsing (`list-line?`, `numbered?`): `test-check-floors` holds each form
  with a row; none was mutated apart from F1 to F3.

## Clean rerun

After the last mutant, in the container: `make test` ran 6 suites, 6 passed; `make check-test-fails`
failed `make test`, as it must, in all 10 cases; `make check-clean` passed. On the host:
`make check-guix` printed `ALL CHECKS PASSED`; `make check-pins` agreed on chez-srfi `7879b52`.
