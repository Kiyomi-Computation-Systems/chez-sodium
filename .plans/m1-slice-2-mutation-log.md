# M1 slice 2 mutation log: the load, the seam and the convention table

Every run was in the Guix container (`scripts/guix-env`): Chez 10.4.0, threaded; libsodium
1.0.22. Three Sonnet builders worked in one tree on disjoint files, each from trim tables the
caller checked first: the load (`memory`, `native`, the oracle, `preflight`, `test-wipe`), the
seam (`check-seam` and the Makefile) and the convention table (`test-conventions`,
`test-constants`). Each mutant changed one file in place, by one exact replacement, and the file
was restored and compared with `cmp`.

## Reproduced by the caller, at the join

- **Rule (m), widened** to let `discovery` and a stray library import `memory`: 3 rows of
  `test-check-seam` fail.
- **The wipe dropped** (`call-with-block` hands `free-foreign-block!` a wipe that does nothing):
  `test-wipe` fails.
- **`sodium_memzero`'s `size_t` written `uptr`** in the convention table: 12 rows of
  `test-conventions` fail.
- **Clean rerun at the join:** `make test` 17 of 17, with `check-seam`; `make check-test-fails`
  all 13 cases; `make test-memory` 17 of 17, the slowest 50 s of 450; `make check-memory-gate`
  all 59 cases; `make build` accepts the container's library and refuses a missing one as
  `load-failed`; `make check-help`; `make check-clean`. `make check-nothreads` fails, naming the
  eight libraries, as it must on a threaded Chez.

## Against 1.0.18 (slice 2's review)

Slice 2's reviewer ran the load against the host's `libsodium.so.23` (Ubuntu's 1.0.18), with
Guix's built 1.0.18 headers, in the container: `test-constants` 20 of 20 and `test-native` 63 of
63, the oracle compiled `-Wall -Werror` against 1.0.18's header; `test-wipe` and `test-blocks`
pass; `make build`'s program reports `1.0.18 (library 10.3)`; and the three load suites pass
under the gate on Valgrind 3.27. CI's `main` and `memory` are the first runs on Valgrind 3.22 and
GCC 13.

## The load

Each entry: Guards (the rows meant to catch it), Mutation (one exact replacement, or the one
set of replacements that makes a single change, applied in place), Result per suite run
(RED when a row fails or the suite exits non-zero, with the first failing rows; "GREEN
(survived)" on a suite not meant to catch it), the restore (`cmp` against the saved original),
and the clean rerun. A RED run is accepted only when the suite started (an INVALID flag marks a
suite that never started, for example a mutant that does not compile); none is INVALID.

Suite runs: `$CHEZ --libdirs src:tests:build/scheme-libs --program tests/test-X.sps`. "gate"
is `make test-memory MEMORY_SUITES=tests/test-X.sps`. The harness is
`build/slice2-load/runmut.py`, its mutants `build/slice2-load/mkspec.py`.

Red first, before the entries:

- `tests/test-blocks.sps`: with no `memory.sls`, the run died with "library (chez-sodium private
  memory) not found".
- `tests/test-native.sps`: with `native.sls` moved aside, 57 rows failed by name and 6 passed
  (the rows that need no native); restored with a `cmp`-checked move.
- `tests/test-wipe.sps`: with `native.sls` moved aside, its one row failed (child exit 255,
  "library (chez-sodium private native) not found"). Its mutants below (W1 to W4, T4, T5) are
  the rows watched failing with the code present.

Survivors: none. A "GREEN (survived)" line below is a suite that was not meant to see that
mutant. W5 (below) is red in a plain run only through E8, which reads the wipe's argument;
W6 keeps that argument and is green in a plain run and red only under the gate, as the plan's
F3 says it must be.

### L1. The floor check dropped

- **Guards:** E2
- **Mutation:** `src/chez-sodium/private/native.sls`: the `version-checked` step deleted from the load's let*
- **Result, test-native:** RED (exit 1)
  - FAIL E2 the load's let* steps, in order: choose, load, the three version bindings, the version, major and minor read, the floor, sodium_init's binding
  - FAIL E4 the load's work is in the one definition: load-shared-object, choose-libsodium, check-version, check-init and bind-required occur in no other 
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### L2. The floor check moved after sodium_init

- **Guards:** E2
- **Mutation:** `src/chez-sodium/private/native.sls`: `version-checked` moved to follow `init-checked`
- **Result, test-native:** RED (exit 1)
  - FAIL E2 the load's let* steps, in order: choose, load, the three version bindings, the version, major and minor read, the floor, sodium_init's binding
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### L3. The version trio swapped in the record

- **Guards:** A8 (major, minor), A11
- **Mutation:** `src/chez-sodium/private/native.sls`: `(cons 'major major) (cons 'minor minor)` read `(cons 'major minor) (cons 'minor major)`
- **Result, test-native:** RED (exit 1)
  - FAIL native's major is the C oracle's, whole
  - FAIL native's minor is the C oracle's, whole
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### L4. sodium_init never called (a constant recorded)

- **Guards:** A12 (first direct answer 0), A8 init, E2
- **Mutation:** `src/chez-sodium/private/native.sls`: `(init (raw-init))` read `(init 0)`
- **Result, test-native:** RED (exit 1)
  - FAIL sodium-init, called after the load, answers 1, and again 1: the load called it first
  - FAIL E2 the load's let* steps, in order: choose, load, the three version bindings, the version, major and minor read, the floor, sodium_init's binding
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### L5. A binding made lazy

- **Guards:** E3
- **Mutation:** `src/chez-sodium/private/native.sls`: `raw-memzero` bound on its first call, inside a lambda
- **Result, test-native:** RED (exit 1)
  - FAIL E2 the load's let* steps, in order: choose, load, the three version bindings, the version, major and minor read, the floor, sodium_init's binding
  - FAIL E3 every foreign-procedure form in native.sls binds eagerly: five in all, each the whole second argument of (bind-required chosen ...) and direct
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### B1. call-with-block's block not freed on a raise or an escape

- **Guards:** B2 (counts 1)
- **Mutation:** `src/chez-sodium/private/native.sls`: the block is freed only when PROC returned, marked by `make-failure` set to `ok` after PROC
- **Result, test-native:** RED (exit 1)
  - FAIL call-with-bytes: a raise from PROC frees the block, and reaches the caller; so does an escape
  - FAIL call-with-bytes: re-entering PROC through a continuation, once the block is freed, raises from its WHO, and PROC runs once
  - FAIL call-with-bytes refuses a string as no bytevector, from its WHO, irritants (not-a-bytevector bytes (kind string)), with nothing allocated at the 
  - FAIL call-with-bytes refuses a symbol as no bytevector, from its WHO, irritants (not-a-bytevector bytes (kind symbol)), with nothing allocated at the 
  - FAIL call-with-bytes refuses a number as no bytevector, from its WHO, irritants (not-a-bytevector bytes (kind number)), with nothing allocated at the 
  - FAIL call-with-bytes refuses a list as no bytevector, from its WHO, irritants (not-a-bytevector bytes (kind list)), with nothing allocated at the rais
  - FAIL call-with-bytes refuses a vector as no bytevector, from its WHO, irritants (not-a-bytevector bytes (kind vector)), with nothing allocated at the 
  - FAIL call-with-bytes refuses a boolean as no bytevector, from its WHO, irritants (not-a-bytevector bytes (kind boolean)), with nothing allocated at th
  - FAIL call-with-bytes refuses a PROC that is no procedure, from its WHO, and a WHO that is no symbol, from itself, each by shown-value, with nothing al
  - FAIL C5 call-in-section around call-with-bytes of 64 bytes, under an engine at every fuel from 1 until it completes: each run answers the 64 bytes, ra
  - FAIL C6 under an engine at every fuel: a raise from PROC caught inside THUNK answers as data, and a raise out of THUNK reaches the caller as the same 
  - FAIL D1 call-with-bytes refuses a re-entry outside its critical thunks, and its argument refusals come before any: a handler of each runs at depth 1, 
  - FAIL D2 call-with-bytes raises a failed free outside its critical after thunk: a PROC that freed its block itself makes free-foreign-block! refuse the
  - FAIL D3 the same refusal through call-in-section is raised again after the outer section: a handler of it runs at depth 1; every count is zero after
  - FAIL every count is zero at the end
- **Result, test-wipe:** RED (exit 1)
  - FAIL row 24: every block call-with-block and call-with-bytes free reads all zeros at the free, after a return, a raise, an escape, odd sizes, an empty
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### B2. A re-entry let through

- **Guards:** B3, D1, C4 control
- **Mutation:** `src/chez-sodium/private/native.sls`: the outer before thunk's `(when freed` read `(when #f`
- **Result, test-native:** RED (exit 1)
  - FAIL call-with-bytes: re-entering PROC through a continuation, once the block is freed, raises from its WHO, and PROC runs once
  - FAIL an outer guard that does not match: around call-in-section, the caller's own object arrives; around a bare call-with-bytes, the re-entry's refusa
  - FAIL D1 call-with-bytes refuses a re-entry outside its critical thunks, and its argument refusals come before any: a handler of each runs at depth 1, 
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### W1. The wipe dropped

- **Guards:** test-wipe: every wipe row 2; E8
- **Mutation:** `src/chez-sodium/private/native.sls`: `call-with-block` hands `free-foreign-block!` a no-op wipe
- **Result, test-native:** RED (exit 1)
  - FAIL E8 call-with-block's definition holds exactly one foreign-block form and one free-foreign-block! form, and the second argument of that free is so
- **Result, test-wipe:** RED (exit 1)
  - FAIL row 24: every block call-with-block and call-with-bytes free reads all zeros at the free, after a return, a raise, an escape, odd sizes, an empty
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### W2. The wipe shortened by one byte

- **Guards:** test-wipe: every wipe row 2; E8
- **Mutation:** `src/chez-sodium/private/native.sls`: `call-with-block` wipes `(- size 1)` bytes
- **Result, test-native:** RED (exit 1)
  - FAIL E8 call-with-block's definition holds exactly one foreign-block form and one free-foreign-block! form, and the second argument of that free is so
- **Result, test-wipe:** RED (exit 1)
  - FAIL row 24: every block call-with-block and call-with-bytes free reads all zeros at the free, after a return, a raise, an escape, odd sizes, an empty
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### W3. sodium_memzero itself shortened by one byte

- **Guards:** A13 (N 16, N 15), test-wipe
- **Mutation:** `src/chez-sodium/private/native.sls`: the recorded `sodium-memzero` zeroes `(max 0 (- n 1))` bytes
- **Result, test-native:** RED (exit 1)
  - FAIL sodium-memzero zeroes exactly N bytes: 16 of 16, 15 of 16 with the last left, none of 16; it answers the unspecified value, and nothing is left c
- **Result, test-wipe:** RED (exit 1)
  - FAIL row 24: every block call-with-block and call-with-bytes free reads all zeros at the free, after a return, a raise, an escape, odd sizes, an empty
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### W4. The wipe moved into a wrapper of PROC (plain code after PROC)

- **Guards:** test-wipe: raise and escape rows 2, the rest 1
- **Mutation:** `src/chez-sodium/private/native.sls`: PROC's answer is returned after a plain `sodium-memzero` call; the free gets a no-op wipe
- **Result, test-native:** RED (exit 1)
  - FAIL E8 call-with-block's definition holds exactly one foreign-block form and one free-foreign-block! form, and the second argument of that free is so
- **Result, test-wipe:** RED (exit 1)
  - FAIL row 24: every block call-with-block and call-with-bytes free reads all zeros at the free, after a return, a raise, an escape, odd sizes, an empty
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### W5. The wipe over a dead block (placement before the free), plain run

- **Guards:** W3 at unit level is test-blocks'; D2, D3 pass in a plain run by design
- **Mutation:** `src/chez-sodium/private/native.sls`: `call-with-block`'s after thunk wipes `made` for `size` bytes, then frees with a no-op wipe: a write to the dead block when PROC freed it
- **Result, test-native:** RED (exit 1)
  - FAIL E8 call-with-block's definition holds exactly one foreign-block form and one free-foreign-block! form, and the second argument of that free is so
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63

### W5g. The same mutant, under the gate

- **Guards:** the gate: Invalid write of size 1
- **Mutation:** `src/chez-sodium/private/native.sls`: the same replacement as W5, run with `make test-memory MEMORY_SUITES=tests/test-native.sps`
- **Result, gate test-native:** RED (exit 2)
  - gate: ==847== Invalid write of size 1
  - gate: ==847== ERROR SUMMARY: 6 errors from 3 contexts (suppressed: 0 from 0)
  - gate: test-memory: ran 1, passed 0, failed 1, hung 0, slow 0
- **Restore:** cmp ok
- **Clean rerun:** gate exit 0 test-memory: ran 1, passed 1, failed 0, hung 0, slow 0

### Y1. call-with-bytes with bytevector-copy restored

- **Guards:** E9
- **Mutation:** `src/chez-sodium/private/native.sls`: `bytes` rebound to `(bytevector-copy bytes)`
- **Result, test-native:** RED (exit 1)
  - FAIL E9 call-with-bytes' definition copies nothing: no bytevector-copy, bytevector-copy!, bytevector->u8-list, make-bytevector, utf8->string, string->
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### Y2. The empty bytevector's one byte left unwritten

- **Guards:** B5
- **Mutation:** `src/chez-sodium/private/native.sls`: `(foreign-set! 'unsigned-8 block 0 0)` read `#f`
- **Result, test-native:** RED (exit 1)
  - FAIL call-with-bytes hands C a bytevector's bytes in a counted block, never NULL: none is one byte, 0; 00, 61 00 62, 00 00 00 and C3 A9 FF FE 80 as gi
  - FAIL call-with-bytes writes the one byte for an empty bytevector itself: a reused block whose byte an unwritten block leaves non-zero reads 0
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### Y3. NULL handed to PROC for an empty bytevector

- **Guards:** B1 (pointer row)
- **Mutation:** `src/chez-sodium/private/native.sls`: PROC is handed 0 when the bytevector is empty
- **Result, test-native:** RED (exit 1)
  - FAIL call-with-bytes hands C a bytevector's bytes in a counted block, never NULL: none is one byte, 0; 00, 61 00 62, 00 00 00 and C3 A9 FF FE 80 as gi
- **Result, test-wipe:** RED (exit 1)
  - FAIL row 24: every block call-with-block and call-with-bytes free reads all zeros at the free, after a return, a raise, an escape, odd sizes, an empty
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### Y4. shown-value in place of refuse-secret

- **Guards:** B4 (symbol, number, character list rows)
- **Mutation:** `src/chez-sodium/private/native.sls`: `call-with-bytes` refuses a non-bytevector with `(shown-value bytes)`
- **Result, test-native:** RED (exit 1)
  - FAIL call-with-bytes refuses a string as no bytevector, from its WHO, irritants (not-a-bytevector bytes (kind string)), with nothing allocated at the 
  - FAIL call-with-bytes refuses a symbol as no bytevector, from its WHO, irritants (not-a-bytevector bytes (kind symbol)), with nothing allocated at the 
  - FAIL call-with-bytes' refusal of a symbol is an assertion violation and no &chez-sodium-error, and the condition shown whole holds none of its text
  - FAIL call-with-bytes refuses a number as no bytevector, from its WHO, irritants (not-a-bytevector bytes (kind number)), with nothing allocated at the 
  - FAIL call-with-bytes' refusal of a number is an assertion violation and no &chez-sodium-error, and the condition shown whole holds none of its text
  - FAIL call-with-bytes refuses a list as no bytevector, from its WHO, irritants (not-a-bytevector bytes (kind list)), with nothing allocated at the rais
  - FAIL call-with-bytes' refusal of a list is an assertion violation and no &chez-sodium-error, and the condition shown whole holds none of its text
  - FAIL call-with-bytes refuses a vector as no bytevector, from its WHO, irritants (not-a-bytevector bytes (kind vector)), with nothing allocated at the 
  - FAIL call-with-bytes refuses a boolean as no bytevector, from its WHO, irritants (not-a-bytevector bytes (kind boolean)), with nothing allocated at th
  - FAIL D1 call-with-bytes refuses a re-entry outside its critical thunks, and its argument refusals come before any: a handler of each runs at depth 1, 
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### S1. call-in-section without its section

- **Guards:** C2, C5
- **Mutation:** `src/chez-sodium/private/native.sls`: `critical-section` removed from `call-in-section`
- **Result, test-native:** RED (exit 1)
  - FAIL call-in-section runs THUNK in one critical section: the interrupt depth is 1 before, 2 inside and 1 after
  - FAIL C5 call-in-section around call-with-bytes of 64 bytes, under an engine at every fuel from 1 until it completes: each run answers the 64 bytes, ra
  - FAIL C6 under an engine at every fuel: a raise from PROC caught inside THUNK answers as data, and a raise out of THUNK reaches the caller as the same 
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### S2. call-in-section raising inside (no guard)

- **Guards:** C3 (handler depth 2), C4
- **Mutation:** `src/chez-sodium/private/native.sls`: the guard removed from inside the section
- **Result, test-native:** RED (exit 1)
  - FAIL call-in-section raises what THUNK raised after its section: a symbol, a list, #f, a string and a condition each reach a handler at depth 1, as th
  - FAIL an outer guard that does not match: around call-in-section, the caller's own object arrives; around a bare call-with-bytes, the re-entry's refusa
  - FAIL D3 the same refusal through call-in-section is raised again after the outer section: a handler of it runs at depth 1; every count is zero after
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### S3. call-in-section catching and never raising again

- **Guards:** C3, C4, C6
- **Mutation:** `src/chez-sodium/private/native.sls`: `(raise (cadr outcome))` read `(cadr outcome)`
- **Result, test-native:** RED (exit 1)
  - FAIL call-in-section raises what THUNK raised after its section: a symbol, a list, #f, a string and a condition each reach a handler at depth 1, as th
  - FAIL an outer guard that does not match: around call-in-section, the caller's own object arrives; around a bare call-with-bytes, the re-entry's refusa
  - FAIL C6 under an engine at every fuel: a raise from PROC caught inside THUNK answers as data, and a raise out of THUNK reaches the caller as the same 
  - FAIL D3 the same refusal through call-in-section is raised again after the outer section: a handler of it runs at depth 1; every count is zero after
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### S4. call-in-section with an in-band sentinel

- **Guards:** C1
- **Mutation:** `src/chez-sodium/private/native.sls`: the answer is tagged by being a list headed `raised`
- **Result, test-native:** RED (exit 1)
  - FAIL call-in-section answers THUNK's value: #f, 0, (), a list headed raised, and a string, none of them raised
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### X1. A helper in native calling foreign-block outside call-with-block

- **Guards:** E7
- **Mutation:** `src/chez-sodium/private/native.sls`: a `stray` definition calling `(foreign-block 1)`
- **Result, test-native:** RED (exit 1)
  - FAIL E7 foreign-block and free-foreign-block! occur in no top-level form of native's body, define-syntax templates included, but call-with-block's def
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### X2. native exporting foreign-block

- **Guards:** A3
- **Mutation:** `src/chez-sodium/private/native.sls`: `foreign-block` added to the export list
- **Result, test-native:** RED (exit 1)
  - FAIL (chez-sodium private native) exports exactly the load's record, the five raw bindings, call-in-section and the block and byte helpers, and neithe
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### X3. A macro template building a block (define-syntax)

- **Guards:** E7 (reads define-syntax templates)
- **Mutation:** `src/chez-sodium/private/native.sls`: a `define-syntax` whose template is `(foreign-block 1)`
- **Result, test-native:** RED (exit 1)
  - FAIL E7 foreign-block and free-foreign-block! occur in no top-level form of native's body, define-syntax templates included, but call-with-block's def
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### F1. loaded-libsodium sharing its path string

- **Guards:** A4, E10
- **Mutation:** `src/chez-sodium/private/native.sls`: `(string-copy libsodium-path)` read `libsodium-path`
- **Result, test-native:** RED (exit 1)
  - FAIL loaded-libsodium answers a fresh list at every call: its keys in order, equal and never eq?, fresh strings, and what a caller changes in one neve
  - FAIL the load's path and source are the ones this suite chose
  - FAIL E10 sodium-version's body is (string-copy libsodium-version), and loaded-libsodium builds its two strings with string-copy of the path and the ve
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### F2. sodium-version sharing its string

- **Guards:** A10 (fresh string), E10
- **Mutation:** `src/chez-sodium/private/native.sls`: `sodium-version` answers `libsodium-version` itself
- **Result, test-native:** RED (exit 1)
  - FAIL sodium-version is the recorded version, the oracle's, and a fresh string at every call: what a caller changes in one never reaches the next
  - FAIL E10 sodium-version's body is (string-copy libsodium-version), and loaded-libsodium builds its two strings with string-copy of the path and the ve
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### F3. loaded-libsodium sharing one list and its pairs

- **Guards:** A4, E10
- **Mutation:** `src/chez-sodium/private/native.sls`: `loaded-libsodium` answers one list built once
- **Result, test-native:** RED (exit 1)
  - FAIL loaded-libsodium answers a fresh list at every call: its keys in order, equal and never eq?, fresh strings, and what a caller changes in one neve
  - FAIL the load's path and source are the ones this suite chose
  - FAIL native's version is the C oracle's, whole
  - FAIL native's major is the C oracle's, whole
  - FAIL sodium-version is the recorded version, the oracle's, and a fresh string at every call: what a caller changes in one never reaches the next
  - FAIL E10 sodium-version's body is (string-copy libsodium-version), and loaded-libsodium builds its two strings with string-copy of the path and the ve
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### U1. c-string->string decoding with plain utf8->string

- **Guards:** the BOM rows (c-string->string, check-version)
- **Mutation:** `src/chez-sodium/private/native.sls`: the U+FEFF restoration replaced by the bare decoded string
- **Result, test-native:** RED (exit 1)
  - FAIL c-string->string reads EF BB BF 61 as U+FEFF then a, keeps a second U+FEFF, keeps one before an invalid byte (replaced, not refused), and reads a
  - FAIL a version string of EF BB BF 31 2E 30 2E 31 38 reads as U+FEFF then 1.0.18, and check-version refuses it as below-floor, where plain 1.0.18 passe
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### M1. Memory: WIPE called on a dead block

- **Guards:** W3, W7 (the child)
- **Mutation:** `src/chez-sodium/private/memory.sls`: the not-live branch calls the wipe first
- **Result, test-blocks:** RED (exit 1)
  - FAIL W3 a freed address and one never allocated are refused with the wipe never called, and nothing is counted
  - FAIL W7 free-foreign-block! refuses a dead address, freed already or never allocated, before free and before the wipe: in a child Chez, whose wipe ran
- **Result, test-native:** GREEN (survived) (exit 0)
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-blocks exit 0 # of expected passes      18; test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### M2. Memory: WIPE after the count-down

- **Guards:** W1 (counts read inside the wipe)
- **Mutation:** `src/chez-sodium/private/memory.sls`: the count-down moved ahead of the wipe
- **Result, test-blocks:** RED (exit 1)
  - FAIL W1 free-foreign-block! calls its wipe once, with the block's address and size, while the block is still counted; the count falls after
  - FAIL W6 a wipe that raises, over a block whose count was taken away, raises the wipe's object, not the double free
- **Result, test-native:** GREEN (survived) (exit 0)
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-blocks exit 0 # of expected passes      18; test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### M3. Memory: WIPE called twice

- **Guards:** W1
- **Mutation:** `src/chez-sodium/private/memory.sls`: `(wipe address size)` written twice
- **Result, test-blocks:** RED (exit 1)
  - FAIL W1 free-foreign-block! calls its wipe once, with the block's address and size, while the block is still counted; the count falls after
  - FAIL W2 the size the wipe gets is the one foreign-block recorded: 1, 7 and 4096 each arrive as made
  - FAIL W7 free-foreign-block! refuses a dead address, freed already or never allocated, before free and before the wipe: in a child Chez, whose wipe ran
- **Result, test-native:** GREEN (survived) (exit 0)
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-blocks exit 0 # of expected passes      18; test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### M4. Memory: WIPE given a fixed size

- **Guards:** W2 (and W1)
- **Mutation:** `src/chez-sodium/private/memory.sls`: `(wipe address size)` read `(wipe address 8)`
- **Result, test-blocks:** RED (exit 1)
  - FAIL W1 free-foreign-block! calls its wipe once, with the block's address and size, while the block is still counted; the count falls after
  - FAIL W2 the size the wipe gets is the one foreign-block recorded: 1, 7 and 4096 each arrive as made
  - FAIL W8 a wipe that reads the whole block finds it live, holding what was written
- **Result, test-native:** GREEN (survived) (exit 0)
- **Result, test-wipe:** RED (exit 1)
  - FAIL row 24: every block call-with-block and call-with-bytes free reads all zeros at the free, after a return, a raise, an escape, odd sizes, an empty
- **Restore:** cmp ok
- **Clean rerun:** test-blocks exit 0 # of expected passes      18; test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### M5. Memory: WIPE not guarded

- **Guards:** W5 (depth 2 or a lost free)
- **Mutation:** `src/chez-sodium/private/memory.sls`: the guard around the wipe replaced by a plain call
- **Result, test-blocks:** RED (exit 1)
  - FAIL W5 a wipe that raises: its object reaches a handler at depth 1, itself, the block is freed and counted down, and a second free is refused as not 
  - FAIL W6 a wipe that raises, over a block whose count was taken away, raises the wipe's object, not the double free
- **Result, test-native:** GREEN (survived) (exit 0)
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-blocks exit 0 # of expected passes      18; test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### M6. Memory: the procedure check missing

- **Guards:** W4
- **Mutation:** `src/chez-sodium/private/memory.sls`: `(unless (procedure? wipe)` read `(unless #t`
- **Result, test-blocks:** RED (exit 1)
  - FAIL W4 a wipe that is no procedure is refused by shown-value, and the block stays live and counted until freed properly
- **Result, test-native:** GREEN (survived) (exit 0)
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-blocks exit 0 # of expected passes      18; test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### M7. Memory: the order of failures

- **Guards:** W6
- **Mutation:** `src/chez-sodium/private/memory.sls`: a double-free is raised in preference to the wipe's failure
- **Result, test-blocks:** RED (exit 1)
  - FAIL W6 a wipe that raises, over a block whose count was taken away, raises the wipe's object, not the double free
- **Result, test-native:** GREEN (survived) (exit 0)
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-blocks exit 0 # of expected passes      18; test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### M8. Memory: the wipe after the free, plain run

- **Guards:** W8 (the wipe reads a freed block), W3 child
- **Mutation:** `src/chez-sodium/private/memory.sls`: the wipe moved after `foreign-free`
- **Result, test-blocks:** RED (exit 1)
  - FAIL W8 a wipe that reads the whole block finds it live, holding what was written
- **Restore:** cmp ok
- **Clean rerun:** test-blocks exit 0 # of expected passes      18

### M8g. Memory: the wipe after the free, under the gate

- **Guards:** W8 under the gate: Invalid read
- **Mutation:** `src/chez-sodium/private/memory.sls`: the same replacement as M8, run under the gate
- **Result, gate test-blocks:** RED (exit 2)
  - gate: ==847== Invalid read of size 1
  - gate: ==847== ERROR SUMMARY: 40 errors from 1 contexts (suppressed: 0 from 0)
  - gate: test-memory: ran 1, passed 0, failed 1, hung 0, slow 0
- **Restore:** cmp ok
- **Clean rerun:** gate exit 0 test-memory: ran 1, passed 1, failed 0, hung 0, slow 0

### M9. Memory: a failed wipe skips the free

- **Guards:** W5
- **Mutation:** `src/chez-sodium/private/memory.sls`: a block whose wipe raised is neither deleted nor freed
- **Result, test-blocks:** RED (exit 1)
  - FAIL W5 a wipe that raises: its object reaches a handler at depth 1, itself, the block is freed and counted down, and a second free is refused as not 
- **Result, test-native:** GREEN (survived) (exit 0)
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-blocks exit 0 # of expected passes      18; test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### M10. Memory: foreign-block not counted

- **Guards:** the counts rows throughout
- **Mutation:** `src/chez-sodium/private/memory.sls`: `(count-up! 'block)` removed
- **Result, test-blocks:** RED (exit 1)
  - FAIL foreign-block: an address, counted as a block while it lives; free-foreign-block! frees it, and the count is zero after
  - FAIL a block is writable over its whole size
  - FAIL two blocks live at once are both counted, and each frees, the first made first; a block of 1 byte is one too
  - FAIL W1 free-foreign-block! calls its wipe once, with the block's address and size, while the block is still counted; the count falls after
  - FAIL W2 the size the wipe gets is the one foreign-block recorded: 1, 7 and 4096 each arrive as made
  - FAIL W3 a freed address and one never allocated are refused with the wipe never called, and nothing is counted
  - FAIL W4 a wipe that is no procedure is refused by shown-value, and the block stays live and counted until freed properly
  - FAIL W6 a wipe that raises, over a block whose count was taken away, raises the wipe's object, not the double free
  - FAIL W8 a wipe that reads the whole block finds it live, holding what was written
  - FAIL W7 free-foreign-block! refuses a dead address, freed already or never allocated, before free and before the wipe: in a child Chez, whose wipe ran
  - FAIL free-foreign-block! raises its count-down's double free after its critical section: a handler of it runs at depth 1, and the count stays at zero
- **Result, test-native:** RED (exit 1)
  - FAIL sodium-memzero zeroes exactly N bytes: 16 of 16, 15 of 16 with the last left, none of 16; it answers the unspecified value, and nothing is left c
  - FAIL c-string->string reads EF BB BF 61 as U+FEFF then a, keeps a second U+FEFF, keeps one before an invalid byte (replaced, not refused), and reads a
  - FAIL a version string of EF BB BF 31 2E 30 2E 31 38 reads as U+FEFF then 1.0.18, and check-version refuses it as below-floor, where plain 1.0.18 passe
  - FAIL call-with-bytes hands C a bytevector's bytes in a counted block, never NULL: none is one byte, 0; 00, 61 00 62, 00 00 00 and C3 A9 FF FE 80 as gi
  - FAIL call-with-bytes writes the one byte for an empty bytevector itself: a reused block whose byte an unwritten block leaves non-zero reads 0
  - FAIL call-with-bytes: a raise from PROC frees the block, and reaches the caller; so does an escape
  - FAIL call-with-bytes: re-entering PROC through a continuation, once the block is freed, raises from its WHO, and PROC runs once
  - FAIL foreign-bytes reads N bytes at an address, undecoded, into a bytevector: 00 61 00 FF 80 C3 whole, its first 2, none at the block, and none at NUL
  - FAIL foreign-bytes answers a fresh bytevector: the block written after the read leaves it, and two reads are two bytevectors
  - FAIL foreign-bytes refuses an address and a count that are no exact naturals, each named by its field and shown-value, and NULL with bytes to read, fr
  - FAIL c-string->bytevector reads the bytes up to the NUL, undecoded: 61 62, none, FF, EF BB BF kept, C3 A9 before a NUL and 78; #f for NULL, compared a
  - FAIL c-string->bytevector answers a fresh bytevector: the block written after the read leaves it, and two reads are two bytevectors
  - FAIL an outer guard that does not match: around call-in-section, the caller's own object arrives; around a bare call-with-bytes, the re-entry's refusa
  - FAIL C5 call-in-section around call-with-bytes of 64 bytes, under an engine at every fuel from 1 until it completes: each run answers the 64 bytes, ra
  - FAIL C6 under an engine at every fuel: a raise from PROC caught inside THUNK answers as data, and a raise out of THUNK reaches the caller as the same 
  - FAIL D1 call-with-bytes refuses a re-entry outside its critical thunks, and its argument refusals come before any: a handler of each runs at depth 1, 
- **Result, test-wipe:** RED (exit 1)
  - FAIL row 24: every block call-with-block and call-with-bytes free reads all zeros at the free, after a return, a raise, an escape, odd sizes, an empty
- **Restore:** cmp ok
- **Clean rerun:** test-blocks exit 0 # of expected passes      18; test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1

### T1. The oracle's major and minor swapped

- **Guards:** A8, A11
- **Mutation:** `tests/libsodium-oracle.c`: `major_answer, minor_answer` printed in the other order
- **Result, test-native:** RED (exit 1)
  - FAIL native's major is the C oracle's, whole
  - FAIL native's minor is the C oracle's, whole
  - FAIL sodium-version-string's address reads as the version, and the library's major and minor are the oracle's, never swapped
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63

### T2. The oracle run outside the gate

- **Guards:** A7b (oracle ran under Valgrind exactly when the gate asked)
- **Mutation:** `tests/libsodium-oracle.sls`: `gated-command` removed from the oracle's run
- **Result, gate test-native:** RED (exit 2)
  - gate: ==847== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
  - gate: test-memory: ran 1, passed 0, failed 1, hung 0, slow 0
- **Restore:** cmp ok
- **Clean rerun:** gate exit 0 test-memory: ran 1, passed 1, failed 0, hung 0, slow 0

### T3. test-blocks' child run outside the gate

- **Guards:** W7 (valgrind line)
- **Mutation:** `tests/test-blocks.sps`: the dead-address child started without `gated-command`
- **Result, gate test-blocks:** RED (exit 2)
  - gate: ==847== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
  - gate: test-memory: ran 1, passed 0, failed 1, hung 0, slow 0
- **Restore:** cmp ok
- **Clean rerun:** gate exit 0 test-memory: ran 1, passed 1, failed 0, hung 0, slow 0

### T4. The interposer says 1 whatever it sees

- **Guards:** test-wipe: control-unwiped reads 1
- **Mutation:** `tests/free-watch.c`: `verdict = nonzero ? 2 : 1;` read `verdict = 1;`
- **Result, test-wipe:** RED (exit 1)
  - FAIL row 24: every block call-with-block and call-with-bytes free reads all zeros at the free, after a return, a raise, an escape, odd sizes, an empty
- **Restore:** cmp ok
- **Clean rerun:** test-wipe exit 0 # of expected passes      1

### T5. The wipe child's LD_PRELOAD appended to, not set alone

- **Guards:** test-wipe: ld-preload row
- **Mutation:** `tests/test-wipe.sps`: `LD_PRELOAD=` set to the interposer and one more path
- **Result, test-wipe:** RED (exit 1)
  - FAIL row 24: every block call-with-block and call-with-bytes free reads all zeros at the free, after a return, a raise, an escape, odd sizes, an empty
- **Restore:** cmp ok
- **Clean rerun:** test-wipe exit 0 # of expected passes      1

### W6. The wipe over a dead block (S0-F1 placement), with the free's own wipe kept: plain run, then the gate

- **Guards:** the gate alone: "Invalid write of size 1" (a plain run exits 0); E8 is satisfied, since the free still takes sodium-memzero
- **Mutation:** `src/chez-sodium/private/native.sls`: `call-with-block`'s after thunk calls `(sodium-memzero made size)` before `(free-foreign-block! made sodium-memzero)`: the dead block of D2 and D3 is written
- **Result, test-native:** GREEN (survived) (exit 0)
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Result, gate test-native:** RED (exit 2)
  - gate: ==847== Invalid write of size 1
  - gate: ==847== ERROR SUMMARY: 6 errors from 3 contexts (suppressed: 0 from 0)
  - gate: test-memory: ran 1, passed 0, failed 1, hung 0, slow 0
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      63; test-wipe exit 0 # of expected passes      1; gate exit 0 test-memory: ran 1, passed 1, failed 0, hung 0, slow 0

### T2b. The oracle run outside the gate: the failing row, read from the gate's log

- **Guards:** A7b
- **Mutation:** `tests/libsodium-oracle.sls`: as T2, run once by hand with the log kept.
- **Result, gate test-native:** RED. `build/memory/test-native.log` held exactly one failing row:
  "FAIL the C oracle ran under Valgrind exactly when the gate asked".
- **Restore:** `cmp` ok.
- **Clean rerun:** gate pass, test-native 8 s.

### Review fixes (S2-F1 to S2-F6)

New rows: test-native E11 (one plain import of memory), E12 (inner dynamic-wind takes #t), D4
(call-with-block asked for (greatest-fixnum) bytes: handler at depth 1, counts zero);
test-wipe's dead-block row (S2-F3); test-blocks W9 (a wipe that frees its own block).
Red first for W9: on the old order the suite died with "free(): double free detected in tcache 2",
exit 134, before `memory.sls` was changed.

S2-F4 (B5): a plain run catches an unwritten empty-bytevector byte through B5 itself. Under the
gate B5 is skipped (Valgrind never reuses a block), and Valgrind's "Conditional jump or move
depends on uninitialised value(s)" catches a read of the unwritten byte. The one-byte block's
wipe is held in every run by test-wipe's `empty-bytes-dirtied` and `return-1` rows. (Comment
added at B5; no mutant.)

### R1. The reviewer's renamed second import of memory (S2-F1)

- **Guards:** E11
- **Mutation:** `src/chez-sodium/private/native.sls`: a second import `(rename (only (chez-sodium private memory) foreign-block free-foreign-block!) (foreign-block raw-block) (free-foreign-block! raw-free))`
- **Result, test-native:** RED (exit 1)
  - FAIL E11 native imports (chez-sodium private memory) exactly once, as the plain import set, with no only, rename, prefix, except or for around it, and
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      66; test-wipe exit 0 # of expected passes      2

### R2. A plain second import of memory

- **Guards:** E11
- **Mutation:** `src/chez-sodium/private/native.sls`: `(chez-sodium private memory)` imported twice
- **Result, test-native:** RED (exit 1)
  - FAIL E11 native imports (chez-sodium private memory) exactly once, as the plain import set, with no only, rename, prefix, except or for around it, and
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      66; test-wipe exit 0 # of expected passes      2

### R3. The only sole import of memory narrowed (only ...)

- **Guards:** E11
- **Mutation:** `src/chez-sodium/private/native.sls`: the one import wrapped in `only`
- **Result, test-native:** RED (exit 1)
  - FAIL E11 native imports (chez-sodium private memory) exactly once, as the plain import set, with no only, rename, prefix, except or for around it, and
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      66; test-wipe exit 0 # of expected passes      2

### D1. call-with-block's make guard removed (S2-F2)

- **Guards:** D4 (handler depth 2, not 1)
- **Mutation:** `src/chez-sodium/private/native.sls`: `foreign-block` called without the catch-all guard in the before thunk
- **Result, test-native:** RED (exit 1)
  - FAIL D4 call-with-block asked for (greatest-fixnum) bytes raises foreign-alloc's refusal after its critical before thunk: a handler of it runs at dept
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      66; test-wipe exit 0 # of expected passes      2

### D2. call-with-block's inner dynamic-wind made plain (S2-F2)

- **Guards:** E12
- **Mutation:** `src/chez-sodium/private/native.sls`: `(dynamic-wind #t` read `(dynamic-wind`
- **Result, test-native:** RED (exit 1)
  - FAIL E12 call-with-block's definition holds two dynamic-wind forms: the outer plain, the inner with #t as its first argument
- **Result, test-wipe:** GREEN (survived) (exit 0)
- **Restore:** cmp ok
- **Clean rerun:** test-native exit 0 # of expected passes      66; test-wipe exit 0 # of expected passes      2

### P1. S0-F1 mutant, plain run: a wipe over a dead block, the free keeping sodium-memzero (S2-F3)

- **Guards:** test-wipe dead-block row
- **Mutation:** `src/chez-sodium/private/native.sls`: `(sodium-memzero made size)` before the free, in the after thunk
- **Result, test-wipe:** RED (exit 1)
  - FAIL row 24: a block PROC freed itself is dead, and is never written: the next block of its size, the same chunk, still holds what PROC left in bytes 
  - FAIL row 24: every block call-with-block and call-with-bytes free reads all zeros at the free, after a return, a raise, an escape, odd sizes, an empty
- **Result, test-native:** RED (exit 134)
  - tail: %%%% Starting test native
  - tail: malloc(): unaligned tcache chunk detected
- **Restore:** cmp ok
- **Clean rerun:** test-wipe exit 0 # of expected passes      2; test-native exit 0 # of expected passes      66

### F6. The table entry deleted after the wipe, as before (S2-F6)

- **Guards:** W9 (the suite dies: glibc aborts on the double free, exit 134)
- **Mutation:** `src/chez-sodium/private/memory.sls`: the order of `hashtable-delete!` and the wipe restored
- **Result, test-blocks:** RED (exit 134)
  - tail: %%%% Starting test blocks
  - tail: free(): double free detected in tcache 2
- **Restore:** cmp ok
- **Clean rerun:** test-blocks exit 0 # of expected passes      19

## The seam

Each mutant is one exact replacement in tests/check-seam.sps (the Makefile for P1, P2, H1 to H4), run against tests/test-check-seam.sps on a stub src/ (build/slice2-seam/src), then restored with a cmp check. Clean rerun for every one: after restore, 91 passes and 0 failures, and `make check-seam` passes. "Guards" are the rows that went red; every other row stayed green. Rows that read the real src/ (the allowed-chez-names exactness row) passed on the stub tree and on the real tree after the load builder landed.

### C1 shape
- Guards: second-library: every library form in a file is checked, the second in; chez-whole: (chezscheme) imported whole; scheme-alias: (scheme), the alias, imported whole; chez-wrapped: (chezscheme) under except, prefix, rename, for, library,; export-wrapped-chez: rule (g) and a wrapper over (only (chezscheme) ..; lock-regular: a .# regular file is no lock file: it is read and checke; lock-directory: a .# directory is no lock file: it is walked; (chezscheme) imported whole is refused in the first, the middle and th; every library this Chez has that the import allowlist does not allow i
- Mutation: `    (cond       ((not names) ` -> `    (cond       ((not names) '())       (#f `
- Result: 9 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### C4 alias
- Guards: scheme-alias: (scheme), the alias, imported whole; chez-wrapped: (chezscheme) under except, prefix, rename, for, library,; every library this Chez has that the import allowlist does not allow i
- Mutation: `(define chez-names '((chezscheme) (scheme)))` -> `(define chez-names '((chezscheme)))`
- Result: 3 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### C2 not-listed
- Guards: name-import-only: a name outside allowed-chez-names: import-only, whic; name-top-level-value: a name outside allowed-chez-names: top-level-val; name-primitive: a name outside allowed-chez-names: $primitive, which r; names-several: allowed and refused names mixed, including format, whic; names-denylisted: the names the old denylist held are outside the allo; names-refused, real table: define-ftype, lock-object, foreign-callable; names-refused, variant table: the same names stay refused when every l; ftype-with-unlisted: rule (f) and rule (c) in one import set, each nam; every name (chezscheme) exports that allowed-chez-names does not list ; a name outside the list is refused at every position of an only list
- Mutation: `((not (memq id allowed-chez-names))` -> `(#f`
- Result: 10 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### C3 non-symbol
- Guards: names-not-symbols: an only over (chezscheme) with a name that is no id
- Mutation: `((not (for-all symbol? names))` -> `(#f`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### C5 rnrs-eval
- Guards: rnrs-eval: (rnrs eval), plain and wrapped; every library this Chez has that the import allowlist does not allow i
- Mutation: `(define eval-libraries '((rnrs eval)))` -> `(define eval-libraries '())`
- Result: 2 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### D-1 boundary
- Guards: outside-family: rule (d), eight libraries that are not (chez-sodium) n; outside-imports: a library outside the family that imports a private o
- Mutation: `(if (or (public-name? name) (private-name? name))          '()` -> `(if #t          '()`
- Result: 2 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### D-2 private-name? cddr
- Guards: outside-family: rule (d), eight libraries that are not (chez-sodium) n
- Mutation: `(pair? (cdr name)) (pair? (cddr name))        (eq?` -> `(pair? (cdr name))        (eq?`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### D-3 private-name? private
- Guards: outside-family: rule (d), eight libraries that are not (chez-sodium) n
- Mutation: `(eq? (cadr name) 'private)))` -> `#t))`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### E2 rnrs list
- Guards: legal: the public library and private ones, wrappers over (rnrs ...) a; rnrs-libraries is the (rnrs ...) libraries this Chez has, but (rnrs ev; the (rnrs ...) libraries the allowlist allows are all accepted, in one
- Mutation: `(rnrs sorting) ` -> ``
- Result: 3 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### F1 library-only clause
- Guards: names-several: allowed and refused names mixed, including format, whic; ftype-with-unlisted: rule (f) and rule (c) in one import set, each nam; each library-only name is refused in every library but the one listed 
- Mutation: `((and only (not (member name (cdr only))))` -> `(#f`
- Result: 3 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### F2 drop foreign-alloc entry
- Guards: ftype-with-unlisted: rule (f) and rule (c) in one import set, each nam; library-only-chez-names, written out whole: foreign-alloc and foreign-; each library-only name is refused in every library but the one listed 
- Mutation: `'((foreign-alloc (chez-sodium private memory))     (foreign-free` -> `'((foreign-free`
- Result: 3 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### F3 foreign-free to native
- Guards: memory-native-listed: rule (f) passing: memory imports foreign-alloc a; no library under src/ imports a library-only name that its entry does ; library-only-chez-names, written out whole: foreign-alloc and foreign-; each library-only name is refused in every library but the one listed ; each name allowed, in the library that may import it, refuses a re-exp
- Mutation: `(foreign-free (chez-sodium private memory))` -> `(foreign-free (chez-sodium private native))`
- Result: 5 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### F4 add foreign-sizeof entry
- Guards: library-only-chez-names, written out whole: foreign-alloc and foreign-
- Mutation: `(display-condition (chez-sodium private native))))` -> `(display-condition (chez-sodium private native))     (foreign-sizeof (chez-sodium private native))))`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### A1 allowed + foreign-sizeof
- Guards: allowed-chez-names is exactly the names the libraries under src/ impor; allowed-chez-names, written out whole; every name (chezscheme) exports that allowed-chez-names does not list 
- Mutation: `scheme-version scheme-version-number threaded? with-mutex))` -> `scheme-version scheme-version-number threaded? with-mutex foreign-sizeof))`
- Result: 3 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### A2 allowed - with-mutex
- Guards: legal: the public library and private ones, wrappers over (rnrs ...) a; memory-native-listed: rule (f) passing: memory imports foreign-alloc a; export-chez: rule (g): a name imported from (chezscheme) exported, pla; allowed-chez-names is exactly the names the libraries under src/ impor; allowed-chez-names, written out whole; every name allowed-chez-names lists that no library-only entry keeps p; a name outside the list is refused at every position of an only list; each name allowed, in the library that may import it, refuses a re-exp
- Mutation: `scheme-version scheme-version-number threaded? with-mutex))` -> `scheme-version scheme-version-number threaded?))`
- Result: 8 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### A3 allowed + get-thread-id
- Guards: allowed-chez-names is exactly the names the libraries under src/ impor; allowed-chez-names, written out whole; every name (chezscheme) exports that allowed-chez-names does not list 
- Mutation: `scheme-version scheme-version-number threaded? with-mutex))` -> `scheme-version scheme-version-number threaded? with-mutex get-thread-id))`
- Result: 3 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### G1 drop chez clause
- Guards: export-chez: rule (g): a name imported from (chezscheme) exported, pla; a name imported from (chezscheme) is refused at every position of the ; each name allowed, in the library that may import it, refuses a re-exp
- Mutation: `((memq (car pair) chez)` -> `(#f`
- Result: 3 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### G2 external not internal
- Guards: export-chez: rule (g): a name imported from (chezscheme) exported, pla; each name allowed, in the library that may import it, refuses a re-exp
- Mutation: `((memq (car pair) chez)` -> `((memq (cdr pair) chez)`
- Result: 2 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### G3 export-pairs never #f
- Guards: export-unreadable: rule (g) fails closed: each export spec that is nei
- Mutation: `    (else #f)))  ;; syntax-names` -> `    (else '())))  ;; syntax-names`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### G4 rename arity
- Guards: export-unreadable: rule (g) fails closed: each export spec that is nei
- Mutation: `(and (list? pair) (= (length pair) 2)                           (symbol? (car pair)) (symbol? (cadr pair))))                    (cdr spec)))      (map` -> `(and (list? pair) (>= (length pair) 2)                           (symbol? (car pair)) (symbol? (cadr pair))))                    (cdr spec)))      (ma`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### H1 undefined
- Guards: import-undefined: a family import, through prefix, and one in the publ; outside-imports: a library outside the family that imports a private o; memory-undefined: rule (m) and rule (h) both name a library that impor; memory not defined: a plain import binds nothing, so only rule (h) nam
- Mutation: `(if (member imported defined)` -> `(if #t`
- Result: 4 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### I1 placement off
- Guards: second-library: every library form in a file is checked, the second in; off-path: rule (i), a second library in a file, which an import elsewh; lock-symlink-live: a .# symbolic link that resolves to a library is no
- Mutation: `(placement-complaints path (filter library-form? (cadr found)) root)` -> `'()`
- Result: 3 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### I2 drop >1
- Guards: second-library: every library form in a file is checked, the second in; off-path: rule (i), a second library in a file, which an import elsewh
- Mutation: `(if (> (length libraries) 1)` -> `(if #f`
- Result: 2 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### I3 drop path compare
- Guards: second-library: every library form in a file is checked, the second in; off-path: rule (i), a second library in a file, which an import elsewh; lock-symlink-live: a .# symbolic link that resolves to a library is no
- Mutation: `(if (string=? path want)` -> `(if #t`
- Result: 3 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### K1 macro clause
- Guards: macro-export: rule (k): a library that imports library-only names expo
- Mutation: `((and (memq (car pair) macros) (pair? guarded))` -> `(#f`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### K2 no begin recursion
- Guards: macro-export: rule (k): a library that imports library-only names expo
- Mutation: `((and (list? form) (pair? form) (eq? (car form) 'begin))` -> `((and (list? form) (pair? form) #f)`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### K3 no guarded test
- Guards: macro-internal: rule (k) passing: an internal macro, a let-syntax, nev
- Mutation: `((and (memq (car pair) macros) (pair? guarded))` -> `((memq (car pair) macros)`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### U1 unread clause
- Guards: unread-ss: a .ss file, which Chez loads as a library and the program d; unread-so: a lone .so, with no source beside it, whatever it holds; unread-extensions: every unread ending, each named for its longest: .s
- Mutation: `((unread-ending (car names))` -> `(#f`
- Result: 3 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### U2 unread-extensions
- Guards: unread-extensions: every unread ending, each named for its longest: .s
- Mutation: `(remp (lambda (ext) (string=? ext ".sls"))` -> `(remp (lambda (ext) (or (string=? ext ".sls") (string=? ext ".chezscheme.so")))`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### S1 link clause
- Guards: dir-symlink: a symbolic link to a directory, which the program does no
- Mutation: `(loop (cdr names) files (cons path links) unread))` -> `(loop (cdr names) files links unread))`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### L1 lock never
- Guards: lock-symlink: a .# dangling symbolic link, which is Emacs's lock file,
- Mutation: `(and (prefix? name ".#")` -> `(and #f (prefix? name ".#")`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### L2 lock every .#
- Guards: lock-regular: a .# regular file is no lock file: it is read and checke; lock-directory: a .# directory is no lock file: it is walked; lock-symlink-live: a .# symbolic link that resolves to a library is no
- Mutation: `(file-symbolic-link? path)        (not (file-exists? path))))` -> `#t))`
- Result: 3 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### L3 lock no exists test
- Guards: lock-symlink-live: a .# symbolic link that resolves to a library is no
- Mutation: `(not (file-exists? path))))` -> `#t))`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### L4 lock dot prefix
- Guards: dangling-dot-link: a dangling symbolic link named with a dot but not .
- Mutation: `(and (prefix? name ".#")` -> `(and (prefix? name ".")`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### L5 lock contains
- Guards: dangling-hash-link: a dangling symbolic link with .# inside its name, 
- Mutation: `(and (prefix? name ".#")` -> `(and (let loop ((i 0)) (and (<= (+ i 2) (string-length name)) (or (string=? (substring name i (+ i 2)) ".#") (loop (+ i 1)))))`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### Z1 no-datum
- Guards: no-datum: a file that holds no datum
- Mutation: `(if (null? data)` -> `(if #f`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### Z2 library-form? any list
- Guards: not-a-library: a datum that is no library form, the first or a later o
- Mutation: `(define (library-form? datum)   (and (list? datum)        (>= (length datum) 4)` -> `(define (library-form? datum)   (list? datum)) (define (library-form-orig? datum)   (and (list? datum)        (>= (length datum) 4)`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### Z3 no eof check
- Guards: eof-literal: a file with an #!eof literal, which would end the reading
- Mutation: `((port-eof? port) (list 'data (reverse found)))` -> `(#t (list 'data (reverse found)))`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### Z4 no guard in read-data
- Guards: dangling-link: a dangling symbolic link not named .# is no lock file: ; dangling-dot-link: a dangling symbolic link named with a dot but not .; dangling-hash-link: a dangling symbolic link with .# inside its name, ; unreadable: a file that cannot be read as data; eof-literal: a file with an #!eof literal, which would end the reading
- Mutation: `(guard (e (#t (list 'unreadable (describe e))))     (call-with-port` -> `(begin     (call-with-port`
- Result: 5 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### Z5 no depth guard
- Guards: cannot-read-import: an import it cannot read: a number, an empty list,
- Mutation: `    ((or (not (list? spec)) (null? spec) (> depth max-depth)) #f)     ((eq? (car spec) 'library)      (and (= (length spec) 2) (reference-name (cadr s` -> `    ((or (not (list? spec)) (null? spec)) #f)     ((eq? (car spec) 'library)      (and (= (length spec) 2) (reference-name (cadr spec))))`
- Result: 1 row(s) red, killed (the program loops on the cyclic import; the harness did not time out the suite, I killed the child after 12 minutes; make test`s timeout would end it as HUNG)
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### Z6 no-files
- Guards: an empty directory holds no library; a directory that does not exist holds no library
- Mutation: `(if (null? files)` -> `(if #f`
- Result: 2 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### Z7 usage
- Guards: no directory named: the usage line, exit 1; two directories named: the usage line, exit 1
- Mutation: `(if (not (= (length args) 1))` -> `(if #f`
- Result: 2 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### R-L rule (l) back
- Guards: cannot-read-import: an import it cannot read: a number, an empty list,; every name (chezscheme) exports that allowed-chez-names does not list 
- Mutation: `(export-complaints path name form memory-exports))))` -> `(export-complaints path name form memory-exports)      (if (member 'utf8->string (apply append (map cdr (cdr (cadddr form)))))          (list (string-`
- Result: 2 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M1-off
- Guards: memory-import: rule (m): the public library and a private one for each; memory-undefined: rule (m) and rule (h) both name a library that impor; memory import it cannot read: an only list with a name that is no iden
- Mutation: `(append (if (equal? imported memory-library)` -> `(append (if #f`
- Result: 3 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M1-prefix (string)
- Guards: memory-import: rule (m): the public library and a private one for each
- Mutation: `(append (if (equal? imported memory-library)` -> `(append (if (and (= (length imported) 3) (prefix? (symbol->string (caddr imported)) "memory"))`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M1-listprefix
- Guards: memory-import: rule (m): the public library and a private one for each
- Mutation: `(append (if (equal? imported memory-library)` -> `(append (if (and (>= (length imported) 3) (equal? (list (car imported) (cadr imported) (caddr imported)) memory-library))`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M1-all
- Guards: memory-import: rule (m): the public library and a private one for each; memory-native-ok: rule (m) passing: native imports memory plain and ex; memory-own-name: rule (m) passing: native imports only free-foreign-bl; memory-undefined: rule (m) and rule (h) both name a library that impor; memory-reexport: rule (m): native exports a name it imports from memor; memory re-export, only: a name an only import set binds is refused; memory re-export, only: a name the only list leaves out is not named; memory re-export, except: a name the import set keeps is refused; memory re-export, except: the name it leaves out is not named; memory re-export, prefix: the prefixed name is refused; memory re-export, prefix: the unprefixed name is not the one bound; memory re-export, rename: the new local name is refused; memory re-export, rename: the old name is not the one bound; memory re-export, rename: a name the rename leaves alone is still boun; memory re-export, for: a name an import set bound for a phase is refus; memory re-export, library: a name a (library ...) import set binds is ; memory re-export, nested: a prefix under an only is read through; memory re-export, version reference: the reference's version is droppe; memory re-export: the external name memory exports is the one bound, n; memory re-export: the export is named at every position of the export ; memory import it cannot read: an only list with a name that is no iden; memory not defined: a plain import binds nothing, so only rule (h) nam; memory-importers, written out whole: native alone
- Mutation: `(define memory-importers '((chez-sodium private native)))` -> `(define memory-importers '())`
- Result: 23 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M1-wide
- Guards: memory-import: rule (m): the public library and a private one for each; memory-undefined: rule (m) and rule (h) both name a library that impor; memory-importers, written out whole: native alone
- Mutation: `(define memory-importers '((chez-sodium private native)))` -> `(define memory-importers '((chez-sodium private native) (chez-sodium)))`
- Result: 3 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M2-off
- Guards: memory-reexport: rule (m): native exports a name it imports from memor; memory re-export, only: a name an only import set binds is refused; memory re-export, except: a name the import set keeps is refused; memory re-export, prefix: the prefixed name is refused; memory re-export, rename: the new local name is refused; memory re-export, rename: a name the rename leaves alone is still boun; memory re-export, for: a name an import set bound for a phase is refus; memory re-export, library: a name a (library ...) import set binds is ; memory re-export, nested: a prefix under an only is read through; memory re-export, version reference: the reference's version is droppe; memory re-export: the external name memory exports is the one bound, n; memory re-export: the export is named at every position of the export 
- Mutation: `((memq (car pair) from-memory)` -> `(#f`
- Result: 12 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M2-internal
- Guards: memory-reexport: rule (m): native exports a name it imports from memor
- Mutation: `((memq (car pair) from-memory)` -> `((memq (cdr pair) from-memory)`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M2-only
- Guards: memory-own-name: rule (m) passing: native imports only free-foreign-bl; memory re-export, only: a name the only list leaves out is not named; memory import it cannot read: an only list with a name that is no iden
- Mutation: `((only) (and (for-all symbol? args) args))` -> `((only) inner)`
- Result: 3 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M2-except
- Guards: memory re-export, except: the name it leaves out is not named
- Mutation: `((except) (and (for-all symbol? args)                              (remp (lambda (id) (memq id args)) inner)))` -> `((except) inner)`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M2-prefix
- Guards: memory re-export, prefix: the prefixed name is refused; memory re-export, prefix: the unprefixed name is not the one bound
- Mutation: `((prefix)                (and (= (length args) 1) (symbol? (car args))                     (map (lambda (id)                            (string->symbo` -> `((prefix) inner)`
- Result: 2 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M2-rename
- Guards: memory re-export, rename: the new local name is refused; memory re-export, rename: the old name is not the one bound
- Mutation: `(else                (and (for-all (lambda (pair)                                (and (list? pair) (= (length pair) 2)                                ` -> `(else inner)`
- Result: 2 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M2-library
- Guards: memory re-export, library: a name a (library ...) import set binds is 
- Mutation: `(and (= (length spec) 2) (reference-name (cadr spec)) exports))` -> `(and (= (length spec) 2) (reference-name (cadr spec)) '()))`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M2-for
- Guards: memory re-export, for: a name an import set bound for a phase is refus
- Mutation: `((for) inner)` -> `((for) '())`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M2-plain
- Guards: memory-reexport: rule (m): native exports a name it imports from memor; memory re-export, except: a name the import set keeps is refused; memory re-export, prefix: the prefixed name is refused; memory re-export, rename: the new local name is refused; memory re-export, rename: a name the rename leaves alone is still boun; memory re-export, for: a name an import set bound for a phase is refus; memory re-export, version reference: the reference's version is droppe; memory re-export: the external name memory exports is the one bound, n; memory re-export: the export is named at every position of the export 
- Mutation: `(else (and (reference-name spec) exports))))` -> `(else (and (reference-name spec) '()))))`
- Result: 9 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M2-external
- Guards: memory re-export: the external name memory exports is the one bound, n
- Mutation: `(map cdr (or (export-pairs spec) '()))` -> `(map car (or (export-pairs spec) '()))`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M2-fail-open
- Guards: memory import it cannot read: an only list with a name that is no iden
- Mutation: `(if (import-bound spec memory-exports 0)        '()        (list (cannot-read path name spec)))` -> `'()`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M2-no-memory-exports
- Guards: memory-reexport: rule (m): native exports a name it imports from memor; memory re-export, except: a name the import set keeps is refused; memory re-export, prefix: the prefixed name is refused; memory re-export, rename: the new local name is refused; memory re-export, rename: a name the rename leaves alone is still boun; memory re-export, for: a name an import set bound for a phase is refus; memory re-export, library: a name a (library ...) import set binds is ; memory re-export, version reference: the reference's version is droppe; memory re-export: the external name memory exports is the one bound, n; memory re-export: the export is named at every position of the export 
- Mutation: `(memory-exports (memory-exports-of files))` -> `(memory-exports '())`
- Result: 10 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M-order
- Guards: memory-undefined: rule (m) and rule (h) both name a library that impor
- Mutation: `(append (if (equal? imported memory-library)                    (memory-complaints path name spec memory-exports)                    '())             ` -> `(append (undefined-complaints path name imported defined)                (if (equal? imported memory-library)                    (memory-complaints pa`
- Result: 1 row(s) red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### E1 else branch (second run; the first replacement was a syntax error and proved nothing)
- Guards: outside-imports; unlisted-libraries; every library this Chez has that the import allowlist does not allow is refused
- Mutation: insert a clause `(#t (quote ()))` before the unlisted-library `else` of import-complaints
- Result: 3 rows red, killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### M2-first-only (second run; the first replacement raised on an empty export clause and proved nothing)
- Guards: memory-reexport; export-chez; export-unreadable; macro-export; a name imported from (chezscheme) is refused at every position of the export clause; each name allowed ... refuses a re-export; memory re-export: the export is named at every position of the export clause
- Mutation: export-complaints scans only the first export spec
- Result: 7 rows red, killed; the rows of rules (g) and (k) go red too because the scan is shared: the only (m)-specific row is the every-position row
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### P1 check-seam out of test prerequisites (Makefile)
- Guards: check-test-fails seam case
- Mutation: `test: deps check-help check-suites check-seam ...` without check-seam
- Result: case "seam" FAILED: make test exited 0 and its lines differ (got no check-seam line); killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### P2 recipe reads tests instead of src (Makefile)
- Guards: check-test-fails seam case (and the real `make check-seam`)
- Mutation: `--program tests/check-seam.sps src` -> `... tests`
- Result: check-seam names fixture trees under tests/ and exits 1; the seam case failed; killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### P3 rule (f) off in check-seam.sps
- Guards: check-test-fails seam case
- Mutation: `((and only (not (member name (cdr only))))` -> `(#f`
- Result: case "seam" FAILED: make test exited 0 (got "the seam holds (3 libraries in 3 files checked)"); killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### P4 foreign-alloc removed from allowed-chez-names
- Guards: check-test-fails seam case
- Mutation: drop `foreign-alloc` from allowed-chez-names
- Result: case "seam" FAILED: the line reads "allowed-chez-names ... does not list it", not the library-only line; killed
- Clean rerun: 91 pass, 0 fail; file restored (cmp identical)

### H1 build without ##
- Guards: check-help
- Mutation: `build: ## Load` -> `build: Load`: "make help does not list .PHONY target build"
- Result: make check-help exit 2 with that line; killed
- Clean rerun: make check-help exit 0; Makefile restored (cmp identical)

### H2 check-seam without ##
- Guards: check-help
- Mutation: `check-seam: ## Fail` -> `check-seam: # Fail`: "make help does not list .PHONY target check-seam"
- Result: make check-help exit 2 with that line; killed
- Clean rerun: make check-help exit 0; Makefile restored (cmp identical)

### H3 build out of .PHONY
- Guards: check-help
- Mutation: drop build from .PHONY: "make help lists build, which is not in .PHONY"
- Result: make check-help exit 2 with that line; killed
- Clean rerun: make check-help exit 0; Makefile restored (cmp identical)

### H4 check-seam out of .PHONY
- Guards: check-help
- Mutation: drop check-seam from .PHONY: "make help lists check-seam, which is not in .PHONY"
- Result: make check-help exit 2 with that line; killed
- Clean rerun: make check-help exit 0; Makefile restored (cmp identical)

### Survivors
None.

## The convention table

Mutants are one exact replacement, run in the container, then the file is restored and
compared with `cmp`-equivalent (byte-identical copy), then the suite is rerun clean. Suites that
read `src/` ran in `build/slice2-conv/sandbox/`, whose `src/` holds the stub `native.sls` (the real
`src/` has no `native.sls` until the join); its `tests/` is the real `tests/`.

### T2-swap-rows
- **Guards:** table names row, in order
- **Mutation:** `tests/foreign-conventions.sls`: swap the names of the major and minor rows (order of rows changes)
- **Result:** KILLED; 1 failing row(s): table: it has a row for each of the five entry points, in ADR-0002's order, and no other
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### T3-size_t-as-uptr-table
- **Guards:** written-out five rows (m1-five); the src and sweep rows (row/binding disagree) once native exists
- **Mutation:** `tests/foreign-conventions.sls`: replace '(uptr size_t) void plain\n' with '(uptr uptr) void plain\n'
- **Result:** KILLED; 12 failing row(s): table: the five rows are written out: the version string an address, major and minor and sodium_init an int, s; table: the types its rows use are exactly the allowlists': every type an argument or a non-void result is the ; table: the type only an argument uses is size_t, which the result allowlist refuses; src: no violation: each form is a literal binding held to its row, and each row has its form; fixture decoys: the word foreign-procedure in a comment, a string, #'foreign-procedure outside bind-required, ; fixture varargs-refused: sodium_memzero written with (__varargs_after 2) is no convention, and fails, by name,; fixture scheme-object-u8: a u8* argument, a Scheme object, fails, twice, by name: refused, and not the row's; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### T4-init-collect-safe-table
- **Guards:** all-plain row and m1-five
- **Mutation:** `tests/foreign-conventions.sls`: replace '("sodium_init" ("int" ()) () int plain' with '("sodium_init" ("int" ()) () int collect-safe'
- **Result:** KILLED; 19 failing row(s): table: every row is plain: no collect-safe call is bound yet (ADR-0001, decision 7); table: the five rows are written out: the version string an address, major and minor and sodium_init an int, s; src: no violation: each form is a literal binding held to its row, and each row has its form; fixture decoys: the word foreign-procedure in a comment, a string, #'foreign-procedure outside bind-required, ; fixture stray-syntax: a second (syntax foreign-procedure), in bind-required's fender, fails; the first, the im; fixture stray-other-macro: a (syntax foreign-procedure) in the fender of a macro that is not bind-required fai; fixture permitted: the import entry, bind-required's one fender mention and a form's head are all there is, an; fixture stray-optional-binder: a macro named bind-optional has no allowance: its one fender mention fails, tho; fixture safe-other: sodium_init bound __collect_safe, against its plain row, fails, by name; fixture outside: a form in another library fails, naming the file, the library and the entry; fixture outside-no-library: a form in a file that holds no library fails too; fixture bound-twice: a C name bound twice in one file fails, once, by name; fixture bound-twice-two-files: and bound once in each of two files fails the same; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### T5a-unsigned-64-in-row
- **Guards:** no row writes a type its allowlist refuses; m1-five
- **Mutation:** `tests/foreign-conventions.sls`: replace '(uptr size_t) void plain\n' with '(uptr unsigned-64) void plain\n'
- **Result:** KILLED; 13 failing row(s): table: the five rows are written out: the version string an address, major and minor and sodium_init an int, s; table: the types its rows use are exactly the allowlists': every type an argument or a non-void result is the ; table: the type only an argument uses is size_t, which the result allowlist refuses; table: no row writes a type its allowlist refuses; src: no violation: each form is a literal binding held to its row, and each row has its form; fixture decoys: the word foreign-procedure in a comment, a string, #'foreign-procedure outside bind-required, ; fixture varargs-refused: sodium_memzero written with (__varargs_after 2) is no convention, and fails, by name,; fixture scheme-object-u8: a u8* argument, a Scheme object, fails, twice, by name: refused, and not the row's; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### T5b-unsigned-64-in-row-and-allowlist
- **Guards:** written-out allowlists, exactly-the-types, m1-five (no-refused-type passes)
- **Mutation:** `tests/foreign-conventions.sls`: memzero row writes unsigned-64 and the argument allowlist gains it
- **Result:** KILLED; 15 failing row(s): table: the five rows are written out: the version string an address, major and minor and sodium_init an int, s; table: the allowlists are int, uptr and size_t as arguments, and int, uptr and void as results; table: the types its rows use are exactly the allowlists': every type an argument or a non-void result is the ; table: the type only an argument uses is size_t, which the result allowlist refuses; src: no violation: each form is a literal binding held to its row, and each row has its form; fixture decoys: the word foreign-procedure in a comment, a string, #'foreign-procedure outside bind-required, ; fixture varargs-refused: sodium_memzero written with (__varargs_after 2) is no convention, and fails, by name,; fixture scheme-object-u8: a u8* argument, a Scheme object, fails, twice, by name: refused, and not the row's; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; complement: none of the types is one the allowlist allows; complement: the fixture binds every type, each row says exactly what its binding says, and the allowlist refus
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### T6-size_t-result
- **Guards:** argument-only row and no-refused-type row
- **Mutation:** `tests/foreign-conventions.sls`: replace '("sodium_init" ("int" ()) () int plain' with '("sodium_init" ("int" ()) () size_t plain'
- **Result:** KILLED; 23 failing row(s): table: the five rows are written out: the version string an address, major and minor and sodium_init an int, s; table: the types its rows use are exactly the allowlists': every type an argument or a non-void result is the ; table: the type only an argument uses is size_t, which the result allowlist refuses; table: no row writes a type its allowlist refuses; src: no violation: each form is a literal binding held to its row, and each row has its form; fixture decoys: the word foreign-procedure in a comment, a string, #'foreign-procedure outside bind-required, ; fixture stray-syntax: a second (syntax foreign-procedure), in bind-required's fender, fails; the first, the im; fixture stray-other-macro: a (syntax foreign-procedure) in the fender of a macro that is not bind-required fai; fixture permitted: the import entry, bind-required's one fender mention and a form's head are all there is, an; fixture stray-optional-binder: a macro named bind-optional has no allowance: its one fender mention fails, tho; fixture plain-collect-safe-row: sodium_init bound plain, against a row that says collect-safe, fails, by name; fixture safe-other: sodium_init bound __collect_safe, against its plain row, fails, by name; fixture collect-safe-ok: sodium_init bound __collect_safe, against a row that says collect-safe, holds, so the; fixture outside: a form in another library fails, naming the file, the library and the entry; fixture outside-no-library: a form in a file that holds no library fails too; fixture bound-twice: a C name bound twice in one file fails, once, by name; fixture bound-twice-two-files: and bound once in each of two files fails the same; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### T7-cites-0011-not-0001
- **Guards:** cites ADR-0001 row (0011 exists, so a bare exists check passes)
- **Mutation:** `tests/foreign-conventions.sls`: replace '"ADR-0001 decision 7: plain"\n        "ADR-0002 decision 5, amended' with '"ADR-0011 decision 7: plain"\n        "ADR-0002 decision 5, amended'
- **Result:** KILLED; 1 failing row(s): table: every row cites ADR-0001 and ADR-0002, and every record cited is a decision record that exists
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### T8-cites-nonexistent
- **Guards:** cited records exist
- **Mutation:** `tests/foreign-conventions.sls`: replace '"ADR-0003 decision 2: the floor is read from it"' with '"ADR-9999 decision 2: the floor is read from it"'
- **Result:** KILLED; 1 failing row(s): table: every row cites ADR-0001 and ADR-0002, and every record cited is a decision record that exists
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### C1-collect-safe-twice
- **Guards:** written-out convention-forms row; convention-of rows
- **Mutation:** `tests/foreign-conventions.sls`: replace "'((plain) (collect-safe __collect_safe)))" with "'((plain) (collect-safe __collect_safe __collect_safe)))"
- **Result:** KILLED; 5 failing row(s): conventions: plain is nothing before the entry, and collect-safe is __collect_safe alone; conventions: convention-of reads nothing as plain, and __collect_safe alone as collect-safe; conventions: convention-of reads anything else as other, whole: __collect_safe twice, a convention unknown, an; fixture safe-other: sodium_init bound __collect_safe, against its plain row, fails, by name; fixture collect-safe-ok: sodium_init bound __collect_safe, against a row that says collect-safe, holds, so the
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### C2-variadic-back
- **Guards:** written-out convention-forms row; the other-list row
- **Mutation:** `tests/foreign-conventions.sls`: replace "'((plain) (collect-safe __collect_safe)))" with "'((plain) (collect-safe __collect_safe) (variadic (__varargs_after 2))))"
- **Result:** KILLED; 3 failing row(s): conventions: plain is nothing before the entry, and collect-safe is __collect_safe alone; conventions: convention-of reads anything else as other, whole: __collect_safe twice, a convention unknown, an; fixture varargs-refused: sodium_memzero written with (__varargs_after 2) is no convention, and fails, by name,
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### C3-other-read-as-collect-safe
- **Guards:** the other row (__collect_safe twice, beside a count)
- **Mutation:** `tests/foreign-conventions.sls`: replace '((equal? (cdar rest) conventions) (caar rest))' with "((equal? (cdar rest) (if (and (pair? conventions) (eq? (car conventions) '__collect_safe)) '(__collect_safe) conventions)) (caar rest))"
- **Result:** KILLED; 1 failing row(s): conventions: convention-of reads anything else as other, whole: __collect_safe twice, a convention unknown, an
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### T1-drop-row
- **Guards:** table names row; written-out five rows
- **Mutation:** `tests/foreign-conventions.sls`: delete the sodium_memzero row
- **Result:** KILLED; 15 failing row(s): table: it has a row for each of the five entry points, in ADR-0002's order, and no other; table: every row is plain: no collect-safe call is bound yet (ADR-0001, decision 7); table: the five rows are written out: the version string an address, major and minor and sodium_init an int, s; table: the types its rows use are exactly the allowlists': every type an argument or a non-void result is the ; table: the type only an argument uses is size_t, which the result allowlist refuses; src: no violation: each form is a literal binding held to its row, and each row has its form; fixture decoys: the word foreign-procedure in a comment, a string, #'foreign-procedure outside bind-required, ; fixture varargs-refused: sodium_memzero written with (__varargs_after 2) is no convention, and fails, by name,; fixture scheme-object-u8: a u8* argument, a Scheme object, fails, twice, by name: refused, and not the row's; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### S1-sixth-function
- **Guards:** src five-forms row and src no-violation (no-row randombytes_buf)
- **Mutation:** `build/slice2-conv/sandbox/src/chez-sodium/private/native.sls`: replace '(memzero (bind-required' with '(extra (bind-required chosen (foreign-procedure "randombytes_buf" (uptr size_t) void)))\n               (memzero (bind-required'
- **Result:** KILLED; 8 failing row(s): src: every foreign-procedure form under src/ is one of the five bindings of (chez-sodium private native), in i; src: no violation: each form is a literal binding held to its row, and each row has its form; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### S2-delete-init-form
- **Guards:** src five-forms row; no-form sodium_init
- **Mutation:** `build/slice2-conv/sandbox/src/chez-sodium/private/native.sls`: replace '(init (bind-required chosen (foreign-procedure "sodium_init" () int)))' with '(init 0)'
- **Result:** KILLED; 8 failing row(s): src: every foreign-procedure form under src/ is one of the five bindings of (chez-sodium private native), in i; src: no violation: each form is a literal binding held to its row, and each row has its form; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### S3-form-in-other-library
- **Guards:** src five-forms row (library) and no-violation (outside-native)
- **Mutation:** `build/slice2-conv/sandbox/src/chez-sodium/private/native.sls`: sodium_memzero form moved to (chez-sodium private other)
- **Result:** KILLED; 8 failing row(s): src: every foreign-procedure form under src/ is one of the five bindings of (chez-sodium private native), in i; src: no violation: each form is a literal binding held to its row, and each row has its form; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** the stub restored (byte-identical) and the extra `other.sls` removed; 51 passes, no failure (the in-harness rerun ran before `other.sls` was removed, so it showed rc 1 and is superseded).

### S4-init-twice
- **Guards:** src no-violation (bound-twice); five-forms row (once each)
- **Mutation:** `build/slice2-conv/sandbox/src/chez-sodium/private/native.sls`: replace '(memzero (bind-required' with '(init2 (bind-required chosen (foreign-procedure "sodium_init" () int)))\n               (memzero (bind-required'
- **Result:** KILLED; 8 failing row(s): src: every foreign-procedure form under src/ is one of the five bindings of (chez-sodium private native), in i; src: no violation: each form is a literal binding held to its row, and each row has its form; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### S5-u8
- **Guards:** src no-violation: type-refused argument 0 u8* and mismatch
- **Mutation:** `build/slice2-conv/sandbox/src/chez-sodium/private/native.sls`: replace '"sodium_memzero" (uptr size_t) void)' with '"sodium_memzero" (u8* size_t) void)'
- **Result:** KILLED; 7 failing row(s): src: no violation: each form is a literal binding held to its row, and each row has its form; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### S6-string-result
- **Guards:** src no-violation: type-refused result string and mismatch
- **Mutation:** `build/slice2-conv/sandbox/src/chez-sodium/private/native.sls`: replace '"sodium_version_string" () uptr)' with '"sodium_version_string" () string)'
- **Result:** KILLED; 7 failing row(s): src: no violation: each form is a literal binding held to its row, and each row has its form; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### S6b-utf-8-result
- **Guards:** src no-violation: type-refused result utf-8 and mismatch
- **Mutation:** `build/slice2-conv/sandbox/src/chez-sodium/private/native.sls`: replace '"sodium_version_string" () uptr)' with '"sodium_version_string" () utf-8)'
- **Result:** KILLED; 7 failing row(s): src: no violation: each form is a literal binding held to its row, and each row has its form; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### S7-memzero-size_t-as-uptr-in-binding
- **Guards:** src no-violation: mismatch arguments (uptr size_t) (uptr uptr) (the allowlists accept uptr, so only the row catches it)
- **Mutation:** `build/slice2-conv/sandbox/src/chez-sodium/private/native.sls`: replace '"sodium_memzero" (uptr size_t) void)' with '"sodium_memzero" (uptr uptr) void)'
- **Result:** KILLED; 7 failing row(s): src: no violation: each form is a literal binding held to its row, and each row has its form; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### S8-memzero-unsigned-64
- **Guards:** src no-violation: type-refused argument 1 unsigned-64 and mismatch
- **Mutation:** `build/slice2-conv/sandbox/src/chez-sodium/private/native.sls`: replace '"sodium_memzero" (uptr size_t) void)' with '"sodium_memzero" (uptr unsigned-64) void)'
- **Result:** KILLED; 7 failing row(s): src: no violation: each form is a literal binding held to its row, and each row has its form; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### S9-init-size_t-result
- **Guards:** src no-violation: type-refused result size_t and mismatch
- **Mutation:** `build/slice2-conv/sandbox/src/chez-sodium/private/native.sls`: replace '"sodium_init" () int)' with '"sodium_init" () size_t)'
- **Result:** KILLED; 7 failing row(s): src: no violation: each form is a literal binding held to its row, and each row has its form; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### S10-init-arity
- **Guards:** src no-violation: mismatch arguments () (int)
- **Mutation:** `build/slice2-conv/sandbox/src/chez-sodium/private/native.sls`: replace '"sodium_init" () int)' with '"sodium_init" (int) int)'
- **Result:** KILLED; 7 failing row(s): src: no violation: each form is a literal binding held to its row, and each row has its form; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### S11-memzero-returns-int
- **Guards:** src no-violation: mismatch result void int
- **Mutation:** `build/slice2-conv/sandbox/src/chez-sodium/private/native.sls`: replace '"sodium_memzero" (uptr size_t) void)' with '"sodium_memzero" (uptr size_t) int)'
- **Result:** KILLED; 7 failing row(s): src: no violation: each form is a literal binding held to its row, and each row has its form; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### S12-memzero-pointer-as-int
- **Guards:** src no-violation: mismatch arguments (uptr size_t) (int size_t)
- **Mutation:** `build/slice2-conv/sandbox/src/chez-sodium/private/native.sls`: replace '"sodium_memzero" (uptr size_t) void)' with '"sodium_memzero" (int size_t) void)'
- **Result:** KILLED; 7 failing row(s): src: no violation: each form is a literal binding held to its row, and each row has its form; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### S13-init-collect-safe
- **Guards:** src no-violation: mismatch convention plain collect-safe
- **Mutation:** `build/slice2-conv/sandbox/src/chez-sodium/private/native.sls`: replace '(foreign-procedure "sodium_init" () int)' with '(foreign-procedure __collect_safe "sodium_init" () int)'
- **Result:** KILLED; 7 failing row(s): src: no violation: each form is a literal binding held to its row, and each row has its form; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### S14-stray-alias
- **Guards:** src no-violation: stray-reference
- **Mutation:** `build/slice2-conv/sandbox/src/chez-sodium/private/native.sls`: replace '(define-syntax bind-required' with '(define-syntax fp (identifier-syntax foreign-procedure))\n  (define-syntax bind-required'
- **Result:** KILLED; 7 failing row(s): src: no violation: each form is a literal binding held to its row, and each row has its form; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### S15-second-fender-mention
- **Guards:** src no-violation: one stray-reference
- **Mutation:** `build/slice2-conv/sandbox/src/chez-sodium/private/native.sls`: replace "(free-identifier=? #'fp #'foreign-procedure)" with "(free-identifier=? #'fp #'foreign-procedure) (free-identifier=? #'fp #'foreign-procedure)"
- **Result:** KILLED; 7 failing row(s): src: no violation: each form is a literal binding held to its row, and each row has its form; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### S16-binder-renamed
- **Guards:** src no-violation: the fender mention is no longer allowed (stray-reference)
- **Mutation:** `build/slice2-conv/sandbox/src/chez-sodium/private/native.sls`: replace '(define-syntax bind-required' with '(define-syntax bind-requird'
- **Result:** KILLED; 7 failing row(s): src: no violation: each form is a literal binding held to its row, and each row has its form; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### R1-scan-strays-empty
- **Guards:** every stray-* fixture, decoys, stray-optional-binder and stray-optional-syntax: stray-reference lists
- **Mutation:** `tests/foreign-conventions.sls`: replace "(if data (stray-references file data) '())" with "'()"
- **Result:** KILLED; 8 failing row(s): fixture decoys: the word foreign-procedure in a comment, a string, #'foreign-procedure outside bind-required, ; fixture stray-alias: a keyword alias, (define-syntax fp (identifier-syntax foreign-procedure)), and a binding ; fixture stray-define: (define fp foreign-procedure) fails, by file; fixture stray-quoted: the symbol in a quoted list fails, by file; fixture stray-syntax: a second (syntax foreign-procedure), in bind-required's fender, fails; the first, the im; fixture stray-other-macro: a (syntax foreign-procedure) in the fender of a macro that is not bind-required fai; fixture stray-optional-binder: a macro named bind-optional has no allowance: its one fender mention fails, tho; fixture stray-optional-syntax: both of bind-optional's fender mentions fail, with no bind-required there to le
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### R2-foreign-forms-walks-tails
- **Guards:** decoys (extra forms found), permitted and stray-syntax (a (syntax foreign-procedure) read as a form)
- **Mutation:** `tests/foreign-conventions.sls`: replace '(loop (cdr rest) (append found (foreign-forms (car rest))))' with "(loop '() (append found (foreign-forms (car rest)) (foreign-forms (cdr rest))))"
- **Result:** KILLED; 32 failing row(s): src: every foreign-procedure form under src/ is one of the five bindings of (chez-sodium private native), in i; src: no violation: each form is a literal binding held to its row, and each row has its form; fixture decoys: the word foreign-procedure in a comment, a string, #'foreign-procedure outside bind-required, ; fixture stray-alias: a keyword alias, (define-syntax fp (identifier-syntax foreign-procedure)), and a binding ; fixture stray-define: (define fp foreign-procedure) fails, by file; fixture stray-quoted: the symbol in a quoted list fails, by file; fixture stray-syntax: a second (syntax foreign-procedure), in bind-required's fender, fails; the first, the im; fixture stray-other-macro: a (syntax foreign-procedure) in the fender of a macro that is not bind-required fai; fixture permitted: the import entry, bind-required's one fender mention and a form's head are all there is, an; fixture stray-optional-binder: a macro named bind-optional has no allowance: its one fender mention fails, tho; fixture stray-optional-syntax: both of bind-optional's fender mentions fail, with no bind-required there to le; fixture plain-collect-safe-row: sodium_init bound plain, against a row that says collect-safe, fails, by name; fixture safe-other: sodium_init bound __collect_safe, against its plain row, fails, by name; fixture collect-safe-ok: sodium_init bound __collect_safe, against a row that says collect-safe, holds, so the; fixture varargs-refused: sodium_memzero written with (__varargs_after 2) is no convention, and fails, by name,; fixture scheme-object-u8: a u8* argument, a Scheme object, fails, twice, by name: refused, and not the row's; fixture scheme-object-string: a string result, a Scheme object, fails, twice, by name; fixture scheme-object-utf8: a utf-8 result, a Scheme object, fails, twice, by name; fixture outside: a form in another library fails, naming the file, the library and the entry; fixture entry-not-literal: an entry that is a name, a call, a quoted symbol, a convention, or missing fails, n; fixture types-not-literal: an argument list that is a name, is improper, holds a number or is a vector, and a ; fixture no-row: a binding the table has no row for fails, by name; fixture bound-twice: a C name bound twice in one file fails, once, by name; fixture bound-twice-two-files: and bound once in each of two files fails the same; fixture positions: a refused type fails at each position: first, middle and last argument, the result, void as; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai; complement: the fixture binds every type, each row says exactly what its binding says, and the allowlist refus
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### R3-binders-optional-back
- **Guards:** stray-optional-binder and stray-optional-syntax
- **Mutation:** `tests/foreign-conventions.sls`: replace "(define binders '(bind-required))" with "(define binders '(bind-required bind-optional))"
- **Result:** KILLED; 2 failing row(s): fixture stray-optional-binder: a macro named bind-optional has no allowance: its one fender mention fails, tho; fixture stray-optional-syntax: both of bind-optional's fender mentions fail, with no bind-required there to le
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### R4-import-allowance-zero
- **Guards:** permitted (no violation), decoys, stray fixtures that count the import
- **Mutation:** `tests/foreign-conventions.sls`: import-allowance answers 0 for an import clause and for a library holding one
- **Result:** KILLED; 31 failing row(s): src: no violation: each form is a literal binding held to its row, and each row has its form; fixture decoys: the word foreign-procedure in a comment, a string, #'foreign-procedure outside bind-required, ; fixture stray-alias: a keyword alias, (define-syntax fp (identifier-syntax foreign-procedure)), and a binding ; fixture stray-define: (define fp foreign-procedure) fails, by file; fixture stray-quoted: the symbol in a quoted list fails, by file; fixture stray-syntax: a second (syntax foreign-procedure), in bind-required's fender, fails; the first, the im; fixture stray-other-macro: a (syntax foreign-procedure) in the fender of a macro that is not bind-required fai; fixture permitted: the import entry, bind-required's one fender mention and a form's head are all there is, an; fixture stray-optional-binder: a macro named bind-optional has no allowance: its one fender mention fails, tho; fixture stray-optional-syntax: both of bind-optional's fender mentions fail, with no bind-required there to le; fixture plain-collect-safe-row: sodium_init bound plain, against a row that says collect-safe, fails, by name; fixture safe-other: sodium_init bound __collect_safe, against its plain row, fails, by name; fixture collect-safe-ok: sodium_init bound __collect_safe, against a row that says collect-safe, holds, so the; fixture varargs-refused: sodium_memzero written with (__varargs_after 2) is no convention, and fails, by name,; fixture scheme-object-u8: a u8* argument, a Scheme object, fails, twice, by name: refused, and not the row's; fixture scheme-object-string: a string result, a Scheme object, fails, twice, by name; fixture scheme-object-utf8: a utf-8 result, a Scheme object, fails, twice, by name; fixture outside: a form in another library fails, naming the file, the library and the entry; fixture entry-not-literal: an entry that is a name, a call, a quoted symbol, a convention, or missing fails, n; fixture types-not-literal: an argument list that is a name, is improper, holds a number or is a vector, and a ; fixture no-row: a binding the table has no row for fails, by name; fixture bound-twice: a C name bound twice in one file fails, once, by name; fixture bound-twice-two-files: and bound once in each of two files fails the same; fixture positions: a refused type fails at each position: first, middle and last argument, the result, void as; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai; complement: the fixture binds every type, each row says exactly what its binding says, and the allowlist refus
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### R5-fender-allowance-zero
- **Guards:** permitted, stray-syntax, stray-optional-binder, decoys
- **Mutation:** `tests/foreign-conventions.sls`: fender-allowance answers 0 even for a binder with a fender mention
- **Result:** KILLED; 10 failing row(s): src: no violation: each form is a literal binding held to its row, and each row has its form; fixture stray-syntax: a second (syntax foreign-procedure), in bind-required's fender, fails; the first, the im; fixture permitted: the import entry, bind-required's one fender mention and a form's head are all there is, an; fixture stray-optional-binder: a macro named bind-optional has no allowance: its one fender mention fails, tho; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### R6-form-parts-from-the-front
- **Guards:** decoys, entry-not-literal, every src and fixture row with a convention
- **Mutation:** `tests/foreign-conventions.sls`: replace '(list (reverse (cdddr r)) (caddr r) (cadr r) (car r))' with "(list '() (car rest) (cadr rest) (caddr rest))"
- **Result:** KILLED; 3 failing row(s): fixture safe-other: sodium_init bound __collect_safe, against its plain row, fails, by name; fixture collect-safe-ok: sodium_init bound __collect_safe, against a row that says collect-safe, holds, so the; fixture varargs-refused: sodium_memzero written with (__varargs_after 2) is no convention, and fails, by name,
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### R7-native-library-wrong
- **Guards:** the src rows, decoys and every fixture that binds in native
- **Mutation:** `tests/foreign-conventions.sls`: replace "(define native-library '(chez-sodium private native))" with "(define native-library '(chez-sodium private nativ))"
- **Result:** KILLED; 27 failing row(s): src: no violation: each form is a literal binding held to its row, and each row has its form; fixture decoys: the word foreign-procedure in a comment, a string, #'foreign-procedure outside bind-required, ; fixture stray-syntax: a second (syntax foreign-procedure), in bind-required's fender, fails; the first, the im; fixture stray-other-macro: a (syntax foreign-procedure) in the fender of a macro that is not bind-required fai; fixture permitted: the import entry, bind-required's one fender mention and a form's head are all there is, an; fixture stray-optional-binder: a macro named bind-optional has no allowance: its one fender mention fails, tho; fixture stray-optional-syntax: both of bind-optional's fender mentions fail, with no bind-required there to le; fixture plain-collect-safe-row: sodium_init bound plain, against a row that says collect-safe, fails, by name; fixture safe-other: sodium_init bound __collect_safe, against its plain row, fails, by name; fixture collect-safe-ok: sodium_init bound __collect_safe, against a row that says collect-safe, holds, so the; fixture varargs-refused: sodium_memzero written with (__varargs_after 2) is no convention, and fails, by name,; fixture scheme-object-u8: a u8* argument, a Scheme object, fails, twice, by name: refused, and not the row's; fixture scheme-object-string: a string result, a Scheme object, fails, twice, by name; fixture scheme-object-utf8: a utf-8 result, a Scheme object, fails, twice, by name; fixture entry-not-literal: an entry that is a name, a call, a quoted symbol, a convention, or missing fails, n; fixture types-not-literal: an argument list that is a name, is improper, holds a number or is a vector, and a ; fixture no-row: a binding the table has no row for fails, by name; fixture bound-twice: a C name bound twice in one file fails, once, by name; fixture bound-twice-two-files: and bound once in each of two files fails the same; fixture positions: a refused type fails at each position: first, middle and last argument, the result, void as; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai; complement: the fixture binds every type, each row says exactly what its binding says, and the allowlist refus
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### R8-literal-type-always-true
- **Guards:** types-not-literal fixture
- **Mutation:** `tests/foreign-conventions.sls`: replace '(define (literal-type? x) (or (symbol? x) (list? x)))' with '(define (literal-type? x) #t)'
- **Result:** KILLED; 1 failing row(s): fixture types-not-literal: an argument list that is a name, is improper, holds a number or is a vector, and a 
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### R9-refused-types-empty
- **Guards:** positions and types fixtures, the scheme-object fixtures, complement fixture
- **Mutation:** `tests/foreign-conventions.sls`: refused-types answers the empty list
- **Result:** KILLED; 5 failing row(s): fixture scheme-object-u8: a u8* argument, a Scheme object, fails, twice, by name: refused, and not the row's; fixture scheme-object-string: a string result, a Scheme object, fails, twice, by name; fixture scheme-object-utf8: a utf-8 result, a Scheme object, fails, twice, by name; fixture positions: a refused type fails at each position: first, middle and last argument, the result, void as; complement: the fixture binds every type, each row says exactly what its binding says, and the allowlist refus
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### R10-allowlist-loosened-integer-64
- **Guards:** written-out allowlists row, exactly-the-types row, complement none-allowed row and types fixture
- **Mutation:** `tests/foreign-conventions.sls`: replace "(define allowed-argument-types '(int uptr size_t))" with "(define allowed-argument-types '(int uptr size_t integer-64))"
- **Result:** KILLED; 4 failing row(s): table: the allowlists are int, uptr and size_t as arguments, and int, uptr and void as results; table: the types its rows use are exactly the allowlists': every type an argument or a non-void result is the ; complement: none of the types is one the allowlist allows; complement: the fixture binds every type, each row says exactly what its binding says, and the allowlist refus
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### R11-collect-safe-read-as-plain
- **Guards:** the convention-of read row, safe-other and collect-safe-ok fixtures, and the flip sweep
- **Mutation:** `tests/foreign-conventions.sls`: replace '((equal? (cdar rest) conventions) (caar rest))' with "((equal? (cdar rest) conventions) 'plain)"
- **Result:** KILLED; 3 failing row(s): conventions: convention-of reads nothing as plain, and __collect_safe alone as collect-safe; fixture safe-other: sodium_init bound __collect_safe, against its plain row, fails, by name; fixture collect-safe-ok: sodium_init bound __collect_safe, against a row that says collect-safe, holds, so the
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### X1-result-check-dropped
- **Guards:** the result sweep, S-mutants for results (alone: row and binding disagree on a result)
- **Mutation:** `tests/foreign-conventions.sls`: replace '(if (equal? result (row-result row))' with '(if #t'
- **Result:** KILLED; 3 failing row(s): fixture scheme-object-string: a string result, a Scheme object, fails, twice, by name; fixture scheme-object-utf8: a utf-8 result, a Scheme object, fails, twice, by name; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### X2-arguments-check-dropped
- **Guards:** the argument sweep and the size_t sweep
- **Mutation:** `tests/foreign-conventions.sls`: replace '(if (equal? arguments (row-arguments row))' with '(if #t'
- **Result:** KILLED; 3 failing row(s): fixture scheme-object-u8: a u8* argument, a Scheme object, fails, twice, by name: refused, and not the row's; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### X3-convention-check-dropped
- **Guards:** the flip sweep, safe-other, plain-collect-safe-row, varargs-refused
- **Mutation:** `tests/foreign-conventions.sls`: replace '(if (equal? (convention-of conventions) (row-convention row))' with '(if #t'
- **Result:** KILLED; 4 failing row(s): fixture plain-collect-safe-row: sodium_init bound plain, against a row that says collect-safe, fails, by name; fixture safe-other: sodium_init bound __collect_safe, against its plain row, fails, by name; fixture varargs-refused: sodium_memzero written with (__varargs_after 2) is no convention, and fails, by name,; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### K1-size_t-allowed-as-result
- **Guards:** written-out allowlists, exactly-the-types, complement: fx_result_only_0 accepted instead of refused
- **Mutation:** `tests/foreign-conventions.sls`: replace "(define allowed-result-types '(int uptr void))" with "(define allowed-result-types '(int uptr void size_t))"
- **Result:** KILLED; 4 failing row(s): table: the allowlists are int, uptr and size_t as arguments, and int, uptr and void as results; table: the types its rows use are exactly the allowlists': every type an argument or a non-void result is the ; table: the type only an argument uses is size_t, which the result allowlist refuses; complement: the fixture binds every type, each row says exactly what its binding says, and the allowlist refus
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### K2-unsigned-64-allowed-as-argument
- **Guards:** written-out allowlists, exactly-the-types, complement none-allowed row and types fixture
- **Mutation:** `tests/foreign-conventions.sls`: replace "(define allowed-argument-types '(int uptr size_t))" with "(define allowed-argument-types '(int uptr size_t unsigned-64))"
- **Result:** KILLED; 4 failing row(s): table: the allowlists are int, uptr and size_t as arguments, and int, uptr and void as results; table: the types its rows use are exactly the allowlists': every type an argument or a non-void result is the ; complement: none of the types is one the allowlist allows; complement: the fixture binds every type, each row says exactly what its binding says, and the allowlist refus
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### K5-size_t-dropped-from-argument-allowlist
- **Guards:** written-out allowlists, exactly-the-types, no-refused-type row, src rows
- **Mutation:** `tests/foreign-conventions.sls`: replace "(define allowed-argument-types '(int uptr size_t))" with "(define allowed-argument-types '(int uptr))"
- **Result:** KILLED; 15 failing row(s): table: the allowlists are int, uptr and size_t as arguments, and int, uptr and void as results; table: the types its rows use are exactly the allowlists': every type an argument or a non-void result is the ; table: no row writes a type its allowlist refuses; src: no violation: each form is a literal binding held to its row, and each row has its form; fixture decoys: the word foreign-procedure in a comment, a string, #'foreign-procedure outside bind-required, ; fixture varargs-refused: sodium_memzero written with (__varargs_after 2) is no convention, and fails, by name,; fixture scheme-object-u8: a u8* argument, a Scheme object, fails, twice, by name: refused, and not the row's; fixture no-row: a binding the table has no row for fails, by name; fixture positions: a refused type fails at each position: first, middle and last argument, the result, void as; sweep: a row removed fails, by name, for each of the five rows; sweep: a row with no form fails, by name; sweep: a row's convention flipped fails, by name, for each of the five rows: plain to collect-safe; sweep: a row's result type changed fails, by name, for each of the five rows: int to uptr, and uptr and void t; sweep: a row's argument type changed at each position fails, by name, for each of the two arguments; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### K4-type-dropped-from-types-fixture
- **Guards:** complement fixture row (the list is short by two)
- **Mutation:** `tests/fixtures/conventions/types/chez-sodium/private/native.sls`: the a0 and r0 bindings (integer-8) deleted from the types fixture
- **Result:** KILLED; 1 failing row(s): complement: the fixture binds every type, each row says exactly what its binding says, and the allowlist refus
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      51, FAIL rows 0

### F4-size_t-as-uptr-in-table-and-binding
- **Guards:** m1-five (the written-out rows) alone: the table and the stub binding agree, so the src rows and the allowlists pass (flag F4); the header map in test-constants is the other guard
- **Mutation:** `tests/foreign-conventions.sls`: replace '(uptr size_t) void plain\n' with '(uptr uptr) void plain\n'
- **Result:** KILLED; 7 failing row(s): table: the five rows are written out: the version string an address, major and minor and sodium_init an int, s; table: the types its rows use are exactly the allowlists': every type an argument or a non-void result is the ; table: the type only an argument uses is size_t, which the result allowlist refuses; fixture decoys: the word foreign-procedure in a comment, a string, #'foreign-procedure outside bind-required, ; fixture varargs-refused: sodium_memzero written with (__varargs_after 2) is no convention, and fails, by name,; fixture scheme-object-u8: a u8* argument, a Scheme object, fails, twice, by name: refused, and not the row's; sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, agai
- **Clean rerun:** table restored byte-identical, and the stub (also mutated, memzero bound `(uptr uptr)`) restored byte-identical; 51 passes, no failure. (The in-harness rerun ran with the stub still mutated, so it showed rc 1.) The src rows and the allowlist rows stayed green, as flag F4 says: only the written-out rows and the sweep catch a size_t loosened in table and binding together.

### E1-size_t-mapped-to-uptr
- **Guards:** the map unit row, result-type row, and the map check of the real table
- **Mutation:** `tests/test-constants.sps`: replace '((string=? plain "size_t") \'size_t)' with '((string=? plain "size_t") \'uptr)'
- **Result:** KILLED; 7 failing row(s): prototypes: each row's Chez types are the map of its C types, the rows that are not each by name; map: int, size_t and unsigned long long are int, size_t and unsigned-64; any pointer is uptr; a top-level qual; result-type: void for "void" alone, and chez-type's answer for every other C type of the map's list; the map check names a size_t written uptr, unsigned-64 or int, and a pointer written int, each by name; the map check names a result written wrong, each by name: sodium_init as uptr, void or size_t, sodium_version_; the map check maps a void result to void and nothing else to it: sodium_memzero written void is no problem, an; the map check passes each row written right: the five rows, and sodium_memzero in its qualifier-free spelling
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      20, FAIL rows 0

### E2-size_t-unmapped
- **Guards:** the map unit row, result-type row, and the map check of the real table
- **Mutation:** `tests/test-constants.sps`: replace '((string=? plain "size_t") \'size_t)' with '((string=? plain "size_t") #f)'
- **Result:** KILLED; 7 failing row(s): prototypes: each row's Chez types are the map of its C types, the rows that are not each by name; map: int, size_t and unsigned long long are int, size_t and unsigned-64; any pointer is uptr; a top-level qual; result-type: void for "void" alone, and chez-type's answer for every other C type of the map's list; the map check names a size_t written uptr, unsigned-64 or int, and a pointer written int, each by name; the map check names a result written wrong, each by name: sodium_init as uptr, void or size_t, sodium_version_; the map check maps a void result to void and nothing else to it: sodium_memzero written void is no problem, an; the map check passes each row written right: the five rows, and sodium_memzero in its qualifier-free spelling
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      20, FAIL rows 0

### E3-ull-mapped-to-uptr
- **Guards:** the map unit rows
- **Mutation:** `tests/test-constants.sps`: replace '((string=? plain "unsigned long long") \'unsigned-64)' with '((string=? plain "unsigned long long") \'uptr)'
- **Result:** KILLED; 2 failing row(s): map: int, size_t and unsigned long long are int, size_t and unsigned-64; any pointer is uptr; a top-level qual; result-type: void for "void" alone, and chez-type's answer for every other C type of the map's list
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      20, FAIL rows 0

### E4-ull-dropped
- **Guards:** the map unit rows
- **Mutation:** `tests/test-constants.sps`: replace '((string=? plain "unsigned long long") \'unsigned-64)' with '(#f #f)'
- **Result:** KILLED; 2 failing row(s): map: int, size_t and unsigned long long are int, size_t and unsigned-64; any pointer is uptr; a top-level qual; result-type: void for "void" alone, and chez-type's answer for every other C type of the map's list
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      20, FAIL rows 0

### E5-qualifier-strip-removed
- **Guards:** the map unit rows (qualified scalars, void *const) and the map check of the real table (memzero is spelled with qualifiers)
- **Mutation:** `tests/test-constants.sps`: replace '(filter (lambda (w) (not (member w \'("const" "volatile" "restrict"))))' with '(filter (lambda (w) #t)'
- **Result:** KILLED; 7 failing row(s): prototypes: each row's Chez types are the map of its C types, the rows that are not each by name; map: int, size_t and unsigned long long are int, size_t and unsigned-64; any pointer is uptr; a top-level qual; result-type: void for "void" alone, and chez-type's answer for every other C type of the map's list; the map check names a size_t written uptr, unsigned-64 or int, and a pointer written int, each by name; the map check names a result written wrong, each by name: sodium_init as uptr, void or size_t, sodium_version_; the map check maps a void result to void and nothing else to it: sodium_memzero written void is no problem, an; the map check passes each row written right: the five rows, and sodium_memzero in its qualifier-free spelling
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      20, FAIL rows 0

### E6-qualifier-strip-by-substring
- **Guards:** the map unit row: "constint" must stay unmapped, not become int
- **Mutation:** `tests/test-constants.sps`: every substring const removed from the type text, not the whole word
- **Result:** KILLED; 2 failing row(s): map: int, size_t and unsigned long long are int, size_t and unsigned-64; any pointer is uptr; a top-level qual; result-type: void for "void" alone, and chez-type's answer for every other C type of the map's list
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      20, FAIL rows 0

### E7-pointer-test-wrong
- **Guards:** the pointer rows of the map and the real table
- **Mutation:** `tests/test-constants.sps`: replace '(string=? (car (reverse words)) "*")' with '(string=? (car words) "const")'
- **Result:** KILLED; 8 failing row(s): prototypes: each row's Chez types are the map of its C types, the rows that are not each by name; map: int, size_t and unsigned long long are int, size_t and unsigned-64; any pointer is uptr; a top-level qual; result-type: void for "void" alone, and chez-type's answer for every other C type of the map's list; map: void as an argument is unmapped, and a pointer to void is uptr, never void; the map check names a size_t written uptr, unsigned-64 or int, and a pointer written int, each by name; the map check names a result written wrong, each by name: sodium_init as uptr, void or size_t, sodium_version_; the map check maps a void result to void and nothing else to it: sodium_memzero written void is no problem, an; the map check passes each row written right: the five rows, and sodium_memzero in its qualifier-free spelling
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      20, FAIL rows 0

### E8-generic-default-prints-1
- **Guards:** every plant row (the wrong rows answer 1)
- **Mutation:** `tests/test-constants.sps`: replace 'default: 0))' with 'default: 1))'
- **Result:** KILLED; 1 failing row(s): the prototype check refuses each kind of wrong row, by name: a dropped pointee const, an extra and a missing p
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      20, FAIL rows 0

### E9-function-type-empty-parameters-written-()
- **Guards:** the header row: int (*)() is an unprototyped type, not int (*)(void)
- **Mutation:** `tests/test-constants.sps`: replace '(if (null? (cadr proto))\n                       "void"' with '(if (null? (cadr proto))\n                       ""'
- **Result:** SURVIVED; 0 failing row(s): none
- **Why it survives:** `int (*)()` and `int (*)(void)` are compatible types in C, and `_Generic` answers 1 for both, so how `function-type` spells an empty parameter list is not observable by any row. The `(void)` spelling is kept for compilers that read `()` as unprototyped in other contexts. No row can kill it; recorded, not fixed.
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      20, FAIL rows 0

### E10-compile-status-ignored
- **Guards:** the missing-function row: the compile step must be the named failure
- **Mutation:** `tests/test-constants.sps`: replace '(if (not (= (car compiled) 0))' with '(if #f'
- **Result:** KILLED; 1 failing row(s): the prototype check fails the compile, by step, for a function the header lacks
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      20, FAIL rows 0

### E11-answer-loosened
- **Guards:** the answer? row
- **Mutation:** `tests/test-constants.sps`: replace "(memv (caddr d) '(0 1)) #t))))" with '(integer? (caddr d)) #t))))'
- **Result:** KILLED; 1 failing row(s): answer?: a version string, and a prototype's 0 or 1, are answers; a number for the version, a 2, a name that i
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      20, FAIL rows 0

### E12-map-problems-result-unchecked
- **Guards:** the result plant rows of the map check
- **Mutation:** `tests/test-constants.sps`: replace '(eq? result (row-result row)))\n                       #f' with '#t)\n                       #f'
- **Result:** KILLED; 2 failing row(s): the map check names a result written wrong, each by name: sodium_init as uptr, void or size_t, sodium_version_; the map check maps a void result to void and nothing else to it: sodium_memzero written void is no problem, an
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      20, FAIL rows 0

### E13-map-problems-arguments-unchecked
- **Guards:** the argument plant rows of the map check
- **Mutation:** `tests/test-constants.sps`: replace '(if (and (equal? arguments (row-arguments row))' with '(if (and #t'
- **Result:** KILLED; 2 failing row(s): the map check names a size_t written uptr, unsigned-64 or int, and a pointer written int, each by name; the map check names a void argument, which maps to nothing, and a prototype that ends "...", since nothing her
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      20, FAIL rows 0

### E14-void-result-unmapped
- **Guards:** result-type row, the real table map check, void plant rows
- **Mutation:** `tests/test-constants.sps`: replace '(if (string=? c-type "void") \'void (chez-type c-type))' with '(chez-type c-type)'
- **Result:** KILLED; 7 failing row(s): prototypes: each row's Chez types are the map of its C types, the rows that are not each by name; result-type: void for "void" alone, and chez-type's answer for every other C type of the map's list; the map check names a size_t written uptr, unsigned-64 or int, and a pointer written int, each by name; the map check names a result written wrong, each by name: sodium_init as uptr, void or size_t, sodium_version_; the map check names a void argument, which maps to nothing, and a prototype that ends "...", since nothing her; the map check maps a void result to void and nothing else to it: sodium_memzero written void is no problem, an; the map check passes each row written right: the five rows, and sodium_memzero in its qualifier-free spelling
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      20, FAIL rows 0

### E15-unsigned-long-mapped-to-size_t
- **Guards:** the unsigned long limit row and the map unit rows
- **Mutation:** `tests/test-constants.sps`: replace '((string=? plain "size_t") \'size_t)' with '((member plain (quote ("size_t" "unsigned long"))) \'size_t)'
- **Result:** KILLED; 3 failing row(s): map: int, size_t and unsigned long long are int, size_t and unsigned-64; any pointer is uptr; a top-level qual; result-type: void for "void" alone, and chez-type's answer for every other C type of the map's list; the limit: sodium_memzero written with unsigned long is answered 1 by the header, since size_t is that type he
- **Clean rerun:** restored (cmp identical); rc 0, # of expected passes      20, FAIL rows 0

### Mutants with no row to kill them

- **No `-I` flag (F10):** the compile gets no `-I`; a flag added quietly finds the same header, so no row can fail. Held by the source: `header-facts` passes `-o PROGRAM SOURCE` after `$CC` and nothing else.
- **The program needs no library (F9):** `c-program` calls no libsodium function; adding a call would fail the link in the container only if a `-l` flag were absent, and the header-facts compile has none, so a call fails the compile row by status. Not planted separately: the E10 row shows a compile failure is named.
- **Table rows against `src/` after the join:** every `src/` row was exercised here only against the stub in `build/slice2-conv/sandbox/src/`, never against the load builder's real `native.sls`.
