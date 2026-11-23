# Slice 1, the pure core: trim tables

Sources: chez-sqlite3 v0.1.1 (`960d9f0`), eight files. Plan: `.plans/2026-11-22-m1-plan.md` §2.1, §2.2,
§4.1 items 1 to 3, §6 slice 1. Records: ADR-0002, 0003, 0006, 0010 with their 2026-11-23
amendments; `.plans/global-constraints.md`; AGENTS.md.

Conventions in the tables:

- **kept**: copied with the renames of plan §2 and nothing else.
- **changed**: copied, and the "what changes" column says what.
- **dropped**: a drop row says what the piece protected, where that protection lives now, the
  citation, and the check of the reason against every rule the copy keeps ("vs kept").
- Names: `chez-sqlite3` to `chez-sodium`, `sqlite-` to `sodium-`, `libsqlite3-` to `libsodium-`.
  The v0.1.1 names are used in the "piece" column so a reader can find the source.
- Every new library imports `(chez-sodium private require-threaded)` first among its imports
  (ADR-0004; `test-require-threaded` scans `src/` and adds a row for each library on its own).
  None of the four imports a name from `(chezscheme)`. `conditions`, `discovery` and `verify`
  import `(rnrs)` and each other alone.
- Every ADR number in a copied comment is re-pointed (flag F1).

---

## 1. The eight tables

### 1.1 `private/conditions.sls`

| # | Piece | Disposition | For a change: what changes. For a drop: what it protected, where that lives now, citation, vs kept |
|---|---|---|---|
| c1 | Header comment | changed | Tree is ADR-0006's: root, `&sodium-library-unavailable`, `&sodium-failed`. Cites ADR-0006 (not ADR-0013) and ADR-0002. No "ADR-0010/0012/0014/0015/0017/0018/0019/0021" line survives. |
| c2 | `(require-threaded)`, `(rnrs)` imports | kept | |
| c3 | `(chez-sqlite3 private libsqlite3-info)` import | **dropped** | Protected: the `library` field's type check and the report the refusal carried. The field is gone (ADR-0006 gives five fields; plan §2.1; plan §4.2 item 4: major, minor and the rest live in native's `loaded-libsodium` on a load, and no condition carries them). Now: nothing; a refusal's `detail` is the version string. vs kept: no kept piece reads a report. `make-sodium-library-unavailable` and `raise-library-unavailable` lose the argument, so each caller (`discovery`'s `refuse`, `verify`'s `refuse`) drops it too. Both are in this slice. |
| c4 | `(only (chez-sqlite3 private constants) sqlite-result-code-name sqlite-primary-code-name)` import | **dropped** | Protected: naming SQLite's integer codes (`raise-sqlite-error`). `&sodium-failed`'s `code` is the raw integer libsodium answered (ADR-0006 decision 3, amended). vs kept: `refuse-field`, `checked-accessor` and `shown-value` need no table. `constants` is "never" in plan §3. |
| c5 | `&chez-sqlite3-error`, `make-`, `?` | kept | `&chez-sodium-error` under `&error`, fieldless. |
| c6 | `kind-of` | kept | Its kinds are `string list number boolean char symbol bytevector vector procedure other`. `refuse-secret` and `secret-shown` use it. Must stay total and never walk its argument: a circular list is `list` by `pair?`. |
| c7 | `shown-atom?`, `shown-value` | kept | Unchanged. AGENTS: for sizes, limits and preset names only. See F3 for the two internal users. |
| c8 | `checked-accessor` | kept | Unchanged, but see F3 (it shows symbols, numbers and char lists). |
| c9 | `sqlite-library-unavailable-reasons` | changed | `'(invalid-override not-found load-failed below-floor missing-api init-failed)`, ADR-0002 decision 6's order. `not-threadsafe` out, `init-failed` in. The detail table in the comment: `init-failed`'s detail is the integer `sodium_init` answered (plan §4.2 item 12). |
| c10 | `&sqlite-library-unavailable` type | changed | Fields `reason path source detail candidates`. `library` dropped (c3). |
| c11 | Five checked accessors (`-reason -path -source -detail -candidates`) | changed | Renamed, over `"a &sodium-library-unavailable"`. |
| c12 | `sqlite-library-unavailable-library` accessor | **dropped** | Protected: reading the report off a refusal. Gone with the field (c3). vs kept: no kept rule names it. `test-conditions`' accessor lists lose it (five, not six). |
| c13 | `make-sqlite-library-unavailable` | changed | Five arguments. Refuses a reason outside the six by assertion violation from the constructor, irritant `(shown-value reason)`. The `library` check is dropped with the field. |
| c14 | `raise-library-unavailable` | changed | `(reason path source detail candidates message irritants)`: no `library`. `&who chez-sodium`, `&message`, `&irritants` as before. |
| c15 | `&sqlite-error`, its 5 accessors, `make-sqlite-error`, `raise-sqlite-error` | **dropped** | Protected: SQLite's answer as a condition: code and extended code by name, message, sql and offset. libsodium has one failure case, `crypto_pwhash_str` answering -1, whose condition is `&sodium-failed` with `function` and `code` (ADR-0006 decision 3; plan §4.1 item 2). `password-verify`'s -1 is `#f`, no condition (ADR-0006 decision 4). vs kept: `refuse-field` was written for `make-sqlite-error`'s field checks and stays for `make-sodium-failed`; `check-raise-who` stays (c24). Nothing kept reads a code table. |
| c16 | `&sqlite-busy`, `&sqlite-constraint`, `&sqlite-read-only`, `&sqlite-interrupt` and `sqlite-error-subtype` | **dropped** | Protected: classes of SQLite's primary codes, and a total function, run where nothing may raise, that names the class. One case here (c15). vs kept: the "nothing raises in a critical section" rule (AGENTS) is kept; no kept piece runs in a section (the `raise-*` helpers run after it, ADR-0007), and the kept `kind-of`/`shown-value` are total. |
| c17 | `&sqlite-invalid-text`, 2 accessors, `make-`, `raise-invalid-text` | **dropped** | Protected: TEXT read from SQLite that is not well-formed UTF-8. Here no text is read from libsodium but ASCII: the version, the prefix, a hash string (plan §4.2 item 7: rule (l) dropped for the same reason). Scheme strings written in hold no surrogates, so UTF-8 encoding cannot fail. vs kept: the version string is untrusted input to the kept `check-version`, but its strict parse refuses any non-ASCII digit (rows v-nonascii). M3 owns the check of a hash string read back. |
| c18 | `&sqlite-wrong-thread`, 2 accessors, `make-`, `raise-wrong-thread` | **dropped** | Protected: a connection used off the thread that opened it. No handles: no verb holds state between calls (ADR-0005; brief §3.2); a block is made and freed inside one call (ADR-0007). vs kept: no kept piece holds a thread id; `get-thread-id` is already out of the seam (plan §2.2). |
| c19 | `&sqlite-closed`, `make-`, `raise-closed` | **dropped** | Protected: a verb on a closed connection. No handles (as c18). vs kept: none. |
| c20 | `&sqlite-setting-mismatch`, 3 accessors, `make-`, `raise-setting-mismatch` | **dropped** | Protected: a PRAGMA read back that differs from what was set. libsodium has no settings; limits are arguments (ADR-0009). vs kept: none. |
| c21 | `&sqlite-transaction-ended`, `make-`, `raise-transaction-ended` | **dropped** | Protected: a body outliving its transaction. No transactions. vs kept: none. |
| c22 | `&sqlite-extensions-unavailable`, `make-`, `raise-extensions-unavailable` | **dropped** | Protected: an open that opts in to extension loading on a library lacking `sqlite3_load_extension`, an optional entry (`bind-optional`). Every entry here is required (ADR-0002 decision 4; ADR-0003: every function bound exists at the floor); `bind-optional` is "never" (plan §3). vs kept: `missing-api` stays and covers any absent entry, since all are required. |
| c23 | `exact-integer?` | changed | Kept for `make-sodium-failed`'s `code`: `(and (integer? x) (exact? x))`. Not in the plan's keep list (F8). |
| c24 | `exact-natural?` | **dropped** | Protected: the thread ids, the column and the offset checks. `code` is negative at -1, so a natural is the wrong test. vs kept: no kept maker checks a natural. |
| c25 | `refuse-field` | kept | Private, not exported. Used by `make-sodium-failed`, `check-raise-who`. |
| c26 | `check-raise-who` | kept | Private. `raise-sodium-failed` uses it. Not in the plan's keep list (F8). |
| c27 | The export list's SQLite names (about 50) | **dropped** | With their pieces c12, c15 to c22. The export row of `test-conditions` is written out whole against the new list (section 3). |

### 1.2 `private/load-state.sls`

Plan: "Renames." Every piece stays.

| # | Piece | Disposition | Detail |
|---|---|---|---|
| l1 | Header comment | changed | Names `CHEZ_SODIUM_LIBRARY`, libsodium. Cites ADR-0002. |
| l2 | `failure`, `load-failure`, `record-load-failure!` | kept | Plain renames of the condition type in `as-serious`. |
| l3 | `as-serious` | changed | `&chez-sodium-error`, `&who chez-sodium`, message "loading libsodium raised something other than a serious condition", irritant the object. |
| l4 | `load-step` | kept | `guard` clause `(#t ...)`, `raise` (never `raise-continuable`), records then raises again. |
| l5 | Exports `load-failure record-load-failure! as-serious load-step` | kept | |

No drop. This is the pure Chez-wedge defence (ADR-0002 context; AGENTS "A failure is remembered and
raised again") and applies unchanged.

### 1.3 `private/discovery.sls`

| # | Piece | Disposition | What changes / what a drop protected |
|---|---|---|---|
| d1 | Header comment | changed | `CHEZ_SODIUM_LIBRARY`. Rule 4 (macOS) removed. The note that DYLD redirects an absolute path is removed; the Linux half stays ("`LD_LIBRARY_PATH` redirects neither", nothing reads it, ADR-0002 consequences). Soname rule added: `.so.26` then `.so.23`, never the bare `.so`. |
| d2 | Exports | changed | `choose-libsodium libsodium-world linux-triple libsodium-candidates libsodium-sources`. |
| d3 | `libsqlite3-sources` | changed | `'(override guix-environment guix-profile guix-home guix-user-profile guix-system system)`, seven. `macos-system` dropped. |
| d4 | `macos-system` source | **dropped** | Protected: naming Apple's `/usr/lib` candidate in a report. ADR-0010; plan §2.1. vs kept: the rule "every source a candidate list yields is one of the sources, and every source but the override's is yielded by some list" is kept and would fail on a stale `macos-system`; the fixture's third call (`'tarm64osx`) goes, so the rule holds for the seven. |
| d5 | `choose-libsqlite3`, override branch | kept | Absolute path (first char `/`) taken as given, never checked with `exists?`, never a fallback; anything else set, `""` too, is `invalid-override`, detail the value, irritant the value. Message names `CHEZ_SODIUM_LIBRARY`. |
| d6 | `choose-libsqlite3`, `macos` case (`(car (libsqlite3-candidates #f ...))`) | **dropped** | Protected: Apple's dyld-cache library has no file on disk, so it was returned without asking `exists?`. ADR-0010; plan §2.1. vs kept: the kept override rule "never asks `exists?`" is separate (d5) and its row keeps. The kept `first-existing` asks `exists?` of every candidate, which is right on Linux: files exist. |
| d7 | `choose-libsqlite3`, `linux` and `else` cases | changed | `(case platform ...)` collapses to: a Linux machine type gets the world's list, any other machine type gets `(first-existing '() exists?)`: `not-found`, empty candidates (F7). |
| d8 | `first-existing` | kept | Asks one at a time in order, stops at the first; none is `not-found`, candidates the whole list, no path, source or detail. Message names `CHEZ_SODIUM_LIBRARY`. |
| d9 | `refuse` | changed | No `library` argument: `(raise-library-unavailable reason path source detail candidates message (list irritant))`. |
| d10 | `machine-platform` | changed | Returns `'linux` for a name ending `le`, else `#f`. The `osx` suffix and `'macos` drop (see d11). (Or a `linux-machine-type?` boolean; F7.) |
| d11 | The `osx` platform, `.dylib` candidate, Apple branch of `libsqlite3-candidates` | **dropped** | Protected: Apple's one candidate, `/usr/lib/libsqlite3.dylib`. ADR-0010 ("no macOS code paths"). vs kept: the kept "no list for another platform" rule (`(else '())`) now also covers `osx`, and its row keeps (v-platform-other). Nothing on a non-Linux machine type reads `/proc/self/maps` (kept, row d-nolist-reads). |
| d12 | `linux-triple` | kept | `ta6le a6le` to `x86_64-linux-gnu`; `tarm64le arm64le` to `aarch64-linux-gnu`; else `#f`. |
| d13 | `libsqlite3-world`, `guix-libc?`, `line-path` | kept | Guix when a `/proc/self/maps` line names `libc.so.6` whose path starts with `/gnu/store/`; FHS otherwise, `#f` included. |
| d14 | `libsqlite3-candidates` | changed | Linux cases only; `world` must be `guix` or `fhs`, else assertion violation. |
| d15 | `guix-candidates`, `profile-candidate` | changed | `profile-candidate` returns two entries per profile: `lib/libsodium.so.26`, then `lib/libsodium.so.23`, the same source. Profile order unchanged. Unset or non-absolute variable contributes nothing. |
| d16 | `fhs-candidates` | changed | In each of `/usr/local/lib`, `/usr/lib/<triple>` (when there is a triple), `/usr/lib64`, `/usr/lib`: `libsodium.so.26`, then `.so.23`, source `system`. Directory-major, never soname-major. 8 paths with a triple, 6 without; Guix 10 at most. |
| d17 | New: the soname list | new | Private `libsodium-sonames : (Listof String)` = `("libsodium.so.26" "libsodium.so.23")`; one definition both worlds use. Never contains the bare `libsodium.so`. |
| d18 | String helpers `absolute?`, `absolute-or-false`, `string-prefix?`, `string-suffix?`, `basename`, `lines` | kept | `string-suffix?` is used by d10, `string-prefix?` by d13. |

### 1.4 `private/verify.sls`

| # | Piece | Disposition | What changes / what a drop protected |
|---|---|---|---|
| v1 | Header comment | changed | ADR-0002, ADR-0003, ADR-0011 (not 0008, not 0010). One check. |
| v2 | Imports | changed | `libsqlite3-info` out (c3). |
| v3 | `sqlite-floor` (3045001) | changed | `sodium-floor : (List Natural Natural Natural)` = `'(1 0 18)`, written in the code, held to `floors.sexp` by `test-verify`'s behaviour (ADR-0011; plan §2.1). |
| v4 | `check-version` | changed | `(check-version version-string path source)`: `(U String #f) String Symbol -> #t`. Parses strictly into three naturals; below the floor, or unreadable, or `#f`, is `below-floor`, detail the string or `#f`, `candidates '()`, irritant `(list path)`. The message must not `string-append` the version (the v0.1.1 message would raise on `#f`). Floor shown in the message through a private list-to-text helper (v8). |
| v5 | `check-version`'s version-number argument and its `exact-integer?` check | **dropped** | Protected: a C `int` from `sqlite3_libversion_number`, negative included. libsodium's version is a string; major and minor are libtool numbers, reported never compared (ADR-0003 decisions 2, 3). vs kept: the rule "the floor is met only when the string shows it" now carries the whole decision; negative-number rows go with the argument. The int-range defence of the three `sodium_*` int returns lives in native (slice 2). |
| v6 | `check-version`'s assertion violation for a non-string version | changed | A non-string is no longer a caller bug: `#f` is the NULL case (plan §4.1 item 1). `#f`, and anything else that is not a string, is `below-floor` (F6: caller decides whether a non-`#f` non-string is instead an assertion violation). |
| v7 | `check-threadsafe` | **dropped** | Protected: `sqlite3_threadsafe() == 0`, a library built without mutexes, reason `not-threadsafe`. libsodium has no such report; `sodium_init` is thread-safe (ADR-0002 context), and the threaded Chez is required elsewhere (ADR-0004, `require-threaded`). The reason itself is out of the list (c9). vs kept: the rule inside it, "an answer must be an exact integer, because 0 is truthy and 1.0 is an integer", is kept in spirit by the init answer's check. That check is in native, slice 2, not in this slice (F5). |
| v8 | `version-number->string` | **dropped** | Protected: the floor's `M.m.p` text in the remedy, from a number. Now the floor is a list, so a private, unexported `floor->string` joins it with `.` for the message. vs kept: messages are never asserted (ADR-0006 decision 8); no suite reads the text; do not write the dotted floor into `src/` as a literal (the floor is written in `floors.sexp`, ADR-0011, `check-floors`). |
| v9 | `natural?`, `exact-integer?` | **dropped** | Helpers of v5 and v8 only. vs kept: the parse tests characters, not numbers. |
| v10 | `refuse` | changed | No `library`; `(raise-library-unavailable reason path source detail '() message (list path))`. |
| v11 | New: strict parse | new | See section 2, N6. |

### 1.5 `tests/test-conditions.sps` (1319 lines)

Groups of rows in v0.1.1, in file order.

| # | Group | Disposition | Detail |
|---|---|---|---|
| tc1 | Header, imports, runner, `raised`, `contains?` | changed | `(chez-sodium-testing)`; `libsqlite3-info` and `constants` imports out; `(rnrs mutable-pairs)` (circular list), `(rnrs records inspection)`, `(only (chezscheme) library-exports)` stay. Ends `(exit (suite-exit-status runner))`. |
| tc2 | `kinds`, `a-report`, `a-library-unavailable` fixtures | changed | `kinds`: `error? chez-sodium-error? sodium-library-unavailable?`. `a-report` **dropped** with the field. Fixture has five distinct fields. |
| tc3 | Export-list row | changed | Written out whole against section 2's list. |
| tc4 | "the report fixture is a libsqlite3-info" | **dropped** | Protected: the fixture built. `a-report` is gone; vs kept: the other fixtures are built under no guard that matters (the five-field maker takes plain values). |
| tc5 | Root rows (2) | kept | |
| tc6 | Library-unavailable rows: kinds, fields, reasons, constructor takes each, each-with-its-fields | changed | Five fields, six new reasons. |
| tc7 | "library may be #f: no report" row | **dropped** | Protected: the `library` field's `#f`. Field gone. vs kept: the `reason` rows read the other fields. |
| tc8 | Constructor refusals: non-reason, chez-curl's `no-ssl`, near-reasons, strings, char/vector/condition | changed | Same shapes. The refused list gains `not-threadsafe` (a former reason), and the `no-ssl` row says nothing of chez-curl. |
| tc9 | Constructor refusals of a `library` that is no info or `#f` (2 rows) | **dropped** | Protected: the field's type check (c3). vs kept: the reason refusal rows stay and are unchanged in shape. |
| tc10 | `raise-library-unavailable` rows: whole condition, no path, handler returns, takes each reason, refuses what the constructor refuses | changed | Drop the report column and the `library` argument; `who chez-sodium`; the last row's second case (a string as library) dropped. |
| tc11 | Accessor refusal rows (3) | changed | Five accessors. |
| tc12 | `checked-accessor` row, `kind-of` row, `shown-value` row | kept | |
| tc13 | "libsqlite3-info's own copy of the rule agrees" | **dropped** | Protected: two copies of `shown-value`'s rule agreeing; the second lived in `libsqlite3-info` because of an import cycle. vs kept: no copy of the rule exists in `src/` (grep: `shown-value` is defined in `conditions` alone). If a later library copies it, this row returns for that copy. |
| tc14 | Rows for `&sqlite-error`, wrong-thread, closed: kinds, fields, accessor refusals, maker refusals, raise helpers, never-return | **dropped** | Their pieces are dropped (c15, c18, c19). Each shape is re-made for `&sodium-failed` (section 3, rows sf-*): fields, maker refusals, accessor refusals, no-secret-printed, whole-condition raise, who check, never returns, three simple conditions, fixed message. vs kept: every kind of rule these rows held stays, applied to the one type that remains. |
| tc15 | Subtype rows (`sqlite-error-subtype` table walks, 108 codes, 31 primaries, 103 codes, interrupt) | **dropped** | Pieces dropped (c16). `constants` is dropped (c4). vs kept: none. |
| tc16 | `&sqlite-invalid-text` rows | **dropped** | c17. |
| tc17 | `&sqlite-setting-mismatch`, `&sqlite-transaction-ended` rows | **dropped** | c20, c21. |
| tc18 | `&sqlite-extensions-unavailable` rows (including the fixed-message and three-simple-conditions rows) | **dropped** | c22. The *shape* rows (fixed message, exactly three simple conditions) are re-made for `raise-sodium-failed`. |
| tc19 | The matrix row, the parents row, the own-fields row | changed | Three library types plus `&assertion` and plain `&error`. |

### 1.6 `tests/test-load-state.sps` (213 lines)

| # | Group | Disposition | Detail |
|---|---|---|---|
| ls1 | Header, imports, `caught`, `made-serious`, `recorded` | changed | Renames. `chez-sodium-testing`, `chez-sodium private conditions`. |
| ls2 | "nothing is recorded at first"; "load-step answers its expression's value, and records nothing" | kept | |
| ls3 | 5 `as-serious` rows | changed | `chez-sodium-error?`, `who chez-sodium`. |
| ls4 | `first` and its two recording rows | kept | |
| ls5 | `later-failures` and its 2 rows | changed | `(make-sodium-library-unavailable 'not-found #f #f #f '())`, five arguments. |
| ls6 | "record-load-failure! refuses a condition that is not serious" | kept | |
| ls7 | "load-step raises its failure, not continuably" | kept | |
| ls8 | 3 `twice` rows (bare symbol wedges; through `load-step` serious; a warning is serious) | kept | They measure Chez, and are the reason for `load-step` (ADR-0002 context). Library names `(load-state-fixture ...)`. |

No drop.

### 1.7 `tests/test-discovery.sps` (659 lines)

| # | Group | Disposition | Detail |
|---|---|---|---|
| td1 | Header, imports, runner, `outcome`, `env`, `present`, `nothing`, `everything`, `choose`, `choose/asked` | changed | Renames. `(only (chezscheme) get-process-id machine-type)` stay. |
| td2 | Fixtures `guix-vars`, `g-*`, `guix-list`, `f-*`, `fhs-list`, `override`, `ld-vars`, `with-override`, `guix-maps`, `fhs-maps`, `maps-line`, `without-last-newline` | changed | `g-*`, `f-*` become `.so.26`/`.so.23` pairs (lists of 10 and 8). `ld-vars` keeps `LD_LIBRARY_PATH` and drops `DYLD_LIBRARY_PATH`. `apple` fixture dropped. |
| td3 | `apple` fixture, `DYLD_LIBRARY_PATH` fixture value | **dropped** | Protected: the macOS candidate; the proof that `DYLD_*` is unread. ADR-0010. vs kept: the "nothing reads `LD_LIBRARY_PATH`" rows keep (td11). |
| td4 | Override rows: absolute chosen; never `exists?`; beats every FHS candidate; relative, bare name, empty are `invalid-override`; `/` alone; slash-not-first shapes | kept | Override paths use `libsodium.so.26`. |
| td5 | Override rows "chosen on macOS, over Apple's" and "invalid-override on macOS ... never falls back to Apple's" | **dropped** | Protected: the override beating or refusing without falling back to Apple's. ADR-0010. vs kept: "chosen on a platform with no list" stays; the no-fallback half is kept for that platform by td10's row (an invalid override on `ta6fb` and `tarm64osx` stays `invalid-override`, no fallback to anything). |
| td6 | "the old CHEZ_CURL_LIBCURL, and near names, are no override" | changed | Names: `CHEZ_CURL_LIBCURL`, `CHEZ_SQLITE3_LIBRARY` (the variable the rename could leave), `SODIUM_LIBRARY`, `CHEZ_SODIUM`, `LIBSODIUM`. |
| td7 | Platform rows: `le` is Linux; `osx` is macOS; any other none; nt, nb, qnx none | changed | The `osx` row is replaced by "an `osx` machine type has no candidates: `not-found`, empty list" (both architectures). |
| td8 | macOS group (3 rows: Apple's candidate without `exists?`; world not consulted; one candidate) | **dropped** | Protected: Apple's candidate. ADR-0010. vs kept: the world rows are unaffected. |
| td9 | World group (11 rows) | kept | |
| td10 | Guix group (11 rows) | changed | The list is the 10 paths, in order; precedence "each wins over every one after it" over the 10; probe order "stops at the first that exists". Unset, empty, relative variables contribute nothing (both sonames of that profile out). |
| td11 | FHS group (13 rows) | changed | The list is the 8 or 6 paths. |
| td12 | Triple table rows, `libsqlite3-candidates` refuses a bad world, "no list has no candidates" | kept | |
| td13 | Sources group | changed | Seven sources; the third list call (`'tarm64osx`) removed. |
| td14 | not-found row, "every refusal is a chez-sodium-error ... from who chez-sodium, with a message" | changed | not-found lists all 8 FHS paths. |
| td15 | "reads only" rows (3) | changed | `world-cases` keeps `ta6le` Guix, `ta6le` FHS, `tarm64osx` (now "a non-Linux machine type"), `ta6fb`. The "never DYLD" half goes. |
| td16 | Real `/proc/self/maps` section: `linux?`, `binary-world`, 2 rows | changed | The `linux?` flag and its `'fhs` off-Linux branch are **dropped** (ADR-0010: assumptions that hold only on Linux need no flag). Row 1 becomes "the real maps is read" (expected `read`). vs kept: the kept `machine-platform` already returns no candidates off Linux, so discovery itself is not weakened; only the suite's own off-Linux escape goes. |

### 1.8 `tests/test-verify.sps` (251 lines)

| # | Group | Disposition | Detail |
|---|---|---|---|
| tv1 | Header, imports, runner | changed | `(floors)` stays. `libsqlite3-info` out. |
| tv2 | `report` fixture and its row | **dropped** | Protected: carrying a report on a refusal. Gone (c3). |
| tv3 | `outcome`, `readable` | changed | No library column. `readable` keeps type, who, message. |
| tv4 | Floor from `floors.sexp`: `floor-text-of-file`, `floor-num`, `below-num`, `num->text` | changed | Computed under a guard. `floor-text-of-file` from `(floor-text (read-floors) 'sodium)`; floor numbers from `(floor-numbers (read-floors) 'sodium)`; the version one below as text. Sentinel symbols when the file cannot give them. `floor-num` as `X*1000000+...` is **dropped**: floors are lists. |
| tv5 | Rows "floor is 3.45.1", "is the file's floor", "file floor accepted", "one below file floor refused", "floor itself accepted", "3.45.0 refused" | changed | `sodium-floor` equals `'(1 0 18)` and equals `(floor-numbers (read-floors) 'sodium)`; `"1.0.18"` accepted; the file's floor text accepted; the text one below refused; `"1.0.17"` refused with detail `"1.0.17"`. |
| tv6 | Boundary rows: accepted at and above every digit; refused below every digit | changed | Strings (section 3, rows v-above, v-below). |
| tv7 | Negative version number row | **dropped** | Protected: `int` negative from C. v5. vs kept: a leading `-` is now refused as unreadable (rows v-unreadable). |
| tv8 | "version number that is no exact integer is an assertion violation" | **dropped** | Argument gone (v5). vs kept: a non-string version is covered by v-nonstring. |
| tv9 | "version string that is no string is an assertion violation" (2 rows) | changed | Becomes v-nonstring (F6). |
| tv10 | 3 `check-threadsafe` rows | **dropped** | v7. |
| tv11 | "every refusal is a chez-sqlite3-error from who chez-sqlite3, with a message" | changed | One check. |
| tv12 | "the two checks decide alone" | **dropped** | Protected: a pass of one check never hides the other's refusal. One check remains; the order of the floor against `sodium_init` is native's (ADR-0002 decision 4; slice 2 reads native's body and slice 3 the decoy's call log). vs kept: the order rule is kept, held elsewhere. |
| tv13 | 2 `version-number->string` rows | **dropped** | v8. |

---

## 2. New, with no source

Signatures in Typed Racket style. "Rows" are named in section 3.

| # | Piece | Signature | Where | Rows |
|---|---|---|---|---|
| N1 | `secret-shown` | `(: secret-shown (-> Any (List 'kind Symbol)))`. `(list 'kind (kind-of x))`, whatever `x` is. Never calls `shown-value`; never walks or measures `x`. | conditions | cs-* |
| N2 | `refuse-secret` | `(: refuse-secret (-> Symbol Symbol Symbol Any Nothing))` `(WHO RULE PARAMETER VALUE)`. `(assertion-violation WHO "<fixed text>" RULE PARAMETER (secret-shown VALUE))`. Irritants `(RULE PARAMETER (kind K))`, nothing else, no length. Checks WHO, RULE and PARAMETER are symbols first, refusing by `refuse-secret` naming the field, and the bad argument by `secret-shown` (F9). | conditions | rs-* |
| N3 | `&sodium-failed` | fields `function` (String) and `code` (Integer); parent `&chez-sodium-error`; not an `&assertion`. | conditions | sf-* |
| N4 | `make-sodium-failed` | `(: make-sodium-failed (-> String Integer &sodium-failed))`. Refuses a `function` that is no string, and a `code` that is no exact integer, by `refuse-field`, field first, value by `shown-value` (F3). Accepts -1, 0, 2 and a bignum. | conditions | sf-ctor |
| N5 | `sodium-failed?`, `sodium-failed-function`, `sodium-failed-code` | `(: sodium-failed? (-> Any Boolean))`, `(: sodium-failed-function (-> &sodium-failed String))`, `(: sodium-failed-code (-> &sodium-failed Integer))`. Accessors by `checked-accessor`. | conditions | sf-acc |
| N6 | `raise-sodium-failed` | `(: raise-sodium-failed (-> Symbol String Integer Nothing))` `(WHO FUNCTION CODE)`. `check-raise-who` first, then the maker. Raises the type compounded with `&who WHO`, one fixed `&message`, no irritants. Never returns. | conditions | sf-raise-* |
| N7 | The reason `init-failed`; detail is the integer | in `sodium-library-unavailable-reasons`, `: (Listof Symbol)` | conditions | lu-* |
| N8 | `sodium-floor` | `(: sodium-floor (List Natural Natural Natural))` = `'(1 0 18)` | verify | v-floor-* |
| N9 | `check-version` | `(: check-version (-> (U String #f) String Symbol #t))` `(VERSION-STRING PATH SOURCE)`. Refusal: reason `below-floor`, detail the argument, `candidates '()`, `&who chez-sodium`, message, irritants `(PATH)`. | verify | v-* |
| N10 | The strict parse | private `(: parse-version (-> String (U (List Natural Natural Natural) #f)))`. Exactly three parts split at `.`; each part non-empty, ASCII `0`..`9` only (tested by char comparison, never `char-numeric?` or `string->number`, which take signs, radix prefixes, fractions and non-ASCII digits), no leading zero unless the part is exactly `"0"`. The naturals are compared as numbers, major, minor, patch. | verify | v-unreadable, v-nonascii, v-above, v-below |
| N11 | The NULL case | `#f` to `check-version` is `below-floor`, detail `#f` | verify | v-null |
| N12 | The floor held to the file | rows only: `sodium-floor` equals `(floor-numbers (read-floors) 'sodium)`; `check-version` accepts `(floor-text ... 'sodium)` and refuses the text one below | test-verify | v-floor-file |
| N13 | The soname list and the two-soname candidates | `(: libsodium-sonames (Listof String))`, private; `(: libsodium-candidates (-> (U 'guix 'fhs #f) Symbol (-> String (U String #f)) (Listof (Pairof String Symbol))))` | discovery | ds-* |
| N14 | `libsodium-sources` without `macos-system` | `(: libsodium-sources (Listof Symbol))` | discovery | ds-sources |
| N15 | `libsodium-world`, `choose-libsodium` | `(: libsodium-world (-> (U String #f) (U 'guix 'fhs)))`; `(: choose-libsodium (-> (-> String (U String #f)) Symbol (U String #f) (-> String Boolean) (Values String Symbol)))` | discovery | (kept) |

---

## 3. The rows, by suite

`W` marks a row that must be watched to fail against a stub or a named mutant before it counts.
Every suite is first run red against a stub (a library exporting the same names, answering nothing
useful), then green. The watch is logged in `.plans/m1-slice-1-mutation-log.md`.

### 3.1 `tests/test-conditions.sps`

Common:

- **c-exports** (W: a missing name, an extra name, `sodium-library-unavailable-library` left in, a SQLite name left in). Written out whole, sorted, against `(library-exports '(chez-sodium private conditions))`. The list: `&chez-sodium-error make-chez-sodium-error chez-sodium-error? &sodium-library-unavailable make-sodium-library-unavailable sodium-library-unavailable? sodium-library-unavailable-reason -path -source -detail -candidates sodium-library-unavailable-reasons raise-library-unavailable &sodium-failed make-sodium-failed sodium-failed? sodium-failed-function sodium-failed-code raise-sodium-failed kind-of shown-value secret-shown refuse-secret checked-accessor`.
- **root-1, root-2** (kinds `(#t #t #f #f)`; `chez-sodium-error?` false for a plain error, a message, a symbol, `#f`).

`&sodium-library-unavailable`:

- **lu-kinds**: an error, a chez-sodium-error, a library-unavailable, not a sodium-failed.
- **lu-fields** (W: an accessor reading the wrong field): the five distinct fixture values.
- **lu-reasons** (W: a reason dropped; one misspelt; `init-failed` missing; `not-threadsafe` left in): the list is exactly `(invalid-override not-found load-failed below-floor missing-api init-failed)`, written out.
- **lu-ctor-each**: the constructor takes each of six, written out apart from the export.
- **lu-each-with-fields**: one refusal of each reason with its fields: `init-failed` with detail the integer `2`, and `-1`; `below-floor` with detail a string, and with `#f`; `not-found` with candidates.
- **lu-refuse-1..5** (W: the allow-list matched case-insensitively, by prefix, or as text): non-reasons, `'no-ssl`, `#f`, `5`, `'()`, a string spelling a reason, `not-threadsafe`, the near-reasons (upper-case, suffixed, truncated: 18), the six as strings (kind `string`), a char, a vector, a condition.
- **lu-fields-count**: the record's fields are exactly `reason path source detail candidates` (records inspection). W: the `library` field left in.
- **rlu-whole** (W: `&who` dropped; irritants not carried; `&message` dropped): types, who `chez-sodium`, a message present, the irritants as given, the five fields.
- **rlu-min**: no path, no source, no irritants.
- **rlu-return**: a handler that returns gets nothing back (W: `raise-continuable`).
- **rlu-each**: takes each of six reasons.
- **rlu-refuse**: a bad reason is the constructor's assertion violation.
- **acc-1..3** (W: an accessor unchecked): each of the five refuses a string by kind, a plain error, the root alone, a message, `#f`, a number, a list holding a string, a vector; and prints no secret.
- **acc-sf**: each of the five also refuses an `&sodium-failed`.

`checked-accessor`, `kind-of`, `shown-value`: kept rows, one each, with `shown-values` as v0.1.1's.

`&sodium-failed`:

- **sf-fields** (W: fields swapped): `function` `"crypto_pwhash_str"`, `code` -1; and another fixture with other values, so no field reads the other.
- **sf-ctor**: refuses `function` that is not a string (a symbol, `#f`, a number, a list holding a string, a bytevector), and `code` that is not an exact integer (`1.0`, `"1"`, `#f`, `1/2`, `'x`); each names the field first. Accepts `-1`, `0`, `2`, `(expt 2 70)`.
- **sf-acc-refuse**: both accessors refuse a library-unavailable, the root, a plain error, a string by kind, a number.
- **sf-acc-secret**: no accessor prints the secret it refused, bare, in a list, in a vector.
- **sf-raise-whole** (W: `&who` dropped; irritants non-empty): a `&sodium-failed`, an error, no `&assertion`, who as given, a message, irritants `()`, function and code as given.
- **sf-raise-who**: two different whos (`password-hash`, `password-verify`) come back as given.
- **sf-raise-bad-who**: a who that is no symbol is refused from `raise-sodium-failed` naming `who`, before the fields; a bad `function` or `code` is the maker's.
- **sf-raise-return**: a handler that returns does not make it return.
- **sf-three-simple**: exactly three simple conditions: the type, `&who`, `&message`.
- **sf-message**: the message is a non-empty string, equal from each who, and different from `raise-library-unavailable`'s.

Tree:

- **matrix** (W: a type under the wrong parent): every type (`&chez-sodium-error`, `&sodium-library-unavailable`, `&sodium-failed`, an assertion violation, a plain error) against `error?`, `assertion-violation?`, `chez-sodium-error?`, `sodium-library-unavailable?`, `sodium-failed?`.
- **parents**: each of the two leaf types' parent is `&chez-sodium-error`; the root's is `&error`.
- **preds-false**: the three predicates are false for a symbol, `#f`, a string, a number, a char, `'()`, a vector, a procedure, a message, a plain error.

`secret-shown` and `refuse-secret`:

- **cs-kinds** (W: `secret-shown` calling `shown-value`): a whole matrix of values to their kinds, written out: strings (`""` and `"x"`); a symbol (`'hunter2`); exact, inexact and bignum numbers; `#t`, `#f`; a char; a bytevector (empty and not); a vector; a procedure; `'()`; a proper list of chars; a list of symbols; an improper pair; a circular list; a hash table; a condition; `(eof-object)`. Each is `(kind K)`.
- **cs-nolength** (W: a length in the irritant): a string, list and bytevector of two lengths each give an equal answer.
- **cs-circular**: a circular list answers `(kind list)` and returns.
- **rs-shape** (W: `shown-value` instead of `secret-shown`; `&who` dropped; rule and parameter swapped): for every kind in cs-kinds, `refuse-secret` raises an assertion violation from the given who, irritants exactly `(RULE PARAMETER (kind K))`.
- **rs-row16** (W: `shown-value` instead of `secret-shown`): a symbol, a number and a list of chars, each refused as its kind; none is shown as it is. This is brief §8.1 row 16's helper half.
- **rs-text**: the condition's displayed text (`describe`) holds none of the secret's text, for a symbol, a string, a bytevector, a char list, a vector of strings.
- **rs-message**: it has a `&message` that is a non-empty string.
- **rs-args**: a WHO, RULE or PARAMETER that is no symbol is refused from `refuse-secret`, naming which field, and showing the bad argument by kind (including when the secret is passed in a wrong position).
- **rs-total**: `refuse-secret` raises an assertion violation, never anything else, for every kind (the `raised` helper gives `(assertion-violation ...)`, never `(other ...)`, never `(no-raise ...)`).

### 3.2 `tests/test-load-state.sps`

Rows ls2 to ls8 as in 1.6. W (each against its mutant):

- `load-step` recording nothing; `record-load-failure!` overwriting the first; `load-step` using `raise-continuable`; `as-serious` returning a non-serious object; `record-load-failure!` accepting a non-serious condition; `load-step`'s guard clause limited to serious conditions (so the bare-symbol twice row would wedge).

### 3.3 `tests/test-discovery.sps`

- **ds-override**: td4's rows with sodium names.
- **ds-override-so23** (new, W: the override searched or checked with `exists?`): `CHEZ_SODIUM_LIBRARY=/opt/sodium/lib/libsodium.so.23`, with `exists?` true for `/opt/sodium/lib/libsodium.so.26` and for everything: chosen as given, and `choose/asked`'s asked list is empty.
- **ds-near-names** (td6).
- **ds-platform** (td7): `le` Linux; `osx` and others none.
- **ds-world** (td9 kept).
- **ds-guix-list** (W: `.so.23` before `.so.26`; the bare `libsodium.so` in a list; a Guix variable not absolute accepted): the whole 10-path list, in order, with sources.
- **ds-fhs-list** (W: same mutants; the triple directory moved): the whole 8-path list; 6 without a triple; `a6le`, `tarm64le`, `arm64le`.
- **ds-both-sonames** (new, W: `.so.23` before `.so.26`): a directory (FHS and each of the five Guix profiles) holding both: `.so.26` is chosen, `exists?` asked once.
- **ds-only-so23** (new): a directory holding only `.so.23`: it is chosen, `.so.26` asked first.
- **ds-only-bare** (new, W: the bare `libsodium.so` tried): a directory holding only `libsodium.so` (and `libsodium.so.26.4.0`): `not-found`, and the bare name is not in the asked list or in `candidates`.
- **ds-dir-major** (new, W: sorted by soname across directories): an earlier directory with only `.so.23` and a later one with `.so.26`: the earlier `.so.23` wins.
- **ds-guix-no-fhs** (W: an FHS directory in the Guix world), **ds-fhs-no-guix** (W: a Guix profile in the FHS world): every candidate exists, a standard directory is never chosen in a Guix world, a Guix profile never in an FHS one.
- **ds-precedence-guix, ds-precedence-fhs**: each candidate wins over every one after it (10 and 8 cases); probing asks in order and stops at the first that exists.
- **ds-unset**: unset, empty and relative `GUIX_ENVIRONMENT`, `GUIX_PROFILE`, `HOME` contribute nothing, with both sonames.
- **ds-notfound** (W: not every path listed): `not-found` lists all 8 FHS paths (and the Guix list when Guix) in order, no path, no source, no detail; asked in the same order.
- **ds-sources** (W: `macos-system` left in): exactly seven; every yielded source in the seven; each but `override` yielded.
- **ds-who-message**: every refusal is a chez-sodium-error, an error, from `chez-sodium`, with a message.
- **ds-reads** (W: `LD_LIBRARY_PATH` read, in each of the four cases and in the override cases): the names asked of `getenv`, sorted: only `CHEZ_SODIUM_LIBRARY` with an override; in a Guix world with none also `GUIX_ENVIRONMENT`, `GUIX_PROFILE`, `HOME`; otherwise only `CHEZ_SODIUM_LIBRARY`. `LD_LIBRARY_PATH` is set to a different path in every fixture and every path exists, so a read would change an answer.
- **ds-nolist** (td10): an invalid override on `ta6fb` and `tarm64osx` is `invalid-override` with no fallback; a valid one is chosen.
- **ds-real-maps**: the real `/proc/self/maps` is read; the world agrees with whether this Chez's own binary lies under `/gnu/store/`.

### 3.4 `tests/test-verify.sps`

- **v-floor-literal** (W: floor one patch higher: `'(1 0 19)`; one lower: `'(1 0 17)`): `sodium-floor` is `'(1 0 18)`.
- **v-floor-file** (W: the same two): `sodium-floor` equals `(floor-numbers (read-floors) 'sodium)`; `check-version` accepts the file's floor text; refuses the text one below (patch minus one). Both through `floors`, under a guard, with a sentinel.
- **v-at** (W: the floor one patch higher): `"1.0.18"` accepted, `(returned #t)`.
- **v-below** (W: compared as strings; compared on the patch alone): refused as `below-floor` with the string as detail, `path`, `source`, `candidates '()`: `"1.0.17"`, `"1.0.9"`, `"1.0.0"`, `"0.99.99"`, `"0.100.0"`, `"1.0.1"`. `"1.0.9"` is below by number and above by string; `"0.99.99"` is above by patch alone.
- **v-above** (W: same): accepted: `"1.0.19"`, `"1.0.22"`, `"1.0.100"`, `"1.0.1000"`, `"1.1.0"`, `"1.9.0"`, `"1.10.0"`, `"1.100.0"`, `"2.0.0"`, `"10.0.0"`, `"99.99.99"`, a bignum patch `"1.0.99999999999999999999"`. `"1.0.100"` is above by number and below by string.
- **v-unreadable** (W: a leading zero accepted; a sign accepted; whitespace trimmed; a fourth part accepted; `string->number` used): each is `below-floor`, detail the string, never raises: `"1.0"`, `"1"`, `"1.0.18.0"`, `"01.0.18"`, `"1.00.18"`, `"1.0.018"`, `"00.0.18"`, `" 1.0.18"`, `"1.0.18 "`, `"1.0.18\n"`, `"1.0.18\t"`, `"1.0.18-stable"`, `"1.0.18rc1"`, `"v1.0.18"`, `""`, `"."`, `".."`, `"..."`, `"1..18"`, `".0.18"`, `"1.0."`, `"1.0.18."`, `"+1.0.18"`, `"1.+0.18"`, `"1.0.+18"`, `"-1.0.18"`, `"1.0.-18"`, `"1,0,18"`, `"1.0.1e1"`, `"#x1.0.18"`, `"1/1.0.18"`, `"1.0.18.5/3"`, a string with a NUL.
- **v-nonascii** (W: `char-numeric?` used): a digit that is not ASCII, as a part: an Arabic-Indic one (U+0661), a fullwidth one (U+FF11), and `"1.0.18"` with a trailing U+00A0: each `below-floor`.
- **v-null** (W: the NULL case raising or accepted): `#f` is `below-floor`, detail `#f`; the call raises nothing else.
- **v-nonstring**: `5`, `'x`, a bytevector, `'("1.0.18")`: `below-floor` (F6).
- **v-who**: every refusal is a chez-sodium-error from `chez-sodium`, with a message, including the `#f` case (W: the message built with `string-append` on the argument).
- **v-signature** (F4): `check-version` takes three arguments, the string, the path and the source; a call with libtool numbers is not a call (a row that calls it with `"1.0.18"` and a libtool `10.3` is a different answer from `"1.0.17"` with `26.4`: the string alone decides).
- **v-order** is native's, not here.

### 3.5 Watched to fail: the plan's list, and what I add

Plan, slice 1:

| Plan item | Row that holds it | Added |
|---|---|---|
| each suite, red against a stub | all four | |
| conditions: a reason dropped or misspelt | lu-reasons, lu-ctor-each, rlu-each | `init-failed` alone dropped |
| conditions: a string shown by `shown-value` | cs-kinds, rs-shape | |
| conditions: `refuse-secret` using `shown-value` | rs-row16, rs-shape | `secret-shown` using it |
| conditions: an accessor unchecked | acc-1..3, sf-acc-refuse | |
| conditions: `&who` dropped | rlu-whole, sf-raise-whole, rs-shape | |
| discovery: `.so.23` before `.so.26` | ds-guix-list, ds-fhs-list, ds-both-sonames | |
| discovery: the bare `libsodium.so` | ds-only-bare, the list rows | |
| discovery: an FHS directory in the Guix world; a Guix profile in the FHS world | ds-guix-no-fhs, ds-fhs-no-guix | |
| discovery: the override checked with `exists?`, or searched | ds-override, ds-override-so23 | |
| discovery: `LD_LIBRARY_PATH` read | ds-reads | |
| verify: compared as a string | v-below, v-above | |
| verify: a leading zero accepted | v-unreadable | |
| verify: major or minor compared | not holdable in verify (F4) | slice 3's `libtool-high` and `libtool-low` |
| verify: the floor one patch higher | v-floor-literal, v-floor-file, v-at | one lower too |
| the exit checks | not this agent's | |

---

## 4. Flags

**F1. ADR numbers in copied comments collide.** v0.1.1's comments cite chez-sqlite3's own numbers.
Counts by file: `conditions.sls` ADR-0002 x2, 0010 x2, 0012 x2, 0013 x10, 0014, 0015 x2, 0017 x2,
0018 x2, 0019 x2, 0021 x3, and "chez-curl ADR-0036"; `load-state.sls` 0002; `discovery.sls` 0002 x3;
`verify.sls` 0002 x2, 0003 x2, 0008, 0010; `test-conditions.sps` 0002 x3, 0013 x4, 0021;
`test-discovery.sps` 0002 x5; `test-verify.sps` 0002, 0003, 0008, 0010; `test-load-state.sps` none.
ADR-0002 and ADR-0003 name the same topic here. Every other number points at a different record in
chez-sodium: here ADR-0006 is conditions (not 0013), ADR-0010 is Linux only (not wrong-thread or
threadsafe), ADR-0012 is the public library, and ADR-0011 holds the floors-by-behaviour rule (not
0008). The builder must re-point each (0013 to 0006, 0008 to 0011), drop each cite that goes with a
dropped piece, and cite a sibling's record with its repository name or not at all (AGENTS). Count
before and after, per AGENTS's global-replace rule.

**F2. `secret-shown` is in no plan or record.** The plan names `refuse-secret` and its irritants
`(RULE PARAMETER (kind K))` (§4.1 item 3), and `shown-value` for sizes. `secret-shown` comes from
the brief for this task. I specify it as the one place `(list 'kind (kind-of x))` is written
(N1), exported so its own rows can read it. If the caller wants it private, `cs-*` rows go through
`refuse-secret` alone.

**F3. `shown-value` has two users that can see something secret, against AGENTS.** AGENTS: "`shown-value` shows
numbers, symbols, characters and lists of them as they are, so it is for sizes, limits and preset
names only." The plan keeps `checked-accessor` and `refuse-field`, which both call it on a
caller's argument. `checked-accessor` backs the public accessors (`sodium-library-unavailable-reason`
and the rest); a program that passed `'hunter2`, a number or a char list to one would see it in the
irritants. These are not a "secret parameter" in AGENTS's list (no verb), so the plan is
defensible, but the sentence is literal. Option, for the owner: build both on `secret-shown`
(the cost: three accessor-refusal rows say `(kind symbol)` and `(kind number)`, where v0.1.1 said
the symbol and the number). I have written the rows as v0.1.1 has them, with `shown-value`, and
named the option.

**F4. "verify: major or minor compared" cannot be a verify mutant.** `check-version` takes the
string, the path and the source (plan §2.1), so verify never sees major or minor. That mutant lives
in native (slice 2) and in the decoy rows `libtool-high` and `libtool-low` (slice 3). In slice 1 the
nearest check is v-signature: the answer depends on the string alone.

**F5. The check of `sodium_init`'s answer has no home in slice 1.** v0.1.1's
`check-threadsafe` held a rule worth keeping: an answer must be an exact integer, since 0 is truthy
and 1.0 is an integer. The plan's `init-failed` rule (0 and 1 load, any other answer is
`init-failed` with the answer as detail) is placed in native (§4.2 item 3, step 5), so its only
tests are slice 2's recorded answer and slice 3's decoys (-1, 2, 1). A pure `check-init` in
`verify`, testable here on made-up integers (0, 1 accepted; -1, 2, 256, `-2147483648`, 4294967296
refused; `#f`, `1.0`, `"0"` an assertion violation), would hold ADR-0002 decision 5's rule in
slice 1, and the `init-failed` reason would have a row here. The plan's `verify` row does not list
it. I have not added it. Your decision.

**F6. A non-string, non-`#f` version.** The plan says "anything lower or unreadable is
`below-floor`" and "`#f`" is NULL, and says nothing of `5` or a symbol. v0.1.1 raised an assertion
violation for a non-string. I recommend `below-floor` for every non-string: one rule, nothing raises
inside the load. The alternative, an assertion violation naming only the argument's kind, keeps
`detail` to string or `#f`. Rows v-nonstring follow whichever you choose.

**F7. A non-Linux machine type.** The plan drops "macOS: its platform, its candidate and
`macos-system`". It does not say what `ta6osx` or `tarm64osx` now gets. I keep `machine-platform`
(or a `linux-machine-type?` boolean) so that a name not ending in `le` yields `not-found` with an
empty candidates list, as `ta6fb` did in v0.1.1, and so that nothing reads `/proc/self/maps` off
Linux. The other reading, where every machine type falls to the FHS list, is a code path that
tries `/usr/lib` on macOS (ADR-0010 forbids no such path, but the row "any other platform has no
candidates" would then fail). Confirm the first reading.

**F8. The plan's keep list for `conditions` omits two helpers that must stay.** `check-raise-who`
(for `raise-sodium-failed`) and `exact-integer?` (for `make-sodium-failed`'s `code`). The plan's drop
list does not name them either. Kept.

**F9. `refuse-secret` argument checks.** The plan gives `(refuse-secret WHO RULE PARAMETER VALUE)`
and says nothing of a bad WHO, RULE or PARAMETER. My addition: each must be a symbol, refused from
`refuse-secret`, the bad argument shown by `secret-shown`. Reason: if a caller swaps VALUE into the
RULE or PARAMETER position (a library bug), `refuse-field`'s `shown-value` would put a symbol or
number secret into the irritants. Rows rs-args hold it. Drop it if you want a thinner helper.

**F10. The `&sodium-failed` details the plan leaves open.** `function` any string, `code` any exact
integer (not a C-`int` range check: slice 1 does not know the verb's range). Message: fixed text,
the same from every who; irritants `()`. The plan says only "the verb is its `&who`" and
"carries a `&message`".

**F11. Candidate count and order.** ADR-0002 and plan §2.1 give "in each directory,
`libsodium.so.26` then `.so.23`". I read directory-major: 10 Guix paths (5 profiles) and 8 FHS paths
(6 with no triple). `not-found`'s candidates are the full list of paths, both sonames. Plan and ADR
agree on this; they do not state the counts.

**F12. A stale line in the plan.** §2.2 lists `test-verify`'s new rows "the one below refused" as
"the floor from `floors.sexp`". `floors.sexp` holds only the floor, so "the one below" is computed
(patch minus one) in the suite. If the floor's patch is ever 0, the suite names it with a sentinel
(`no-version-below`), as v0.1.1 did, rather than computing across a minor.

**F13. `test-discovery`'s `linux?` flag.** I drop it (td16): a suite's own off-Linux escape is a
macOS code path (ADR-0010). Kept alone in that group is the row that the real maps is read.

**F14. No conflict found** between the plan, ADR-0002, 0003, 0006 and 0010 and their amendments on the
four libraries. The six reasons, five fields, the strict parse and the soname order agree in all
four. The plan's one wrinkle is §4.1 item 1's "detail the string, or `#f` for NULL": a
non-string argument (F6) has no stated detail.

---

## 5. Counts

Rows marked **dropped** in 1.1 to 1.8: **38**.

- conditions.sls: 13 (c3, c4, c12, c15 to c22, c24, c27)
- load-state.sls: 0
- discovery.sls: 3 (d4, d6, d11)
- verify.sls: 4 (v5, v7, v8, v9)
- test-conditions.sps: 9 (tc4, tc7, tc9, tc13 to tc18)
- test-load-state.sps: 0
- test-discovery.sps: 3 (td3, td5, td8)
- test-verify.sps: 6 (tv2, tv7, tv8, tv10, tv12, tv13)

Also dropped in part, inside a row marked "changed": `a-report` (tc2), the `floor-num` number
form (tv4), the `linux?` flag (td16), the `DYLD_LIBRARY_PATH` half of the reads rows (td15), the
`osx` branch of `machine-platform` (d10), the non-string assertion violation (v6).
