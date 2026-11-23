# Slice 2, the load builder: trim tables and design note

Phase 1: no code is written into the project. Sources are chez-sqlite3 v0.1.1 (`960d9f0`);
"v0.1.1 L123" means line 123 of that file at that commit (for `test-native.sps`, of the copy at
`.../scratchpad/test-native-v011.sps`, which is `git show 960d9f0:tests/test-native.sps`).
Probe files are in `build/slice2-load/` (ignored). Every probe named below was run in the
container; results are in §6.

Contents: §0 the rules every "checked against" cites; §1 trim tables; §2 design note; §3 rows
and mutants; §4 import lists; §5 flags; §6 probes run.

## 0. The kept rules a dropped piece is checked against

A drop's reason is checked against each of these, because the copy keeps them (chez-sqlite3
`.plans/traps.md`, "a reason to drop a copied rule"). A table cell says "K2, K5" where those are
the rules the dropped piece could touch; a drop that touches none says so and why.

| Id | Kept rule | Record |
|---|---|---|
| K1 | Nothing raises inside `critical-section` or a critical `dynamic-wind` thunk; a section answers data, the raise follows it | ADR-0007 decisions 2 to 4, 7, 9; AGENTS "Chez and the FFI" |
| K2 | The seam: only `memory` holds `foreign-alloc` and `foreign-free`; only `native` holds `foreign-procedure`, `foreign-entry?`, `foreign-ref`, `foreign-set!`, `load-shared-object`, `getenv`, `machine-type`, `format`, `format-condition?`, `display-condition`; `allowed-chez-names` is exactly what `src/` imports; rule (m) | ADR-0001 decision 9; ADR-0012 |
| K3 | Every binding has a convention row; allow-lists are exactly the rows' types: arguments `(int uptr size_t)`, results `(int uptr void)` in M1; each `foreign-procedure` form is the whole second argument of `bind-required` | ADR-0001 decision 10; plan §4.2 item 2 |
| K4 | No Scheme object crosses into C; every pointer is a `uptr`; every buffer is a counted block; no pointer is NULL, so a block is at least one byte | ADR-0001 decisions 4, 5 |
| K5 | Every block the library frees is wiped first, by one `sodium_memzero` call fused with the free; a dead block is refused unwiped | ADR-0008 decision 1 and amendment |
| K6 | No Scheme copy of a secret; a secret parameter is refused through `refuse-secret`, irritants `(RULE PARAMETER (kind K))`; no condition holds a secret; `shown-value` only for sizes, limits, preset names | ADR-0006 decision 6, amended; ADR-0008 decisions 3, 4 |
| K7 | Blocks are counted (`block` only); the count is zero when a suite exits; `free-foreign-block!` refuses an address that is not live before anything reaches `free` | ADR-0011 decision 1 |
| K8 | One load, in order, never fall through; the first failure is remembered, made serious and raised again; step 0 is `earlier-failure` | ADR-0002 decision 4; `load-state` |
| K9 | Every entry point is required (no optional); the floor is read from `sodium_version_string`; `sodium_init` 0 or 1 loads, else `init-failed`; every binding eager | ADR-0002, ADR-0003, plan §4.2 items 3, 12 |
| K10 | Tests assert reason, who and irritants, never a message; sentinels of their own; no expected `#f` from something that can raise; `let*` and `for-each` for order; every engine row references the library once before its first engine | plan §6 "Every brief restates these" |
| K11 | Comments are for a developer reading the code: no milestone, slice, research path, date, "the maintainer"; a bare `ADR-NNNN` is ours, a sibling's carries its repository name | AGENTS "Layout, process & libraries" |
| K12 | A child that reaches native code starts through `gated-command` and asserts `(valgrind . yes)` exactly when the gate asked; the wipe child alone runs outside, with `LD_PRELOAD` set to the interposer alone | ADR-0011 |
| K13 | `&who`: a helper raises with the WHO it is given; an internal invariant names its own procedure | ADR-0006, amended |

### Re-pointing record numbers in copied comments

v0.1.1's comments cite chez-sqlite3's records. Our records, for the same subject:

| v0.1.1 cites | Subject | Ours |
|---|---|---|
| ADR-0001 | bind directly | ADR-0001 |
| ADR-0002 | discovery and the load | ADR-0002 |
| ADR-0005 | the memory gate, counted blocks | ADR-0011 (counters); ADR-0008 (the wipe) |
| ADR-0008 | floors, one source | ADR-0011 |
| ADR-0009 | the public library and the seam | ADR-0012 |
| ADR-0011 | collect-safe, no Scheme memory, sections | ADR-0001 (types, no Scheme object, blocks); ADR-0007 (sections, the cap) |
| ADR-0013 | conditions, `shown-value` | ADR-0006 |
| ADR-0010, 0015, 0021 | threadsafe/connection, values, db_config/extensions | none: delete the sentence (those pieces are dropped) |
| `X-mN`, `M3`, "slice N", "(measured ...)" with a date or research path | | delete, or say the fact without the pointer (K11) |

A comment that must point at chez-sqlite3's own record (for example the origin of `bind-required`)
writes `chez-sqlite3 ADR-0011`, never the bare number.

---

## 1. Trim tables

"Kept" means copied with only the renames (`chez-sqlite3` to `chez-sodium`, `CHEZ_SQLITE3_*` to
`CHEZ_SODIUM_*`, `sqlite` to `sodium` where the text means the library) and the re-pointing above.

### 1.1 `src/chez-sodium/private/memory.sls` (from `memory.sls`, 97 lines)

| Piece (v0.1.1) | Status | What changes / what it protected |
|---|---|---|
| Header comment L2-28 | Changed | Renames; the refusal paragraph (L24-25) cites ADR-0006 and says sizes and addresses are named by `shown-value` (neither is a secret); gains one paragraph: `free-foreign-block!` takes the wipe and runs liveness check, wipe and free as one step (ADR-0008, amended); no mention of `libsqlite3` beyond "never loads libsodium" |
| `library` form, `export foreign-block free-foreign-block!` | Kept | Same two exports (`test-blocks` holds them whole) |
| `import`: `require-threaded`, `(rnrs)`, `(only (chezscheme) critical-section foreign-alloc foreign-free make-mutex with-mutex)`, `counters`, `conditions` | Kept | Exactly the plan's five Chez names; `guard`, `hashtable-ref` come from `(rnrs)`. Confirmed in §4 |
| `live`, `lock` | Kept | |
| `locked` | Kept | |
| `foreign-block` | Kept | Comments only. Its refusal of a size keeps `(shown-value size)` (a size, K6) |
| `free-foreign-block!` | **Changed** | New signature `(free-foreign-block! ADDRESS WIPE)`, design in §2.2. Also: the recorded size is read from `live`; `(WIPE ADDRESS SIZE)` runs after the liveness check and before `foreign-free`, all under `locked` inside the one `critical-section`; a WIPE that raises is caught there, the block is still freed, and the failure is raised after the section; a WIPE that is no procedure is refused before the section. A block that is not live is never wiped (ADR-0008, amended) |

Drops: none. (v0.1.1's "free-failure path" for a block PROC freed itself is **kept**, not dropped:
ADR-0008's amendment rejected dropping it, §2.2.)

### 1.2 `src/chez-sodium/private/native.sls` (from `native.sls`, 1025 lines)

| Piece (v0.1.1) | Status | What changes / what it protected, where it lives now, checked against |
|---|---|---|
| Header comment L2-144 | Changed | Rewritten for the five bindings and the one-section load (ADR-0002 order: choose, load, version entries, floor, `sodium_init`, rest). Drop the macOS sentence, the report paragraph, the collect-safe list (none in M1), the variadic and `sqlite-transient` paragraphs, the `ADR-0010/0015/0021` citations. The strings paragraph names `call-with-bytes`, `foreign-bytes`, `c-string->bytevector`, `c-string->string` only |
| `library` exports | Changed | The 13 names of §2.0. Not `foreign-block` or `free-foreign-block!` (ADR-0012 decision 7) |
| `import`: `require-threaded`, `(except (rnrs) dynamic-wind)`, `(only (chezscheme) …)`, `load-state`, `conditions`, `memory`, `discovery`, `verify` | Changed | The `(chezscheme)` list is the plan's 12 names, §4. Dropped imports: `libsqlite3-info` (no report record), `(only counters register-exit-check!)` and `memory-check` (no exit checks, ADR-0011 amended), `foreign-sizeof` |
| Step 0 `earlier-failure` | Kept | First definition of the body (K8); `test-native` reads it as data |
| `linux-machine?` | Kept | Used by `maps-text` (S0-F16: kept implicitly in the plan; stated here). Protects: reading `/proc/self/maps` only on Linux machine types |
| `maps-text` | Kept | Discovery's world input (ADR-0002); `K2`: `machine-type` stays native's |
| `loader-message` | Kept | The loader's text for `load-failed`'s detail |
| `required-entry` | **Changed** | Plan §2.1 says "without their report argument". It takes `(NAME WHERE)`, WHERE the pair `(PATH . SOURCE)` that step 1 chose, and raises `missing-api` through `raise-library-unavailable 'missing-api PATH SOURCE NAME '() MESSAGE (list PATH)`. Protects: Chez's bare "no entry for" (K9). WHERE replaces the top-level `libsqlite3-path`/`-source` references, which no longer exist when the section runs (§2.1, Flag F1) |
| `bind-required` (macro) | **Changed** | `(bind-required WHERE (foreign-procedure CONVENTION ... "ENTRY" (ARG ...) RESULT))` expands to `(begin (required-entry "ENTRY" WHERE) (foreign-procedure ...))`. The form stays the whole second argument (K3). Same fender: first identifier is `foreign-procedure`, entry a string literal. No `library` argument |
| `bind-optional` (macro) | **Dropped** | Protected Apple's missing `sqlite3_load_extension`. No libsodium entry is optional (ADR-0002 decision 4; every function bound exists at the floor, X-m3). Checked: K2/K3 (the convention checker's "stray reference" rule no longer needs `bind-optional`'s allowance, plan §2.2); K9 (strengthens it). The `foreign-entry?` import stays for `required-entry` |
| `sqlite-transient` | **Dropped** | SQLITE_TRANSIENT, a destructor pointer of all-ones. libsodium takes no destructor. Its `foreign-sizeof` import goes with it. Checked: K4 (no pointer-width constants anywhere now), K2 (`foreign-sizeof` leaves `library-only-chez-names` unless a later piece needs it) |
| `exact-natural?` | Kept | Used by `c-string->string`, `c-string->bytevector` (S0-F16, kept implicitly in the plan) |
| `check-who` | Kept | A WHO that is no symbol is refused from the helper (K13); its irritant is `(shown-value WHO)`: a WHO is a procedure name, never a secret |
| `holds-nul?` | **Dropped** | Protected `call-with-c-string` (C reads to the first NUL). No M1 piece hands C a string. Returns with `call-with-c-string` in M3, for the hash string only: a password may hold U+0000 (brief row 12), so it must never be applied to one. Checked: K4 (no C string is made in M1), K6 |
| `call-with-block` | **Changed** | `(free-foreign-block! made sodium-memzero)` replaces `(free-foreign-block! made)`; comments: the "Latent" paragraph names `call-in-section` as the catch-all guard every verb's block is made under (S0-F2), and drops the list of chez-sqlite3's guard sites. Behaviour otherwise v0.1.1's, including the refusal of a re-entry from the outer plain before thunk and the failed-free path |
| `call-with-c-string` | **Dropped** (M3) | The hash string and password writers. v0.1.1's makes two Scheme copies (`string-copy`, `string->utf8`), which ADR-0008 forbids for a secret. Checked: K6 (the reason it is not copied), K4. Owed to M3 (plan §4.2 item 6) |
| `c-string->string` | Kept | Reads `sodium_version_string` and, later, `crypto_pwhash_strprefix`. Its leading-U+FEFF restoration protected user text in SQLite messages; every string libsodium answers is ASCII (plan §4.2 item 7), so it protects nothing here, and is kept at no cost because the plan says keep it (Flag F8) |
| `c-string->bytevector` | Kept | Reads NUL-terminated C text undecoded; `c-string->string` reads through it |
| `foreign-bytes` | Kept | Copies a counted run out of a pointer: M2's outputs. Its irritants use `shown-value` on an address and a count (neither is a secret, K6) |
| `call-with-bytes` | **Changed** | No `bytevector-copy` (ADR-0008 decision 4): the loop reads the caller's bytevector in place, `n` read once. A non-bytevector is refused through `(refuse-secret WHO 'not-a-bytevector 'bytes BYTES)`, irritants `(not-a-bytevector bytes (kind K))` (S0-F5, K6). `check-who` and the PROC check keep their v0.1.1 irritants. Empty bytevector: block of one byte, written 0 (K4) |
| `call-with-out-pointer` | **Dropped** | Protected `sqlite3_open_v2`'s `sqlite3 **` slot. None of M1's five, nor Tier 1/2's functions, writes through an out-pointer: outputs go to caller-supplied blocks. Checked: K4 (no pointer is NULL: a slot was a block anyway), K5 (any later slot would be wiped by `call-with-block`), K2 (`foreign-sizeof` leaves with it) |
| `c-int?` | **Dropped** | Protected `int` arguments (Chez's `int` takes 2^31 to 2^32-1). No M1 binding takes an `int` argument (the five: `()`, `()`, `()`, `()`, `(uptr size_t)`). Checked: ADR-0001 decision 6 / AGENTS "every value fits its C type" is **kept**, and each verb that takes an `int` argument adds its own check; none exists yet. If one joins, `c-int?` returns with it |
| `call-with-int-cell` | **Dropped** | Protected `sqlite3_db_config`'s `int *` cell. Same reasons as `call-with-out-pointer`. Checked: K4, K5 |
| Step 1 `chosen` | **Changed** | Runs inside the section's thunk as a `let*` init, `(call-with-values (lambda () (choose-libsodium getenv (machine-type) (maps-text) file-exists?)) cons)`; no top-level `libsodium-path`/`-source` until the answers are defined (§2.1). `load-step` no longer wraps it alone |
| Step 2 `libsqlite3-loaded` | **Changed** | Inside the thunk: `(guard (e (#t (raise-library-unavailable 'load-failed PATH SOURCE (loader-message e) '() MESSAGE (list PATH)))) (load-shared-object PATH) #t)`; no `report` argument. The raise is taken by `call-in-section`'s guard, as data |
| Step 3 `raw-libversion-number` | **Dropped** | `sqlite3_libversion_number`: SQLite's integer version. libsodium's floor is read from the string (ADR-0003 amended); major and minor are libtool numbers, recorded, never compared. Checked: K9 (floor now only from the string); `test-verify` holds the string parse |
| Step 3 `raw-libversion` | **Changed** | Becomes `raw-version-string`: `(bind-required chosen (foreign-procedure "sodium_version_string" () uptr))`. Plus `raw-major`, `raw-minor` for `sodium_library_version_major` and `_minor` (`() int` each) |
| Step 3 `raw-sourceid` | **Dropped** | `sqlite3_sourceid`. libsodium has no counterpart. Nothing reads it |
| `answered-null` | **Dropped** | Refused a NULL `sqlite3_libversion` as `load-failed`. Now a NULL `sodium_version_string` reads as `#f` and `check-version` refuses it `below-floor` (ADR-0003 amended; S0-F16). Checked: K9 (the one rule "accepted only when read as three naturals at or above the floor"); `test-verify`'s `#f` row holds it |
| Step 3 `report` | **Dropped** | The `libsqlite3-info` record: five fields, opaque (a caller could not rebuild it with `record-rtd`). Replaced by the load's answers, an alist the thunk returns, and `loaded-libsodium`, which builds a fresh list per call. Checked: K6, K2 (no record, no `libsqlite3-info` library); opacity protected a shared mutable report; nothing shared is handed out now (§2.4), and `test-native` holds freshness |
| Step 4 `version-checked` | **Changed** | Inside the thunk, `(check-version version (car chosen) (cdr chosen))`, three arguments (`verify.sls`). Version read by `(c-string->string (raw-version-string))` |
| Step 5 `raw-threadsafe`, `threadsafe`, `threadsafe-checked`, `check-threadsafe` | **Dropped** | Refused a non-threadsafe SQLite. libsodium has no such query; `sodium_init` is thread-safe (ADR-0002 context) and the threaded Chez is `require-threaded`'s job (ADR-0004). Checked: K8/K9 (no load step needs it); ADR-0004's rule is held by `require-threaded` and `check-nothreads`, both kept |
| Step 6 `raw-initialize` | **Changed** | `raw-init`: `(bind-required chosen (foreign-procedure "sodium_init" () int))` |
| Step 6 `initialized` | **Changed** | `(let* ((init (raw-init)) (init-checked (check-init init PATH SOURCE))) ...)`: 0 and 1 load, anything else `init-failed`, the answer recorded. v0.1.1 refused any non-OK as `load-failed` |
| Step 7, the 44 SQLite bindings | **Dropped, except `sodium_memzero` new** | Each was a SQLite call. M1's one other binding is `raw-memzero`: `(bind-required chosen (foreign-procedure "sodium_memzero" (uptr size_t) void))`. Each later milestone appends its own entry points to the let* (ADR-0002, amended). Checked: K3 (every dropped binding's convention row is dropped with it, plan §2.2) |
| Step 7 `sqlite3-load-extension`, `load-extension-available?` | **Dropped** | The optional entry and its record; see `bind-optional` |
| Step 8 `memory-baseline`, `memory-check-registered`, `register-exit-check!`, `make-memory-check` | **Dropped** | `sqlite3_memory_used` leak check at exit. libsodium has no counter (ADR-0011 amended). Checked: K7: the block count at exit is `suite-exit-status`' check and is **kept** |
| `loaded-libsqlite3` | **Changed** | `loaded-libsodium` (§2.4): fresh list per call |
| `loaded-threadsafe` | **Dropped** | With the threadsafe step |
| New: `call-in-section` | New | §2.3 |
| New: `sodium-version` | New | §2.4 |
| New: the five raw exports | New | §2.0, §2.1 |

Counting every "Dropped" cell above that stands for a v0.1.1 piece: see §5 for the total.

### 1.3 `tests/test-blocks.sps` (from `test-blocks.sps`, 296 lines)

| Piece (v0.1.1) | Status | What changes / what it protected |
|---|---|---|
| Header comment L2-37 | Changed | Renames; the child runs through `gated-command` (`CHEZ_SODIUM_GATE_CHILD`); refusals named by `shown-value` (K6: sizes and addresses). Add: a WIPE stub is the suite's own, memory never loads libsodium |
| Imports | Changed | `(chez-sodium private counters)`, `(chez-sodium private memory)`, `(chez-sodium-testing)`, `(only (chezscheme) foreign-ref foreign-set! getenv library-exports disable-interrupts enable-interrupts)` as v0.1.1 |
| runner, simple-end printer | Kept | |
| `raised`, `poke!`, `peek`, `iota-from`, `sorted-names` | Kept | |
| `zero-counts`, `counts-with` | Changed | `zero-counts` is `((block . 0))`; the connection and statement kinds are gone (`native-kinds` is `(block)`) |
| `with-block` | Changed | Frees with the suite's stub: `(free-foreign-block! block no-wipe)`, `no-wipe` = `(lambda (address size) #f)` |
| Row: exports exactly two | Kept | |
| Row: `foreign-block` an address, counted, freed | Changed | `(free-foreign-block! block no-wipe)` |
| Row: writable over its whole size | Kept | |
| Row: refuses a non-positive size | Changed | Counts `zero-counts`. Irritants unchanged (sizes by `shown-value`) |
| Row: two blocks live | Changed | Two-argument frees; one-byte block row kept |
| Row: refuses non-address `'x`, `"4096"` | Changed | `(free-foreign-block! 'x no-wipe)`; irritants `(x)` and `((kind string))` unchanged. Protects: an address that is no integer never reaches `free` |
| Dead-address child, program text and `valgrind-line` | Changed | The child frees with a counting stub and prints how many times the stub ran. Expected stdout: `((free-foreign-block! that-block) (free-foreign-block! (4096)) ((block . 0)) (wipe-calls . 1))` then the valgrind line. The 1 is the live block's own free: **both dead frees left the stub uncalled**. The child still runs through `gated-command` (K12) |
| `interrupt-depth`, `handler-depth` | Kept | |
| Row: not-live raised after the section, depth 1 | Changed | Two-argument call |
| Row: double-free raised after the section, depth 1 | Changed | Two-argument call; the stub runs once (the block was live) |
| Row: failed malloc raised after the section | Kept | |
| Row: every count zero at the end | Kept | |
| New rows W1 to W8 | New | §3.1 |

Drops: none.

### 1.4 `tests/test-native.sps` (from `test-native.sps`, 2779 lines; line numbers are the copy's)

| Group (v0.1.1) | Status | What changes / what it protected, where it lives, checked against |
|---|---|---|
| Header L1-128 | Changed | Rewritten for this suite's groups (§3.2); drop the "the 21 / the five / the three" paragraphs and the collect-safe paragraph |
| Imports L116-127 | Changed | `(rnrs)`, `(rnrs eval)`, `(rnrs mutable-pairs)` (freshness rows), `(srfi :64)`, `(only (chezscheme) foreign-ref foreign-set! getenv machine-type void library-exports disable-interrupts enable-interrupts make-engine)`, `(chez-sodium-testing)`, `(libsodium-oracle)`, `counters`, `memory`, `discovery`, `(only conditions chez-sodium-error?)`. Dropped: `libsqlite3-info`, `constants`, `foreign-sizeof`, `fork-thread`, `make-mutex`, `with-mutex`, `collect-rendezvous`, `sleep`, `make-time`, `foreign-entry?` |
| runner, printer L129-143 | Kept | |
| `native-load`, `counts-after-load`, `native-procedure` L145-166 | Kept | `native-load` is the one reference before any engine (K10) |
| The 44 `(define sqlite3-… (native-procedure …))` L167-218 | **Dropped** | Aliases of SQLite bindings. Replaced by aliases of the 13 exports (§2.0). Checked: K10 |
| `info`, `zero-counts`, `counts-with`, `in-order`, `raised`, `poke!`, `peek`, `make-list-of`, `with-block` L222-282 | Kept, `with-block` Changed | `zero-counts` is `((block . 0))`; `with-block` frees with a no-op wipe stub (as §1.3) |
| `code-of`, `ok`, `cantopen`, `ioerr`, `error-code`, `range`, `toobig`, `readwrite-create` L284-299 | **Dropped** | SQLite result codes from `(chez-sqlite3 private constants)`. libsodium's codes are stated by the brief and confirmed by row 22 in M2/M3. M1's one code is `sodium_init`'s 0 and 1, asserted as literals. Checked: K10 (literals, not a table) |
| `sorted-names` L301 | Kept | |
| `maps-text`, `expected-choice`, `expected-path` L307-335 | Changed | `CHEZ_SODIUM_LIBRARY`, `choose-libsodium` |
| `errstr-codes`, `read-compile-options`, `oracle-options`, `option-name` L337, L355-364, L380-392 | **Dropped** | SQLite's `errstr` and compile options. Nothing in libsodium's five answers resembles them |
| `oracle`, `read-by-oracle`, `reported` L340-378 | Changed | `(libsodium-oracle getenv expected-path)`; `reported` answers `version`, `major`, `minor`, `init` (§3.2 A8) |
| Row "loads, reached through eval" L398 | Kept | |
| Row "every count zero once the load has returned" L402 | Kept | |
| Row "exports exactly …" L407 | Changed | The 13 names, written out |
| Row "loaded-libsqlite3 … the same one at every call" L427 | Changed | Inverted: a fresh list, fresh strings, per call (§2.4). v0.1.1's `eq?` held an opaque shared record; ours must not share (K6 spirit) |
| Row "the report is opaque" L436 | **Dropped** | Protected the opaque record. No record exists; the freshness row (A4) is the protection. Checked: K6 |
| Rows "chose a path", "the report's path and source", "the C oracle read the library" L443-455 | Kept, renamed | |
| Per-field oracle loop L457-462 | Changed | Fields `version major minor init` |
| Row "sqlite3-compileoption-used" L464 | **Dropped** | SQLite option names |
| `open-with`, rows "open :memory:", "open fails" L474-524 | **Dropped** | Proved the first bindings answer. Replaced by the five-binding rows A11-A13 |
| "the 21": `with-memory`, `prepare`, `with-statement`, `read-bytes`, `column-*-bytes`, `flonum-bits`, `with-bytes`, `text-of`, all rows L526-842 | **Dropped** | Statement tier. Nothing here prepares a statement. Checked: K3 (no convention row, dropped with the bindings) |
| "a length past 32 bits" L843-865 | **Dropped** | `sqlite3_bind_*64` lengths. Chez's `size_t` lengths are an M2 concern (the 64 KiB cap, a verb's own row). Checked: ADR-0001 decision 6 (range checks are each verb's, before its section) |
| "the copy: SQLITE_TRANSIENT" and "transient against the header" L866-918 | **Dropped** | See `sqlite-transient` |
| "every column read, against the oracle" L920-1096 | **Dropped** | SQLite columns |
| "the change counters, autocommit and interrupt" L1098-1400 | **Dropped** | SQLite counters |
| "the settings and extension calls" L1402-1610 | **Dropped** | `db_config`, `sqlite3_free`, `load_extension` |
| "call-with-c-string and c-string->string" L1612-1801: the `call-with-c-string` rows (L1631-1730, L1762-1801) | **Dropped** (M3) | Return with the helper |
| c-string rows: "answers #f for NULL, refuses what is no address" L1731, "EF BB BF" L1747 | Kept | They test `c-string->string` alone (Flag F8) |
| "call-with-out-pointer" L1803-1870, "call-with-int-cell" L1872-1962 | **Dropped** | See those helpers |
| "call-with-bytes, foreign-bytes, c-string->bytevector" L1964-2135 | Kept, `call-with-bytes` rows Changed | Rows: block contents, raise/escape frees, re-entry: kept. "refuses what is no bytevector" L2050: **Changed** to `refuse-secret`'s shape (A symbol's irritant is `(kind symbol)`, never the symbol): §3.2 B4. `foreign-bytes` L2074-2106 and `c-string->bytevector` L2108-2135: kept |
| "raised after the section" helpers and rows L2137-2215 | Changed | `interrupt-depth`, `handler-depth`, `reentered` kept. The `call-with-c-string`/`call-with-out-pointer` row L2184 and `call-with-int-cell` row L2191: **Dropped**. The `call-with-bytes` row L2205: **Changed** (refuse-secret shape for the string argument) |
| PROC-frees-its-block rows L2216, L2229 | `call-with-bytes` one **Changed**, `call-with-c-string` one **Dropped** | The kept row must now show the dead block refused **unwiped**: §3.2 D2 and §5 Flag F3 (how it is held) |
| "the body, read as data" L2242-2540 | **Rewritten** | The body now has one load definition, not a list of top-level `load-step` defines: reader helpers kept (`native-body`, `occurs?`, `has-subform?` reading elements never tails, `foreign-forms`, `c-name`, `definition-of`); rows replaced by §3.2 E1-E9. `numbers-in` and the `sqlite-transient` row **Dropped** with that piece |
| "__collect_safe: sqlite3_open_v2 on a FIFO" L2542-2635, "sqlite3_load_extension on a FIFO" L2636-2764 | **Dropped** | Held C binding conventions for collect-safe calls. M1 binds nothing collect-safe (plan §2.2, S0-F16). M3 adds `crypto_pwhash_str` and its FIFO decoy row (row 19). Checked: K3 (the convention table forbids `__collect_safe` on every M1 row, since each row has convention `plain`: held by `test-conventions`) |
| "every count is zero at the end", `test-end`, `(exit …)` L2773-2779 | Kept | `check-suites` needs the exit line |

### 1.5 `tests/libsodium-oracle.c` (from `libsqlite3-oracle.c`, 477 lines)

| Piece | Status | What changes / what it protected |
|---|---|---|
| Header comment | Changed | One mode; no `--rows`, `--transient`, `--counters` text |
| Includes | Changed | `<sodium.h>` for prototypes only (no link, no `-I`: `C_INCLUDE_PATH`); `<dlfcn.h> <stdio.h>`; `<string.h>` for `under_valgrind` |
| `put_quoted` | Kept | `#f` for NULL |
| `under_valgrind` | Kept | Prints `(valgrind . yes)` or `no` |
| `find` | Changed | Becomes the sketch's `FIND` macro: `__typeof__(&name) var = (__typeof__(&name)) dlsym(lib, #name)`: typed by the header so `-Wall -Werror` holds each call to the header's prototype |
| `--rows`, `--transient`, `--counters` modes, `put_bytes`, `hex`, `step_all`, column readers | **Dropped** | SQLite. M3 brings a hex mode (row 4) when passwords need to cross a shell; nothing here needs it |
| compile-options loop, `errstr` loop | **Dropped** | SQLite |
| `main` | Changed | `libsodium-oracle PATH` only (§2.8) |

### 1.6 `tests/libsodium-oracle.sls` (from `libsqlite3-oracle.sls`, 164 lines)

| Piece | Status | What changes |
|---|---|---|
| Header | Changed | One mode; "the gate takes a child named libsodium-oracle" (ADR-0011); no measured-Valgrind claim copied unless re-measured |
| Exports | Changed | `libsodium-oracle oracle-fields c-compiler split-words` |
| `oracle-fields` | Changed | `'(version major minor init)`; `valgrind` stays outside it, as v0.1.1 |
| `split-words`, `c-compiler` | Kept | |
| `libsqlite3-oracle` | Changed | `(libsodium-oracle getenv path)`, no codes |
| `libsqlite3-oracle-rows`, `-transient`, `-counters`, `utf8-hex` | **Dropped** | SQLite modes; `utf8-hex` served the hex arguments. Returns in M3 with the hex mode |
| `oracle-answer`, `run-oracle` | Kept | Compile with `-Wall -Werror -o DIR/libsodium-oracle tests/libsodium-oracle.c -ldl`; run through `gated-command`; the datum check is `(car datum)` equals the field, so `(init 0 1)` passes as a list datum |
| `read-all` | Kept | |

### 1.7 `tests/preflight.sps` (from `preflight.sps`, 79 lines)

| Piece | Status | What changes |
|---|---|---|
| Header | Changed | §2.9 |
| Imports | Changed | `(rnrs)`, `(only (chezscheme) eval environment)`, `conditions`, `counters`. `libsqlite3-info` dropped |
| `say`, `or-none`, `say-counts` | Kept | |
| Refusal branch | Changed | Prints reason, path, source, detail, candidates, remedy, counts. **Drops** the `(when library …)` branch: no report is carried on a refusal (ADR-0006: five fields) |
| Accepted branch | Changed | `loaded-libsodium` read through `eval` in native's environment; prints path and source, the version string with `major.minor`, counts |

### 1.8 `manifest.scm` and `packaging/debian-prereqs.txt` (comments only)

| Piece | Status | What changes |
|---|---|---|
| `manifest.scm` comment on `libsodium` and `gcc-toolchain` | Changed | Say they serve `test-constants`, the oracle, the decoy and the interposer. The plan names `packaging/manifest.scm`: the file is at the repo root (Flag F9) |
| `debian-prereqs.txt` `libsodium-dev` comment | Changed | Add that `libsodium23` is what `main`'s suites load; no new package. No floor text, so `check-floors` is not touched |

---

## 2. Design note

### 2.0 Native's exports (the plan does not fix them; this is the proposal, Flag F2)

```
loaded-libsodium sodium-version
sodium-version-string sodium-library-version-major sodium-library-version-minor
sodium-init sodium-memzero
call-in-section call-with-block call-with-bytes foreign-bytes
c-string->bytevector c-string->string
```

Thirteen names. The five raw bindings follow v0.1.1's habit of exporting each raw binding to its
suite. `(chez-sodium)` re-exports `sodium-version` alone (slice 4). Neither `foreign-block` nor
`free-foreign-block!` is exported (ADR-0012 decision 7).

Typed Racket style signatures, written above each definition:

```
;; loaded-libsodium : -> (List (Pair 'path String) (Pair 'source Symbol) (Pair 'version String)
;;                            (Pair 'major Integer) (Pair 'minor Integer) (Pair 'init Integer))
;; sodium-version : -> String
;; sodium-version-string : -> Natural          ; const char *, an address
;; sodium-library-version-major : -> Integer
;; sodium-library-version-minor : -> Integer
;; sodium-init : -> Integer
;; sodium-memzero : Positive-Integer Natural -> Void
;; call-in-section : (-> A) -> A
;; call-with-block : Symbol Positive-Integer (Positive-Integer -> Any) (Positive-Integer -> A) -> A
;; call-with-bytes : Symbol Bytevector (Positive-Integer -> A) -> A
;; foreign-bytes : Natural Natural -> Bytevector
;; c-string->bytevector : Natural -> (U Bytevector #f)
;; c-string->string : Natural -> (U String #f)
;; memory.sls:  foreign-block : Positive-Integer -> Positive-Integer
;;              free-foreign-block! : Positive-Integer (Positive-Integer Positive-Integer -> Any) -> Void
```

### 2.1 The load in one section (ADR-0007 decision 9)

**Body order** (the order the library evaluates, so the order at run time):

1. `earlier-failure`, the first definition: `(let ((failure (load-failure))) (when failure (raise failure)) #f)`. Outside the section: a raise at the body's start (K8).
2. The helpers, as plain definitions: `call-in-section`, `linux-machine?`, `maps-text`, `loader-message`, `required-entry`, the `bind-required` macro, `exact-natural?`, `check-who`, `call-with-block`, `c-string->string`, `c-string->bytevector`, `foreign-bytes`, `call-with-bytes`. `call-with-block` refers to `sodium-memzero`, defined later: a reference inside a lambda, run only after the body finishes.
3. One definition, `load-answers`:

```scheme
(define load-answers
  (load-step
   (call-in-section
    (lambda ()
      (let* ((chosen (call-with-values
                      (lambda () (choose-libsodium getenv (machine-type) (maps-text) file-exists?))
                      cons))                                           ; (PATH . SOURCE)
             (libsodium-loaded
              (guard (e (#t (raise-library-unavailable
                             'load-failed (car chosen) (cdr chosen) (loader-message e) '()
                             "the loader refused this libsodium; name one this Chez can load with CHEZ_SODIUM_LIBRARY, an absolute path"
                             (list (car chosen)))))
                (load-shared-object (car chosen))
                #t))
             (raw-version-string
              (bind-required chosen (foreign-procedure "sodium_version_string" () uptr)))
             (raw-major
              (bind-required chosen (foreign-procedure "sodium_library_version_major" () int)))
             (raw-minor
              (bind-required chosen (foreign-procedure "sodium_library_version_minor" () int)))
             (version (c-string->string (raw-version-string)))          ; #f for NULL
             (major (raw-major))
             (minor (raw-minor))
             (version-checked (check-version version (car chosen) (cdr chosen)))
             (raw-init (bind-required chosen (foreign-procedure "sodium_init" () int)))
             (init (raw-init))
             (init-checked (check-init init (car chosen) (cdr chosen)))
             (raw-memzero
              (bind-required chosen (foreign-procedure "sodium_memzero" (uptr size_t) void))))
        (list (cons 'path (car chosen)) (cons 'source (cdr chosen))
              (cons 'version version) (cons 'major major) (cons 'minor minor) (cons 'init init)
              (cons 'sodium-version-string raw-version-string)
              (cons 'sodium-library-version-major raw-major)
              (cons 'sodium-library-version-minor raw-minor)
              (cons 'sodium-init raw-init)
              (cons 'sodium-memzero raw-memzero)))))))
```

4. Top-level definitions from that data (nothing here can raise, so no `load-step`):

```scheme
(define (answer key) (cdr (assq key load-answers)))   ; every element is a pair
(define libsodium-path (answer 'path))   (define libsodium-source (answer 'source))
(define libsodium-version (answer 'version))
(define libsodium-major (answer 'major)) (define libsodium-minor (answer 'minor))
(define libsodium-init (answer 'init))
(define sodium-version-string (answer 'sodium-version-string))   ; ... the other four likewise
(define sodium-library-version-major (answer 'sodium-library-version-major))
(define sodium-library-version-minor (answer 'sodium-library-version-minor))
(define sodium-init (answer 'sodium-init))
(define sodium-memzero (answer 'sodium-memzero))
```

5. `loaded-libsodium`, `sodium-version` (§2.4).

**What each step does inside the section**

- Every refusal (`invalid-override`, `not-found` from `choose-libsodium`; `load-failed` from the guard; `missing-api` from `required-entry`; `below-floor` from `check-version`; `init-failed` from `check-init`) is raised by our own pure code inside the thunk, caught by `call-in-section`'s catch-all guard as data, and **raised again after the section** with the same object. `load-step`, outside the section, then makes it serious, records it, and raises it: a caller's handler runs at depth 1 (probed, §6). A second reference raises the recorded condition at step 0 (probed).
- `bind-required` takes `chosen`, the `(PATH . SOURCE)` pair, as its first argument and the whole form as its second. Its fender is v0.1.1's. The `foreign-procedure` form is evaluated only after `load-shared-object` and `required-entry`, because it is a `let*` init that follows them: every binding is eager (K9). Evaluating `foreign-procedure` inside a critical section inside the thunk works (probed).
- `sodium_init` runs in the section (ADR-0007 decision 9: "dlopen, every bind and `sodium_init`" are in it). 0 and 1 load.
- Each later milestone appends `(raw-X (bind-required chosen (foreign-procedure ...)))` inits after `raw-memzero`, and one `(cons 'NAME raw-X)` to the answers.
- **Nothing in the thunk raises through an interrupt-enabled handler**: `critical-section` holds interrupts off for the whole load, so an engine spends no ticks inside; only an abandon before the section starts can wedge the library (the plan's measured window of about 11 ticks at fuel 1; documented limit).

**Who reads the forms.** `test-conventions` reads "every list headed by `foreign-procedure` anywhere" (v0.1.1's scan nests through `let`, `lambda` and vectors). Here the five forms are `let*` inits, not top-level definitions of a `load-step`: the conventions agent must not expect `(define NAME (load-step (bind-required …)))` (Flag F1). `test-native`'s body-as-data rows are rewritten (§3.2 E1-E9).

### 2.2 The wipe fused with the free (ADR-0008, amended)

**`memory.sls`:**

```scheme
;; free-foreign-block! : Positive-Integer (Positive-Integer Positive-Integer -> Any) -> Void
;; Frees the live block at ADDRESS after WIPE has been called with ADDRESS and the size
;; foreign-block recorded, and counts it down: one step in one critical section, the
;; table's lock held. An address that is not a live block is refused and WIPE is never
;; called: the block may already be freed. A WIPE that raises is caught inside the section,
;; the block is still freed and counted down, and the failure is raised after the section.
;; WIPE must not call back into this library.
(define (free-foreign-block! address wipe)
  (unless (procedure? wipe)
    (assertion-violation 'free-foreign-block! "a wipe is a procedure" (shown-value wipe)))
  (let ((outcome
         (critical-section
          (let ((step (locked lock
                        (lambda ()
                          (let ((size (hashtable-ref live address #f)))
                            (if (not size)
                                '(not-live)
                                (let ((wiped (guard (c (#t (list 'wipe-failed c)))
                                               (wipe address size)
                                               #f)))
                                  (hashtable-delete! live address)
                                  (foreign-free address)
                                  (or wiped '(freed))))))))
            (if (eq? (car step) 'not-live)
                step
                (let ((counted (guard (c (#t (list 'double-free c)))
                                 (count-down! 'block)
                                 #f)))
                  (cond ((eq? (car step) 'wipe-failed) step)
                        (counted counted)
                        (else step))))))))
    (case (car outcome)
      ((not-live) (assertion-violation 'free-foreign-block! "not a live block" (shown-value address)))
      ((double-free wipe-failed) (raise (cadr outcome)))
      (else (if #f #f)))))
```

(A prototype of this body ran in `build/slice2-load/lib/probe/memory.sls`; §6.) Choices beyond the
plan's text, each for a rule: WIPE guarded because nothing raises inside a section (K1); the
table entry deleted after the wipe and before the free, under the lock, so a second thread's free
of the same address finds it not live and is refused unwiped (K5, K7); the wipe-failure raised in
preference to a double-free (the first failure). A builder who prefers the free outside the lock,
as v0.1.1 had it, may: `test-blocks` cannot tell them apart (Flag F4).

**`native.sls`'s `call-with-block`:** in the critical after thunk, `(free-foreign-block! made sodium-memzero)` replaces v0.1.1's `(free-foreign-block! made)`, inside the same `guard` that records `free-failure`. `sodium-memzero` is the plain binding `(uptr size_t) void`; memory still holds no `foreign-procedure` (K2). Nothing else wipes: not a wrapper of PROC, not `fill!`, not a `foreign-set!` loop.

**The PROC-frees-its-block rows.** PROC frees the block itself, `(free-foreign-block! address no-wipe)`; the after thunk's `(free-foreign-block! made sodium-memzero)` finds no live block, refuses it unwiped, and the refusal is raised after `call-with-block`'s extent at depth 1. Held, per §3.2 D2:
- the refusal (`free-foreign-block!`, irritants `(ADDRESS)`), depth 1, counts zero: any run;
- **never written after free: only under the gate.** I measured (§6): the plan's S0-F1 mutant (wipe placed in `call-with-block` before the free, over a dead block) passes a plain run and fails `valgrind` with "Invalid write of size 1" at `memset` in `__explicit_bzero_chk`; the fused design is clean under the same Valgrind. So that mutant is killed by `make test-memory MEMORY_SUITES=tests/test-native.sps` alone, and the suite's header must say so (Flag F3). `test-blocks` kills the unit-level analogue (W3: a dead address never reaches WIPE).

### 2.3 `call-in-section`

```scheme
;; call-in-section : (-> A) -> A
;; THUNK's answer, run in one critical section. A raise inside, of any object, is caught
;; there and raised again, the same object, once the section has ended: a handler of it
;; runs with interrupts enabled. THUNK answers data; for a verb the guard is a net for a
;; bug, not a channel (ADR-0007 decision 7).
(define (call-in-section thunk)
  (let ((outcome (critical-section
                  (guard (c (#t (list 'raised c)))
                    (list 'answered (thunk))))))
    (if (eq? (car outcome) 'answered)
        (cadr outcome)
        (raise (cadr outcome)))))
```

The tags are a two-element list built per call, so a THUNK answer shaped like `(raised x)` is returned as an answer, never raised (row C1). It is also the catch-all guard that keeps `call-with-block`'s re-entry refusal latent: probed (§6), under it an outer guard that does not match receives the caller's own object; bare `call-with-block` gives the refusal.

### 2.4 `loaded-libsodium` and `sodium-version`

```scheme
;; loaded-libsodium : -> (List (Pair 'path String) ... (Pair 'init Integer))   [§2.0]
(define (loaded-libsodium)
  (list (cons 'path (string-copy libsodium-path))
        (cons 'source libsodium-source)
        (cons 'version (string-copy libsodium-version))
        (cons 'major libsodium-major)
        (cons 'minor libsodium-minor)
        (cons 'init libsodium-init)))
;; sodium-version : -> String
(define (sodium-version) (string-copy libsodium-version))
```

Every call builds fresh pairs and fresh strings, so nothing a caller does to an answer reaches the next. No section (ADR-0007 decision 8). `source` is a symbol and the numbers are immediate.

### 2.5 `call-with-bytes`

```scheme
;; call-with-bytes : Symbol Bytevector (Positive-Integer -> A) -> A
(define (call-with-bytes who bytes proc)
  (check-who 'call-with-bytes who)
  (unless (bytevector? bytes)
    (refuse-secret who 'not-a-bytevector 'bytes bytes))
  (unless (procedure? proc)
    (assertion-violation who "not a procedure" (shown-value proc)))
  (let ((n (bytevector-length bytes)))
    (call-with-block who (max 1 n)
      (lambda (block)
        (if (= n 0)
            (foreign-set! 'unsigned-8 block 0 0)
            (let loop ((i 0))
              (when (< i n)
                (foreign-set! 'unsigned-8 block i (bytevector-u8-ref bytes i))
                (loop (+ i 1))))))
      proc)))
```

Irritants of the secret refusal: `(not-a-bytevector bytes (kind K))`, `K` from `kind-of` of the value whatever it is, never its length (K6). A prototype ran: `(call-with-bytes 'v 'hunter2 …)` raised `v` with `(not-a-bytevector bytes (kind symbol))` (§6).

### 2.6 The body-as-data rows (ADR-0012 decision 7)

`native-body` is read as v0.1.1 reads it: `(read)` of the file, `(cddddr form)`. Over it:

- every top-level form is scanned except `(define (call-with-block …) …)`; none may mention `foreign-block` or `free-foreign-block!` (`occurs?` over elements, never tails);
- `call-with-block`'s definition mentions each (non-vacuity, so deleting the call fails the row);
- the library's `export` list mentions neither (`library-exports` of `(chez-sodium private native)` has neither: also in A3).

Rows E1 to E9 are in §3.2.

### 2.7 `test-wipe.sps` and `free-watch.c`

`tests/free-watch.c` is the review's `freewatch.c` (copied unchanged in behaviour; compiles clean under `-Wall -Werror -shared -fPIC … -ldl`): `watch_set(ptr, n)` names a block, `watch_verdict()` answers 0 not freed, 1 freed all zero, 2 freed holding a non-zero byte, read through `volatile`. Its header comment follows K11 (no probe or milestone reference).

**The parent** (`test-wipe.sps`, imports `(chez-sodium-testing)`, `(libsodium-oracle)` for `c-compiler`):
1. `call-with-temp-directory`; compile `tests/free-watch.c` to `DIR/libfreewatch.so` with `(c-compiler getenv)`, `-Wall -Werror -shared -fPIC -o … -ldl`, through `capture-command`.
2. Write the child program to `DIR/wipe-child.sps`.
3. Run **outside Valgrind**, not through `gated-command`:
   `(capture-command (list "env" "-u" "CHEZ_SODIUM_GATE_CHILD" (string-append "LD_PRELOAD=" SO) CHEZ "--libdirs" "src:tests:build/scheme-libs" "--program" CHILD SO))`.
   `-u` comes before the assignment (GNU `env`). `LD_PRELOAD` is set to the interposer alone, never appended: the parent's own holds Valgrind's preloads under the gate (ADR-0011 amended). The comment says why the child is outside the gate.
4. Assert: status 0, empty stderr, stdout equal to the whole expected text (§3.3).

**The child** imports `(chez-sodium private native)` and `memory` and loads the interposer with `load-shared-object` (already preloaded; the probe worked). It prints, as data, one line per row `(NAME VERDICT)`, then `(ld-preload . same)` when `(getenv "LD_PRELOAD")` equals the interposer path, `(valgrind . no)` from `/proc/self/maps` (as `test-blocks`' child), and `(counts ((block . 0)))`. A row fills its block with `#x41`, names it from **inside PROC** with `watch_set(block, size)`, and reads `watch_verdict()` after the call returns. Sizes 1, 33 and 40 are not word multiples: a wipe short by one byte leaves a `#x41`.

**The standing positive control** (K10 list): `control-unwiped` allocates with `foreign-block`, fills `#x41`, names it, frees it with `(free-foreign-block! b (lambda (a n) #f))`: verdict **2**. `control-never-freed` allocates, fills, names, **reads the verdict before freeing**: **0**, then frees it (count back to zero). So the interposer is shown able to say 2 and 0 in the same process, with no mutant.

### 2.8 `libsodium-oracle`'s one mode

`libsodium-oracle PATH` (exit 0; 1 on a load or lookup failure with a message on stderr; 2 on usage). It `dlopen`s PATH with `RTLD_NOW | RTLD_LOCAL`, finds each function with `dlsym` on that handle alone, typed by `__typeof__(&name)`, and prints, one datum per line:

```
(version . "1.0.22")     sodium_version_string(), #f for NULL
(major . 26)             sodium_library_version_major()
(minor . 4)              sodium_library_version_minor()
(init 0 1)               sodium_init() called twice: its first two answers
(valgrind . yes)         /proc/self/maps maps vgpreload_memcheck, else no
```

The three version functions are called before the first `sodium_init`, held to C's statement order by computing them before the `init` calls. Measured here: 1.0.22 `"1.0.22"`, 26, 4, `(init 0 1)`; a missing path exits 1 (§6). It prints no pointer, so the decoy's `volatile uintptr_t` rule does not apply.

### 2.9 `preflight.sps`'s output

Accepted, stdout, exit 0:

```
chez-sodium: libsodium loaded and accepted
  path:       /usr/lib/x86_64-linux-gnu/libsodium.so.23 (system)
  version:    1.0.18 (library 10.3)
  counts:     ((block . 0))
```

Refused, stderr, exit 1:

```
chez-sodium: libsodium refused
(reason . below-floor)
  path:       PATH-or-none
  source:     SOURCE-or-none
  detail:     DETAIL-or-none
  candidates: none   |   candidates:\n    PATH ...
  remedy:     the condition's message, or a fixed fallback naming CHEZ_SODIUM_LIBRARY
  counts:     ((block . 0))
```

The text is the contract slices 3 and 5 read (`check-dev.sh`, `check-sodium.sh --discovery` match the `path:` and `version:` lines). It reaches native only through `eval` inside the guard, for v0.1.1's reason (a program that imports native runs its body before the guard). Anything that is no `&sodium-library-unavailable` is left to Chez's default handler.

---

## 3. Rows and mutants

### 3.1 `test-blocks.sps`: new rows

| Id | Row | Killed by (mutant) |
|---|---|---|
| W1 | `free-foreign-block!` calls WIPE once with the address and the size `foreign-block` recorded, and `(native-counts)` read inside WIPE is `((block . 1))` (not yet counted down); after the call `((block . 0))` | wipe dropped; wipe after the count-down; wipe called twice |
| W2 | Sizes 1, 7, 4096: WIPE receives exactly each, though the caller never passes one | size taken from the caller or hard-coded |
| W3 | A freed address, and one never allocated: refused (`free-foreign-block!`, irritants `(ADDRESS)`), **WIPE never called** (log empty), counts zero | wipe before the liveness check (S0-F1 at unit level) |
| W4 | WIPE that is no procedure (`'x`, `#f`, `"w"` as `(kind string)`): refused `free-foreign-block!` irritants `(x)`, `(#f)`, `((kind string))` from `shown-value`, the block still live and counted; freed after by the row | `procedure?` check missing |
| W5 | WIPE that raises `'boom`: handler of it runs at depth 1 and receives `'boom` itself (`eq?`), the block is freed anyway (counts zero) and a second free is refused as not live | raise inside the section (depth 2); a failed wipe that skips the free |
| W6 | WIPE that raises, and a count taken away first (double-free): the wipe's failure is raised, not the double-free | order of failures |
| W7 | Dead-address child: stdout `… (wipe-calls . 1)` | W3 at process level |
| W8 | A WIPE that reads the block (`foreign-ref` of every byte) sees it live: under `make test-memory` an `Invalid read` would fail the suite | wipe after `foreign-free` (gate only) |

All guards around `free-foreign-block!` here are catch-all or handler-depth, never a clause that can fail to match.

### 3.2 `test-native.sps`: rows by group

Every row follows K10. Rows that call `call-with-block` or `call-with-bytes` directly use catch-all guards or `handler-depth`.

**A. The load against the oracle**
- A1 native loads, reached through `eval` (`'loaded`). A2 every count zero once the load has returned.
- A3 the exports, written out whole (13 names, §2.0), via `library-exports`; neither `foreign-block` nor `free-foreign-block!` in it.
- A4 `loaded-libsodium` is a fresh list per call: keys in order `(path source version major minor init)`; two calls `equal?` and not `eq?`; the two `version` strings not `eq?`; after `string-set!` on one call's `path` and `version` strings and `set-cdr!` on its `major` pair, a third call equals the first. (Kills a shared answer.)
- A5 this suite chose a path itself. A6 the report's path and source are the chosen ones. A7 the oracle read the library at that path; **A7b** the oracle ran under Valgrind exactly when the gate asked (v0.1.1 had this row only for the oracle modes now dropped).
- A8 per field, whole to the oracle: `version`, `major`, `minor` equal the oracle's; `init`: `(init RECORDED DIRECT)` equals the oracle's `(init 0 1)`, `RECORDED` read from `loaded-libsodium` and `DIRECT` from a call of `(sodium-init)` made after, under `let*`.
- A9 literal: in the oracle's fresh process `sodium_init` answers `(0 1)` (row 22; the oracle's own datum, not computed from native).
- A10 `sodium-version` equals the report's version and the oracle's; a fresh string per call (not `eq?`; mutating one leaves the next). A11 `(c-string->string (sodium-version-string))` equals the version; `sodium-library-version-major` and `-minor` equal the oracle's; (1.0.18's are 10 and 3, 1.0.22's 26 and 4: never equal, so a swapped pair shows).
- A12 `(sodium-init)` after the load answers 1, twice (`(1 1)`). Kills "never called" (a recorded constant would leave a first direct answer of 0) and a load that does not call it.
- A13 `sodium-memzero` zeroes exactly N bytes: a 16-byte block of `#x41`: N 16 gives sixteen 0, N 15 gives fifteen 0 then `#x41`, N 0 changes nothing; the answer is the unspecified value; counts zero after.

**B. The helpers**
- B1 `call-with-bytes` blocks: none gives one byte `0`, never NULL; `00`, `61 00 62`, `00 00 00`, `C3 A9 FF FE 80` as given; 5,000 bytes whole; one block counted while PROC runs, none after.
- B2 a raise from PROC, and an escape through a continuation, free the block. B3 re-entering PROC after the free raises from WHO with irritants `()`, PROC once.
- B4 refusals of a non-bytevector, each leading `(not-a-bytevector bytes (kind K))` from WHO, counts zero at the raise, PROC not run: `"hunter2"` (`string`), `'hunter2` (`symbol`), `12345` (`number`), `(list #\h #\u #\n #\t #\e #\r)` (`list`), `(vector 1 2)` (`vector`), `#f` (`boolean`). Each also: an assertion violation and no `&chez-sodium-error`; and the condition shown whole (`describe`) holds none of its secret's text. A PROC that is no procedure `(x)`, a WHO that is no symbol (from `call-with-bytes`, `((kind string))`). (Kills `shown-value` in place of `refuse-secret`: it would show the symbol, the number and the character list as they are.)
- B5 `call-with-bytes` writes the one byte for an empty bytevector itself: a block freed full of `#xFF` with `no-wipe`, then `call-with-bytes` of `#vu8()` reads `0` at the same address; skipped by name where malloc does not hand the block back, as v0.1.1's NUL row (Valgrind never reuses). Kills a copy that leaves the byte unwritten, which the plain "reads 0" row cannot see on fresh heap.
- B6 `foreign-bytes` (3 rows), `c-string->bytevector` (3 rows), `c-string->string` (2 rows), as v0.1.1. Freshness rows use non-empty answers (Chez shares its empty bytevector).

**C. `call-in-section`**
- C1 answers THUNK's value: `#f`, `0`, `'()`, `(list 'raised 5)`, a string; none is raised.
- C2 inside the section interrupts are off: `interrupt-depth` read in THUNK is 2, outside 1 before and after.
- C3 a raise of a symbol, a list, `#f`, a string and a condition: the handler of each runs at depth 1 and receives the same object (`eq?`).
- C4 S0-F2: an outer guard that does not match, around `(call-in-section (lambda () (call-with-bytes … (lambda (a) (raise 'mine)))))`, receives `mine`; the control around the bare `call-with-bytes` receives the refusal (irritants `()`). Both in one row.
- C5 engine: `call-in-section` around `call-with-bytes` of 64 bytes, at every fuel from 1 until the first fuel at which the job completes without expiring: every run answers `done`, raises nothing, `((block . 0))`. The row asserts the sweep reached a completing fuel (non-vacuous). Never asserts a count of expiries. (The completing fuel measured: 4.)
- C6 engine with a PROC that raises inside: `call-with-bytes`' raise is caught by a guard inside THUNK and answered as data, at every fuel; and a raising THUNK re-raises the same object at every fuel.

**D. After the section**
- D1 `call-with-bytes` re-entry refused outside its critical thunks (depth 1, PROC once); its argument refusals come before any and at depth 1: `"abc"` as `(not-a-bytevector bytes (kind string))`, a non-procedure `(x)`, WHO `42` from `call-with-bytes` `(42)`.
- D2 PROC frees its own block with `no-wipe`: the failed free is raised after the extent at depth 1, `(assertion-violation free-foreign-block! (ADDRESS))`, counts zero; and the row's header says the dead block is refused unwiped and that only the gate sees a write to it (§2.2).
- D3 the same through `call-in-section`: the refusal is re-raised after the outer section, handler depth 1.

**E. The body as data** (reads `src/chez-sodium/private/native.sls`)
- E1 the load is one definition: `(define load-answers (load-step (call-in-section (lambda () (let* …)))))`: a `define` whose value is `load-step` of `call-in-section` of a zero-argument lambda whose body is a `let*`; exactly one such form.
- E2 the `let*` steps in order, each as `(NAME HEAD names-used)`: `(chosen call-with-values)`, `(libsodium-loaded guard)`, `(raw-version-string bind-required chosen)`, `(raw-major bind-required chosen)`, `(raw-minor bind-required chosen)`, `(version c-string->string raw-version-string)`, `(major raw-major)`, `(minor raw-minor)`, `(version-checked check-version version chosen)`, `(raw-init bind-required chosen)`, `(init raw-init)`, `(init-checked check-init init chosen)`, `(raw-memzero bind-required chosen)`. (Each step moved, dropped or swapped changes the list.)
- E3 every `foreign-procedure` form: exactly five in the whole body, each the whole second argument of `(bind-required chosen …)` and directly the init of its `let*` binding (not inside a `lambda`): `(raw-version-string chosen "sodium_version_string")`, `(raw-major chosen "sodium_library_version_major")`, `(raw-minor chosen "sodium_library_version_minor")`, `(raw-init chosen "sodium_init")`, `(raw-memzero chosen "sodium_memzero")`. Kills a lazy binding and a sixth form.
- E4 the load's work is in that one section: `load-shared-object`, `choose-libsodium`, `check-version`, `check-init` and `bind-required` (as a call, not its macro definition) occur in no top-level form but `load-answers`' (and the `define-syntax` for the last).
- E5 the answers are top-level definitions `(define NAME (answer 'KEY))` for each exported raw binding, and `sodium-memzero`'s is the one `call-with-block` refers to.
- E6 the first definition is `earlier-failure`, calling `load-failure` and `raise`.
- E7 `foreign-block` and `free-foreign-block!` occur only inside `call-with-block`'s definition (and in it); the export list holds neither.
- E8 `call-with-block`'s definition holds exactly one `free-foreign-block!` form and its second element is `sodium-memzero`.
- E9 `call-with-bytes`' definition holds none of `bytevector-copy`, `bytevector-copy!`, `bytevector->u8-list`, `make-bytevector`, `utf8->string`, `string->utf8`, `subbytevector`.
- E10 `sodium-version`'s body is `(string-copy libsodium-version)` and `loaded-libsodium`'s builds its two strings with `string-copy`.

**F.** every count is zero at the end.

### 3.3 `test-wipe.sps`: the whole expected child output (in order)

```
(return-32 1) (return-33 1) (return-1 1) (raise 1) (escape 1)
(bytes-40 1) (empty-bytes-dirtied 1) (in-section 1) (direct-memzero 1)
(control-unwiped 2) (control-never-freed 0)
(ld-preload . same) (valgrind . no) (counts ((block . 0)))
```

`return-N`: `call-with-block` of N bytes, filled `#x41`, PROC names it and returns. `raise`: PROC names it, then `(raise 'x)` under a catch-all guard. `escape`: PROC names it then jumps out through a `call/cc` continuation. `bytes-40`: `call-with-bytes` of 40 non-zero bytes, PROC names the block. `empty-bytes-dirtied`: `call-with-bytes` of `#vu8()`; **PROC writes `#x41` over its one byte, then names the block of size 1** (as planned, the row would be undiscriminating: `call-with-bytes` writes 0 into that byte, so a dropped wipe still reads all zero; Flag F5). `in-section`: the `call-with-bytes` of 40 bytes inside `call-in-section`. `direct-memzero`: `foreign-block`, fill, `(free-foreign-block! b sodium-memzero)` through native's export.

### 3.4 Watched to fail (the plan's list, mapped; each is run as a mutant of the new code and must turn the named row red)

| Mutant | Red row(s) |
|---|---|
| The load's order: a step moved or dropped (read from the body, and by the oracle) | E2; A8/A12 for `sodium_init`; A8 for the version trio |
| `sodium_init` never called (a constant recorded instead) | A12 (first direct answer 0, not 1); A8 `init` |
| A binding made lazy (the form inside a lambda, or called on first use) | E3 |
| `call-with-block`'s block not freed on a raise or an escape | B2 (counts 1) |
| A re-entry let through (the outer before thunk refusing nothing) | B3, D1 |
| The wipe dropped | test-wipe: every wipe row reads 2 (probed: all seven) |
| The wipe shortened by one byte | test-wipe: every wipe row reads 2 (probed: all seven); A13 (N 15) for `sodium-memzero` itself |
| The wipe moved into a wrapper of PROC (plain code after PROC) | test-wipe: `raise` and `escape` rows 2, the rest 1 (probed) |
| The wipe over a dead block (S0-F1 placement) | **gate only**: `make test-memory MEMORY_SUITES=tests/test-native.sps` reports "Invalid write of size 1" (probed); W3 at unit level; E8 if the wipe is removed from the free's argument |
| `call-with-bytes` with `bytevector-copy` restored | E9 |
| NULL for an empty bytevector | B1 (pointer row) and the `0`-written row B5 |
| `call-in-section` without its section | C2; C5 (a resume refused as a re-entry at fuel 1: probed, the mutant fails at every fuel from 1 to 208 (the sweep ran to 400); the sectioned one at none) |
| `call-in-section` raising inside (no guard, or no re-raise) | C3 (handler depth 2); C4 |
| `call-in-section` with an in-band sentinel | C1 |
| The oracle's fields swapped | A8; A9 literal; its version, major, minor never coincide (§3.2 A11) |
| `shown-value` in place of `refuse-secret` | B4 |
| A helper in native calling `foreign-block` outside `call-with-block`; native exporting either name | E7; A3 |
| `loaded-libsodium`/`sodium-version` sharing their strings or pairs | A4, A10, E10 |
| Memory: WIPE called on a dead block / after the count-down / with a caller's size / not guarded / procedure check missing | W3 / W1 / W2 / W5 / W4 |

---

## 4. Import lists

**Native**, `(only (chezscheme) …)`, 12 names: `critical-section`, `display-condition`, `dynamic-wind`, `foreign-entry?`, `foreign-procedure`, `foreign-ref`, `foreign-set!`, `format`, `format-condition?`, `getenv`, `load-shared-object`, `machine-type`. **Confirmed, no difference** from the plan: `critical-section` is `call-in-section`'s; `dynamic-wind` (with `(except (rnrs) dynamic-wind)`) is `call-with-block`'s critical form `(dynamic-wind #t before body after)`; `foreign-entry?` is `required-entry`'s; `foreign-ref` is `c-string->bytevector`'s and `foreign-bytes`'; `foreign-set!` is `call-with-bytes`'; `format`, `format-condition?`, `display-condition` are `loader-message`'s; `getenv`, `machine-type`, `load-shared-object` are the load's. Not imported: `foreign-sizeof` (the dropped pieces were its only users: `sqlite-transient`, `call-with-out-pointer`, `c-int?`, `call-with-int-cell`), `void`, `fork-thread`, `with-mutex`. The prototype in `build/slice2-load/lib/probe/native.sls` compiled with exactly this list plus `(rnrs)`, and it uses `guard` and `string-copy` from `(rnrs)`.

Other imports of native: `(chez-sodium private require-threaded)` first (K2/ADR-0004), `(chez-sodium private load-state)`, `conditions`, `memory`, `discovery`, `verify`.

**Memory**, `(only (chezscheme) …)`, 5 names: `critical-section`, `foreign-alloc`, `foreign-free`, `make-mutex`, `with-mutex`. **Confirmed, no difference.** The new body uses `guard`, `hashtable-ref`, `hashtable-delete!` from `(rnrs)`. Other imports: `require-threaded` first, `counters`, `conditions`.

**Suites** import freely (K2 binds `src/` only): `test-native` adds `(rnrs mutable-pairs)` and `make-engine`.

---

## 5. Flags, and the drop count

**Drop count: 36 table rows marked Dropped** (native 16, test-native 16, oracle .c 2, oracle .sls 1, preflight 1; memory 0, test-blocks 0). Some rows group many pieces (the 44 SQLite bindings, the statement tier's rows, the threadsafe step's four names). Five more drops sit inside rows marked Changed: native's imports, test-native's imports, the two re-entry rows of v0.1.1's "raised after the section" group that served `call-with-c-string` and `call-with-int-cell`, and preflight's `libsqlite3-info` import. Every drop's cell names the rules it was checked against (K1 to K13, §0), or says why none applies.

**F1. `bind-required`'s shape, and the forms are no longer top-level definitions.** The plan says both "without their report argument" and "the whole second argument". With path and source local to the section's thunk, the macro cannot reference top-level `…-path` variables, so its first argument is `chosen`, the `(PATH . SOURCE)` pair. `(bind-required chosen (foreign-procedure …))` is a `let*` init inside `load-answers`, not `(define NAME (load-step …))`. The conventions agent's `test-conventions` scanner reads forms anywhere, but anything that expects the old top-level shape, and `check-seam` if it reads `bind-required`'s arity, needs telling.

**F2. Native's export list is not in the plan.** I propose 13 names (§2.0). The only choice the plan constrains: neither `foreign-block` nor `free-foreign-block!`.

**F3. The S0-F1 mutant is visible only under Valgrind.** A wipe over a dead block exits 0 in a plain run (probed). The PROC-frees rows hold the refusal, depth and counts in any run; "never written after free" holds only in `make test-memory` on that suite. The brief and Done criteria say "under the gate"; the builder must run the gated suite and record the mutant failing there. Optional strengthening (not in the plan): an interposer that poisons a freed block, so a late write is visible in a plain run.

**F4. Memory choices beyond the plan's text:** a WIPE that raises is guarded and the block still freed; a non-procedure WIPE is refused first; the lock is held through wipe and free (the ADR's "one step under memory's lock"; v0.1.1 freed outside it). Each has a row (W4, W5, W6). The owner may want the ADR to say the first two.

**F5. `test-wipe`'s empty-bytevector row, as planned, cannot fail.** `call-with-bytes` writes 0 into the one byte, so the block reads all zero with or without the wipe. The row must have PROC dirty the byte first (§3.3).

**F6. Load refusals are not observable in slice 2's suites.** Row 17's raise-after-section for the load needs a refused load, which is a child per case (slice 3). Slice 2 holds the shape (E1, E4) and my probe: handler depth 1, and the recorded failure raised again at the second reference. The Done criterion "refusing a missing one by reason" is checked by running `make build` with a bad override and recording the reason.

**F7. `call-with-block`'s refusals and the rule symbol.** ADR-0006's "rule symbol first" binds the public surface. The re-entry refusal (irritants `()`) and the helpers' PROC refusal (`(x)`) are internal and, under `call-in-section`, unreachable by a caller, so I keep v0.1.1's irritants (K13). If the owner wants uniformity, rows B3, D1 change.

**F8. `c-string->string`'s U+FEFF restoration protects nothing here** (every string libsodium returns is ASCII; plan §4.2 item 7 says so while keeping the function). Kept as the plan says, with its two rows. A candidate for a later drop.

**F9. The plan names `packaging/manifest.scm`; the file is `manifest.scm` at the repo root.** `packaging/` holds `debian-prereqs.txt` and `floors.sexp`.

**F10. The plan's `test-native` row for "the report against the oracle" has no `valgrind` row for the main oracle in v0.1.1** (only for modes now dropped). A7b adds it; otherwise a child that escaped the gate passes.

**F11. Record numbers** in every copied comment: §0's table. v0.1.1's `memory.sls` L1-28 cites 0005, 0011, 0013; `native.sls` cites 0001, 0002, 0005, 0009, 0010, 0011 (17 times), 0013, 0015 and 0021.

**F12. A WIPE contract.** `free-foreign-block!`'s WIPE must not call back into memory (it would find the table mid-update). Chez's mutexes are recursive so it would not deadlock, but the comment says it.

**F13. `check-seam` and rule (m):** unaffected by the new shape, except that `call-in-section`, `required-entry` and the macro are native-internal and export nothing a rule reads.

**F14. M2's owed item** "how row 24 reaches a verb's blocks" is unchanged by this design: `test-wipe`'s child uses `call-with-block` and `call-with-bytes`; a verb's own blocks are reached through a verb row then.

---

## 6. Probes run

All in the container, `scripts/guix-env sh -c '…'`; the files are in `build/slice2-load/` (`lib/probe/{memory,native,native-mut,native-drop,native-short,native-wrap}.sls`, `p1` to `p7.sps`, `wipe-child*.sps`, `free-watch.c`, `libfreewatch.so`). `$CHEZ --libdirs build/slice2-load/lib:src --program …` with `CHEZ_SODIUM_LIBRARY` at the container's 1.0.22.

| # | What | Got |
|---|---|---|
| 1 | The §2.1 load as one `call-in-section` thunk, importing the real `discovery`, `verify`, `load-state`, `conditions`, `counters`; `foreign-procedure` forms evaluated as `let*` inits inside the thunk after `load-shared-object` (`p1`) | Loaded; `loaded-libsodium` = path (override), version `"1.0.22"`, major 26, minor 4, `(init . 0)`; `(sodium-version)` twice not `eq?`; a direct `(sodium-init)` afterwards answers 1 |
| 2 | A refused load (override `""`, and a library without the entries: glibc's `libm.so.6`) and a handler read at depth (`p2`) | The first reference: handler at depth 1, condition who `chez-sodium`, irritants the path; the second reference: depth 1, the same recorded refusal |
| 3 | `call-in-section` raising a list, a continuable raise, and a plain answer (`p3`) | handler depth 1 and `eq?` to the raised object in both raises; the answer returned |
| 4 | Memory prototype with WIPE (`p4`): live free with a stub; the same address again; a raising WIPE; PROC frees its own block; `call-with-bytes` of a symbol | Stub ran once, for the live free only; the dead free raised `free-foreign-block!` with the address and did not call the stub; the raising WIPE raised at depth 1 (`boom`) and counts were zero; PROC-frees raised `free-foreign-block!` at depth 1, counts zero; the symbol gave `(v (not-a-bytevector bytes (kind symbol)))` |
| 5 | S0-F1 placement (wipe in `call-with-block` before the free, `native-mut`), the same `p4`, plain and under `valgrind -q` | Plain: identical output, exit 0. Valgrind: fused design silent; the mutant "Invalid write of size 1 … memset … __explicit_bzero_chk … block of size 3 free'd" |
| 6 | Outer guard that does not match around `call-with-bytes` whose PROC raises `mine` (`p6`) | Under `call-in-section`: `(caught mine)`. Bare: `(caught ())`, the re-entry refusal replacing the caller's object |
| 7 | Engine sweep, `call-in-section` over `call-with-bytes` of 64 bytes, fuels 1 to 400, plus a no-section variant (`p5`); and the first completing fuel (`p7`) | Sectioned: no bad fuel. No-section: wrong at every fuel from 1 to 208 (the answer is `(raised ())`, the refusal), right from 209 to 400. The sectioned job completes without expiry at fuel 4; 0 ms plain, 7 ms under Valgrind |
| 8 | The wipe child (`wipe-child.sps`, `libfreewatch.so` compiled with `$CC -Wall -Werror -shared -fPIC … -ldl`, `env LD_PRELOAD=… $CHEZ …`) | Real design: `return`, `return-odd`, `return-one`, `raise`, `escape`, `empty-bytes`, `bytes` all verdict 1; control-unwiped 2; control-never-freed 0 once read before freeing |
| 9 | The child against three mutants: wipe dropped, wipe short by one byte, wipe in a wrapper of PROC | Dropped: all seven wipe rows 2. Short: all seven 2. Wrapper: `raise` and `escape` 2, the others 1 |
| 10 | `oracle-sketch.c` compiled `-Wall -Werror … -ldl`, run on the container's library and on a missing path | `(version . "1.0.22") (major . 26) (minor . 4) (init 0 1)`, exit 0; missing path: message on stderr, exit 1 |

Not probed (stated, not claimed): the wipe child launched from a parent under Valgrind through `capture-command`'s `/bin/sh -c "'env' …"` (the plan's `gate-child.sps` probe used `system` with the same `env LD_PRELOAD=` shape and held); `make build`'s `preflight.sps` text; CI's Valgrind 3.22 on Ubuntu's 1.0.18.
