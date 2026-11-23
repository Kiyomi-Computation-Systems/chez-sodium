# Slice 4: the public library. Trim tables, design note, rows and mutants, flags

Sources: chez-sqlite3 v0.1.1 (`960d9f0`): `src/chez-sqlite3.sls`, `tests/test-public.sps`,
`tests/test-never-loads.sps`. Targets: `src/chez-sodium.sls`, `tests/test-public.sps`,
`tests/test-never-loads.sps`, and one comment in `tests/check-nothreads.sps`. No code was
written; probes are under `build/slice4-public/` (section 5).

**Rules the copy keeps** (the "checked against" column below cites them by tag):

- **K1** `(chez-sodium)` defines nothing; each export is `eq?` to its private definition
  (ADR-0012, decision 1).
- **K2** Exports are predicates and accessors, never a `&` name or a constructor; in M1 exactly
  the eight names of ADR-0012, decision 2.
- **K3** Every export has a Typed Racket style signature comment (AGENTS.md; global constraints).
- **K4** `require-threaded` is the first import (ADR-0004; `test-require-threaded` holds it).
- **K5** check-seam: no `(chezscheme)` import, so nothing to re-export from it (rules c, f, g);
  imports only `(chez-sodium ...)` libraries (e); the file is at its name's path, one library
  (i); no import of `memory` (m).
- **K6** The condition exports load no libsodium (never-loads).
- **K7** No verb holds state between calls: no handles (ADR-0005).
- **K8** `sodium-version` holds no section, makes no block, calls no C, and answers a fresh
  string (ADR-0007, decision 8).
- **K9** Every engine row references the library once before its first engine, and runs at each
  fuel from 1 until it completes (ADR-0007; global constraints).
- **K10** Tests assert reasons, who and irritants, whole outputs, never messages; no secret in a
  test name; no `#f` expected from something that can raise; `let*` where order matters.

## 1. Trim table: `src/chez-sqlite3.sls` to `src/chez-sodium.sls`

Whole file shape kept: `#!r6rs`, a header comment, one `(library NAME (export ...) (import
...))` form with no body, no `(rnrs)` import, exports grouped under `;; ---` banners, each export
preceded by a `;; name : Type` comment, imports as `(only (private-lib) names ...)`.

| # | Piece | Kept / changed / dropped | What changes, or what a drop protected and why nothing here needs it |
|---|---|---|---|
| S1 | Library name `(chez-sqlite3)` | changed | `(chez-sodium)`. |
| S2 | Header comment | changed | Rewritten short, for a developer (AGENTS.md: no milestone, slice or date; a bare ADR-NNNN may point). Keep the three ideas: it defines nothing, every name is re-exported from the library that defines it (ADR-0012); so a reference runs that library alone and a condition predicate or accessor loads no libsodium, which is how a program tests for `&sodium-library-unavailable` around an `eval` of the first name that loads; every name that reaches libsodium runs the load at its first reference, once per process (ADR-0002). Re-pointed: v0.1.1's ADR-0009 is ours ADR-0012; its ADR-0013 is ours ADR-0006. |
| S3 | Header paragraphs on connections, statements, transactions, settings, extensions, `interrupt-database!` (v0.1.1 ADR-0010, 0012, 0014 to 0021) | dropped (D1) | Protected: the thread-ownership, close, statement-cache and transaction rules for a stateful handle. No handle exists here (K7, ADR-0005); the stateless rules that remain are ADR-0007's, held by `call-in-section`'s and native's own suites. Checked against K1 to K10: no kept rule mentions a handle. |
| S4 | Export group "connections" (`open-database`, `close-database!`, `call-with-database`, `database?`, `interrupt-database!`) | dropped (D2) | Protected: handle lifetime. No handles (K7). Nothing else protects it; nothing needs to. K2 lists the eight names: these are not among them. |
| S5 | "extensions" (`load-extension!`) | dropped (D3) | Protected: loading SQLite extensions by absolute path. libsodium has none; no entry in brief §3's subset. K2. |
| S6 | "the conveniences" (`execute!` ... `query-fold`) | dropped (D4) | Protected: statements finished on every path. No statements. K7. |
| S7 | "the counters" (`changes`, `total-changes`, `last-insert-rowid`, `in-transaction?`) | dropped (D5) | SQLite's connection counters. Nothing here counts anything a caller reads; the block counts are private (`counters`, test-only). K2. |
| S8 | "transactions" (`with-transaction`, `sqlite-transaction-ended?`) | dropped (D6) | Protected: transaction nesting. None exists. K7. |
| S9 | "statements" (9 names) | dropped (D7) | Protected: prepared-statement lifecycle. None. K7. |
| S10 | "values" (`bind!` ... `sql-null?`) | dropped (D8) | Protected: SQL value mapping. None. K2. |
| S11 | "the library" group | changed | One name kept, `sodium-version : -> String`, imported `(only (chez-sodium private native) sodium-version)`. v0.1.1 imported it from `report`; there is no `report` library: native holds it (plan §2.1, §4.2 item 4; ADR-0012). The banner says `(chez-sodium private native)`. |
| S12 | `sqlite-version-number`, `sqlite-source-id`, `sqlite-library-path`, `sqlite-library-source`, `sqlite-compile-option?`, `sqlite-compile-options` | dropped (D9) | Protected: a caller's way to learn which library loaded and how it was built. Here brief §4 gives `sodium-version` alone; path and source are on the refusal's accessors and in native's private `loaded-libsodium` (read by `make build`); libsodium has no version number, source id or compile options (plan §2.1). Adding any would break K2's whole list (ADR-0012 decision 2; test-public's whole-exports row would fail). |
| S13 | `chez-sqlite3-error?` | changed | `chez-sodium-error? : Any -> Boolean`, from `(chez-sodium private conditions)`. |
| S14 | `sqlite-error?` and its five accessors (`-code`, `-extended-code`, `-message`, `-sql`, `-offset`) | dropped (D10) | Protected: catching a SQLite result by type and reading it. `&sodium-failed` replaces the idea, but nothing raises it in M1; its names join in M3 with the first raise (ADR-0012 decision 2, ADR-0006 amended). An export now would be a predicate that never answers `#t`. K2 forbids it. |
| S15 | `sqlite-library-unavailable?` and `-reason`, `-path`, `-source`, `-detail`, `-candidates` | changed | Renamed `sodium-library-unavailable...`. Types: `Any -> Boolean`; `SodiumLibraryUnavailable -> Symbol` (one of `invalid-override not-found load-failed below-floor missing-api init-failed`); `-> (U String #f)`; `-> (U Symbol #f)`; `-> Any`; `-> (Listof String)`. Order as ADR-0012. |
| S16 | `sqlite-wrong-thread?` and its two accessors; `sqlite-closed?`, `sqlite-busy?`, `sqlite-constraint?`, `sqlite-read-only?`, `sqlite-interrupt?` | dropped (D11) | Protected: catching these SQLite conditions. They do not exist in ADR-0006's tree (two leaves). K2. |
| S17 | `sqlite-invalid-text?` (+2), `sqlite-setting-mismatch?` (+3), `sqlite-extensions-unavailable?` | dropped (D12) | Same. |
| S18 | The ten `(only (chez-sqlite3 private X) ...)` imports for the dropped names | dropped (D13) | They import what D2 to D12 export. Without them K5 (e, h) has fewer libraries to check, nothing less. |
| S19 | `(import (chez-sqlite3 private require-threaded) ...)` first | kept | Renamed; stays first (K4). `test-require-threaded` names it on a miss (measured, section 5). |
| S20 | Imports of `native` and `conditions` | changed | Two imports: `(only (chez-sodium private native) sodium-version)` and `(only (chez-sodium private conditions) chez-sodium-error? sodium-library-unavailable? sodium-library-unavailable-reason ... -candidates)`. No other. Never `memory` (m); no `(chezscheme)`, no `(rnrs)` (the body is empty, so there is nothing to bind syntax for; v0.1.1 imported neither). |
| S21 | Empty body | kept | K1. Held by test-public's no-body row (a body is invisible to the child, section 5, mutant P4). |

Export order and banners (build exactly): `;; --- the library (chez-sodium private native) ---`
`sodium-version`; `;; --- conditions (chez-sodium private conditions) ---` the seven, in
ADR-0012's order.

Signature comments (K3), written above each name in the export clause:

```
;; sodium-version : -> String
;; chez-sodium-error? : Any -> Boolean
;; sodium-library-unavailable? : Any -> Boolean
;; sodium-library-unavailable-reason : SodiumLibraryUnavailable -> Symbol
;;   Symbol = (U 'invalid-override 'not-found 'load-failed 'below-floor 'missing-api 'init-failed)
;; sodium-library-unavailable-path : SodiumLibraryUnavailable -> (U String #f)
;; sodium-library-unavailable-source : SodiumLibraryUnavailable -> (U Symbol #f)
;; sodium-library-unavailable-detail : SodiumLibraryUnavailable -> Any
;; sodium-library-unavailable-candidates : SodiumLibraryUnavailable -> (Listof String)
```

## 2. Trim table: `tests/test-public.sps`

| # | Piece | Kept / changed / dropped | Detail |
|---|---|---|---|
| T1 | Header comment | changed | Rewritten: the exports whole; the re-exports; `sodium-version` against `loaded-libsodium`, fresh; the engine sweep. Drops the report/compile-option paragraphs. ADR numbers: ADR-0012 (re-exports), ADR-0006 (conditions), ADR-0007 (engines). |
| T2 | Imports | changed | Keep `(rnrs)`, `(rnrs eval)`, `(rnrs mutable-strings)` (the scribble row's `string-fill!`), `(srfi :64)`, `(chez-sodium-testing)`, `(chez-sodium private counters)`; `(only (chezscheme) library-exports make-engine)`. Dropped (D14): `(rnrs mutable-pairs)` (`set-car!` in the compile-options row), `disable-interrupts enable-interrupts` (the depth rows, D22), `(chez-sqlite3 private libsqlite3-info)` (a record that does not exist; native answers an alist). No import of `(chez-sodium)`, `native` or `memory`: they are reached by `eval` only (the suite is allowed to load libsodium, but a refused load must fail rows by name, not kill the suite before its first line). |
| T3 | Runner and failure printer | kept | Verbatim. |
| T4 | `public-load` | changed | `(eval '(sodium-version) (environment '(chez-sodium)))` under `guard`, `'loaded` or `(raised TEXT)`. It is also the **reference before the first engine** (K9) and it makes the `environment` call that loads the library: Chez's `library-exports` raises "library (chez-sodium) is not loaded" otherwise (measured; trap for the builder). Keep it textually before every `library-exports` and engine row. |
| T5 | `reach`, `public` | kept | Renamed. |
| T6 | Top-level bindings of the report procedures | changed | `sodium-version` from `(public 'sodium-version)`; `loaded-libsodium` from `(reach '(chez-sodium private native) 'loaded-libsodium)`. Dropped (D15): `sqlite3-compileoption-get`, `sqlite3-compileoption-used`, `c-string->string`, `call-with-c-string` (no compile options; `c-string->string` is test-native's). |
| T7 | `zero-counts` | changed | `'((block . 0))`: `native-kinds` is `(block)` only. Used by the engine row (the "leaves no live block" clause of K9). |
| T8 | `sorted-names`, `attempt` | kept | `attempt` is used by the version rows and the engine row. |
| T9 | `yes-no` | dropped (D16) | Protected: `sqlite-compile-option?`'s boolean answers. No boolean-returning verb is in M1; the `eq?` rows build `'same`/`'different` themselves. |
| T10 | `public-names` table | changed | Eight rows: `(sodium-version chez-sodium private native)` and the seven condition names with `(chez-sodium private conditions)`. The 62 other rows go with D2 to D12. |
| T11 | Row "(chez-sqlite3) loads, reached through eval" | kept | Renamed. |
| T12 | Row "exports 70 names, counted from the library itself" | dropped (D17) | Protected: an expected list with a duplicated or mistyped name. The next row compares the sorted expected list with the sorted `library-exports`, both ways, so any extra, missing or duplicated name is a mismatch; the count adds nothing and would hard-code a number the builder must keep in step. Checked against K2: the whole-list row holds it. |
| T13 | Row "exports exactly ..." | changed | Expected: `(sorted-names (map car public-names))` against `(sorted-names (library-exports '(chez-sodium)))`, under `guard`. Row text names the groups (the version, the conditions' predicates and accessors). |
| T14 | Six rows holding `connection`, `open`, `conveniences`, `extension`, `transaction`, `report` to their exact exports | dropped (D18) | Protected: that each private library exports its public names plus named internals and nothing a consumer could take raw. Here the two private libraries the public one imports have their own whole-export rows: `test-conditions` (`conditions`) and `test-native` (`native`, which also holds that neither `foreign-block` nor `free-foreign-block!` is exported). The other part, that each private library really exports the name the public one re-exports, is the `eq?` row (an absent name raises inside `eval`, so the row fails by name). Checked against K1, K2, K5: nothing is left unheld. |
| T15 | `public-source` / `public-data` / the "one library form, no body" row | kept | Path `src/chez-sodium.sls`; reads with Chez's `read`; expected `(one-form (chez-sodium) export import no-body)`. This row is **the only holder of K1's "no body"** (mutant P4). |
| T16 | Row "each public name is the procedure its private library defines, eq?" | kept | One row, eight names, `(eval name (environment '(chez-sodium)))` against `(eval name (environment PRIVATE))`, each under its own guard; expected `((NAME same) ...)`. |
| T17 | `info`, "the report, whole" row | changed | Expected `(cdr (assq 'version (loaded-libsodium)))` computed under a guard with sentinel `(no-report TEXT)`; actual `(attempt sodium-version)`. The path/source/number/source-id parts are dropped with D9. |
| T18 | "the report's version is a string, its number a natural, its source a symbol" | dropped (D19) | Protected: the answer types. The string's type is fixed by the whole-equality row (equal to native's recorded string), and native's string is held to the C oracle by `test-native`. The number and source answers do not exist (D9). |
| T19 | `scribbled` and the row "each string the report answers is a fresh copy" | changed | One function, `sodium-version`, not three. Keep `string-fill!` on the first answer then compare the second. **Add** a row beside it: `(eq? (sodium-version) (sodium-version))` mapped to `'same`/`'fresh`, expected `'fresh`. The plan's "a fresh string each call" is two rows, since the scribble row alone passes a version that returns `eq?` strings only if the fill reaches the second answer, and the `eq?` row names the fault directly. |
| T20 | `raw-options`, "native lists compile options", "compile-options is native's list", "fresh list of fresh strings", `option-name`, `names-to-ask`, "compile-option? answers as native's does", "says yes for every listed name", "refuses what is no string" | dropped (D20) | Protected: the compile-option verbs' answers, freshness and refusals (by who and irritants). No such verb. The analogue for a verb with arguments is row 15 of the brief, built with each verb in M2 and M3. `sodium-version` takes no argument, so it has no refusal to hold; an arity mistake is Chez's, not ours (K10: nothing of ours to assert). |
| T21 | `interrupt-depth`, `handler-depth`, "raises its refusals outside any critical section: a handler runs at depth 1" | dropped (D21) | Protected: no raise inside a critical section (reaches a handler with interrupts disabled). `sodium-version` raises nothing and holds no section (K8). The same property of `call-in-section` is held by `test-native` (row 17's helper half). |
| T22 | `run-engine`, `fuels` | changed | `run-engine` kept verbatim (THUNK, FUEL, CAP; `(answer expired)` or `(unfinished CAP)`). `fuels` replaced by a loop (section 3.2). |
| T23 | `first-option`, `options-under-engine`, and the long comment on the engine row about the C string's block and a critical section | dropped (D22) | Protected: an expiry freeing a C string's block mid-call. `sodium-version` has no block and no section (K8), so the paragraph would be false here. Replaced by section 3.2's comment, which says what the row can and cannot see. |
| T24 | The engine row (fuels 1 to 40, then fuel 1 must expire) | changed | Section 3.2. The fixed 40 and the fuel-1 expiry assertion go (K9: "from 1 until it completes"; plan §6: "never an expiry"). See flag F4. |
| T25 | Row "every count is zero at the end" | dropped (D23) | Protected: no native object left. `suite-exit-status` (the last line) fails any suite whose `native-counts` are not all zero, and the engine row's expected value carries `zero-counts`. Checked against K9 ("leaves no live block"): held. |
| T26 | `(test-end "public")` and the exit line | kept | `(exit (suite-exit-status runner))` last; `check-suites` reads it. |

## 3. Design note

### 3.1 `(chez-sodium)`'s exports

Exactly ADR-0012 decision 2, eight names, each a re-export `eq?` to its private definition:

| Public name | Defined in |
|---|---|
| `sodium-version` | `(chez-sodium private native)` |
| `chez-sodium-error?` | `(chez-sodium private conditions)` |
| `sodium-library-unavailable?` | `conditions` |
| `sodium-library-unavailable-reason`, `-path`, `-source`, `-detail`, `-candidates` | `conditions` |

It defines nothing and has no body. Not exported (each a test-public mutant): `sodium-failed?`,
`sodium-failed-function`, `sodium-failed-code` (M3), any `&` name, any `make-` constructor,
`loaded-libsodium`, `sodium-library-unavailable-reasons`, anything from `memory`. The
accessors are `checked-accessor`s, so they refuse a non-condition with who = the accessor and
irritants `(not-a-sodium-library-unavailable (kind K))`; that is `test-conditions`' to hold, and
the public ones are the same procedures (the `eq?` row).

### 3.2 `test-public`

Order of the file: header, imports, runner, printer, `public-load` (T4), `reach`/`public`, the
bindings (T6), helpers, `public-names`, `(test-begin "public")`, rows, `test-end`, exit.

Rows, in order:

1. `loaded` : `public-load`.
2. **Exports whole** (T13). Must follow row 1's `environment` call.
3. **No body** (T15).
4. **`eq?`, eight names** (T16).
5. **The version, whole**: `sodium-version` equals `loaded-libsodium`'s `version`.
6. **Fresh**: two answers are not `eq?`; and the scribble row (T19).
7. **Engine sweep** (below).

**Engine sweep.** `(public 'sodium-version)` was already referenced at top level and in row 1,
so the library's body has run before any engine (K9, ADR-0007 amended). Define

```
version-sweep : -> (U (List 'all-right 'completed) (List ...evidence...))
  for FUEL from 1 to CAP (1000): run-engine (lambda () (attempt sodium-version)) FUEL 100000
  each run: answer must equal native's version, never a raise
  stop at the first FUEL whose run had zero expiries (completed)
  answer 'all-right when every run answered right, 'completed when the loop stopped that way
  and the sweep's list otherwise: the first wrong run, or 'never-completed.
```

Expected value: `(list 'all-right 'completed zero-counts)`. Every expected piece is a symbol the code
cannot produce by failing. Measured on this build (1.0.22): fuel 1 expires 3 times, fuel 4
completes with none; the row must not assert those numbers (K9, trap "a suite's own text moves
its fuels"). Its teeth are shown by mutant P8, not by the row asserting an expiry (flag F4).

### 3.3 `test-never-loads`

Two jobs, kept apart.

**(a) The testing library and the counters load no libsodium** (v0.1.1's job, unchanged in
shape).

- Rows 1 to 4 are data: the two allowlists, the loaders, the reach. The allowlists are copied
  from the files as they are: `tests/chez-sodium-testing.sls` imports
  `(rnrs)`, `(srfi :64)`, `(chez-sodium private counters)`,
  `(only (chezscheme) base-exception-handler critical-section delete-directory
  display-condition exit-handler file-directory? get-process-id getenv make-mutex mkdir system
  with-mutex)`, `(prefix (only (chezscheme) file-exists?) chez:)`; `counters.sls` imports
  `(chez-sodium private require-threaded)`, `(rnrs)`, `(only (chezscheme) critical-section
  make-mutex with-mutex)`. The builder copies them from the files, then re-reads to check (the
  suite compares exact spec lists).
- The loaders row expects exactly `((chez-sodium) (chez-sodium private native))` (sorted by
  written form). Measured: no other library under `src/` imports native (`load-state` only names
  it in a comment). The reach row expects `((chez-sodium private counters) (chez-sodium private
  require-threaded))`, no loader among the allowlisted or reached libraries.
- The child imports `(rnrs) (chez-sodium-testing) (chez-sodium private counters)`, references
  every export of the testing library, and prints `(COUNT MAPPED)`; expected
  `(0 "(N no)\n" "")` with N the count of the testing library's exports. It reaches no native
  code, so it is **not** gated (a child that did would map libsodium and fail the row).

**(b) The condition exports of `(chez-sodium)` load nothing (new; plan §2.2).**

Two children, one program text, run through `gated-command` (each reaches native's body), each
under `env` for the override; both assert `(valgrind . yes)` exactly when
`CHEZ_SODIUM_GATE_CHILD` is set, as `test-blocks` does (the child reads `vgpreload_memcheck`
from `/proc/self/maps`). Command order matters: `env CHEZ_SODIUM_LIBRARY=P` goes *before* the
gate's words, `(append '("env" "CHEZ_SODIUM_LIBRARY=P") (gated-command getenv argv))`, or
Valgrind would run `env` and not trace the child (the gate does not trace children; Makefile
`--trace-children` note).

- **Absent child** (the plan's row). `CHEZ_SODIUM_LIBRARY` = `<temp dir>/absent-libsodium.so`,
  absolute, never created. The program:
  1. `(define env (environment '(rnrs) '(chez-sodium)))`, `(define (pub n) (eval n env))`. It
     does **not** import `(chez-sodium)` and names `sodium-version` only inside a quoted datum.
  2. It imports `(chez-sodium private conditions)` for `make-sodium-library-unavailable` alone,
     to build a condition with a distinct value in each field: reason `not-found`, path `"/p"`,
     source `system`, detail `7`, candidates `("c")`. That import runs `conditions` body, which
     loads nothing.
  3. Prints `(before . no)`: `/proc/self/maps` holds no `libsodium`.
  4. For each of the seven condition exports, by `(pub 'NAME)`, **called**: the two predicates on
     the made condition (`yes`) and on `42` (`no`, as symbols, never a bare `#f`), the five
     accessors on the made condition (`not-found "/p" system 7 ("c")`). The whole line is
     written as data.
  5. `(sodium-version)` by `(pub 'sodium-version)` under `guard`, printing `(raised load-failed P
     override () yes)`: `chez-sodium-error?`, reason, path (equal to the override, which the parent
     built), source, candidates (measured `()` for `load-failed`; `candidates` carries the other
     reasons' lists), through the public accessors on the caught object. Not the detail (it is the
     loader's message: K10).
  6. Prints `(after . no)`: nothing mapped, since the load was refused.
  7. Prints the valgrind line.
  Expected stdout, whole, built by the parent; stderr `""`; status 0.
- **Control child (standing positive control).** Same text, run with the suite's own
  `CHEZ_SODIUM_LIBRARY`/discovery (no `env`), still through `gated-command`. Step 5 prints
  `(answered yes)`: the answer equals `(cdr (assq 'version ((eval 'loaded-libsodium
  (environment '(rnrs) '(chez-sodium private native))))))`; step 6 prints `(after . yes)`; steps
  3 and 4 are as the absent child's, so the same condition rows pass with a library that
  *can* load. Without it, "mapped is no" cannot fail (plan §6: "a witness has a standing positive
  control"). This is beyond the plan's literal text (flag F5).

**How a condition export is reached without running native's body**, given `(chez-sodium)`
imports native (measured, section 5, P1 to P3):

- Chez runs a library's body when a binding *that library defines* is referenced at run time.
  A re-export resolves to the defining library, so `(eval 'chez-sodium-error? env)` runs
  `conditions` (and `require-threaded`), not `(chez-sodium)`'s empty body and not native's.
  The body of an imported library that nothing referenced does not run (a public library that
  imports native and re-exports its version without referencing it left native unrun until
  `sodium-version` was evaluated).
- A text reference runs the body before the program's first line: a program whose text merely
  names `sodium-version` inside a never-called procedure died with the loader's refusal before
  printing anything; one naming a condition export printed its first line. So the child names
  `sodium-version` only inside a quoted datum for `eval`, as plan §2.2 says, and never imports
  `(chez-sodium)`.
- **What the child cannot see** (so other rows must): a body in `(chez-sodium)` that is never
  referenced by the condition exports, such as `(define touched (sodium-version))`, passed the
  child (mutant P4b: all seven answered, `before`/`after` no). Only test-public's no-body row
  holds that. And a wrapper that touches nothing of native passes the child (mutant P3b) and is
  held by the `eq?` row. A wrapper that *does* reference native is seen at reference, not only at
  call (mutant P10b measured: the reference raised `load-failed`).

### 3.4 `check-nothreads` and `test-require-threaded`

- **They cover `(chez-sodium)` with no edit to their logic.** `check-nothreads` imports every
  library under the directory it is given (`(environment '(rnrs) NAME)`, no body run) and
  `test-require-threaded` reads each `src/**/*.sls` and holds `require-threaded` first;
  `test-check-nothreads`' real-tree row builds its expected names from `src/` itself. Measured
  with a stub `src/chez-sodium.sls`: `check-nothreads` on a threaded Chez named `(chez-sodium)
  loaded, but a non-threaded Chez must refuse it` among its nine; `test-require-threaded` showed
  `FAIL src/chez-sodium.sls imports (chez-sodium private require-threaded) first` (expected
  `first`, actual `not-first`) when native was imported before it, and 57 passes in the right
  order. `check-seam` accepted the stub (9 libraries, 9 files).
- **The one edit is a comment.** `tests/check-nothreads.sps` lines 13 to 15 say: "(chez-sodium) is
  checked, with no edit here, when it arrives." Replace with a present-tense line, for example:
  `(chez-sodium), the public library, is one of them: it imports the refusal first like the rest.`
  Re-wrap the paragraph; nothing else in the file changes. The Makefile's comment at line 285
  ("the public (chez-sodium) too, when it arrives") is the caller's at the join.
- No edit to `tests/test-require-threaded.sps`, `tests/test-check-nothreads.sps`, `tests/check-seam.sps`,
  `tests/test-check-seam.sps` or `tests/preflight.sps` (its comment about the public library is
  already in the present tense and still true).

## 4. Trim table: `tests/test-never-loads.sps`

| # | Piece | Kept / changed / dropped | Detail |
|---|---|---|---|
| N1 | Header comment | changed | Renamed. Dropped (D24): the sentence "Native's load registers the `sqlite3_memory_used` check with the counters, so the testing library runs it without importing native": protected that the testing library ran a registered exit check with no native import. M1 removed exit checks (plan §4.1 item 4; ADR-0011 amended): `suite-exit-status` reads only `native-counts`, so there is nothing to run and no reason to import native. Checked against K6: the allowlist rows hold the import list directly. Keep the rest of that paragraph, which names who imports the testing library and would break if it loaded libsodium (`check-test-fails`' copy, which holds `require-threaded` and `counters` only in all but its leaks case; the launcher's `env -i` runs of `make test`; the children `test-chez-sodium-testing` starts), with counts left out ("briefs name sources, not counts"). Add the header paragraph for part (b). |
| N2 | Imports | changed | `(rnrs)`, `(srfi :64)`, `(only (chezscheme) directory-list file-directory? file-symbolic-link? getenv library-exports)`, `(chez-sodium-testing)`. `getenv` is now also for `gated-command`. |
| N3 | Runner, printer | kept | |
| N4 | `testing-source`, `counters-source`, `testing-allowlist`, `counters-allowlist` | changed | Paths `tests/chez-sodium-testing.sls`, `src/chez-sodium/private/counters.sls`; lists copied from the actual files (3.3a). |
| N5 | `read-library`, `spec-library`, `sls-files`, `src-imports`, `src-read?`, `imports-of`, `written`, `name<?`, `sorted`, `adjoin`, `loaders`, `reach`, `differences`, `import-differences` | kept | `native` is `(chez-sodium private native)`. `reach` follows the family symbol `chez-sodium`; `(chez-sodium-testing)` has first element `chez-sodium-testing`, so it is not walked: same as v0.1.1. |
| N6 | Rows "testing library imports exactly its allowlist", "counters imports exactly its allowlist" | kept | |
| N7 | Row "the libraries under src/ that load libsqlite3" (ten names) | changed | Expected `(sorted '((chez-sodium) (chez-sodium private native)))`. |
| N8 | Row "what the testing library reaches through src/ ... loads" | kept | Expected reach `((chez-sodium private counters) (chez-sodium private require-threaded))`, then `'()` and `'()`. |
| N9 | `child-program` | changed | Imports `(rnrs) (chez-sodium-testing)`; prints `(COUNT MAPPED)`; needle `libsodium`. Dropped (D25): `(exit-checks)` from the print and the `(chez-sodium private counters)` import that only it needed (no such procedure; the counters' own import list is held by the allowlist rows). |
| N10 | The macOS branch `no-maps` expected when `/proc/self/maps` is absent | changed | Linux only (ADR-0010): expected is always `no`. The child still prints `no-maps` when the file is missing, so a platform without `/proc` fails the row by value, not silently. This is a change, not a drop: the check stays and fails closed. |
| N11 | Child row "(N () no)" | changed | `(0 "(N no)\n" "")`. |
| N12 | Part (b): the absent and control children | new | 3.3b. |

## 5. What I ran

All under `scripts/guix-env sh -c '...'`, files under `build/slice4-public/` (ignored).
`$CHEZ` and `CHEZ_SODIUM_LIBRARY` (libsodium 1.0.22, `.so.26`) are set in the container.

- **Stub public library** (`build/slice4-public/libs/chez-sodium.sls`): the eight re-exports,
  `require-threaded` first, `(only ...)` imports, no body. `check-seam` on a `src/` copy with it:
  `the seam holds (9 libraries in 9 files checked)`.
- **P1.** Child with `CHEZ_SODIUM_LIBRARY=/nonexistent/libsodium.so`, `eval` of each condition
  export in `(environment '(rnrs) '(chez-sodium))`: all seven `procedure?` true; maps scan:
  `(sodium-libmapped no)`; then `(eval '(sodium-version) env)` raised the loader refusal. Control
  with the real library: all seven true, `no`, then `"1.0.22"`.
- **P2.** Accessors on the raised condition: `(#t #t load-failed "/nonexistent/x.so" override () #t)`
  (predicate, predicate, reason, path, source, candidates, detail is a string). Accessor on `42`
  and on a string: `(sodium-library-unavailable-reason (not-a-sodium-library-unavailable (kind
  number)))` and `... (kind string)`. A second `sodium-version` call re-raised `load-failed`
  (the remembered failure).
- **P3.** Text references: a program that imports `(chez-sodium)` and merely names a condition
  export inside `(define (f) ...)` printed its first line; one naming `(sodium-version)` in a
  never-called `f` died with the refusal before printing.
- **P3b.** Mutant, wrapper `(define (chez-sodium-error? x) (c:chez-sodium-error? x))`, native
  imported unused: child passed (no load). **P4b.** Mutant, unexported body
  `(define touched (sodium-version))`: child passed, all seven answered, `no` before and after.
  **P10b.** Mutant, wrapper `(define (chez-sodium-error? x) (sodium-version) ...)`: the child
  printed `(chez-sodium-error? raised ... the loader refused ...)` at reference time; the other
  six answered.
- **P5.** `library-exports '(chez-sodium)` before any `environment`: `Exception in
  library-exports: library (chez-sodium) is not loaded`. After `environment` it listed the eight
  names with the override pointing nowhere (no load), and `sodium-version` raised, twice.
- **P6.** Engine sweep of `sodium-version` from fuel 1: `(1 ("1.0.22" 3) #t)`, `(2 ... 1)`,
  `(3 ... 1)`, `(4 ... 0)`; the answers equal `loaded-libsodium`'s version; two answers are not
  `eq?`.
- **P8.** Mutant: native's `sodium-version` as `(call-with-block 'sodium-version 1 (lambda (b) #f)
  (lambda (b) (string-copy libsodium-version)))`, no `call-in-section`: the sweep died with
  `Exception in sodium-version: re-entered after its block was freed`.
- **P11.** Copy of `tests/test-require-threaded.sps` run against a tree whose public library
  imports native before `require-threaded`: `FAIL src/chez-sodium.sls imports (chez-sodium
  private require-threaded) first / expected: first / actual: not-first`, 56 pass 1 fail; with
  the right order, 57 pass.
- **P12.** `check-seam` on a public library that imports `memory` and exports `foreign-block`:
  two problems named, rule (m) both times.
- **check-nothreads** on the stub tree, threaded Chez: `check-nothreads: (chez-sodium) loaded,
  but a non-threaded Chez must refuse it` (and the eight private ones); `FAILED (problems: 9)`.
  Not runnable here with `--nothreads` (flag F3).

## 6. Rows and mutants

Each mutant is applied alone, to a copy, and the named row must go red. "Plan" marks the plan's
slice 4 list.

| Mutant | Row that must fail | Notes |
|---|---|---|
| P1 extra export (plan): `sodium-failed?`; separately `loaded-libsodium`, `&sodium-library-unavailable`, `make-sodium-library-unavailable` | test-public exports-whole | One mutant per kind of extra: M3 name, native name, `&` name, constructor. ADR-0012 decision 2. |
| P2 export missing (plan), each of the eight in turn | exports-whole; `eq?` row (by value, unbound inside `eval`); never-loads child for a missing condition export | Reached through `eval`, so a missing name is a row failing by name, not a program dying before its first line. Watch against stubs that are present and wrong (the trap): a stub library exporting all eight names bound to `(lambda args 'stub)` must fail the `eq?`, version, fresh and engine rows, and pass exports-whole. Run the suite first with no `src/chez-sodium.sls` at all: every row fails by name, the suite exits 1 and names tests. |
| P3 re-export a wrapper, not `eq?` (plan): (a) each of the eight wrapped | `eq?` row names it; no-body row | (b) the wrapper that touches nothing of native passes never-loads: so `eq?` is not redundant. |
| P4 body: (a) `(define unused 1)` in the public library; (b) body `(define touched (sodium-version))` | no-body row alone | (b) passes the child (measured). Shows the no-body row cannot be dropped for the child. |
| P5 swapped re-exports: export `-path` as a rename of private `-source` (and the reverse) | `eq?` row, both names | Exports-whole passes. |
| P6 `sodium-version` answers the same string twice (plan): native's `sodium-version` returns `libsodium-version` with no `string-copy` | fresh row, scribble row; also `test-native`'s own | The public rows must go red on their own. |
| P7 public `sodium-version` is a wrapper returning a cached string | `eq?` row | |
| P8 `sodium-version` wrapped in `call-with-block` with no `call-in-section` | engine sweep | Measured: raises `re-entered after its block was freed`. Row 18's sodium-version half. Control: the same inside `call-in-section` must pass at every fuel (not a mutant: the correct way, to show the row is not killing the shape). |
| P9 `sodium-version` returns another string | version-whole row | e.g. `"0.0.0"`. |
| P10 never-loads: (a) `conditions` imports native, referencing it; (b) a public predicate wrapper that calls `(sodium-version)` (plan: "a condition predicate that loads libsodium") | child row; loaders row for (a) | (a) as a mere import, unreferenced, is invisible to the child (per-reference invocation) and is caught by the loaders row: the child alone is not enough. |
| P10c testing library or counters imports native or `(chez-sodium)` | allowlist rows, loaders/reach row | As v0.1.1. |
| P10d the child's override not passed, or `CHEZ_SODIUM_LIBRARY` left to the suite's real library | absent child's step 5 (answers a string, not `load-failed`) | |
| P10e the child's needle misspelt | control child (`after` must be `yes`) | The standing positive control. |
| P10f `valgrind` line: the child run outside the gate under `make test-memory`, or gated without the gate | both children's valgrind lines | As `test-blocks`. |
| P11 `(chez-sodium)` imports `require-threaded` after another library, or not at all (plan) | `test-require-threaded` names `src/chez-sodium.sls imports (chez-sodium private require-threaded) first` | Measured. `check-nothreads` on a real `--nothreads` Chez can only run in CI. |
| P12 `(chez-sodium)` imports `memory`, or an `(only (chezscheme) ...)` | `check-seam` (rule m; c, f, g) | Not this slice's file; named so the join runs it. |

## 7. Flags

- **F1. `library-exports` before `environment` raises "not loaded".** Chez does not load a
  library for it. v0.1.1's order (the `public-load` row first) hides this. Keep the `environment`
  call in `public-load` ahead of the exports-whole row; if `environment` itself raises, those
  rows then fail by name as `(raised TEXT)`.
- **F2. The plan's "references every condition export ... each answers" is not enough on its own.**
  A body in `(chez-sodium)` that nothing referenced passes the child (measured, P4b). The no-body
  row is the only holder; do not trim it as redundant with the child. The child must also *call*
  each export: a wrapper that touches native is seen at reference, but one that touches native
  only when called would need the call (reasoned from per-reference invocation, not measured).
- **F3. `check-nothreads` cannot be watched refusing `(chez-sodium)` here:** the container's Chez
  is threaded, so the plan's Done line ("`(chez-sodium)` among the libraries CI's `nothreads`
  refuses by name") is observable only in CI's job (slice 3's `ci.yml`). Here the proof is
  indirect: the program reaches it and reports it loaded on a threaded Chez (measured), and
  `test-require-threaded` holds the import order.
- **F4. Engine row versus "never an expiry".** The plan says: assert the outcome at every fuel,
  never an expiry; v0.1.1's row also asserted that fuel 1 expires. That plan rule is about verbs
  with a section, where an engine spends no ticks. `sodium-version` has none (ADR-0007, decision
  8), and expires 3 times at fuel 1 here. I followed the plan: no expiry assertion; the row's
  teeth are P8's measured kill. The owner may prefer a liveness assertion (fuel-1 expiry
  `> 0`, not a count).
- **F5. A positive-control child is added, beyond plan §2.2's text,** to meet plan §6's "a
  witness has a standing positive control". It costs a second gated Chez child (Valgrind start)
  in a suite that already has the absent-library child; the testing-library child is ungated.
- **F6. Gate order for the override.** `env CHEZ_SODIUM_LIBRARY=P` must precede the gate's
  words. Appending it after would hand Valgrind an `env` it does not trace into. Same ordering
  trap as `test-wipe`'s `env -u` (GNU `env` reads `-u` only before assignments).
- **F7. Record numbers re-pointed.** v0.1.1's ADR-0009 (public library) is ADR-0012 here; ADR-0013
  (conditions public surface) is ADR-0006 and ADR-0012 decision 2; ADR-0002 (load once) is ADR-0002
  here (the same topic, different record: use ours); engines are ADR-0007. Any mention of a
  chez-sqlite3 record must carry its repository name (AGENTS.md).
- **F8. Plan consistent on:** the owned files (the Makefile comment is the caller's, line 285);
  the eight names (ADR-0012 decision 2, plan §4.2 item 1, global constraints); "No edit to
  `test-check-nothreads`" (its real-tree row already scans `src/`). **Disagreement:** none found
  between plan, records and v0.1.1 beyond F4. One thing I could not place: the plan's slice 4
  "Done" says "slice 3's checks" (decoy, refusals) pass with this slice; slice 3's files are not
  in my read and I did not look.
- **F9. Trap restated.** A program naming an unbound identifier dies before its first line.
  Test-public and the child reach everything through `eval`, so a missing export is a failing row,
  not a dead suite; still run the red against a stub that is present and wrong (P2), because a
  run with the library absent proves only that rows fail when nothing loads.
- **F10. The detail field is not asserted** in the absent child (it is the loader's message).
  Path, source, reason and candidates are.

## 8. Count of drops

**25 drops.** Source (section 1): D1 to D13. test-public (section 2): D14 imports, D15 the four
compile-option bindings, D16 `yes-no`, D17 the count row, D18 the six private-library export
rows, D19 the type row, D20 the compile-option rows, D21 the depth rows, D22 `first-option` and
the C-string engine paragraph, D23 the zero-counts row. test-never-loads (section 4): D24 the
exit-check sentence, D25 `(exit-checks)` in the child. Each reason is checked against K1 to K10
in its row. Replacements, not drops: S11/S15 (names), T10, T13, T17, T19, T22, T24, N7, N10.
