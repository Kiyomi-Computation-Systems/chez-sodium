# M1 slice 4 mutation log: the public library

Every run was in the Guix container (`scripts/guix-env`): Chez 10.4.0, threaded; libsodium
1.0.22. One Sonnet builder wrote `(chez-sodium)` and its two suites from a trim table the caller
checked first, beside slice 3's builders, on disjoint files. The Makefile's `check-nothreads`
comment was the caller's, at the join, since slice 3 owned the Makefile.

## Reproduced by the caller, at the join

Each in a whole copy of the tree, by one exact replacement, the copy compared with the original
after:

- **An export missing** (`sodium-library-unavailable-candidates`): `test-public` fails "exports
  exactly …" and the `eq?` row.
- **`require-threaded` imported second,** after native: `test-require-threaded` fails
  "src/chez-sodium.sls imports (chez-sodium private require-threaded) first".
- **The join's clean run** is in [slice 3's log](m1-slice-3-mutation-log.md): `make test` 25 of
  25, `test-memory` 25 of 25, and `check-seam` reads 9 libraries.

## After the review

The review ([research/m1-slice-3-review/](research/m1-slice-3-review/README.md)) covered both
slices. Slice 4's fixes:

- **`absent-directory` made under a guard** (S4-F1). Watched: a `make-process-temp-directory`
  that raises fails the child's row by name, with the sentinel in its expected value, and the
  suite runs on: 6 pass, 1 fails.
- **The engine row reads the counts after the sweep** (S4-F2), in a `let*`. Order only; it
  passes as before.
- **`Reason`** in place of a redefined `Symbol` (S4-F3), and the sweep's comment (S4-F4):
  comments only.


## The builder's run

Files: `src/chez-sodium.sls` (41 lines), `tests/test-public.sps` (216), `tests/test-never-loads.sps`
(415), and the comment at lines 13 to 15 of `tests/check-nothreads.sps`. Harness:
`build/slice4-public/mut.py` with `mutants.py`; each mutant is applied alone to a copy of
`src/`, `tests/` and `packaging/` under `build/slice4-public/work/`, never to the shared tree.
A mutant is killed when a suite reports a FAIL row (or `test-require-threaded` does).

### Guards

- Rows reach `(chez-sodium)` through `eval` under a guard, so a missing library or export fails
  a row by name.
- Every raising expression is under `guard`; expected values are symbols or whole strings.
- The library is referenced (`public-load`, and the top-level bindings) before the first engine.
- Both condition children start through `gated-command`, with `env CHEZ_SODIUM_LIBRARY=P` before
  the gate's words, and print `(valgrind . yes|no)`, which the parent compares with
  `CHEZ_SODIUM_GATE_CHILD`.
- The control child shows the maps scan can say `yes` (needle misspelt: killed).

### Mutation (red first, then each mutant)

Red first: (RED2) no `src/chez-sodium.sls`: test-public 0 of 8 pass, every row named failing;
test-never-loads 3 fail by name. (RED1) a library present and wrong (eight stubs, constants):
test-public 2 pass, 6 fail; test-never-loads 3 fail.

| Mutant | Killed by | Result |
|---|---|---|
| C0 control, regenerated correct library | none | passes: 8 and 7 |
| P1a extra `sodium-failed?`; P1b `-reasons`; P1c `&sodium-library-unavailable`; P1d `make-sodium-library-unavailable`; P1e `loaded-libsodium` | test-public exports-whole | killed, each |
| P2 each of the eight missing | test-public exports-whole and eq? (the two version rows too for `sodium-version`); test-never-loads child (for conditions), loaders and control (for `sodium-version`) | killed, 8 of 8 |
| P3 each of the eight wrapped | test-public no-body and eq? rows | killed, 8 of 8; never-loads passes them, as designed |
| P4a unused body; P4b body `(define touched (sodium-version))` | test-public no-body row alone | killed; never-loads passes both |
| P5, P5b path and source swapped by rename | test-public eq? row; never-loads absent and control children | killed |
| P6 native `sodium-version` without `string-copy` | test-public eq-fresh, scribble and engine rows | killed |
| P7 public `sodium-version` caches | test-public eq?, fresh, scribble, engine, no-body | killed |
| P8 `call-with-block` outside `call-in-section` in native `sodium-version` | test-public engine row only | killed |
| P8c same inside `call-in-section` | none | passes (the row does not kill the correct shape) |
| P9 another version string | test-public whole-version and engine rows; control child | killed |
| P10a extra `src` library importing native | never-loads loaders row | killed |
| P10b predicate wrapper calling `sodium-version` | never-loads absent child; test-public no-body and eq? | killed |
| P10c testing library imports native | never-loads allowlist and reach rows | killed |
| P10d override not passed | never-loads absent child | killed |
| P10e needle misspelt | never-loads control child | killed |
| P10f children not gated, with the gate emulated (`CHEZ_SODIUM_GATE_CHILD="valgrind -q"`) | never-loads both condition children (valgrind line) | killed |
| P10g correct code with the gate emulated | none | passes |
| P11a native imported before `require-threaded`; P11b not imported | test-require-threaded names `src/chez-sodium.sls imports (chez-sodium private require-threaded) first` | killed, 56 pass 1 fail |
| T1 engine thunk that does no work | test-public engine row (no run expired) | killed |

Survivors: none. The three that "survived" are controls that must pass (C0, P8c, P10g).

### Result

In the real tree, run directly: test-public 8 pass; test-never-loads 7 pass; test-require-threaded
57 pass; test-check-nothreads 18 pass; `make check-seam`: `check-seam: the seam holds (9 libraries
in 9 files checked)`.

`make test-memory MEMORY_SUITES="tests/test-public.sps tests/test-never-loads.sps"`:
`test-public.sps` pass, 7s under the gate; `test-never-loads.sps` pass, 15s;
`test-memory: ran 2, passed 2, failed 0, hung 0, slow 0`.

### Clean rerun

After the last edit (no change since the mutation run, which used the final files): the direct
runs and the gate run above were taken last.
