# M2 slice 1 mutation log: the bindings

Every run was in the Guix container (`scripts/guix-env`): Chez 10.4.0, threaded; libsodium 1.0.22,
and the floor, 1.0.18, from slice 5's source build, its headers first in `C_INCLUDE_PATH`. The
caller wrote native's step 6 and step 7 and its new exports first (plan §6, slice 1). Then three
Sonnet builders worked in one tree, on disjoint files: the load (`test-native`,
`test-native-codes`, the oracle), the conventions (`foreign-conventions`, `test-conventions`,
`test-constants`) and the decoy (`decoy-libsodium.c`, `library-loading`, the library-loading
suites, `test-decoy-source`). Every mutant was applied in a whole copy of the tree, never in place.

## Reproduced by the caller, at the join

Each in a whole copy of the tree, by one exact replacement, with `make deps` run in the copy:

- **`unsigned-64` dropped from the argument allow-list:** `test-conventions` fails ten rows, among
  them "table: the allowlists are int, uptr, size_t and unsigned-64 as arguments …" and every
  sweep over the thirteen rows.
- **Step 7's `bytes-min` read from `crypto_generichash_bytes`:** `test-native` fails E2, the two
  oracle rows for `generichash-bytes-min`, and the row that holds the five sizes to brief §3.4.
- **The decoy's `randombytes_buf` testing `buf` itself after its copy:** `test-decoy-source` fails
  "the real tests/*.c that include sodium.h: the functions read, whole, and no breach".
- **The review's twin mutant, `generichash-keybytes-min` and `-max` stored under `bytes-min` and
  `bytes-max`,** after the review fixes: `-decoys` fails "decoy control under \"sizes-other\":
  sizes-other loads, and native records its five sizes: 33, 8, 80, 9 and 81". Before them, every
  slice 1 suite passed it (M2S1-F1).
- **Clean runs at the join:** every suite each builder touched, at 1.0.22 and at the floor; then
  `make test`, 29 of 29.

## The load builder

Container (scripts/guix-env), Chez 10.4.0 threaded; libsodium 1.0.22, and the floor, 1.0.18
(build/slice5/prefix-1.0.18, confirmed by reading the loaded version: 1.0.22 and 1.0.18). Each mutant
is applied alone in a whole copy of the tree (rsync, build/scheme-libs copied) and the copy removed
after. "Killed" means at least one row FAILs. Clean rerun after every group: test-native 77 passes,
test-native-codes 13, at 1.0.22 and at 1.0.18.

### Red first (test-native against main's native.sls, in a copy)
15 rows fail, among them the export row and, for each of the five sizes, the F row and the M row.
E2, E3 and E5 and the sizes row fail by name once the new native is back in place under the mutants
below.

### Native: each binding (8) dropped, lazy, moved before sodium_init's call: 24 mutants, all KILLED
- drop (raw binding removed; its answer pair #f, or its size a literal 32/16/64/16/64): E2 and E3
  fail for all eight. For randombytes_buf, generichash, memcmp the codes rows fail too; for the five
  size functions the codes suite and the value rows still pass (the literal equals the real number),
  so E2 and E3 alone kill it, as intended.
- lazy (init wrapped in `(lambda args (apply (bind-required ...) args))`): E2 and E3 fail, all eight;
  behaviour is unchanged and no codes row sees it.
- early (binding moved above `(init (raw-init))`): E2 and E3 fail, all eight; behaviour unchanged.

### Step 7: 11 mutants, all KILLED
- one size function called twice, each of five: E2 alone fails (1 row each).
- a size read from another's function: bytes<-bytes-min, bytes-min<-bytes-max, bytes-max<-bytes: 4 rows
  fail each (E2 and the F, M and written-numbers rows). keybytes-min<-bytes-min and
  keybytes-max<-bytes-max (same numbers, 16 and 64): E2 alone fails.
- the five reads moved above raw-memcmp's binding (before every entry point is bound): E2 fails.

### Exports, answers and stubs: all KILLED
- export of sodium-memcmp dropped: export row fails, codes rows fail (3). Export of
  generichash-keybytes-max dropped: export row and its size rows fail (4).
- stubs present and wrong: size answer from another key (E5); a size defined as 33 (4 rows);
  generichash-keybytes-min answering the bytes-min answer (E5); memcmp answering memzero (E5, 3 codes
  rows); memcmp constant 0 (E5, 2 rows) and constant -1 (E5, 3 rows); generichash constant 0 (E5, 6
  rows); answers pair for bytes-min holding bytes (3 rows); randombytes_buf a no-op (E5, 2 rows),
  memzero (E5 and the size-16 row), a constant fill of CC (E5 and the size-16 row).
- found by the stub row: randombytes-buf = sodium_memzero survived the first size-16 row (not all
  still the fill). Fixed: the row now requires the 16 bytes not all one value; then killed.

### Oracle: KILLED except two equivalent mutants
- sizes swapped (line prints another size's F): 20 rows, the oracle's whole-output rows too.
  Two F's swapped between lines: 20 rows.
- M read from the wrong macro, each: bytes<-BYTES_MAX (2 rows), bytes-max<-BYTES_MIN (2),
  bytes-min<-BYTES (2), keybytes-min<-BYTES (2), keybytes-max<-BYTES (2); F from a macro plus 1 (2).
- SURVIVED, equivalent: bytes-max's M read from KEYBYTES_MAX (both 64), keybytes-min's M read from
  BYTES_MIN (both 16): the same number at 1.0.18 and 1.0.22, so no value row can differ.
- **Corrected after slice 1's review (M2S1-F5):** every size line has such a twin, for F and for
  M alike, since `_BYTES` and `_KEYBYTES` are both 32, the two minimums 16 and the two maximums
  64, at both releases. The review killed none of four more: `bytes`' F read from the unbound
  `crypto_generichash_keybytes`, `keybytes-min`'s F from `_bytes_min`, and two more M's. So the
  oracle holds the numbers, not which function or macro gave them. The M twins cannot be killed
  by value.
- **Corrected again after M2's closing review (M2-F1):** this entry first said the decoy's
  `sizes-other` rows killed the F twins. They do not: those rows hold native's sizes, through
  `refusal-probe --sizes`, and kill native's twins; nothing ran the oracle against the decoy,
  and the oracle's F twins passed every suite that runs it. The closing review's fixes add an
  oracle child under `sizes-other`, which kills them (`.plans/m2-closing-mutation-log.md`).

### test-native-codes: planted wrong expectations, 30 mutants, all KILLED (1 row each, 2 for abc-32)
- The expected hashes come from CPython 3.10's `hashlib.blake2b` on the host, never from
  libsodium: `abc` at sizes 1, 15, 16, 32 and 64; keys `01..N` for N = 1, 15, 16 and 64 at size
  32; the empty input at 32. Slice 1's review rechecked all ten against `hashlib`.
- Added after the review (M2S1-F6): keylen 128 answers -1 and leaves `out` as it was, beside 65,
  at 1.0.22 and at the floor.
outlen 0 code; outlen 65 untouched; each of the five unkeyed hashes (abc 1, 15, 16, 32, 64: abc-32
also fails the keylen 0 row, which shares it); keylen 65 code; each of the four keyed hashes; keylen 0
unkeyed; inlen 0; memcmp equal, first byte ab and ba, last byte ab and ba, every byte ab and ba;
memcmp length 0; randombytes size 0, size 16 verdict, size 16 tail.

### The floor
Both suites pass at 1.0.18 with CHEZ_SODIUM_LIBRARY and C_INCLUDE_PATH as the common file says, and at
1.0.22.

### Gate
make test-memory MEMORY_SUITES="tests/test-native.sps tests/test-native-codes.sps": both pass;
test-native 9 s, test-native-codes 8 s. `make check-test-fails`: all 13 cases; `make check-suites` ok.

## The conventions builder

Every run in the Guix container (Chez 10.4.0, libsodium 1.0.22 headers), mutants each in a whole copy of
the tree (`build/m2s1-conv/mut/NAME/`, never in place). "Floor" is 1.0.18's library and headers
(`build/slice5/prefix-1.0.18`, its header confirmed by compiling SODIUM_VERSION_STRING: 1.0.18).
Files changed: tests/foreign-conventions.sls, tests/test-conventions.sps, tests/test-constants.sps,
tests/fixtures/conventions/types/.../native.sls (regenerated: 59 types, unsigned-64 now the one
result-only type), tests/fixtures/conventions/positions/.../native.sls (p_allowed gains unsigned-64,
p_size_result added).

### Red first: the new rows against main's table
`git show main:tests/foreign-conventions.sls` in a copy: test-conventions 16 fail, 38 pass; test-constants
2 fail (the thirteen-row prototype list; the thirteen-row answer-1 row). Failing: the thirteen names,
every-entry, the-rows, allowlists, "type only an argument uses", src no-violation, positions fixture, and
the sweeps (including the two new ones). Rows that pass on main by design: "src: every form is one of the
thirteen" (reads native, not the table) and the complement rows (the allow-lists are held by the
allowlists/types-used rows; the fixture's types hold the complement).

### test-conventions (plain, 1.0.22), each mutant against the real file passing 54/54
| Check | Mutation | Result (row, whole actual) |
|---|---|---|
| src: no violation | randombytes_buf `u8*` | `(type-refused "randombytes_buf" argument 0 u8*) (mismatch ... (uptr size_t) (u8* size_t))` |
| same | sodium_memcmp `string` | `(type-refused "sodium_memcmp" argument 0 string) (mismatch ...)` |
| same | randombytes_buf `utf-8` | `(type-refused ... argument 0 utf-8) (mismatch ...)` |
| same | crypto_generichash out `u8*` | `(type-refused "crypto_generichash" argument 0 u8*) (mismatch ...)` |
| same | inlen size_t, outlen unsigned-64 | `(mismatch "crypto_generichash" arguments (uptr size_t uptr unsigned-64 uptr size_t) (uptr unsigned-64 uptr size_t uptr size_t))` |
| same | outlen unsigned-64 only | mismatch, arguments `(uptr unsigned-64 uptr unsigned-64 uptr size_t)` |
| same | crypto_generichash_bytes result uptr | `(mismatch "crypto_generichash_bytes" result size_t uptr)` |
| same | keybytes_max result uptr | fails (same row) |
| same | sodium_memcmp `__collect_safe` in native | `(mismatch "sodium_memcmp" convention plain collect-safe)` |
| same | memcmp row collect-safe | `(mismatch ... convention collect-safe plain)`; also "every row is plain" and "the thirteen rows" |
| same | `(define fp foreign-procedure)` | `(stray-reference "chez-sodium/private/native.sls")` |
| table names, every-entry, rows, src | memcmp row removed; randombytes_buf row removed | thirteen-names, every-entry, rows-written-out, src-no-violation fail |
| src: every form is one of the thirteen | memcmp binding replaced by a lambda | fails |
| allowlists, types-used, no row writes a refused type, src, positions | unsigned-64 dropped from the argument list | all fail |
| same | size_t dropped from the result list | all fail |

Every native fault also fails the sweeps (they need a clean src/); the rows named above are the ones
that name the fault.

### test-constants, planted prototype mistakes in the table's own row (both 1.0.22 and floor, same fails)
Each fails "prototypes: the header declares each row's prototype exactly" naming the row, plus the
answer-1 row and the map check (when the Chez types disagree with the C types):
- randombytes_buf `size` as unsigned long long; result int for void
- crypto_generichash inlen as size_t; outlen as unsigned long long; keylen as unsigned long long; last
  argument dropped; `out` as `char *`
- crypto_generichash_bytes int for size_t; _bytes_max unsigned int; _keybytes_min void
- sodium_memcmp `len` as unsigned long long; argument added; pointee const dropped
The `char *` and pointee-const mistakes are caught by the header check alone (the map sends every pointer
to uptr), and fail with the one row named.
Planted wrong rows made right (each plant written as the header has it, so its verdict 1 against its
expected 0): randombytes_buf, crypto_generichash, sodium_memcmp, crypto_generichash_bytes: each fails
"the prototype check refuses each kind of wrong row", at both headers.
Map: unsigned long long mapped to size_t: fails 5 rows (map, result-type, the new crypto_generichash map
plant, thirteen-rows map check, each row's Chez types).

### Clean
- test-conventions plain 54 pass; test-constants plain 22 pass; floor run of both: 54 and 22.
- Gate: `make test-memory MEMORY_SUITES="tests/test-conventions.sps tests/test-constants.sps"`:
  conventions 14 s, constants 8 s (within 450 s); ran 2, passed 2.
- `make check-test-fails`: all 13 cases fail as they must.

## The decoy builder

Container (scripts/guix-env), Chez threaded, libsodium 1.0.22 (floor 1.0.18 for the floor lane run).
Every mutant was applied alone in a whole copy of the tree (`build/m2s1-decoy/mut/NAME/`, harness
`build/m2s1-decoy/mut.py`), the real test files running against it. Killed means a row FAILs.

### Missing-entry split and children
- test-library-loading-missing: M1's five, not-sodium, 3 order rows (9 children).
- test-library-loading-missing-verbs, new: the eight, plus 2 order rows (10 children).
- test-library-loading-decoys: 10 + 4 new switch rows = 14 children. The overflow row is a C driver
  in -combined (not a Chez child).
- Each suite header and the library header say seven suites.

### 1. missing-api rows (each against a native that skips that entry's check)
Guards: `(required-entry entry where)` in `bind-required` becomes
`(unless (string=? entry "NAME") (required-entry entry where))`. The shown call in the expected
log: for each of the eight, the version calls then `sodium_init()` and no size call.
- randombytes_buf, crypto_generichash, crypto_generichash_bytes, _bytes_min, _bytes_max,
  _keybytes_min, _keybytes_max, sodium_memcmp: each KILLED by exactly its own row
  ("a library without NAME is missing-api, naming it"), 1 failure, 16 passes.
Clean rerun: 17 of 17.

### 2. size calls read before every entry is bound
- sizes-early: `(bytes (raw-generichash-bytes))` moved to right after its own binding. KILLED by 5
  rows: lacks-crypto_generichash_bytes_min, _bytes_max, _keybytes_min, _keybytes_max,
  lacks-sodium_memcmp (their logs gain `crypto_generichash_bytes()`). -missing: still 16 of 16.
- sizes-all-early (cruder: sizes zeroed, one early size call added): KILLED by all 8 missing-verbs
  rows and 7 -decoys rows. It proves little beyond sizes-early; kept for the record.
Clean rerun: both suites pass.

### 3. a row per new switch (decoy ignores the switch: its table line removed)
Shown call: the log's first entry, `decoy(SWITCH)` against `decoy(?SWITCH)`.
- ignore-sizes-other, ignore-generichash-fails, ignore-generichash-other, ignore-memcmp-other:
  each KILLED by exactly its own row in -decoys (1 failure, 19 passes).

### 4. test-decoy-source
Real-file mutants (tests/decoy-libsodium.c in the copy), each KILLED by the "real tests/*.c" row:
- src-ternary: `in ? ...` in place of the copy in crypto_generichash's log call (uses 2).
- src-second-use: `if (pnt == NULL) return;` in sodium_memzero (uses 2).
- src-array-plain: `key[]` and `volatile uintptr_t k = key[0];` (plain).
- src-never-read: the copy of `in` removed (uses 0).
- src-not-volatile: `uintptr_t p1 = (uintptr_t) b1;` (plain).
Scanner mutants (each rule turned off, in the test file):
- scan-star-only (the `[` branch removed): KILLED by "an array parameter used plainly" and
  "an array parameter read through its copy passes".
- scan-uses-ge1 (twice or more passes): KILLED by the ternary-beside-copy and second-use plants.
- scan-never-read-ok (zero uses passes): KILLED by "a pointer that is never read" and the two
  definitions plant.
- scan-no-volatile (volatile not required): KILLED by "a copy that is not volatile: it is plain".
  A first attempt at this mutant was equivalent, since the body's first token fixed the offset;
  discarded, and the one listed is the one that fails.
- scan-keeps-comments (comments not stripped): KILLED by "a pointer named in a comment or a string".
- scan-helpers-read (every function read, not the families): KILLED by the real-files row, the
  helper plant and the outside-family plant.
Clean rerun: 23 of 23, plain and under the gate.

### 5. the overflow row (-combined)
Shown call: `tail=sodium_init() sodium_init() overflow`, `unmoved=yes`, `overflows=1`.
- overflow-silent (the log drops the entry, writes no overflow): KILLED by that row.
- overflow-twice (no `overflowed` flag): KILLED by that row.
Clean rerun: 14 of 14.

### Other
- Floor lane (1.0.18 library and headers): -combined 14, -decoys 20, -missing-verbs 17 pass.
- `make check-suites` (29 checked) and `make check-test-fails` (13 cases) pass.
- Gate, each suite with its gated children, at the join (the caller's `make test-memory`, all 29):
  `-decoys` 69 s, 14; `-preflight` 55 s, 12; `-missing-verbs` 53 s, 10; `-missing` 48 s, 9;
  `-real` 46 s, 10; `-combined` 41 s, 8; `-discovery` 34 s, 9; `test-decoy-source` 6 s, 0. The
  review fixes' times are in "Review fixes", below.

### Review fixes
Whole-copy mutants again (`build/m2s1-fix/mut/NAME/`, removed after). Killed means a row FAILs.

#### F1: native's sizes by behaviour (-decoys: control row `(sizes 32 16 64 16 64)`, sizes-other row `(sizes 33 8 80 9 81)`, both through `--sizes yes`, no new child)
Shown call: the `(sizes ...)` line of the probe's whole output.
- sizes-twin (the review's: keybytes-min stored under bytes-min's value, keybytes-max under bytes-max's): KILLED by the sizes-other row alone (control's twins are equal, so the control row passes, as it must).
- sizes-swap-minmax (bytes-min and bytes-max keys swapped): KILLED by the control row and the sizes-other row.
- sizes-swap-bytes (bytes' key holds keybytes-max, keybytes-max's holds bytes): KILLED by the control row and the sizes-other row.
- control-size-bytes (decoy control answers 31 for bytes): KILLED by the control row (-decoys), and by four -combined rows.
- sizes-other-ignored (decoy's bytes, or keybytes-max, ignores sizes-other): KILLED by the sizes-other row.
Clean rerun: -decoys 20 of 20.

#### F2/F10: the switches' answers, in -combined (five gated Chez children: `--drive yes`)
Shown call: the `(sizes ..)`, `(randombytes ..)`, `(generichash ..)`, `(memcmp ..)` and `(calls ..)` lines of each child.
- ignore-sizes-other (all five size functions answer the control's under sizes-other): KILLED by the sizes-other row; each of the five alone (ignore-size-33, -8, -80, -9, -81): KILLED by the same row.
- ignore-gh-fails, ignore-gh-other (answers ignored, log kept): KILLED by exactly the generichash-fails, and generichash-other, row.
- ignore-memcmp-other: KILLED by the memcmp-other row.
- a5-short-randombytes, a5-long-randombytes, a5-short-generichash, a5-long-generichash (one byte short, one past): KILLED by all five rows (every child writes both). a5-skipped-on-fails (no write under generichash-fails): KILLED by that row alone.
- memcmp-len0-removed (no length-0 answer): KILLED by the memcmp-other row alone (the control answers 0 at length 0 by the byte loop; only memcmp-other's 1 shows it).
- memcmp-null-zero (a NULL operand answers 0), memcmp-null-first-only (only the first NULL tested), memcmp-null-compared (no NULL test; the child crashes): each KILLED by all five rows.
- overflow-silent, overflow-twice, overflow-trunc (the overflow row, now in the control child, after its calls): each KILLED by the control row.
Clean rerun: -combined 18 of 18, plain and under the gate.

#### F3: test-decoy-source (37 rows; 14 plants added, the real files' list unchanged)
Plants: P1 (macro between ) and {), Probe 2's macro (and a multi-line one, an object-like one, a macro with the name as its own parameter: no breach), P3 (attribute on a parameter), P5, P6, P7, P8, a struct parameter, `= 0` after the list, `,` and `;` ends, and P4 (#if/#else heads: the first is now unreadable, the second read).
Rule mutants, each KILLED by its plants: scan-macro-off (3), scan-head-off (3), scan-name-off (2), scan-param-off (3), scan-extern-off (1), scan-typedef-none (2), scan-attr-param-none (1), scan-macro-params-counted (2), scan-fnlike-off (2), scan-continuation-off (1).
Real-decoy mutants, each KILLED by the real-files row: src-macro-probe2 (`#define IN_GIVEN (in != NULL)`, breach `(crypto_generichash in macro)`), src-head-macro (a macro between ) and {), src-typedef-param.
Clean rerun: 37 of 37, plain and under the gate.

#### Gate (make test-memory, one suite at a time)
- test-library-loading-decoys: 70 s, 14 children.
- test-library-loading-combined: 66 s, 13 children.
- test-decoy-source: 6 s, no child.
Plain, the other five library-loading suites (missing 16, missing-verbs 17, real 23, preflight 15, discovery 21) still pass.
