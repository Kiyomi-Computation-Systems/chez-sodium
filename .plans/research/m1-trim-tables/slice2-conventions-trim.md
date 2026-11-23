# Slice 2, the conventions agent: trim tables, design note, rows, flags

Sources read: AGENTS.md; the M1 plan (§2.1, §2.2, §4.2 items 2, 5, 9, 12, §4.4, §5.1, §5.2, §6 slice 2
and "Every brief restates these"); ADR-0001 (decision 10 as amended), ADR-0002 and its amendment,
ADR-0003, ADR-0005, ADR-0008 and ADR-0011 for citations; `.plans/global-constraints.md`; slice 0's
review S0-F7, S0-F13, S0-F20; `.plans/research/m1-plan/prototypes.c` and `run.out`; and chez-sqlite3
v0.1.1 (`960d9f0`): `tests/foreign-conventions.sls` (560 lines), `tests/test-conventions.sps` (786),
`tests/test-constants.sps` (1281), the 30 fixture directories (31 files), `.plans/traps.md`.
Copies of the v0.1.1 sources are under `build/slice2-conv/src/` (ignored).

"Status" is KEEP, CHANGE or DROP. Every DROP row says what the piece protected, where that
protection lives now, and the check of that reason against the rules the copy keeps (chez-sqlite3
traps, "a reason to drop a copied rule is checked against every rule the copy keeps").

Where this says "the reader", it means `foreign-conventions.sls`' scanner (`scan-tree`, `scan-strays`,
`violations`).

---------------------------------------------------------------------------------------------------

## 1. Trim tables

### 1A. `tests/foreign-conventions.sls`

| # | Piece | Status | Change, or what the drop protected and where that lives now |
|---|---|---|---|
| A1 | Header comment | CHANGE | Rewrite for `sodium.h`, ADR-0001 decision 10, and `(chez-sodium private native)`. Remove the prose on `bind-optional`, "variadic", `sqlite3.h` and "(ADR-0011)" (that number is the SQLite harness record's; here ADR-0011 is the harness, so a copied citation would point at the wrong record). No milestone, slice or "M4" wording (AGENTS.md, comments). |
| A2 | `conventions-table`, the 44 SQLite rows | DROP | Protected: one row per SQLite binding, so that each binding is held to its C name, types and convention. Lives now: the five rows of §2.1 below, each protecting the same thing for M1's five bindings. Each later milestone appends its own rows (ADR-0002 amendment). Checked against the kept rules: the rules "a form with no row", "a row with no form", the sweeps and the allow-lists all read the table, not the 44 names, so none depends on a dropped row. |
| A3 | `conventions-table`, the five rows | CHANGE (new content) | §2.1. Row shape unchanged: `(NAME PROTOTYPE ARGUMENTS RESULT CONVENTION RECORDS)`, `PROTOTYPE` = `(RESULT (PARAMETER ...))` in `sodium.h`'s spelling. `CONVENTION` is `collect-safe` or `plain`. RECORDS are re-pointed to chez-sodium's records (flag F1). |
| A4 | Table comment: "In ADR-0002's order: the load's 15, then ...", "Every call that can block is collect-safe: sqlite3_open_v2 ...", the variadic paragraph, "SQLITE_TRANSIENT is a pointer-width integer" | CHANGE | Say: ADR-0002 amendment's order; every M1 call is plain (ADR-0001 decision 7: only `crypto_pwhash_str` and `crypto_pwhash_str_verify` are `__collect_safe`, and they arrive with M3); every argument is an integer or the address of a block we allocated (ADR-0001 decision 4). Drop the SQLite names. |
| A5 | `row-name`, `row-prototype`, `row-arguments`, `row-result`, `row-convention`, `row-records` | KEEP | |
| A6 | `allowed-argument-types` | CHANGE | `'(int uptr size_t)` (ADR-0001 decision 10 as amended; plan §2.2; S0-F7). Written out in the library, not read from the table. `int` is in the argument list because it is a result type: the kept "exactly the types the rows use" row builds the argument list from the arguments plus every non-void result. Comment: "exactly the types the table writes there; size_t is an argument only, void a result only." |
| A7 | `allowed-result-types` | CHANGE | `'(int uptr void)`. |
| A8 | `read-data` | KEEP | |
| A9 | `foreign-forms`, `symbol-count`, `forms-headed`, `has-subform?` | KEEP | The scanner reads elements, never tails (plan §6, "a scanner of forms reads elements, never tails"). |
| A10 | `import-allowance` | KEEP | One import entry of `(only (chezscheme) ... foreign-procedure ...)`. native's fixed import list names `foreign-procedure` (plan §6 slice 2). |
| A11 | `binders` = `'(bind-required bind-optional)` | CHANGE | `'(bind-required)`. See A12. |
| A12 | `bind-optional`'s allowance in the stray-reference rule (its one `(syntax foreign-procedure)` fender mention) | DROP | Protected: native's `bind-optional` macro, which wraps `foreign-procedure` for an entry point a library may lack (`sqlite3_load_extension`), needed one fender mention that the stray-reference count must not flag. Lives now: nowhere, and none is needed: ADR-0002 decision 4 says "no `bind-optional`", and the plan drops it from native. Checked against the kept rules: (1) the stray rule counts every occurrence of the symbol and subtracts only what it allows, so with the allowance gone a `bind-optional` fender mention is one more stray, which is the wanted answer (a second, hidden binder is exactly what the rule exists to refuse). Run against the real reader on a stub, 2026-11-23: a library with `bind-required` and `bind-optional`, each with one fender mention, answers `((stray-reference "chez-sodium/private/native.sls"))`. (2) `fender-allowance` stays parameterised by the binder's name, so M3 can still name a second binder only by editing `binders` and the written-out row, a visible change. (3) The v0.1.1 fixtures that relied on the allowance change (C: `permitted-optional`, `stray-optional-syntax`, `load-plain`). |
| A13 | `fender-allowance` | KEEP | |
| A14 | `stray-references`, `source-files`, `ends-with?`, `library-name`, `scan-tree`, `scan-strays` | KEEP | |
| A15 | `native-library` | CHANGE | `'(chez-sodium private native)`. |
| A16 | `form-parts`, `literal-type?` | KEEP | |
| A17 | `convention-forms` | CHANGE | `'((plain) (collect-safe __collect_safe))`. The `(variadic (__varargs_after 2))` entry is dropped (A18). |
| A18 | `variadic` convention, `__varargs_after`, `(variadic (__varargs_after 2))` | DROP | Protected: `sqlite3_db_config` is variadic, and on Apple arm64 a variadic call bound plain puts its variadic arguments where the callee never reads them, so the form needed `(__varargs_after 2)`. Lives now: nothing needs it. libsodium's bound subset has no variadic function (brief §3, ADR-0005; the 36 names probed in `ffi.sps`; every prototype in `prototypes.c`), and the platform is Linux only (ADR-0010). Checked against the kept rules: (1) `convention-of` reads anything not in `convention-forms` as `(other ...)`, which no row holds, so a binding written `(foreign-procedure (__varargs_after N) ...)` is `(mismatch NAME convention plain (other (__varargs_after N)))`; confirmed by running the reader on the stub: `(convention-of '((__varargs_after 2)))` answers `(other (__varargs_after 2))`. (2) The map rule in `test-constants` read the count via `variadic-after`; that is dropped with it (D-block). (3) A new fixture and rows keep "a variadic form is refused" held (see 1C, `varargs-refused`, and 1B rows B19). |
| A19 | `convention-of` | KEEP | |
| A20 | `refused-types`, `form-violations`, `bound-entries`, `violations` | KEEP | The header comment's "in this order" list of violation kinds stays; only the word "variadic" goes. |
| A21 | The export list | KEEP | Same names. |

### 1B. `tests/test-conventions.sps`

| # | Piece | Status | Change, or what the drop protected and where that lives now |
|---|---|---|---|
| B1 | Header comment | CHANGE | For five rows, `src/chez-sodium/...`, `sodium.h`. No SQLite, "44", "bind-optional", "variadic" or milestone words. |
| B2 | Imports | CHANGE | `(chez-sodium-testing)` for `(chez-sqlite3-testing)`; `(only (chezscheme) directory-list load-shared-object)` (`machine-type` goes with B33). |
| B3 | `(only (library-loading) every-entry optional-entries)` import | DROP | Protected: the import feeds the row that holds `(library-loading)`'s list of entries to the table, so that a missing-api row is made for exactly the table's names (chez-sqlite3 trap "a list that makes rows makes no row for what it drops"). Lives now: `library-loading.sls` is slice 3's file (plan §6, slice 3, the refusals agent), so it does not exist when slice 2 is built, and an import of it kills the suite before a test runs (trap "a program that names an unbound identifier dies before its first line"). The protection must be rebuilt in slice 3: its brief must carry the row "library-loading's every-entry equals `(map row-name conventions-table)`, whole and in order" in `test-library-loading-*` (or add it to `test-conventions`, a file slice 3 may then edit). Checked against the kept rules: no kept row reads `every-entry`. Flag F2. |
| B4 | Runner setup and the expected/actual printer | KEEP | |
| B5 | `expected-names` | CHANGE | `("sodium_version_string" "sodium_library_version_major" "sodium_library_version_minor" "sodium_init" "sodium_memzero")`, in ADR-0002's order (plan §4.2 item 3). Comment drops the SQLite tiers. |
| B6 | `collect-safe-names` | CHANGE | `'()`: M1 has no collect-safe row. Kept as a written-out list so that M3's change is one line, and so that "every row is plain" is asserted against a list in the suite, not derived from the table. |
| B7 | `variadic-names`, `optional-names` | DROP | Protected: the lists that said which rows are variadic and which optional, against which the convention and optional rows compared. Lives now: nothing is variadic or optional (A18, A12; ADR-0002 decision 4 "no entry point is optional"). Checked: no kept row reads them. |
| B8 | `accepted-types` | CHANGE | Remove `size_t` (it joins the allow-list, plan §2.2; ADR-0001). Add `integer-64 unsigned-64 unsigned-int double unsigned-8`: v0.1.1 left them out of the list because its table used them, and the list is "every type Chez 10.4 accepts that the table does not use", so M1's smaller table puts them back. Chez accepts each of the five added, as argument and as result (probed). The list is 54 entries. See flag F3. |
| B9 | `argument-only-types` | CHANGE | `'(size_t)`. |
| B10 | `refused-by-chez-types` | CHANGE | `'(time_t bool sodium_state (* void) (* sodium_state) (& sodium_state))`: `sqlite3` was a made-up ftype name Chez refuses; `sodium_state` is the same kind of name. Probed: Chez refuses all six, as argument and as result. |
| B11 | Helpers `written`, `starts-with?`, `sorted-strings`, `unique`, `sorted-symbols`, `checked`, `table`, `fixtures`, `found-in`, `rows-named`, `synthetic`, `with-field`, `replace-row`, `other-type` | KEEP | `fixtures` = `"tests/fixtures/conventions"`. `other-type` is kept as it is: `(if (eq? t 'int) 'uptr 'int)`. |
| B12 | `flipped` | CHANGE | `(if (eq? c 'plain) 'collect-safe 'plain)`; its comment loses "variadic". |
| B13 | `named-parameters`, `variadic-prototype?` | DROP | Protected: the shape row's allowance for a prototype ending `"..."`. Lives now: nothing ends `"..."` (A18). Checked: only the shape row (B17) used them, and it is rewritten without them. |
| B14 | `index-of`, `list-head-of` | DROP | `index-of` served the "an optional entry point" row (B19); `list-head-of` the `sqlite3_db_config` prototype row (B30). Both rows are dropped, and no kept row calls either. |
| B15 | `native-file` | CHANGE | `"chez-sodium/private/native.sls"`. |
| B16 | Table row: "it has a row for each of M1's 15, M2's 21 ..., in ADR-0002's order, and no other" | CHANGE | `expected-names` against `(map row-name table)`. Name: "table: it has a row for each of the five entry points, in ADR-0002's order, and no other". |
| B17 | Table row: names equal `(library-loading)`'s `every-entry` then `optional-entries` | DROP | See B3. |
| B18 | Table row: shape | CHANGE | Same six fields. Remove the `"..."` branch: `(= (length (cadr p)) (length (row-arguments row)))`. `(memq (row-convention row) '(plain collect-safe))`. |
| B19 | Table row: which rows are collect-safe, variadic, plain | CHANGE | All five plain. Written as `(map (lambda (name) (if (member name collect-safe-names) 'collect-safe 'plain)) expected-names)`. Name cites ADR-0001 decision 7. |
| B20 | Table row: "the rows whose records say 'an optional entry point' are exactly the optional entry points'" | DROP | Protected: that a row's record says "optional" exactly when native binds it by `bind-optional`. Lives now: nothing is optional (A12); the reader would also refuse a reintroduced `bind-optional` as a stray reference (A12, check (1)). Checked: a row that stays would assert `'()` on prose in the records, which is a test on text no rule reads. |
| B21 | Table row: allow-lists written out | CHANGE | `'((int uptr size_t) (int uptr void))`. |
| B22 | Table row: "the types its rows use are exactly the allowlists'" | KEEP | Unchanged. This is the row S0-F7 found the plan's lists would fail; with `(int uptr size_t)` and `(int uptr void)` it passes (argument side: `uptr`, `size_t` as arguments plus `uptr`, `int` as results; result side: `void`, `uptr`, `int`). |
| B23 | Table row: "the types only an argument uses ... which the result allowlist refuses" | CHANGE | `'(size_t)`; name says `size_t`. |
| B24 | Table row: "no row writes a type its allowlist refuses" | KEEP | |
| B25 | Table row: every row cites ADR-0011 and ADR-0002, and each record cited exists | CHANGE | Every row cites ADR-0001 and ADR-0002, and every number cited names a file in `.plans/decisions`. Flag F1: the number 0011 exists in both projects, so a copied check would pass while citing the wrong record; the row must require `"0001"` and `"0002"`, not "0011". |
| B26 | `convention-forms` row | CHANGE | `'((plain) (collect-safe __collect_safe))`. |
| B27 | `convention-of` reads the three forms | CHANGE | `(map convention-of '(() (__collect_safe)))` is `(plain collect-safe)`. |
| B28 | `convention-of` reads anything else as `other` | CHANGE | Keep: `__collect_safe` twice; an unknown (`__collect_unsafe`); the count words. Replace the 3, 1, 0 counts and the safe-beside-count cases with the cases that show variadic is no convention: `((__varargs_after 2))`, `((__varargs_after 0))`, `(__varargs_after 2)` bare, `(__collect_safe (__varargs_after 2))`. Each answers `(other . CONVENTIONS)` whole. This is where A18's protection lives. |
| B29 | `src-items`, `form-entry`; row "every form under src/ is one of the 44 bindings of ... native" | CHANGE | "one of the five bindings of `(chez-sodium private native)`, in its one file and its one library, once each". |
| B30 | Row "src: no violation" | KEEP | |
| B31 | Fixture rows | CHANGE (see 1C) | |
| B32 | Sweeps: row removed, no-form, flipped, result changed, argument changed | CHANGE | Counts become five rows, five, five, five, and two arguments. Names say "each of the five rows" and "each of the two arguments" (never a milestone). Predict the counts before running: 5, 5, 5, 5, 2. |
| B33 | Sweep: `sqlite3_db_config` made plain, made collect-safe | DROP | Protected: the variadic row's convention against the real src. Lives now: nothing variadic (A18). The generic flipped sweep (B32) covers a collect-safe flip of any row. |
| B34 | Sweep: `sqlite3_memory_used`'s and `sqlite3_column_int64`'s `integer-64` results and `sqlite3_bind_int64`'s argument changed to `int` | DROP | Protected: that a 64-bit value is bound `integer-64` and never `int` (a truncation). Lives now: `integer-64` is no allowed type here, and the same protection for `size_t` is the new sweep B35. Checked: the generic sweeps use `other-type`, which swaps to `int` or `uptr`; none of the three dropped plants maps to a kept row. |
| B35 | New sweep: `sodium_memzero`'s `size_t` argument changed to `uptr`, to `unsigned-64` and to `int`, each fails by name against the real src | NEW (CHANGE of B34's role) | Plan §6 slice 2: "a `size_t` row as `uptr`". Expected: `((mismatch "sodium_memzero" arguments (uptr uptr) (uptr size_t)))`, and the same with `(uptr unsigned-64)` and `(uptr int)`. Order of fields as the reader writes them: `(mismatch ENTRY arguments ROW-ARGUMENTS FORM-ARGUMENTS)`. Note `uptr` for `size_t` is allowed by the allow-list on both sides, so only the row catches it (flag F4: the case the header check then catches when binding and row are both loosened). |
| B36 | Written-out M3 five (`m3-five`), its row, its position row, its flip sweep, its result-change sweep | DROP | Protected: that the change counters, autocommit and interrupt are plain and typed as written. Lives now: the written-out five of B37 does the same for M1's five, and the generic sweeps (B32) flip and change each row. |
| B37 | New: the five rows written out (`m1-five`) | NEW | `(("sodium_version_string" () uptr plain) ("sodium_library_version_major" () int plain) ("sodium_library_version_minor" () int plain) ("sodium_init" () int plain) ("sodium_memzero" (uptr size_t) void plain))` against name, arguments, result, convention of each row. Protects "a table loosened with its binding still fails". Name cites ADR-0001 decisions 3 and 7. |
| B38 | Written-out M4 three (`m4-three`), its row, its position row, `sqlite3_db_config`'s prototype row | DROP | Protected: variadic and optional rows and their order. Lives now: nothing (A12, A18). |
| B39 | `argument-cases` and its sweep | KEEP | Expect 2 cases: memzero's `uptr` to `int`, `size_t` to `int`. |
| B40 | `libc-loaded`: `(if (memq (machine-type) '(ta6le tarm64le)) "libc.so.6" "libSystem.B.dylib")` | CHANGE | Plain `"libc.so.6"`; the macOS arm and the `machine-type` import are dropped (ADR-0010: Linux only, "no abstraction kept only so another platform could come later"). Protected the macOS run; nothing kept needs it. |
| B41 | `chez-takes?`, the four complement rows | KEEP | With the new lists. The "refuses the types the list adds" row keeps `(time_t bool (* void))`. |
| B42 | Complement fixture binding and `complement-refusals` | CHANGE | Count: 54 accepted + 6 refused = 60 types, 120 bindings (an argument and a result each), plus 1 for `size_t` as a result alone, plus `fx_void_argument`: 122. Predict it; v0.1.1's 116 was 50 + 6 = 56, 112, + 3 + 1. The `types` fixture is regenerated (flag F5). |

### 1C. Fixtures under `tests/fixtures/conventions/`

Each fixture moves to `<case>/chez-sodium/private/native.sls` (`chez-sodium/stray.sls` for
`outside-no-library`), with `(library (chez-sodium private native) ...)`. The wrapper in a fixture is
`(bind-required (foreign-procedure ...))`, not `(load-step (bind-required report ...))`: the reader
never reads the wrapper, and chez-sodium's `bind-required` has no report argument (plan §2.1; flag F6).

| # | Fixture (v0.1.1) | Status | Change, or what the drop protected and where that lives now |
|---|---|---|---|
| C1 | `bound-twice`, `bound-twice-two-files` | KEEP | Entry `"sodium_init"`, `() int`. Row: `sodium_init` alone (`rows-named`). Expect `((bound-twice "sodium_init"))` for both. |
| C2 | `decoys` | CHANGE | The words, the nested forms and the vector, with chez-sodium names. Its three real forms must hold to real rows or nothing is checked: `"sodium_init" () int` under a `bind-required`, `"sodium_version_string" () uptr` inside a `let`, a `lambda` and a loop, and `"sodium_memzero" (uptr size_t) void` inside a quoted vector. v0.1.1's first form was `__collect_safe` `sqlite3_open_v2`; with no collect-safe row it is plain. Expect `(3 ((stray-reference F) (stray-reference F) (stray-reference F)))`: the syntax mention, the quoted symbol and the list's last element; the import's entry is allowed. Rows: `sodium_init`, `sodium_version_string`, `sodium_memzero`. |
| C3 | `entry-not-literal` | KEEP | `sodium_init` for `sqlite3_close`, `"sodium_" "init"` for the string-append. |
| C4 | `types-not-literal` | KEEP | Names changed to M1's. |
| C5 | `no-row` | KEEP | Bind `"randombytes_buf"` (a real libsodium function with no row yet, so the fixture reads as "a binding no row answers for"). Expect `((no-row "randombytes_buf"))`. |
| C6 | `outside`, `outside-no-library` | KEEP | `sodium_init`. |
| C7 | `unreadable` | KEEP | |
| C8 | `positions` | CHANGE | `p_allowed` used `integer-64`, which is no longer an allowed type. Use `(size_t int uptr) int`: every kept type, as the first, middle and last position of a binding. Expected list otherwise as v0.1.1's. |
| C9 | `permitted` | KEEP | One fender mention in `bind-required`'s fender, the import entry, one head. `bind-required` in the fixture takes its form as the one argument, as native's will. No violation. |
| C10 | `stray-alias`, `stray-define`, `stray-quoted`, `stray-syntax`, `stray-other-macro` | KEEP | Names changed. `stray-alias` binds `sodium_init` through `fp`. Rows as v0.1.1 gives each (`stray-syntax`, `stray-other-macro` use `sodium_init`). |
| C11 | `permitted-optional` | CHANGE (becomes a refusal) | v0.1.1: "no violation". Now `bind-optional`'s fender mention is a stray reference (A12): expect `((stray-reference F))` for a library holding `bind-required` and `bind-optional`, each with one mention. Rename `stray-optional-binder`. Do not keep the name `permitted-optional`. Verified on the stub: one stray. |
| C12 | `stray-optional-syntax` | CHANGE | v0.1.1: a second mention in `bind-optional`'s fender, one stray. Now neither mention is allowed: two strays. Expect `((stray-reference F) (stray-reference F))`. Verify by running before writing the expected list into the row. Also keeps that no `bind-required` is there to lend its allowance. |
| C13 | `load-plain` | DROP | Protected: that a form wrapped in `bind-optional` is read like one `bind-required` wraps, and held to its row. Lives now: `decoys` (C2) holds that the reader reads a form wherever it stands (under a `let`, a `lambda`, a loop, a vector); there is no `bind-optional` (A12), and one would add a stray reference. Checked: the reader's `foreign-forms` has no code that depends on the wrapper. |
| C14 | `plain-open` | CHANGE | v0.1.1: a collect-safe row bound plain fails. Needs a collect-safe row, and M1 has none. Rename `plain-collect-safe-row`. The fixture binds `"sodium_init" () int` plain; the suite hands it a row that says `collect-safe`: `(with-field (car (rows-named '("sodium_init"))) 'convention 'collect-safe)`. Expect `((mismatch "sodium_init" convention collect-safe plain))`. This is the only fixture that reaches the collect-safe half of `convention-of` for a plain binding, and it is how the table and suite hold the collect-safe rules without a real collect-safe row (see §2.4). |
| C15 | `plain-close` | DROP | Protected: that `sqlite3_close` specifically, bound plain, fails. Lives now: C14 holds the rule (a collect-safe row bound plain), and the flipped sweep (B32) flips each of the five rows both ways. Duplicate of C14 once the names are synthetic. |
| C16 | `safe-other` | CHANGE | `sodium_init` bound `__collect_safe`, against its real plain row. Expect `((mismatch "sodium_init" convention plain collect-safe))`. |
| C17 | `free-safe` | DROP | Protected: `sqlite3_free` bound `__collect_safe` fails against its plain row. Lives now: C16 holds the same rule for a different row. Duplicate. |
| C18 | `variadic`, `variadic-3`, `variadic-bare`, `variadic-plain`, `variadic-safe`, `variadic-safe-after` (six fixtures) | DROP | Protected: the variadic form and its refusals (a count of 3, bare words, plain, collect-safe either side of the count). Lives now: A18's checks (1)-(3): the form is no convention, so `convention-of` answers `other` and the row mismatches. C19 below is the one fixture that shows it end to end against the real reader. |
| C19 | New `varargs-refused` | NEW | `sodium_memzero` written `(foreign-procedure (__varargs_after 2) "sodium_memzero" (uptr size_t) void)`: expect `((mismatch "sodium_memzero" convention plain (other (__varargs_after 2))))`. Protects A18. |
| C20 | New `collect-safe-ok` | NEW | `sodium_init` written `(foreign-procedure __collect_safe "sodium_init" () int)`, against the row made collect-safe: expect `()`. Holds that the reader reads `__collect_safe` alone as `collect-safe` and a matching row accepts it (without it, C14 and C16 would pass if the reader read everything as plain). |
| C21 | New `scheme-objects` | NEW | The plan's "a `u8*`, `string` or `utf-8` binding": `sodium_memzero (u8* size_t) void`, `sodium_version_string () string`, `sodium_version_string () utf-8` in one file (bound twice by name, so give each its own entry or file: use three files, one case each, or `fx` names with synthetic rows). Against the real rows the reader answered (probed): `(type-refused "sodium_memzero" argument 0 u8*)` then `(mismatch "sodium_memzero" arguments (uptr size_t) (u8* size_t))`; for `string` and `utf-8` results `(type-refused ... result T)` then `(mismatch ... result uptr T)`, each followed by the `no-form` of every row the file does not bind. Assert whole lists, with rows named by `rows-named` of the one row each case binds, so no `no-form` appears. Protects ADR-0001 decision 4 ("no Scheme object crosses into C") on the real names. |
| C22 | `types` (the complement fixture) | CHANGE | Regenerated from the new lists: 60 types as arguments and as results (120 bindings), the one `fx_result_only_0` (`size_t`), `fx_void_argument`. Order: `accepted-types` then `refused-by-chez-types`. Flag F5. |

### 1D. `tests/test-constants.sps` (prototype half only)

| # | Piece | Status | Change, or what the drop protected and where that lives now |
|---|---|---|---|
| D1 | Header comment | CHANGE | Say: holds each row of the convention table to `sodium.h`, by `_Generic`, and the row's Chez types to its C types by one map. No SQLite, constants or completeness prose. |
| D2 | Imports | CHANGE | `(chez-sodium-testing)`; `(only (foreign-conventions) conventions-table row-name row-prototype row-arguments row-result row-convention)` (`convention-forms` goes with D14). |
| D3 | `(only (library-loading) optional-entries)`, `(only (floors) read-floors floor-numbers)` | DROP | `optional-entries` and the floors fed the optional compile and the completeness plan (D8, D10). Both library files are slice 3's or unrelated to this suite's remaining rules. Checked: no kept row uses either. Dropping the first also removes a dependency on a slice 3 file (see B3). |
| D4 | `constants-source`, `constant-rows`, `primary-c-names`, the `rows:`, `values:`, `names:`, `table:` shape tests, `constants-read`, `exports`, `constant-value`, `entries?`, `row-checks`, `checks`, `asked-names`, `mismatches`, `table`, `table-names`, `name-shaped?` (the constants rows) | DROP | Protected: that every Scheme constant `(chez-sqlite3 private constants)` exports equals SQLite's own value in `sqlite3.h`. Lives now: there is no constants library to protect: "every constant is read through libsodium's own function" (ADR-0001 decision 2; AGENTS.md), so no number is written in Scheme to differ from the header. Checked against the kept rules: the header-facts compile no longer asks any constant (`names` is `'()`), and the one kept compile is the prototype one. Flag F7: nothing checks that no constant is ever written in Scheme; ADR-0001 decision 2 is a rule with no check in M1. |
| D5 | The result-code machinery: `parse-define`, `sqlite-identifier?`, `extended-primary`, `result-code-macros`, `header-define`, `completeness-plan`, `completeness-problems`, the `completeness:`, `recogniser:`, `plan:`, `problems:` tests, `floor-number`, `plan`, `header-names`, `header-number`'s use in the plan | DROP | Protected: that the table of SQLite result codes is exactly the header's `-dM -E` set at the floor and a subset above it. Lives now: libsodium has no result-code table in Scheme. Its codes are 0, 1 and -1, and "every return code the brief states is confirmed by a row against the real library" (ADR-0001 consequences; AGENTS.md): that is row 22, not this suite (row 22 is not in this slice's files). Checked: with the macro compile (`-dM -E`) gone, `header-facts` is one compile and one run. |
| D6 | The procedures' tests: `sqlite-result-code-name`, `sqlite-primary-code-name` | DROP | Protected: those two procedures' answers. They do not exist here. |
| D7 | `starts-with?` (kept if used by the map), `split-lines`, `digits?`, `strip-spaces`, `underscored`, `code-c-name`, `sort-symbols`, `symbol-before?`, `sorted-strings` | DROP (unused helpers) | Each served a dropped piece. Drop whichever the kept code does not call; `split-words` is kept for `c-compiler`; `index-of`, `ends-with?`, `written`, `take` are kept only if the kept code calls them. |
| D8 | `optional-rows`, `optional-records`, `optional-near-misses`, `native-record`, `optional-verdict`, `answer-in`, and the rule's two tests: the optional entry points' own compiles | DROP | Protected: a header that marks a function unavailable (Apple's SDK, for `sqlite3_load_extension`) fails any compile that names it, so an optional entry point's prototype was asked in a compile of its own, and read as UNAVAILABLE when native recorded the library without it. Lives now: nothing is optional (A12), and Linux's `sodium.h` marks no function unavailable (ADR-0010). Checked against the kept rules: the kept single compile asks every row; a header that lacks or marks a row's function fails the whole compile, and the "compiled and ran" row fails by name with the compiler's status and output. That is loud, as wanted: a row for a function the header does not declare must not pass. Reaching native through `eval` (`native-record`) is also gone: this suite loads no libsodium and needs no native, so it has no dependency on the load agent's file (§2.5). |
| D9 | `header-facts`' second compile (`probe.c` with `-dM -E`) and its `macros` branch | DROP | Served D5. |
| D10 | `c-program` | CHANGE | Include `<sodium.h>` and `<stdio.h>`. Drop `CONSTANT` and `UNDEFINED` and the `#ifdef` loop. Keep `PROTOTYPE(f, t)` = `printf("(prototype \"%s\" %d)\n", #f, _Generic((f), t: 1, default: 0))`. Print the header's version as a string: `printf("(header-version \"%s\")\n", SODIUM_VERSION_STRING);` (a macro, so nothing is called). The program must call no libsodium function: it is compiled with `$CC -o program source` and no `-lsodium`, so a call fails to link (probed: the five-row program compiled and ran with no library flag). `answer?` becomes: a list of two, `header-version` and a string; or three, `prototype`, a string, 0 or 1. `read-all`, `write-text`: KEEP. |
| D11 | `header-facts` | CHANGE | One compile and one run in a fresh directory; result `(facts ANSWERS)`; failure is `(compile STATUS STDOUT STDERR)`, `(run ...)`, `(output TEXT)` or `(raised TEXT)`. `capture-command`, `call-with-temp-directory`, `describe` come from `(chez-sodium-testing)`, as before. `c-compiler`: KEEP (`$CC` as words; `("cc")` when blank). No `-I`, no `-Wall`: "a compile is judged by its exit status alone". |
| D12 | `function-type`, `prototype-ask`, `prototype-asks` | KEEP | `required-rows` and `optional-rows` collapse: every row is asked. |
| D13 | `chez-type` | CHANGE | The map of §2.3: `int` to `int`; `size_t` to `size_t`; `unsigned long long` to `unsigned-64`; any pointer to `uptr`; top-level qualifiers dropped first. Remove `unsigned int`, `sqlite3_int64`, `sqlite3_uint64`, `double`, `unsigned char`, `void(*)(void*)`. |
| D14 | `result-type` | KEEP | `void` for `"void"` alone, else `chez-type`. |
| D15 | `variadic-after`, `ellipsis?`, `take`, the `ellipsis` branch of `map-problems` and its `forms` argument | DROP | Protected: that a `"..."` prototype is bound variadic, with `(__varargs_after N)` equal to its count of named parameters, and that a variadic row has such a prototype (ADR-0001 of chez-sqlite3, ADR-0021). Lives now: nothing is variadic (A18). Checked: a row whose prototype ends `"..."` would fall into `map-problems`' plain branch, where `chez-type "..."` is `#f` and the row is named as a problem, so a new variadic prototype is not silently accepted. The row to hold that: B-row "a prototype that ends `...` is a problem" (§3.2). |
| D16 | `map-problems` | CHANGE | One-argument procedure over rows: for each row, `(NAME MAPPED-ARGUMENTS MAPPED-RESULT ARGUMENTS RESULT)` when the mapped types differ from the row's. Drop the `case-lambda` and `variadic-without-ellipsis`. |
| D17 | Tests: "the table has a row for each of M1's 15 ..." (`44`), "the one compile asks every required row and no optional one" | CHANGE | One row: `(length conventions-table)` is 5, and its names (written out) are asked once each, in one compile. |
| D18 | Test: "the header declares each required row's prototype exactly" | KEEP | For all five rows; `(prototype-answer name)` is 1. |
| D19 | Test: "every question got an answer, 1 or 0" | KEEP | |
| D20 | Test: "each row's Chez types are the map of its C types" | KEEP | `(map-problems conventions-table)` is `()`. |
| D21 | Tests: the `map:` and `result-type:` unit rows | CHANGE | Rewrite the lists to the new map and its near misses: see §3.2. |
| D22 | Tests: "the prototype check refuses ..." plants (parameter type, result, count, M2's types, M3's near misses, M4's near misses, `sqlite3_db_config`'s tail) | CHANGE | Replace with the M1 plants of §3.2, each with a written-right control answering 1. |
| D23 | Tests: "the variadic rule ..." (six rows) and `db-config-row`, `db-config-with` | DROP | See D15. |
| D24 | Tests: "the map check maps a void result to void ..." | CHANGE | Same, for `sodium_memzero`: `void` written `void` is no problem; written `int`, or with a `void` argument, it is; `sodium_init` written `void` is. |
| D25 | Test: oracle rows: "constants.sls is read", "the C program compiled and ran", "printed its header version", "every row's check could be made" | CHANGE | Keep "compiled and ran" and "printed its header version" (now a string, non-empty); drop the other two (they read the constants library). |

DROP count: 26 rows marked DROP across 1A to 1D (A2, A12, A18; B3, B7, B13, B14, B17, B20, B33, B34, B36, B38; C13, C15, C17, C18 (six fixtures); D3, D4, D5, D6, D7, D8, D9, D15, D23). Counting fixtures singly, C18 is six, so 31 pieces.

---------------------------------------------------------------------------------------------------

## 2. Design note

### 2.1 The five rows

All five are plain (ADR-0001 decision 7: only `crypto_pwhash_str` and `crypto_pwhash_str_verify` are
`__collect_safe`, "every other call is plain, bounded by ADR-0007's cap"). All five are in ADR-0002's
amendment ("M1 binds five entry points"). Prototypes are `sodium.h` 1.0.22's spelling, as the plan
writes them; checked by hand against its `version.h`, `core.h` and `utils.h`
(`void sodium_memzero(void *const pnt, const size_t len);`) and, in the probe, against 1.0.18's
spelling `void * const pnt, const size_t len` (whitespace only; same type).

```scheme
("sodium_version_string"
 ("const char *" ()) () uptr plain
 ("ADR-0001 decision 3: a returned string is an address, read by our own code"
  "ADR-0001 decision 7: plain"
  "ADR-0002 amendment: the load's first binding"
  "ADR-0003 decision 2: the floor is read from it"))
("sodium_library_version_major"
 ("int" ()) () int plain
 ("ADR-0001 decision 7: plain"
  "ADR-0002 amendment: the load's second binding"
  "ADR-0003 decision 3: reported beside the string, never compared"))
("sodium_library_version_minor"
 ("int" ()) () int plain
 ("ADR-0001 decision 7: plain"
  "ADR-0002 amendment: the load's third binding"
  "ADR-0003 decision 3: reported beside the string, never compared"))
("sodium_init"
 ("int" ()) () int plain
 ("ADR-0001 decision 7: plain"
  "ADR-0002 decision 5, amended: 0 and 1 load, any other answer is init-failed"))
("sodium_memzero"
 ("void" ("void *const" "const size_t")) (uptr size_t) void plain
 ("ADR-0001 decisions 3 and 4: the block is an address, the length is size_t"
  "ADR-0001 decision 7: plain"
  "ADR-0002 amendment: bound last, for the block helper"
  "ADR-0005 decision 4: used inside, to wipe"
  "ADR-0008 decision 1: one plain call over the block's size"))
```

Each row's records begin with the record they cite, as `test-conventions`' record check reads them
(`"ADR-NNNN ..."`). "Each row cites ADR-0001 and ADR-0002" is the rule the suite holds (B25); the
other citations are extras, each naming a file that exists
(`0003-libsodium-floor-1-0-18.md`, `0005-the-subset-rule.md`, `0008-every-block-wiped-before-free.md`).
The record numbers differ from v0.1.1's: its ADR-0011 (calling conventions) is ADR-0001 here, its
ADR-0002 amendment is ADR-0002's amendment here (flag F1). "The load's first binding" and so on are
the order of the plan's §4.2 item 3, whose steps are the order ADR-0002 decision 4 gives.

The binding forms are the plan's §4.2 item 2, which I did not change.

### 2.2 The allow-lists

`allowed-argument-types` is `(int uptr size_t)` and `allowed-result-types` is `(int uptr void)`,
written out in `foreign-conventions.sls`, never read from the table. They are exactly the types the
rows use (S0-F7): the arguments are `uptr` and `size_t` (sodium_memzero) and, since the kept row builds
the argument list from every non-void result too, `int` and `uptr`; the results are `uptr`, `int`,
`void`. `size_t` is argument-only in M1, so the result list refuses it and the `argument-only-types`
row says so. No row uses `unsigned-64`; it joins the argument list with the first row that does
(ADR-0001 decision 10, amended), and until then the map knows it and the allow-list refuses it
(a table row writing it fails "no row writes a type its allowlist refuses"). Dropped from the lists,
and so refused by the complement: `integer-64`, `unsigned-int`, `double`, `unsigned-8`, `unsigned-64`.

### 2.3 The prototype map

C to Chez, in `test-constants.sps`' `chez-type`:

| C type (after dropping top-level qualifiers) | Chez |
|---|---|
| `int` | `int` |
| `size_t` | `size_t` |
| `unsigned long long` | `unsigned-64` |
| any pointer, spelled with a trailing `*` | `uptr` |
| `void`, as a result | `void` |

Anything else maps to `#f`, so a row that writes it fails until a record decides it.

How to drop top-level qualifiers: split the type on whitespace, delete the whole words `const`,
`volatile` and `restrict`, and join with single spaces. A word is deleted, never a substring, so a
type named `constant_t` is untouched. Deleting every qualifier word, not only the top-level ones,
is safe because the map is insensitive to a pointee's qualifier: any pointer is `uptr` whatever it
points at. It also means "const size_t" is `size_t`, "void *const" and "void * const" are `void *`,
and "const char" is `char`, unmapped. `void` maps only as a result (`result-type`), so a `void`
parameter stays unmapped, as in v0.1.1.

What the compiled check says of qualifiers (probed, §4): in a function type, `void *const` and `void *`,
and `const size_t` and `size_t`, are the same type, so `_Generic` answers 1 for either spelling, and a
pointee `const` is different (`const void *` for `void *const` answers 0). The row therefore stays in the
header's own spelling, `("void *const" "const size_t")`, and the map strips.

Not mapped, written into the `map:` unit row as its complement: `unsigned int`, `unsigned`, `long`,
`unsigned long`, `long long`, `ssize_t`, `uint32_t`, `uint64_t`, `unsigned char`, `char`, `signed char`,
`short`, `float`, `double`, `long double`, `bool`, `void(*)(void*)`, `""`, and `"..."`.

Property to hold, and it is a limit: `size_t` and `unsigned long` are the same C type on Linux (LP64), so
`_Generic` answers 1 for `void (*)(void *, unsigned long)` against `sodium_memzero`
(probed). A row spelled `unsigned long` where the header says `size_t` would pass the compiled check
and fail the map ("unsigned long" is unmapped), so the map is what holds the spelling. `unsigned long long`
for `size_t` is a different type and answers 0 (probed): the opslimit trap the brief names.

### 2.4 The two conventions, and the collect-safe rules with no collect-safe row

`plain` is nothing before the entry; `collect-safe` is `__collect_safe` alone; anything else is
`(other ...)`, which no row holds. M1's table has no collect-safe row, so the rules for the convention are
held by tests of the machinery, not by a real row, and each is watched:

1. `convention-forms` and `convention-of`, written out (B26, B27, B28): `__collect_safe` alone reads as
   `collect-safe`; anything else beside it, twice, or unknown, reads as `other`.
2. A fixture whose binding says `__collect_safe` for a row that says plain: `safe-other`
   (C16): `(mismatch "sodium_init" convention plain collect-safe)`.
3. A fixture whose binding is plain for a row that says `collect-safe`: `plain-collect-safe-row`
   (C14): the row is made by `with-field`, not written into the table.
4. `collect-safe-ok` (C20): a matching pair yields no violation, so the reader's two-way reading is
   shown, not assumed.
5. The sweep "each row's convention flipped" (B32), over the real src and table, flips each of
   the five to collect-safe.
6. `collect-safe-names` (B6) is a written-out list, `'()`; M3's change is that list and the two new rows.
   The written-out row B19 holds "every other row is plain" against it. Nothing in `src/` can be
   collect-safe without a row naming it, and no row can be flipped without the written-out list changing.

Not held, by decision: that `crypto_pwhash_str` is collect-safe. Its row arrives with M3 and the
written-out list and `m1-five` extend with it (flag F8).

### 2.5 How `test-constants` compiles

- `$CC` read from the environment as a command's words (`c-compiler`; `cc` when unset or blank), then
  `$CC -o PROGRAM headers.c`, with no `-I`, no `-Wall`, no `-l`. The compiler's own search path finds
  `sodium.h`: in the container, through `C_INCLUDE_PATH` set to the profile's `include` (probed: `$CC` is
  `gcc` 16.2.0, `C_INCLUDE_PATH` is `…-profile/include`, and `sodium.h` is there); in a floor run,
  through `C_INCLUDE_PATH` set to the floor's headers (AGENTS.md; trap "a floor run that sets only the
  library compiles its C against another header"); on `main`, `/usr/include/sodium.h` of Ubuntu's
  `libsodium-dev`.
- One program, one compile, one run, in `call-with-temp-directory`. A compile is judged by its exit
  status alone. A missing compiler or header fails the named row "the C program compiled and ran"; the
  suite never skips.
- The program includes `<sodium.h>` and `<stdio.h>` and calls nothing from libsodium, so it needs no
  library at link time or at run time (probed: compiled with no `-l`, and ran). `_Generic` does not
  evaluate its operand. The name is in parentheses, `(f)`, so a function-like macro of its name would
  not expand.
- The suite loads no libsodium, runs no native code through Chez (`$CC` and the probe program are
  not Chez children, as in v0.1.1), and needs no `native.sls`. So `test-constants` has no dependency on
  the load agent's file and is fully green on its own, from the start.
- Under `make test-memory`, `$CC` and the program run as plain children of the suite, as in v0.1.1;
  neither reaches Chez native code. If the memory gate's rule for children needs them named, that is
  the Makefile owner's (flag F9).

### 2.6 How the suite reads native's forms, and what is red until the join

`test-conventions` reads `src/` as data, `(scan-tree "src")` and `(violations "src" table)`: every
`.sls` under `src/`, with `read`, no evaluation. It looks for every list headed by `foreign-procedure`,
at any depth, reading list elements and never a tail, and reads each form from its end: the result
type, the argument list, the entry string, and whatever precedes is its convention. It also counts every
occurrence of the symbol and allows, per file, one head per form, one entry in an
`(import (only (chezscheme) ... foreign-procedure ...))` clause and one `(syntax foreign-procedure)` in a
fender of `(define-syntax bind-required ...)`'s `syntax-case`. Everything else is a stray reference.

So the stub `src/chez-sodium/private/native.sls` must hold:

1. `(library (chez-sodium private native) ...)`, with the library name exact;
2. an import clause `(only (chezscheme) ... foreign-procedure ...)` (it can hold the plan's fixed twelve
   names, which `check-seam` also reads; the stub's other agent is the seam agent and reads it too);
3. `(define-syntax bind-required ...)` whose `syntax-case` clause has one fender with exactly one
   `(syntax foreign-procedure)`: `(free-identifier=? #'fp #'foreign-procedure)`;
4. each of the five forms as the whole argument of `bind-required` (the plan says "second argument"; the
   report argument goes, so I call it "the form's wrapper" and flag F6), literal entry string,
   literal type lists, in the order of §2.1.

Run against the unchanged v0.1.1 reader (copied under `build/slice2-conv/lib/`, with the table, the
allow-lists, `native-library` and `binders` set as in §1A), a stub of this shape answers `()`, and the
mutants of §3 answer what §3.1 predicts (probed; the rows are in §4).

Rows red, and why:

- **No `native.sls` at all** (the main worktree before the stub): every row that reads `src/`. These are
  B29 (the five forms), B30 ("src: no violation": five `no-form`), and the sweeps B32, B35 (each is a
  `no-form` or a changed list that is not what the test predicts, since the form is absent). The table,
  convention, fixture, complement and allow-list rows are green: they read no `src`.
- **With the stub:** every row is green by construction. Only an unrelated `.sls` under `src/` that holds
  the symbol `foreign-procedure` can turn a row red (a stray reference or an `outside-native`).
- **At the join** (the real native in place of the stub): B29 and B30 and the sweeps are the rows that
  can go red, if the load agent's file differs from the stub in (a) a second `(syntax foreign-procedure)`
  or one in another macro's fender; (b) an entry or type written by a name or a call; (c) a binder named
  other than `bind-required`; (d) a convention before the entry that is not `__collect_safe`; (e) the
  library name; (f) a sixth `foreign-procedure` form, such as `foreign-entry` used wrongly, or one in a
  test helper under `src/`. The caller reads the red row's text: each answers by name.
- `test-constants` has no join dependency, as §2.5 says.

---------------------------------------------------------------------------------------------------

## 3. The rows, and what each is watched against

"Watch it fail" for every new check (AGENTS.md; plan §6). Mutants are applied to the stub `native.sls`
(a), to the table (b), to the reader (c), to a fixture (d), to `test-constants` (e). Where "predicted" is
given I ran the real reader (v0.1.1 with M1's table; `build/slice2-conv/run2.sps` and `run.sps`), and the
answers matched; rows not marked predicted are expectations the builder must watch itself.

### 3.1 `test-conventions`

Row groups, then the mutants each is watched against. Mutant text is what the builder plants, one at a
time, rerunning the suite each time, and logs in the mutation log (Guards, Mutation, Result, Clean rerun).

| Group | Rows | Mutant, and the row that must fail |
|---|---|---|
| Table | five names in order; shape; all plain; allow-lists written out; types exactly the allow-lists'; `size_t` argument-only; no refused type; cites ADR-0001 and ADR-0002 and the files exist; `m1-five` written out | (b) drop a row: names row. (b) swap two rows: names row. (b) memzero's `size_t` written `uptr` in the table alone: `m1-five`, and against a clean stub the `src` rows. (b) `sodium_init` flipped to `collect-safe` in the table alone: all-plain row, `m1-five`. (b) add `unsigned-64` to a row: the allow-list row; add it to the allow-list too: written-out allow-lists and "exactly the types" rows. (b) `size_t` result for a row: "argument-only" row and the result allow-list. (b) a row citing 0011 and 0002 only: cites row (F1). (b) a row citing a number with no file (`9999`): cites row. |
| Conventions | written-out `convention-forms`; `convention-of` reads `()` as plain and `(__collect_safe)` as collect-safe; the `other` list | (c) `convention-forms` collect-safe written `(__collect_safe __collect_safe)`: the written-out row. (c) put the variadic form back: the written-out row. (c) `convention-of` reads `(other __collect_safe __collect_safe)` as collect-safe: the `other` row. |
| src | every form is one of the five, in one file, in one library, once each; no violation | (a) bind a sixth function, `randombytes_buf`: both fail (`no-row`). (a) delete `sodium_init`'s form: both (`no-form`). (a) move a form to another library under `src/`: `outside-native`. (a) bind `sodium_init` twice: `bound-twice`. (a) `u8*` for memzero's pointer (predicted: `(type-refused "sodium_memzero" argument 0 u8*)` and `(mismatch ... arguments (uptr size_t) (u8* size_t))`). (a) `string` and (separately) `utf-8` for `sodium_version_string`'s result (predicted: `(type-refused "sodium_version_string" result string)`, `(mismatch "sodium_version_string" result uptr string)`). (a) memzero's `size_t` written `uptr` in the binding (predicted: `(mismatch "sodium_memzero" arguments (uptr size_t) (uptr uptr))`). (a) `unsigned-64` for `size_t` (predicted: `type-refused argument 1 unsigned-64` and the mismatch). (a) `size_t` as the result of `sodium_init` (predicted: `type-refused result size_t`, `mismatch result int size_t`). (a) arity: `sodium_init` taking `(int)` (predicted: `(mismatch "sodium_init" arguments () (int))`). (a) result type: memzero returns `int` (predicted: `(mismatch "sodium_memzero" result void int)`). (a) pointer as `int`: memzero's first argument `int`: mismatch arguments `(int size_t)`. (a) `__collect_safe` on `sodium_init` (predicted: `(mismatch "sodium_init" convention plain collect-safe)`). (a) a stray alias: `(define-syntax fp (identifier-syntax foreign-procedure))` added to the stub: `(stray-reference F)`, predicted by the reader's count. (a) a second `(syntax foreign-procedure)` in `bind-required`'s fender: one stray. (a) the binder renamed: the first `bind-required` fender mention becomes a stray. |
| Fixtures | those of §1C | (d) each fixture is "red against the reader with the rule it holds turned off", not against a reader that refuses everything (plan §6; trap "a red run against a check that refuses the whole input proves no row"): see the reader mutants below. |
| Reader mutants | (c) `scan-strays` returns `'()`: the stray fixtures. (c) `foreign-forms` walks tails (replace the element loop by `(foreign-forms (cdr x))`): the `decoys` fixture (extra forms found) and `stray-syntax`/`permitted` (extra forms). (c) `binders` put back to `(bind-required bind-optional)`: `stray-optional-binder` (C11) and `stray-optional-syntax` (C12). (c) `import-allowance` forced to 0: `permitted`. (c) `fender-allowance` forced to 0: `permitted`. (c) `form-parts` reads from the front: `decoys`, `entry-not-literal`. (c) `native-library` set to the wrong library name: `outside`/`outside-no-library` are unchanged but every `src` row and `decoys` fail. (c) `literal-type?` always true: `types-not-literal`. (c) `refused-types` always empty: `positions` and `types`. (c) allow-lists loosened by one type, e.g. add `integer-64`: written-out allow-lists row, and `types` (its binding no longer refused). | |
| Sweeps | removed row (5), no-form, flipped (5), result changed (5), argument changed (2), memzero `size_t` to `uptr`, `unsigned-64`, `int` | (c) the reader's `mismatch` for result dropped: the result sweep. (c) the arguments check dropped: argument sweep and B35. (c) the convention check dropped: flipped sweep. (b) the table changed with the stub in agreement: the written-out rows, so a table loosened together with its binding fails. |
| Complement | libc loaded; Chez accepts each complement type as argument and as result (control `not-a-type` refused); Chez refuses the added; none allowed; the fixture binds all 122, each refused | (c) allow `size_t` as a result: `types` (the `fx_result_only_0` binding is accepted instead of refused). (c) allow `unsigned-64` as an argument: `types`. (b) remove `size_t` from `accepted-types`' complement but leave it allowed on both sides: the same rows. (d) drop a type from the `types` fixture: the fixture row's list is short by two. |

### 3.2 `test-constants`

Rows, each also watched to fail. Planted rows are compiled by `verdicts-of` (a fresh compile and run
over the given rows), and each is paired with a written-right control that answers 1. I ran each plant
below as a `_Generic` question against `sodium.h` 1.0.22 (container) and against the two Guix store
1.0.18 headers (host gcc 11.4, `-I` by hand): the answers were the same on both, and all as listed.
Wrong rows planted (the expected answer is 0 unless marked):

| Kind of wrong row | Planted as | `_Generic` answer 1.0.22 and 1.0.18 |
|---|---|---|
| right, as the header spells it | `sodium_version_string` `const char *(void)`; `sodium_library_version_major`, `_minor`, `sodium_init`: `int (void)`; `sodium_memzero` `void (void *const, const size_t)` | 1 (all five), both headers |
| right, unqualified | `sodium_memzero` `void (void *, size_t)` | 1 (top-level qualifiers are not part of the type) |
| right: `size_t` as `unsigned long` | `sodium_memzero` `void (void *, unsigned long)` | **1** on LP64 (same type): documented limit (§2.3); not a plant, a note, and one row asserts the 1 so the limit is held, not forgotten |
| dropped pointee const (result) | `sodium_version_string` `char *(void)` | 0 |
| result `int` as `unsigned int` | `sodium_library_version_major` `unsigned int (void)` | 0 |
| result `int` as `long` | `sodium_library_version_minor` `long (void)` | 0 |
| result `int` as `void` | `sodium_init` `void (void)` | 0 |
| result `void` as `int` | `sodium_memzero` `int (void *const, const size_t)` | 0 |
| extra parameter | `sodium_init` `int (int)`; `sodium_version_string` `const char *(int)` | 0 |
| missing parameter | `sodium_memzero` `void (void *const)`; `void (void)` | 0 |
| `size_t` as `int` | `sodium_memzero` `void (void *const, int)` | 0 |
| `size_t` as `unsigned int` | `... unsigned int` | 0 |
| `size_t` as `unsigned long long` (the opslimit trap) | `... unsigned long long` | 0 |
| pointer as `int` | `void (int, size_t)` | 0 |
| pointer's pointee const | `void (const void *, size_t)` | 0 |
| pointer to another type | `void (char *, size_t)` | 0 |
| a function the header lacks | a row named `sodium_no_such_function` | the whole compile fails; `verdicts-of` answers `(compile STATUS ...)`, the row asserts that shape, not a 0 |

`map-problems` plants (no header involved; each fails by name):

| Wrong row | Expected problem |
|---|---|
| `sodium_memzero` with `(uptr uptr)` | `("sodium_memzero" (uptr size_t) void (uptr uptr) void)` |
| with `(uptr unsigned-64)` | the same shape with `unsigned-64` |
| with `(uptr int)` | likewise |
| with `(int size_t)`: pointer as int | likewise |
| `sodium_init` result `uptr` / `void` / `size_t` | `("sodium_init" () int () ...)` |
| `sodium_version_string` result `int` | likewise |
| `sodium_memzero` result `int` | `void` expected, `int` given |
| a `void` argument | `(#f)` for the unmapped parameter, as v0.1.1's row has it |
| a row with a `"..."` prototype | the row is named: `chez-type "..."` is `#f` (D15) |
| right rows: all five | `()` |

Unit rows for the map, written whole (expected lists include `#f` in positions of unmapped types; use
`eq?`-comparable sentinels, never `#f` from something that can raise; `chez-type` cannot raise on a
string): `"int"`, `"size_t"`, `"unsigned long long"` map to `int`, `size_t`, `unsigned-64`; each pointer
spelling (`"const char *"`, `"void *"`, `"void *const"`, `"void * const"`, `"const void *const"`,
`"unsigned char *"`, `"char *"`, `"const unsigned char *"`, `"char **"`) to `uptr`; qualified scalars
(`"const size_t"`, `"size_t const"`, `"const int"`, `"volatile int"`, `"const unsigned long long"`) to their
unqualified maps; everything of the complement list in §2.3, `"constant_t"` (a word that starts with
`const`), and `"const"` alone, to `#f`. And the same list through `result-type`, with `"void"` answering
`void` and `"void *"` answering `uptr`, never `void`. Predict the lengths before running.

Mutants (e), each watched:

| Mutant | Row that must fail |
|---|---|
| `chez-type` maps `size_t` to `uptr` | map unit row and the `map-problems` check of the real table |
| `size_t` left unmapped | the same |
| `unsigned long long` mapped to `uptr` or dropped | the map unit row |
| the qualifier strip removed | the map unit row (`"const size_t"`, `"void *const"`) and the real-table row (memzero's row is spelled with qualifiers) |
| the qualifier strip a substring replace | `"constant_t"` |
| `ends-with? "*"` replaced by `starts-with? "const"` | pointer rows |
| `PROTOTYPE`'s `_Generic` default branch printing 1 | every plant row (the 0 rows go 1) |
| `function-type` writes `()` for no parameters (not `(void)`) | the header row: in C `()` is an unprototyped function, a different type from `(void)`; verify by running it, and record the answer |
| compile judged by anything but the exit status | the missing-function row |
| `-I` added | not a row: the property "no `-I`" is read from the source; add a row only if the builder can show it in a failing mutant (flag F10) |
| `answer?` loosened | the "every question got an answer" row |

CI's `floor` lane runs this suite against the 1.0.18 headers (plan §6: "each kind of wrong row, planted,
on the container's header and on CI's 1.0.18"): the planted rows are in the suite, so each header sees
them. Locally the 1.0.18 headers are in the Guix store and visible to the host's `gcc` but not to the
container (probed), so a local 1.0.18 run must be on the host, with `-I` for the probe or
`C_INCLUDE_PATH=/gnu/store/…-libsodium-1.0.18/include`, and the host's compiler, or in CI.

---------------------------------------------------------------------------------------------------

## 4. Probes run

All in `build/slice2-conv/` (ignored). I changed no project file.

1. **`probe.c`, in the container** (`scripts/guix-env sh -c '$CC -o build/slice2-conv/probe build/slice2-conv/probe.c &&
   build/slice2-conv/probe'`, `$CC` = gcc 16.2.0, `sodium.h` 1.0.22, no `-I`, no `-l`): 22 `_Generic` checks
   in the shape of `test-constants`' `PROTOTYPE`, `(f)` as operand. Got: the five rows as the header
   spells them 1, memzero unqualified 1, memzero with `unsigned long` 1; the 15 plants all 0 (list in §3.2).
   Also compiled clean with `-Wall -Werror -std=c11`. Header version printed `1.0.22`.
2. **The same `probe.c` on the host, against the two Guix store 1.0.18 headers**
   (`gcc -I/gnu/store/…-libsodium-1.0.18/include`, gcc 11.4.0 on the host): the same 22 answers
   (7 ones, 15 zeros); the header's spelling `void * const pnt, const size_t len`.
3. **The v0.1.1 reader, trimmed as §1A says, against five stubs** (`run.sps`, `run2.sps`, by
   `$CHEZ --libdirs lib --program ...`; table of five rows, allow-lists `(int uptr size_t)` and
   `(int uptr void)`, `binders` `(bind-required)`, `native-library` `(chez-sodium private native)`):
   - the clean stub, five forms in a `bind-required` with one fender mention and one import entry: `()`;
   - the same plus a `bind-optional` with one fender mention: `((stray-reference "chez-sodium/private/native.sls"))`;
   - mutants: memzero with `(uptr uptr)`: `(mismatch "sodium_memzero" arguments (uptr size_t) (uptr uptr))`;
     with `u8*`: `type-refused ... argument 0 u8*` and `mismatch`; with `unsigned-64`: `type-refused argument 1
     unsigned-64` and `mismatch`; result `int`: `mismatch result void int`; `sodium_init` collect-safe:
     `mismatch convention plain collect-safe`; `sodium_init` with an `(int)` argument: `mismatch arguments () (int)`;
     `sodium_version_string` as `string`, `utf-8`: `type-refused result` and `mismatch result uptr ...`;
     `sodium_init` as `size_t`: `type-refused result size_t` and `mismatch result int size_t`;
     `randombytes_buf`: `(no-row "randombytes_buf")`;
   - `(map convention-of '(() (__collect_safe) ((__varargs_after 2))))` answers `(plain collect-safe (other (__varargs_after 2)))`.
   (Each mutant also printed the `no-form` of the rows the file did not bind; omitted above.)
4. **Chez accepts as argument and as result** (`run3.sps`, `run4.sps`): `size_t`, `unsigned-64`, `integer-64`,
   `unsigned-int`, `double`, `unsigned-8`, `unsigned-long-long`, `ssize_t`, `unsigned` accepted; `sodium_state`,
   `(* sodium_state)`, `(& sodium_state)`, `(* void)`, `time_t`, `bool` refused.

Not run: no test file was written or run; the mutation rows of §3 are for the builder.

---------------------------------------------------------------------------------------------------

## 5. Flags

- **F1. Record numbers in copied text need re-pointing, and 0011 would pass silently.** v0.1.1's rows and
  its record check cite "ADR-0011" (the calling conventions record) and "ADR-0002" (its amendment).
  Here ADR-0011 is the harness, ADR-0001 the conventions, and ADR-0002's amendment the five entry
  points. The check "every record cited exists" would still pass on 0011, since a file of that number
  exists here, so the row must name `"0001"` and `"0002"` as required numbers (B25), not copy
  `"0011"`. Also re-point in comments: "ADR-0001 and ADR-0021" (variadic, dropped), "ADR-0013" (completeness,
  dropped), "ADR-0011, amended 2026-11-17", "the M4 plan's section 4.2", "the M2 plan, section 4.8", "Apple".
  AGENTS.md also forbids a milestone, slice, research path, date or "the maintainer" in a comment: strip
  those from the copy ("M1's 15", "M3's five", dates). Cite a sibling's record with its repository name
  (`chez-sqlite3 ADR-0011`).
- **F2. `(library-loading)` is slice 3's file** (plan §6 slice 3). The import and the row tying its
  `every-entry` list to the table cannot be in slice 2 (B3, B17). The protection (a missing-api row for each
  table name, in order; chez-sqlite3's trap "a list that makes rows makes no row for what it drops") must be
  put in slice 3's brief. Not in the plan today.
- **F3. The `accepted-types` complement list changes more than the plan says.** The plan says `size_t` joins
  the allow-lists. The kept row "the allowlist against its whole complement" also needs `integer-64`,
  `unsigned-64`, `unsigned-int`, `double` and `unsigned-8` added to `accepted-types`: v0.1.1 left them out because
  its table used them; without them they are neither allowed nor refused-by-test, and a loosened list that
  allowed one would pass. This is S0-F7's logic applied to the complement. The fixture count moves 116 to 122
  (B42).
- **F4. A row and its binding loosened alike pass `test-conventions`.** `uptr` for `size_t`, in the table and
  in the binding, is allowed on both sides of the allow-list and agrees. Only `test-constants`' map catches
  it (`const size_t` maps to `size_t`, not `uptr`), and the written-out `m1-five` in `test-conventions`.
  The two checks are each other's guard (ADR-0001, consequences). A builder must watch the pair: both loosened,
  then each check alone.
- **F5. The `types` fixture is generated and no generator is in v0.1.1.** Its 116 bindings name `fx_argument_N` and
  `fx_result_N` by position in `accepted-types` then `refused-by-chez-types`. Any edit to either list
  renumbers it. The builder writes a throwaway generator in `build/`, not committed, and the suite's
  `complement-refusals` row holds the fixture to the lists (a stale fixture fails it). Count: 122.
- **F6. "Each the whole second argument of `bind-required`"** (plan §4.2 item 2, the lead's brief) reads
  against plan §2.1, which says native keeps `bind-required` "without their report argument". With no
  report, the form is the first and only argument. The reader does not read the wrapper, so it is
  indifferent; the stub's and fixtures' wrapper shape should match what the load builder writes. Ask the
  caller to fix the wording at the join; I wrote the stub's fender as `(_ (fp convention ... entry (arg ...) result))`.
- **F7. ADR-0001 decision 2 ("every constant is read through libsodium's own function; none is written in
  Scheme") has no check** once `test-constants`' constants half is dropped (D4). It is a rule a record states
  with no check holding it (chez-sqlite3 trap "a rule a record states is a rule only once a check holds it").
  M1 binds no constant function, so there is nothing to check yet; M2 and M3 bind
  `crypto_pwhash_*_min/_max`, `crypto_generichash_bytes` and the rest, and each verb's rows read them.
  Suggest the closing review ask whether a seam-style rule is wanted (no `define` of a number named like a
  libsodium constant). Not mine to build.
- **F8. M3 owes this suite its change.** `collect-safe-names`, `m1-five` (rename), `expected-names`, the
  allow-lists (`unsigned-64`, then `size_t` in the result list when a row returns one), the counts (5, 5, 5, 5, 2),
  the complement fixture's count and the `types` fixture, and the `accepted-types` list move with each row
  that adds a type: each type joins "with the first row that uses it" (ADR-0001 decision 10). Write the
  counts as `(length ...)` of the written-out lists where the row says a count, so the row cannot go stale.
- **F9. `test-memory` and `$CC`.** `test-constants` starts `$CC` and the probe program under the memory gate
  (as v0.1.1). Neither is Chez native code, so the gate's rule for children (`gated-command`) does not
  apply (global constraints: "a child that runs only Scheme is outside the rule"; these run no Scheme and
  no libsodium). Confirm with the Makefile owner that `make test-memory` runs the suite as v0.1.1's did;
  v0.1.1's timing is unknown to me.
- **F10. `no -I` has no failing mutant.** The plan says `$CC` with no `-I`; v0.1.1 holds it only by the
  source (no flag in the list). A row cannot see a flag the compile quietly gets right. Say so in the
  mutation log. If the caller wants a check, compare the compiler's `-v` search list: out of scope.
- **F11. `size_t` and `unsigned long` are one C type on LP64,** so the compiled check cannot tell a row written
  `unsigned long` from `size_t`; the map does (§2.3). `unsigned long long` is distinct and answers 0 (probed).
  Held by a written row, not a comment.
- **F12. 1.0.18's headers have not been compiled against by the suite.** The probe shows the five prototypes
  and 15 plants answer as on 1.0.22 (host gcc 11.4 and the Guix store headers), and no CI header was
  available. CI's `main` (Ubuntu 24.04 gcc 13) and `floor` lanes are the first runs. The plan §5.1 measured
  16 checks on 1.0.22 only.
- **F13. Slice 2's rows that touch native are red only without a stub.** With the plan's stub headers all
  of `test-conventions` is green; the join risks are in §2.6, listed. `test-constants` has no join risk.
- **F14. The stub's file must be `src/chez-sodium/private/native.sls`**; the builder's worktree must not commit
  it (the load agent's file wins at the join), and `check-seam`'s agent reading `src/` sees it too.
- **F15. The decoy header's `(f)`, not `&f`.** `prototypes.c` (the plan's measurement) asks `&f`; v0.1.1's
  `test-constants` asks `(f)`. Both answer the same for the five rows (probed with `(f)`); keep v0.1.1's, since
  it also holds for a function-like macro's name by parenthesising. Not a disagreement, only a difference to
  know.
- **F16. Nothing in the plan, a record or v0.1.1 disagrees on the five rows' types or conventions.** The
  plan's convention row lists `size_t` first for `uptr`/`int` lists exactly as ADR-0001 amended; the
  plan, ADR-0001 decision 10 and S0-F7 agree on `(int uptr size_t)` and `(int uptr void)`.
  One wording difference: ADR-0001 decision 10 says "`unsigned-64` the arguments ... joins with the first
  row that uses it" and the map "gains" it now; the plan puts the map entry in M1 and the allow-list entry
  with the first row, so M1 has a map entry no row uses (held by the map unit row only).
