# Slice 3, the refusals builder: trim tables and design note

Written first phase only: no project file changed. Probes and their outputs are under
`build/slice3-refusals/` (ignored). Sources read: AGENTS.md; the M1 plan (all sections named);
ADR-0001/0002/0003/0006/0007/0011 with their amendments; `global-constraints.md`, `traps.md`,
`progress.md`; `research/m1-plan`, `m1-slice-0-review`, `m1-slice-2-review`; chez-sqlite3 v0.1.1
(`960d9f0`) `tests/decoy-libsqlite3.c`, `refusal-probe.sps`, `preflight.sps`,
`library-loading.sls`, every `test-library-loading-*.sps`, `fixtures/raising/`, `check-dev.sh`,
the Makefile's `dev` and `check-dev`, and its `.plans/traps.md`; chez-sodium's `native.sls`,
`discovery.sls`, `verify.sls`, `load-state.sls`, `conditions.sls`, `preflight.sps`,
`libsodium-oracle.{c,sls}`, `foreign-conventions.sls`, `chez-sodium-testing.sls`, `floors.sls`, the
Makefile.

## 0. What the builder owns, and what is already there

- **Owns (plan §6):** `tests/decoy-libsodium.c`, `tests/refusal-probe.sps`,
  `tests/library-loading.sls`, `tests/test-library-loading-*.sps`, `tests/fixtures/raising/`,
  `tests/check-dev.sh`, the Makefile's `dev` and `check-dev`.
- **Also touches (flag F5):** `tests/test-conventions.sps` (the owed row, one import and one row).
- **Does not touch:** `tests/preflight.sps` is built (slice 2) and already has the plan's §2.2 shape
  (accepted: path and source, version and `library MAJOR.MINOR`, counts; refused: reason, path,
  source, detail, candidates, remedy, counts). Slice 3 only writes rows that run it.
- **Mutation log:** `.plans/m1-slice-3-mutation-log.md`, the newer form (Guards, Mutation, Result,
  Clean rerun). Every mutant of `src/` is applied **in a whole copy of the tree**, since each child
  starts with `--libdirs src` (chez-sqlite3 traps: "a planted library must sit in a whole copy").

### Re-pointing record numbers

v0.1.1's comments cite chez-sqlite3's numbers. A global replace would be wrong: ADR-0005, 0007
and 0008 are other subjects here. Re-point by subject:

| v0.1.1 cites | subject there | cite here |
|---|---|---|
| ADR-0001 | bind directly, no C | ADR-0001 (same subject) |
| ADR-0002 | discovery, reasons | ADR-0002 |
| ADR-0003 | the floor | ADR-0003 |
| ADR-0005 | the memory gate, children under it, counts zero | **ADR-0011** (decision 1) |
| ADR-0007 | the suite rules, the test glob | **ADR-0011** (decision 3) |
| ADR-0008 | floors have one source | **ADR-0011** (decision 4); here ADR-0008 is the wipe |
| ADR-0010 | a connection belongs to its thread | drop the citation |
| ADR-0011 | read C strings byte by byte | ADR-0001, decisions 3 and 4 |
| ADR-0012 | opens, explicit close | drop with the opens |
| ADR-0013 | conditions: assert reasons, never text | **ADR-0006** (decision 8) |

Where a sibling's record is meant, write `chez-sqlite3 ADR-NNNN`. A comment names no slice,
milestone, date or research path (AGENTS.md).

## 1. Trim tables

"Checked" in a drop's reason means checked against every rule the copy keeps (chez-sqlite3 traps,
"a reason to drop a copied rule"); the rules named are the ones that could have taken the dropped
piece's protection.

### 1.1 `tests/decoy-libsodium.c` (from `decoy-libsqlite3.c`)

| # | Piece | | What changes, or what the drop protected and where it lives now |
|---|---|---|---|
| 1 | header comment | changed | Names sodium.h, the five entries, the builds and switches of §2.1 (plan §2.2). Says why each pointer is read through a `volatile uintptr_t` (ADR-0011, amended). |
| 2 | `#include <sqlite3.h>` | changed | `<sodium.h>` and `<stdint.h>`. The prototype check stays: a definition that disagrees with the header fails the compile, so the suite, never a skip (ADR-0001). |
| 3 | `-DDECOY_VERSION_NUMBER`, `-DDECOY_BELOW_NUMBER` | dropped | Protected: the floor's numeric form (`sqlite3_libversion_number`), derived from floors.sexp. libsodium has no number form: the floor is read from the dotted string alone (ADR-0003 decision 2; ADR-0011 decision 4 "dotted form alone"). Checked against `check-floors`: it refuses the floor's *dotted text* in README, workflows and `scripts/ci/`, never in `tests/`; the decoy takes the text by `-D` from the suite, which read it from the file. |
| 4 | `-DDECOY_VERSION="T"`, `-DDECOY_BELOW="T-1"` | kept | The suite passes the floor and the version one below, from `packaging/floors.sexp` (§2.1). `#error` guard kept, naming `library-loading.sls`. |
| 5 | `called`, `calls[4096]`, `decoy_calls` | kept | Comment "Not an SQLite name" becomes "Not a libsodium name". |
| 6 | `DECOY_MARKER` and `decoy_marker` | kept | Rename only. |
| 7 | `enum decoy_switch`, `switches[]`, `decoy_load` constructor | changed | Variable `CHEZ_SODIUM_DECOY`; nine switches: `below-floor`, `version-null`, `version-malformed`, `version-bom`, `libtool-high`, `libtool-low`, `init-fails`, `init-other`, `init-already`. Whole-string compare, `decoy(control)` / `decoy(SWITCH)` / `decoy(?VALUE)` log entries kept. |
| 8 | `#ifndef DECOY_NOT_SQLITE` | changed | `DECOY_NOT_SODIUM`: no `sodium_*` function; `decoy_calls` (and `decoy_marker`) remain. |
| 9 | `sqlite3_libversion_number` | dropped | Protected: version number agreeing with the string, and the first-asked entry of the "report's three". libsodium's `_major`/`_minor` are libtool numbers, never compared (ADR-0003 decision 3): `libtool-high` and `libtool-low` hold that by behaviour. Checked against the kept order rule (bind all version entries before calling any): the three remaining entries carry it (§2.3). |
| 10 | `sqlite3_libversion` | changed | `sodium_version_string`: control `DECOY_VERSION`; `below-floor` and `libtool-high` `DECOY_BELOW`; `version-null` NULL; `version-malformed` `DECOY_VERSION "-stable"`; `version-bom` `"\xEF\xBB\xBF" DECOY_VERSION` (two literals, so `\xBF` does not swallow the `1`); `libtool-low` `DECOY_VERSION`. |
| 11 | `sqlite3_sourceid`, `sourceid-null`, `sourceid-utf8` | dropped | Protected: the UTF-8 (not Latin-1) reading of a string C hands back, and a NULL second string refused as `load-failed`. libsodium hands back one string, the version, which no accepted value can have non-ASCII bytes in: any non-ASCII byte makes it "not three naturals", so `below-floor` whatever the decoding. The one decoding rule that can change a verdict is the leading U+FEFF that Chez's `utf8->string` drops: `version-bom` is its end-to-end row (and `test-native` has the unit row). Checked against the kept `c-string->string` (lenient decode, BOM restored). NULL is now `version-null`. |
| 12 | the switch `libversion-null` | changed | Renamed `version-null` (plan §2.2); its answer is NULL from `sodium_version_string`, refused as `below-floor` rather than `load-failed` (ADR-0003 amended). |
| 13 | `sqlite3_threadsafe`, `not-threadsafe` | dropped | Protected: refusing a library built without thread safety. libsodium has no such query; `sodium_init` is thread-safe and Chez is required threaded (ADR-0002 context, ADR-0004). Checked against ADR-0007's sections: they protect Scheme state, not libsodium's. |
| 14 | `sqlite3_initialize`, `initialize-fails`, `initialize-misuse` | changed | `sodium_init`: control 0; `init-fails` -1; `init-other` 2 (a second code, so no single value passes for "refused"); `init-already` 1, which loads (ADR-0002 amended). Two decoy codes as v0.1.1. |
| 15 | the rest's ten: `compileoption_used`, `compileoption_get`, `open_v2`, `close`, `errmsg`, `errstr`, `errcode`, `extended_errcode`, `next_stmt`, `memory_used` | dropped | SQLite's. Replaced by the one rest entry, `sodium_memzero` (row 17). `sqlite3_memory_used` was the exit check's baseline, read after `initialize` (log's sixth call): no exit checks here (ADR-0011 amended), so the load's log has five entries and none after `sodium_init`. |
| 16 | statement tier 21, change counters 5, `sqlite3_db_config` (variadic, `va_arg`), `sqlite3_free`, `sqlite3_load_extension` (optional) | dropped | Entries M1 does not bind. Each later milestone adds its entries' decoy functions, `DECOY_LACKS_` switches and missing-api rows with its bindings (ADR-0002 amendment). No variadic function is bound (ADR-0001 amendment: no `variadic`), and no entry is optional (X-m3), so the optional-entry build and its `DECOY_LACKS_` meaning ("a library the load accepts, recording it absent") go. Checked against the convention table: it has five rows, none variadic or optional. |
| 17 | (new) `sodium_memzero` | changed-in | Logs `sodium_memzero(p,N)` or `(NULL,N)`, pointer read first as `volatile uintptr_t p = (uintptr_t) pnt;` and only `p` tested (ADR-0011 amended; `sodium_memzero` has no `nonnull` at 1.0.22, so the trap cannot show: applied, not discovered). Then zeroes through a `volatile unsigned char *` when `p` is non-zero, so a decoy that holds a wipe really wipes. |
| 18 | `DECOY_LACKS_<entry>` guards | kept | Five: `sodium_version_string`, `sodium_library_version_major`, `_minor`, `sodium_init`, `sodium_memzero`. |

Measured with a draft (not the deliverable): `$CC -Wall -Werror -shared -fPIC` compiles all eight
builds against 1.0.22's header in about 0.06 s each; the volatile form compiles. Not compiled
against 1.0.18's header here (the container has no 1.0.18 headers; slice 2's reviewer ran the five
prototypes against them and they are spelled as 1.0.22's).

### 1.2 `tests/refusal-probe.sps`

| # | Piece | | What changes, or what the drop protected |
|---|---|---|---|
| 1 | header comment | changed | New lines, new options; no extension, opens, loads, threadsafe, version number, source id, library. Cites ADR-0006, ADR-0011, ADR-0001 per §0's table. |
| 2 | imports | changed | `(only (chezscheme) eval environment foreign-entry? foreign-procedure foreign-ref putenv getenv load-shared-object)`; `(chez-sodium private conditions)`, `(private counters)`. `disable-interrupts`/`enable-interrupts` go with `tried`; `load-shared-object` is new (`--init-before`). `(libsqlite3-info)` has no counterpart. |
| 3 | `show`, `condition-types`, `raised-facts`, `option` | kept | `'library-unavailable` tests `sodium-library-unavailable?`. |
| 4 | `native` env, `reference`, `first` | kept | `reference` guards `sodium-library-unavailable?` and evals `(loaded-libsodium)`. |
| 5 | `info-fields` | dropped | Projected the `libsqlite3-info` record. `loaded-libsodium` answers an alist `((path . P) (source . S) (version . V) (major . N) (minor . N) (init . N))` the probe prints field by field. |
| 6 | `later` | changed | `loaded-libsodium` answers a **fresh list every call** (plan §4.2 item 4), so `eq?` can no longer say `same` for a loaded answer: compare loaded answers by `equal?` (`same`, else `(loaded PATH)`), refusals and raises by `eq?` as v0.1.1. What proves "the load ran once" on a success is then the decoy's whole log (no second `decoy(...)`, no second `sodium_version_string()`) and, with `--then-override`, a different path showing. F2. |
| 7 | `read-c-string`, `under-valgrind?` | kept | byte by byte, never Chez's string type (ADR-0001). |
| 8 | `--opens`: `read-cases`, `raise-tag`, `tried`, `shown`, `opens` | dropped | Protected: that a verb's refusal reaches a `with-exception-handler` handler at interrupt depth 1 with every count zero, and `call-with-X` calls its procedure or not. No verb exists; `call-in-section`'s depth-1 rows are `test-native`'s D-rows (slice 2); each verb's rows come with it (M2, M3). Checked against the kept "nothing raises inside a critical section" rule: native's own refusal at depth 1 is held by `test-native` (D4, E12). |
| 9 | `--loads`, `loads` | dropped | Same, for `load-extension!`. |
| 10 | `--extension-loading` | dropped | The optional entry's record; no optional entry. |
| 11 | loaded lines | changed | `(loaded . P) (source . S) (version . V) (major . N) (minor . N) (init . N)`. `threadsafe` line gone. |
| 12 | refused lines | changed | `(reason) (who) (path) (source) (detail) (candidates) (irritants)`, then `(message)` with `--message`. The `(library . L)` line is dropped: no condition carries a report (ADR-0006, five fields; plan §4.2 item 4). What the load read before refusing is shown by the decoy's call log. |
| 13 | `--then-override`, `(again . (A B))`, `(counts . ((block . 0)))`, `--marker`, `(valgrind . yes/no)`, `(calls . LOG)`, `(exit status)` | kept | Order kept (§2.4). |
| 14 | (new) `--init-before yes`, `--init-after yes` | changed-in | §2.4. |

### 1.3 `tests/library-loading.sls`

| # | Piece | | What changes, or what the drop protected |
|---|---|---|---|
| 1 | header | changed | Names the six suites (§2.5), the rows each holds; no nine suites, no partition, no opens. |
| 2 | imports | changed | `(chez-sodium-testing)`, `(libsodium-oracle)` (only `c-compiler`), `(floors)`, `(only (chezscheme) getenv directory-list file-directory?)`, `(chez-sodium private discovery)` for `libsodium-world`. Gone: `(private verify)` (its `version-number->string`), `(private constants)` (result codes), `machine-type` (see 10). |
| 3 | `string-prefix?`, `string-suffix?`, `absolute?`, `join`, `set?` | kept | |
| 4 | `chez`, `read-data`, `env-order`, `spawn-in`, `spawn`, `as-data`, `probe-with`, `probe` | kept | `env-order` keeps "`-u` pairs first": GNU `env` reads `-u` only before its first assignment (measured again: `env A=1 -u HOME` fails with "env: '-u'"). Children run `env ENV… <gated-command chez --libdirs LIBDIRS --program P ARGS>`. |
| 5 | `override`, `switch-args` | changed | `CHEZ_SODIUM_LIBRARY=`, `CHEZ_SODIUM_DECOY=`; `#f` is `-u CHEZ_SODIUM_DECOY`, `""` is the empty value. |
| 6 | `once`, `outcome`, `gated?`, `valgrind-line` | kept | `gated?` reads `CHEZ_SODIUM_GATE_CHILD`. |
| 7 | `no-native-objects` | changed | `(counts . ((block . 0)))`. Connection and statement kinds are gone (ADR-0011). |
| 8 | `report`, `loaded-lines`, `loaded`, `refused-lines`, `refused` | changed | `report`: `(version . V) (major . N) (minor . N) (init . N)`. No `threadsafe`, no `library`. `refused REASON PATH SOURCE DETAIL CANDIDATES CALLS [IRRITANTS]`; default irritants `(list PATH)`; callers state them for `invalid-override` (`(list DETAIL)`) and `not-found` (`(list CANDIDATES)`), as measured. |
| 9 | `report-of` | dropped | Built the refusal's `library` line from a report. No report on a refusal (row 12 of 1.2), so nothing to build. Checked against `loaded`/`refused`: `refused` has no `library` argument. |
| 10 | `machine-platform`, the macOS arms | dropped | Protected: the platform split of the discovery rows (Apple's dylib, "no list on this platform"). Linux only (ADR-0010, global constraints). Checked against `process-world`, which reads `/proc/self/maps` on Linux: a non-Linux run fails at `process-world` by name before it reaches a row. Discovery's own non-Linux `not-found` is `test-discovery`'s (slice 1). |
| 11 | `read-floor-values` | changed | `(FLOOR-TEXT BELOW-TEXT)`, the floor from `(floor-text (read-floors) 'sodium)`, below = patch minus one when patch > 0; for patch 0 answer `(no-floors …)` so the suite fails its floors row and exits (`test-verify` does the same). No numbers. A floor change edits this helper only when patch is 0. |
| 12 | `report-entries`, `rest-entries`, `every-entry` | changed | `every-entry`: the five C names in native's order. One list; `rest-entries` is one name. |
| 13 | `optional-entries` | dropped | Protected: the one entry a library may lack and still load, kept outside the partition. No `bind-optional` exists (X-m3), the table has no optional row (ADR-0002 decision 4). Checked against the tie row (4.1 below): it holds `every-entry` alone to the table. |
| 14 | `deal-pattern`, `decoy-parts`, `entries-dealt`, `suite-part`, `file-name`, `merge-halves` | dropped | Protected: each entry's missing-api row runs in exactly one of four suites, none over 11 children; the parts equal what the pattern deals. Five entries fit one suite (§2.5, 9 children). Protection now: `missing-api-rows` iterates `every-entry` itself, and the tie row holds `every-entry` to the convention table, whole and in order (so an entry dropped from the list takes its row with it only by failing that row: chez-sqlite3's "a list that makes rows makes no row for what it drops"). Checked against the budget rule (§2.5): 9 children. **Returns when M2/M3 entries push `-missing` past the budget** (F9). |
| 15 | `decoy-source`, `lacks`, `lacks-build`, `all-builds`, `decoy-builds`, `compile-decoy`, `compile-decoys`, `decoy-status`, `decoy-row-in` | changed | `all-builds`: `control`, `marked` (`-DDECOY_MARKER`), `not-sodium` (`-DDECOY_NOT_SODIUM`), one `lacks-ENTRY` per `every-entry`. `lacks-rest` is dropped: with one rest entry it equals `lacks-sodium_memzero`. `compile-decoy` passes `-DDECOY_VERSION="T" -DDECOY_BELOW="T-1"` only. A failed compile fails its row, never skips (ADR-0001). |
| 16 | `read-switch`, `log-of`, `every-call`, `loaded-calls` | changed | `version-calls` = `sodium_version_string()`, `sodium_library_version_major()`, `sodium_library_version_minor()`; `init-call` = `sodium_init()`; `(loaded-calls S)` = `decoy(S)` + version-calls + init-call; no memory-used call. |
| 17 | `the-report-three`, `threadsafe-call`, `initialize-call`, `memory-used-call` | dropped | Folded into 16. |
| 18 | `code-of` | dropped | Read SQLite result codes from `constants.sls`. `init-failed`'s detail is the raw integer the decoy answers, -1 and 2, written in the suite: an expected value no code under test can produce (AGENTS.md). The real library cannot answer -1 (mutex failure only): the rows that need it are decoy rows, and the real 0 and 1 are the oracle's (slice 2). |
| 19 | `opens-arg`, `open-calls`, `loads-arg` | dropped | Opens. Same reason as 1.2 row 8. |
| 20 | `missing-api-rows` | changed | Per entry the log is `decoy(control)` and the calls made before it (§2.3). |
| 21 | `field`, `make-directory` | kept | |
| 22 | `process-world`, `unset-override`, `no-profiles-env`, `guix-candidates-in` | changed | `process-world` calls `libsodium-world`. `no-profiles-env ENV PROFILE HOME`: unset override and decoy, `GUIX_ENVIRONMENT`, `GUIX_PROFILE` and `HOME` each an empty directory, so all five profile sources are listed. `guix-candidates-in ENV PROFILE HOME` lists the ten paths, `.so.26` then `.so.23` in each, in ADR-0002's order (measured, §4). |
| 23 | `gate-log-dir`, `gate-logs`, `command-of-log`, `lines-of`, `command-line-of`, `preflight-in`, `preflight` | kept | `CHEZ_SODIUM_GATE_CHILD`. |
| 24 | `counts-line`, `text`, `accepted-text` | changed | `"  counts:     ((block . 0))\n"`; accepted text is `chez-sodium: libsodium loaded and accepted`, `  path:       P (S)`, `  version:    V (library MAJOR.MINOR)`, counts; no source id. |

### 1.4 `tests/test-library-loading-*.sps`

v0.1.1 had nine suites: `-missing-1..4`, `-real`, `-preflight`, `-extension`, `-decoys`, `-combined`.
Each row below is a v0.1.1 row, with its fate. New suites and rows are in §3.

| # | Piece | | What changes, or what the drop protected |
|---|---|---|---|
| 1 | runner prologue, `CHEZ names the Chez to spawn`, scratch directory, floors row, "this process never loaded", "scratch removed", `(exit (suite-exit-status runner))` | kept | "never loaded" tests `sodium_version_string` and `decoy_calls` with `foreign-entry?`. |
| 2 | `-decoys`: control; below-floor | kept | |
| 3 | `-decoys`: not-threadsafe | dropped | Protected the threadsafe refusal. No libsodium counterpart (1.1 row 13). |
| 4 | `-decoys`: libversion-null (`load-failed`, naming the entry) | changed | `version-null`: **`below-floor`, detail `#f`** (ADR-0003 amended); log has all three version calls (the load reads major and minor before it checks the floor). |
| 5 | `-decoys`: sourceid-null, sourceid-utf8 | dropped | 1.1 row 11. |
| 6 | `-decoys`: initialize-fails, initialize-misuse | changed | `init-fails` -1, `init-other` 2: `init-failed`, detail the integer. |
| 7 | `-decoys`: near-miss values `Below-floor`, `below-floorX`, `""` | kept | Move to `-combined` (§2.5): they test the decoy's exact compare, not a load rule. |
| 8 | `-decoys`: "the decoy's entry lists are the convention table's names" | changed | Moves to `-missing` and `test-conventions` (the owed row, §3.7). |
| 9 | `-decoys`: "CC is cut at whitespace" | kept | `c-compiler` has no other row in chez-sodium. |
| 10 | `-combined`: `lacks-rest` row | dropped | `lacks-rest` equals `lacks-sodium_memzero` here (1.3 row 15); that row is in `-missing`. |
| 11 | `-combined`: `not-sqlite` row | changed | `not-sodium`: `missing-api`, detail `sodium_version_string`, log `decoy(control)`. In `-missing`. |
| 12 | `-combined`: order rows (a lacking build under a refusing switch) | changed | The order is five steps, so three rows: `lacks-sodium_memzero` under `below-floor` and under `init-fails`, `lacks-sodium_init` under `below-floor` (§3.2). v0.1.1's `lacks-threadsafe` rows go with threadsafe. |
| 13 | `-combined`: kept refusal with `--then-override` and `--marker` | kept | Plus a kept-success row (§3.3). |
| 14 | `-combined`: marked build, marker present | kept | |
| 15 | `-missing-1..4`: partition rows (merge-halves, deal pattern, suite part, each suite a file) | dropped | 1.3 row 14. |
| 16 | `-missing-1..4`: missing-api rows | changed | One suite, five entries (§3.2). |
| 17 | `-extension` (whole suite) | dropped | Protected: the optional `sqlite3_load_extension`'s rows, the opt-in's check, `load-extension!` on the decoy. No optional entry, no extension (1.1 row 16). Checked against `-missing`: every entry required, so every lacking build is refused. |
| 18 | `-real`: ambient probe, per-field vs oracle, override probe, preflight on the real library, oracle never-raises row | changed | Fields `version major minor init`; no `version-number`, `source-id`, `threadsafe`; `init` against the oracle's first `sodium_init` answer. Kept: the row that a raise inside the oracle's directory answers `no-oracle` and removes the directory (chez-sodium has no such row). |
| 19 | `-real`: bare-name override, text file, missing path | kept | Plus an empty override (§3.4). |
| 20 | `-real`: discovery in the Guix world, not-found, broken profile; FHS arms | changed | Moved to `-discovery`. Not-found lists ten candidates (§4). macOS arm and the "no list on this platform" arm dropped (1.3 row 10). |
| 21 | `-real`: "every C oracle run ran under Valgrind exactly when the gate asked, and at least two" | changed | At least **one** in `-real`, and at least two in `-discovery` (§3.4, §3.5). |
| 22 | `-preflight`: raising fixture probe, preflight on control, below-floor, bare name, raise (exit 255, no reason line), not-found (guix) | kept | Plus `init-fails` (§3.6). Messages compared with the probe's `--message`, never as text. |
| 23 | `-preflight`: "every probe that read a message ran under Valgrind" | kept | |

### 1.5 `tests/fixtures/raising/chez-sodium/private/native.sls`

| # | Piece | | |
|---|---|---|---|
| 1 | library name, header | changed | `(chez-sodium private native)`. Shadows `src/`'s with `--libdirs tests/fixtures/raising:src`. |
| 2 | `loaded-libsqlite3` raising a plain `error` | changed | `loaded-libsodium`, same body. |
| 3 | `loaded-threadsafe` | dropped | The probe and preflight referenced it; neither does now. |

Imports `(rnrs)` only; binds no foreign procedure; `check-seam` and `test-conventions` read `src/`
alone, so neither sees it.

### 1.6 `tests/check-dev.sh`

| # | Piece | | |
|---|---|---|---|
| 1 | header, `missing=` path, labels | changed | `/nonexistent/chez-sodium-check-dev/libsodium.so.26`, `chez-sodium: libsodium loaded and accepted` and `... refused`. The "adapted from chez-curl" line stays (a sibling). |
| 2 | `fresh_copy`, `fail`, traps, `timeout`, `limit`, `mktemp` | kept | The copy excludes `.git`, `build/`, `.claude/`; handles `vendor/chez-srfi/.git`; verified: the tree is 7.8 MB, one `.git` file under `vendor/`. |
| 3 | `forms` | changed | Imports `(chez-sodium private native) (chez-sodium-testing) (srfi :64)`; no `libsqlite3-info`. Reads the alist: `(cdr (assq 'version info))`. The forms are inside a shell single-quoted string, so write `(quote version)`, not `'version` (measured, §4). Prints `check-dev: ok version V (library MAJOR.MINOR)` and `check-dev: ok path P (S)`. |
| 4 | the awk verdict | changed | Labels as `preflight.sps` prints them (`  version:    ` 14 chars, `  path:       `); the REPL's version line must equal build's version line after its label, `V (library M.N)` whole. Order, once-each, banner rules kept. |
| 5 | `repl` and `refused` cases | kept | With `CHEZ_SODIUM_LIBRARY` naming no file the refusal is `load-failed` (an absolute path that does not exist). |

### 1.7 Makefile: `dev`, `check-dev`

| # | Piece | | |
|---|---|---|---|
| 1 | `dev: deps build`, recipe `$(CHEZ) --libdirs $(LIBDIRS)` | kept | Comment names `(chez-sodium private native)` as what a REPL can import; `(chez-sodium)` after slice 4. |
| 2 | `check-dev` recipe, `require-tools "$(GOAL)" $(TIMEOUT) $(CHEZ)`, `MAKE=… TIMEOUT=… sh tests/check-dev.sh` | kept | |
| 3 | `.PHONY` and `##` help | changed | Add `dev check-dev` to the one `.PHONY` line, and a `##` help comment on each. `check-help` fails until both agree. |
| 4 | prerequisite of `test` | not added | `check-dev` runs `make deps` in fresh copies; v0.1.1 does not make it a prerequisite of `test`; CI's `main` names it (plan §2.4, the CI agent's). Because it is no prerequisite, no `check-test-fails` plant is owed for it (chez-sqlite3 traps: "each new prerequisite comes with its plant"). |

### 1.8 `tests/test-conventions.sps` (owed row)

| # | Piece | | |
|---|---|---|---|
| 1 | `(only (library-loading) every-entry)` import, and the row "table: its names are (library-loading)'s every-entry, the five required entry points, whole and in order" | changed-in | v0.1.1's row, minus `optional-entries`. Expected `(map row-name conventions-table)`; actual `every-entry`. It loads no libsodium (`library-loading` imports none), so the suite's "never loads libsodium" holds. |

Drops: **counted at the end of the file** (§7).

## 2. Design note

### 2.1 The decoy: builds and switches

Builds, by `-D`, chosen at compile time (what a library exports is fixed at link):

| Build | Flag | Entries |
|---|---|---|
| `control` | none | all five, `decoy_calls` |
| `marked` | `-DDECOY_MARKER` | control plus `decoy_marker` |
| `not-sodium` | `-DDECOY_NOT_SODIUM` | no `sodium_*`; `decoy_calls` |
| `lacks-sodium_version_string` ... `lacks-sodium_memzero` | `-DDECOY_LACKS_<entry>` | control without that one |

Every build also gets `-DDECOY_VERSION="FLOOR" -DDECOY_BELOW="BELOW"`, `FLOOR` from
`(floor-text (read-floors) 'sodium)` and `BELOW` the same with the patch minus one (1.0.17 today).
`-Wall -Werror -shared -fPIC`, `$CC` from `c-compiler`, no `-I` (as `test-constants`).

`CHEZ_SODIUM_DECOY`, read once, at load, compared whole:

| Value | `sodium_version_string` | major, minor | `sodium_init` | Load answers (measured) |
|---|---|---|---|---|
| unset (`control`) | FLOOR | 10, 3 | 0 | loaded, `(init . 0)` |
| `below-floor` | BELOW | 10, 3 | 0 (never called) | `below-floor`, detail BELOW |
| `version-null` | NULL | 10, 3 | never called | `below-floor`, detail `#f` |
| `version-malformed` | FLOOR `-stable` | 10, 3 | never called | `below-floor`, detail `"1.0.18-stable"` |
| `version-bom` | EF BB BF then FLOOR | 10, 3 | never called | `below-floor`, detail U+FEFF then FLOOR |
| `libtool-high` | BELOW | 99, 99 | never called | `below-floor`, detail BELOW |
| `libtool-low` | FLOOR | 0, 0 | 0 | loaded, `(major . 0) (minor . 0)` |
| `init-fails` | FLOOR | 10, 3 | -1 | `init-failed`, detail -1 |
| `init-other` | FLOOR | 10, 3 | 2 | `init-failed`, detail 2 |
| `init-already` | FLOOR | 10, 3 | 1 | loaded, `(init . 1)` |
| anything else, `""` too | as control | | | loaded, log starts `decoy(?VALUE)` |

Control's 10 and 3 differ from each other and from 0, 99, so a swap or a constant shows. Both of
`libtool-high` and `libtool-low` are needed: `libtool-high` kills a native that *accepts* on a high
major, `libtool-low` one that *refuses* on a low one.

`version-bom` crosses stdout as data: `write` prints the BOM as raw UTF-8 bytes and the suite's
`capture-command` read-back gets an `equal?` string (measured, `build/slice3-refusals/bomrt.sps`).

**Pointers.** Every logged pointer is `volatile uintptr_t p = (uintptr_t) ptr;` and only `p` is
tested, whether or not the entry is `nonnull` (ADR-0011 amended; traps "nonnull is per function").
In M1 only `sodium_memzero`'s `pnt` is logged. `sodium_version_string`'s returned pointer is
not a parameter. Nothing in M1 can show the trap; F7 notes nothing holds the rule.

### 2.2 The call log, and what each row proves from it

Log: entries separated by one space, written at each call; `decoy_calls()` returns it; the probe
prints it last, as `(calls . "…")`, read byte by byte. The suite asserts it **whole**, so "C was not
reached" is an absence in an exact string, never a substring check. First entry is written by the
library's constructor at load: `decoy(control)`, `decoy(SWITCH)` or `decoy(?VALUE)`.

Entries: `sodium_version_string()`, `sodium_library_version_major()`,
`sodium_library_version_minor()`, `sodium_init()`, `sodium_memzero(p,N)` or `(NULL,N)`.

The load's order, and the log each stop leaves (V = the three version calls, in that order):

| Step | Stop | Reason | Log after `decoy(S)` |
|---|---|---|---|
| 1 choose | override bad; nothing found | `invalid-override`, `not-found` | no decoy loaded: **no `(calls …)` line** (the probe finds no `decoy_calls`) |
| 2 load | loader refuses | `load-failed` | none: nothing loaded, or a text file |
| 3 version entries | one of the three absent (all three are bound before any is called) | `missing-api` | nothing |
| 3 version entries | `not-sodium` (the first asked is the string) | `missing-api` | nothing |
| 4 floor | string unreadable or low | `below-floor` | V, no `sodium_init()` |
| 5 init | `sodium_init` absent | `missing-api` | V |
| 5 init | answers -1 or 2 | `init-failed` | V, `sodium_init()` |
| 6 rest | `sodium_memzero` absent | `missing-api` | V, `sodium_init()` |
| accepted | | loaded | V, `sodium_init()`; `sodium_memzero` bound, never called |

So the five orderings the plan names are rows of the log, each measured against current native
(§4): floor before init (`below-floor` log lacks `sodium_init()`); init before the rest
(`lacks-memzero` under `init-fails` is `init-failed`); floor before init's *binding*
(`lacks-init` under `below-floor` is `below-floor`); the three version entries bound before any call
(every lacking version-entry log is `decoy(control)` alone); the calls' own order (control's log).

### 2.3 Expected answers (whole, as the probe prints them)

With P = the build's path, S = `override`, `no-native-objects` = `(counts . ((block . 0)))`,
`once` = `(again . (same same))`, `valgrind-line`, and the stderr `""`:

- **loaded:** status 0; `(loaded . P) (source . override) (version . V) (major . N) (minor . N) (init . N)`; `once`; counts; valgrind; `(calls . LOG)`.
- **refused:** status 1; `(reason . R) (who . chez-sodium) (path . P) (source . S) (detail . D) (candidates . L) (irritants . I)`; `once`; counts; valgrind; calls if a decoy loaded.
  - I = `(P)` for below-floor, missing-api, init-failed, load-failed;
  - `invalid-override`: path `#f`, source `override`, detail = the value, I = `(VALUE)`;
  - `not-found`: path `#f`, source `#f`, detail `#f`, candidates = every path, I = `(CANDIDATES)`.

### 2.4 `refusal-probe.sps` options

`refusal-probe.sps [--then-override PATH] [--marker NAME] [--message yes] [--init-before yes] [--init-after yes]`

- `--then-override`, `--marker`, `--message`: as v0.1.1.
- **`--init-before yes`:** before the first reference, `(load-shared-object (getenv "CHEZ_SODIUM_LIBRARY"))`, bind `sodium_init` with `(eval '(foreign-procedure "sodium_init" () int) (environment '(chezscheme)))` (an own binding, outside `src/`), call it, print `(init-before . N)` as the **first line**. A failure there prints `(init-before raised WHO TYPES)` and the probe goes on. For rows on the **real** library only: against a decoy it would add `sodium_init()` to the log.
- **`--init-after yes`** (new, F3): after the three references and `(again …)`, call a direct `sodium_init` once and print `(init-after . N)` right after the `again` line. Only if the first reference loaded. Rows on the real library only.
- Order of output: `(init-before …)`; first reference's lines; `(then-override …)`; `(again …)`; `(init-after …)`; `(counts …)`; `(marker …)`; `(valgrind …)`; `(calls …)`. Status by the first reference (0, 1, 2).
- **Row 21 both ways, real library, override = the real path:**
  - `--init-before yes --init-after yes`: `(init-before . 0)`, loaded with `(init . 1)`, `(init-after . 1)`;
  - `--init-after yes` alone: loaded with `(init . 0)`, `(init-after . 1)`.
  Measured on the container's 1.0.22, plain and under the gate's Valgrind options (0 errors, nothing lost; 3.8 s): `build/slice3-refusals/initbefore.sps`, `loadfirst.sps`, `vgib.sh`. The rows' expected values are literal 0 and 1 and the oracle's `(init 0 1)`.

### 2.5 The suites, their rows, and the split under the gate

**Measured.** One Chez child under the gate's Valgrind options, container: 3.85 s (preflight 3.87,
a decoy `control` load 3.85, `not-sodium` 3.83, `invalid-override` with no `dlopen` 3.82), against
0.07 s plain. The plan's 2.6 s was `ffi.sps`; a program that imports `src/` libraries is slower.
The oracle under the gate: 0.25 s. A whole `test-native` run under the gate: 8 s, so a suite's parent
costs about 8 s. CI's runner is about 2.2 times this machine (chez-sqlite3's 5.8 s against 2.6 s):
**8.5 s a child there, estimated; record CI's first run.** The gate fails a suite past 450 s
(three quarters of 600).

**Budget rule:** at most 14 children per suite, so that CI's estimate, `14 x 8.5 + 20`, is about 140
s, under a third of the limit. v0.1.1's rule was "at most 11" at 5.8 s. The builder runs each suite
under `make test-memory MEMORY_SUITES=tests/test-library-loading-X.sps` and records its time; a suite
over 60 s here is split again.

| Suite | Rows (children) | Parent + children, here |
|---|---|---|
| `-decoys` | control, `below-floor`, `version-null`, `version-malformed`, `version-bom`, `libtool-high`, `libtool-low`, `init-fails`, `init-other`, `init-already` (10) | ~47 s |
| `-missing` | five lacking builds (5), `not-sodium` (1), three order rows (3) = 9 | ~43 s |
| `-combined` | kept refusal (1), kept success (1), marker control (1), near-miss `Below-floor`, `below-floorX`, `""` (3) = 6; plus the wipe row if accepted (F4) | ~32 s |
| `-real` | ambient probe, override probe, `invalid-override` bare, `invalid-override` empty, `load-failed` text, `load-failed` missing, row 21 both ways (2) = 8 probes; the oracle once (0.25 s); preflight on the real library (1) = 9 children | ~44 s |
| `-discovery` | discovery (1), not-found (1); in a Guix world also only-`libsodium.so` (1), both sonames (1), only `.so.23` (1), broken profile (1) = 6; oracle 2 or 3 runs | ~35 s |
| `-preflight` | raising-fixture probe (1); preflight: control, below-floor, bare name, `init-fails`, raise, not-found (6) with a `--message` probe each for the four refusals (4) = 11 | ~52 s |

About 49 children and 4 minutes here; about 10 minutes on CI's `memory` job. The first
`-discovery` and `-real` runs on CI's FHS world run the FHS arms (§3.4).

Every child through `gated-command`; each says `(valgrind . yes)` exactly when the gate asked
(`valgrind-line`); preflight's is read from the gate's one new log, `Command:` line whole (kept from
v0.1.1). The wipe child of slice 2 is the only child outside.

### 2.6 `check-dev.sh`, `dev`, `check-dev`

`make dev` = `deps build`, then `$(CHEZ) --libdirs $(LIBDIRS)`. `check-dev.sh` copies the tree to
a scratch directory with no `build/`, runs `make dev` there with the forms piped in, and requires:

- **`repl`:** exit 0; `chez-sodium: libsodium loaded and accepted` once; the REPL banner
  `Chez Scheme Version ` once, after the report; one line each of `check-dev: ok version V (library
  M.N)` and `check-dev: ok path P (S)`, after the banner, equal to build's own lines after their
  labels. Measured: the forms print exactly that in the container (`repl.sh`):
  `check-dev: ok version 1.0.22 (library 26.4)`, `check-dev: ok path /gnu/store/…/libsodium.so.26 (override)`.
- **`refused`:** with `CHEZ_SODIUM_LIBRARY=/nonexistent/chez-sodium-check-dev/libsodium.so.26`,
  `make dev` fails (not 0, not 124), prints the line `chez-sodium: libsodium refused` exactly, and
  no banner and no `check-dev: ok` line.

### 2.7 The row owed from slice 2

`tests/library-loading.sls` exports `every-entry`, the five C names in native's order
(`sodium_version_string`, `sodium_library_version_major`, `sodium_library_version_minor`,
`sodium_init`, `sodium_memzero`). Two rows hold it to the convention table, whole and in order:

- `test-conventions.sps`: `(map row-name conventions-table)` equals `every-entry` (v0.1.1's row, minus the optional list);
- `-missing`: the same, next to the rows the list makes.

Without it a list that makes rows makes none for what it drops (v0.1.1's M2 slice 2 review: delete
one entry, 90 of 90 passed). Watched: delete one entry, and swap two; both red.

### 2.8 What `make test`, `check-test-fails` and the gate need

- **`make test`:** nothing in the Makefile. The six suites match `tests/test-*.sps`;
  `check-suites` needs each to end `(exit (suite-exit-status runner))`. `library-loading.sls`,
  `refusal-probe.sps`, `check-dev.sh` and `fixtures/raising/` match no glob. Plain, a child takes
  about 0.1 s, so each suite runs in seconds, far under `TEST_TIMEOUT` 300.
- **`check-test-fails`:** nothing: no new prerequisite of `test`. Its copy holds no real suite.
- **The gate (`test-memory`, `check-memory-gate`):** nothing in the Makefile. A child's `Command:`
  is `$(CHEZ) --libdirs … --program tests/refusal-probe.sps` or `…/preflight.sps`, which the child
  rule accepts (it begins with `CHEZ`); `env` is outside Valgrind. Suite names are unique. Decoys
  hold no allocation, so a child is clean. The only new gate-time risk is a suite past the budget (§2.5).
- **`.PHONY` and `help`:** `dev` and `check-dev` (1.7 row 3).

## 3. The rows each suite holds, and what is watched to fail

Every suite, as v0.1.1: `CHEZ names the Chez to spawn`; scratch directory; floors row; a closing
"this process never loaded a libsodium nor a decoy" (`foreign-entry?` on `sodium_version_string`,
`decoy_calls`); scratch removed; `(exit (suite-exit-status runner))` last. Every probe row asserts
the **whole** answer (§2.3) with `once`, counts zero, and `valgrind-line`. SRFI-64 turns a raise in
the actual expression into `#f`: every computed value is under a guard with a sentinel, and no
expected value is `#f` from something that can raise.

Row ids are for the mutation log.

### 3.1 `-decoys` (`LD`, control build, one switch a row)

| Id | Row | Expected |
|---|---|---|
| LD0 | `c-compiler` cuts `$CC` at whitespace (4 inputs) | as v0.1.1 |
| LD1 | control, unset | loaded; (version FLOOR) (major 10) (minor 3) (init 0); log `decoy(control)` V `sodium_init()` |
| LD2 | `below-floor` | `below-floor`, detail BELOW; log `decoy(below-floor)` V |
| LD3 | `version-null` | `below-floor`, detail `#f`; log `decoy(version-null)` V |
| LD4 | `version-malformed` | `below-floor`, detail FLOOR `-stable` |
| LD5 | `version-bom` | `below-floor`, detail U+FEFF FLOOR |
| LD6 | `libtool-high` | `below-floor`, detail BELOW; log V only |
| LD7 | `libtool-low` | loaded; `(major . 0) (minor . 0)`, version FLOOR, log with `sodium_init()` |
| LD8 | `init-fails` | `init-failed`, detail -1; log V `sodium_init()` |
| LD9 | `init-other` | `init-failed`, detail 2 |
| LD10 | `init-already` | loaded, `(init . 1)` |

Watched (each in a whole copy, `src/` mutated; expect exactly the named rows red, the rest green):

| Mutant | Red |
|---|---|
| `check-version` always `#t` (native's floor skipped) | LD2 LD3 LD4 LD5 LD6 |
| the floor read from major and minor (accept only when major is at least 10, or the like) | LD6 and LD7 |
| the parse takes a leading natural run (`1.0.18-stable` accepted) | LD4 |
| `c-string->string` without its BOM restore | LD5 |
| the strict parse accepts a leading zero or a space | none here (`test-verify`'s); state so |
| `check-init` accepts 2 (or any nonzero but -1) | LD9 (and LD8 for accept-all) |
| `check-init` refuses 1 | LD10 |
| `sodium_init` never called (`init` fixed at 0) | LD1 (log), LD8, LD9, LD10 |
| `sodium_init` called before the floor check | LD2 LD3 LD4 LD5 LD6 (log gains `sodium_init()`) |
| the three version calls reordered | LD1 (and every log) |
| NULL string raised as `load-failed` | LD3 |
| recorded `init` always 0 | LD10 |
| the decoy's switch compare is a prefix compare (`strncmp`) | LC near-miss rows |

### 3.2 `-missing` (`LM`)

| Id | Row | Expected |
|---|---|---|
| LM1..LM5 | for each of `every-entry`, the lacking build, no switch | `missing-api`, detail the C name, path P, source `override`; log: for the three version entries `decoy(control)`; `sodium_init`: `decoy(control)` V; `sodium_memzero`: `decoy(control)` V `sodium_init()` |
| LM6 | `not-sodium` | `missing-api`, detail `sodium_version_string`; log `decoy(control)` |
| LM7 | `lacks-sodium_memzero` under `below-floor` | `below-floor`; log `decoy(below-floor)` V |
| LM8 | `lacks-sodium_memzero` under `init-fails` | `init-failed`, -1; log up to `sodium_init()` |
| LM9 | `lacks-sodium_init` under `below-floor` | `below-floor`; log V |
| LM10 | table tie | `every-entry` equals the convention table's names, whole and in order |
| LM11 | every build compiled | each status 0 |

| Mutant | Red |
|---|---|
| `sodium_memzero` bound lazily (its bind moved out of the load) | LM5 |
| `required-entry` check dropped for one entry (Chez's bare "no entry for") | that entry's LM row |
| memzero bound before the `sodium_init` check | LM8 |
| `sodium_init` bound before the floor check | LM9 |
| major bound after the string is called | LM2 LM3 (log shows `sodium_version_string()`) |
| `every-entry` loses an entry, or two swap | LM10 (and the table row in `test-conventions`) |
| the decoy lacks an entry native requires | LD1 (control refused) |

### 3.3 `-combined` (`LC`)

| Id | Row | Expected |
|---|---|---|
| LC1 | kept refusal: `control` under `below-floor`, `--then-override MARKED --marker decoy_marker` | `below-floor` as LD2; `(then-override . MARKED)`; `once`; `(marker . absent)`; log LD2's, whole |
| LC2 | kept success: `control` unset, `--then-override MARKED --marker decoy_marker` | loaded as LD1; `(then-override . MARKED)`; `(again . (same same))`; `(marker . absent)`; log LD1's, whole |
| LC3 | `marked` build, `--marker decoy_marker` | loaded; `(marker . present)`; log LD1's |
| LC4..6 | `Below-floor`, `below-floorX`, `""` on control | loaded; log starts `decoy(?Below-floor)`, `decoy(?below-floorX)`, `decoy(?)`, then V `sodium_init()` |

| Mutant | Red |
|---|---|
| step 0 dropped, or `record-load-failure!` a no-op (refusal not kept) | LC1 (second load runs: marker present, log longer) |
| the load re-run for a changed override after a success | LC2 |
| `load-step` dropped (a raise not recorded) | LC1 |

LC2 is the plan's "a second load after a changed override".

### 3.4 `-real` (`LR`) and `-discovery` (`LV`)

`-real`:

| Id | Row | Expected |
|---|---|---|
| LR1 | ambient probe (override as the environment has it) | exit 0, loaded by absolute path |
| LR2 | ambient probe's valgrind line | `valgrind-line` |
| LR3 | ambient probe vs the oracle, field by field | `version`, `major`, `minor` equal the oracle's; `(init . 0)` equals the oracle's first `sodium_init` answer |
| LR4 | override probe on the real path | loaded, whole, with the oracle's report; `(init . 0)` |
| LR5 | preflight on the real library | `accepted-text` whole, exit 0, valgrind |
| LR6 | oracle's raise inside its directory | `(no-oracle raised 1 ())`: answers, and the directory is gone (v0.1.1's row) |
| LR7 | `invalid-override`, `libsodium.so.26` | path `#f`, source `override`, detail the value, irritants `(VALUE)` |
| LR8 | `invalid-override`, empty override | detail `""` |
| LR9 | `load-failed`, a text file | detail what `load-shared-object` says, computed in the parent by `loader-text` |
| LR10 | `load-failed`, a missing path | same |
| LR11 | row 21, `--init-before yes --init-after yes` | `(init-before . 0)`, loaded `(init . 1)`, `(init-after . 1)` |
| LR12 | row 21, `--init-after yes` | loaded `(init . 0)`, `(init-after . 1)` |
| LR13 | every oracle run said whether it ran under Valgrind, at least one | |

`-discovery`:

| Id | Row | Expected |
|---|---|---|
| LV1 | guix world: override unset | loaded `$GUIX_ENVIRONMENT/lib/libsodium.so.26`, source `guix-environment`, report equal the oracle's. FHS world: loaded the first standard candidate that exists, source `system` |
| LV2 | guix world: `no-profiles-env` (three empty directories) | `not-found`, candidates the ten, `.so.26` then `.so.23` in `GUIX_ENVIRONMENT`, `GUIX_PROFILE`, `$HOME/.guix-home/profile`, `$HOME/.guix-profile`, `/run/current-system/profile`. FHS: discovery's success (as LV1) |
| LV3 | guix: a directory holding only `libsodium.so` as `GUIX_ENVIRONMENT` | `not-found`, the ten candidates (the bare name is not among them) |
| LV4 | guix: `libsodium.so.26` a real copy, `.so.23` a text file | loaded `.so.26`; a `.so.23`-first load would be `load-failed` |
| LV5 | guix: only `libsodium.so.23`, a real copy | loaded `.so.23`, `guix-environment` |
| LV6 | guix: a text file as the first candidate, a real library as `GUIX_PROFILE` | `load-failed` on the first, with the loader's message; the second never tried |
| LV7 | every oracle run said whether it ran under Valgrind, at least two | |

LV3 to LV6 are Guix-only: the standard directories cannot be emptied in an FHS world, so there the
row's name says which world ran, as v0.1.1.

| Mutant | Red |
|---|---|
| `.so.23` before `.so.26` | LV4 (and LV2's list) |
| the bare `libsodium.so` tried | LV3 |
| `LD_LIBRARY_PATH` read | none here (slice 1's); state so |
| a Guix profile in an FHS world, or a standard directory in a Guix world | LV2 (list) |
| world always `fhs` | LV1 in the container |
| an empty override treated as unset | LR8 |
| a load error raised raw, not as `load-failed` | LR9 LR10 LV6 |
| the next candidate tried after a failed load | LV6 |
| recorded init wrong when libsodium is initialised first | LR11 |
| recorded init read from a later call | LR12 |

### 3.5 `-preflight` (`LP`)

| Id | Row | Expected |
|---|---|---|
| LP1 | probe on the raising fixture | `(raised loaded-libsodium (serious error who message irritants))`, `(again ((raised …) (raised …)))`, counts, valgrind; exit 2; stderr `""` |
| LP2 | preflight, control | exit 0, `accepted-text` whole |
| LP3 | preflight, `below-floor` | exit 1, stderr: header, `(reason . below-floor)`, `path`, `source: override`, `detail: BELOW`, `candidates: none`, `remedy: ` the probe's message, counts |
| LP4 | preflight, bare name | `invalid-override`; path `none`, source `override`, detail the value |
| LP5 | preflight, `init-fails` | `init-failed`, detail `-1` |
| LP6 | preflight on the raising fixture | exit 255, stdout `""`, no `(reason ` line |
| LP7 | preflight, not-found (guix world), `no-profiles-env` | `candidates:` then the ten, each on a line of four spaces |
| LP8 | every message probe said whether it ran under Valgrind, at least two | |

| Mutant | Red |
|---|---|
| preflight prints a remedy of its own | LP3 LP4 LP5 LP7 |
| preflight guards `chez-sodium-error?` or `#t` instead of `sodium-library-unavailable?` | LP6 |
| preflight's last line not the counts | every LP |
| the probe's `gated-command` dropped from `spawn-in` | every row red under `make test-memory` only (plain passes): say so in the suite's header |

### 3.6 `check-dev` (`CD`), watched

Each in a copy; `make check-dev` must fail with the named line.

| Mutant | Case red |
|---|---|
| `dev` without `build` as a prerequisite | `refused` (a REPL starts: banner) |
| `dev` without `deps` | `repl` (no `build/scheme-libs`: the REPL prints an import error, the `check-dev: ok` lines are missing) |
| the REPL's version line prints the string alone, not `V (library M.N)` | `repl` ("the REPL loaded… but build named…") |
| `build` run twice | `repl` ("report appears 2 times") |
| the banner before build's report | `repl` (order) |
| `check-dev.sh`'s refused case passes on any nonzero | `refused`'s refusal-line check: plant a failure that is not a refusal |

### 3.7 Not rows of mine

`check-ci` rules (the CI agent's, "as v0.1.1 plants it").

### 3.8 Proposed row, needs the owner (F4)

`--wipe N` on the probe: after the load, `(call-in-section (lambda () (call-with-bytes 'probe
(make-bytevector N 65) (lambda (a) 'ok))))` in native's environment, printing `(wipe . ok)`. On the
control decoy: log `… sodium_init() sodium_memzero(p,N)`; for N = 0 `sodium_memzero(p,1)`. Measured:
`((block . 0))` and exactly those entries (`build/slice3-refusals/wipe.sps`). It proves the wipe is
one call over the block's size, and the empty bytevector's one-byte block, end to end, from C's own log
(ADR-0008). It is also the only row that reaches the decoy's `sodium_memzero`. Watched: the wipe
shortened by one byte, doubled, or dropped: red. One child, in `-combined`.

## 4. Measurements run (§5.2 slice 3)

Container, `scripts/guix-env sh …`, files under `build/slice3-refusals/`. Chez 10.4.0, Valgrind
3.27.0, libsodium 1.0.22, GCC 16.2.

| What | Ran | Got |
|---|---|---|
| The not-found row's world | `notfound.sh`, `notfound2.sh`: override unset, `GUIX_PROFILE` unset, `HOME` an empty dir, `preflight.sps` | `GUIX_ENVIRONMENT` at an empty dir: **8 candidates**, `<env>/lib/.so.26`, `.so.23`, then `$HOME/.guix-home/profile`, `$HOME/.guix-profile`, `/run/current-system/profile`, each `.so.26` then `.so.23`; exit 1, `not-found`. With `GUIX_ENVIRONMENT` unset: 6. With `GUIX_PROFILE` also an empty dir: **10**, all five sources. `/run/current-system` does not exist in the container |
| Ambient discovery, override unset | same | loaded `$GUIX_ENVIRONMENT/lib/libsodium.so.26 (guix-environment)`, `1.0.22 (library 26.4)` |
| A directory holding only `libsodium.so` | `run2.sh`/`run3.sh` | `not-found`, bare name not in the list |
| Both sonames, `.26` real, `.23` a text file | `run3.sh` | loaded `.so.26`, `guix-environment` |
| Only `.so.23`, a real copy | `run3.sh` | loaded `.so.23` |
| A text file first, a real library second | `run3.sh` | `load-failed`, "file too short"; second never tried |
| `invalid-override` bare, empty | `run2.sh` | both `invalid-override`, detail the value, irritants `(VALUE)` |
| `load-failed` text file, missing path | `run2.sh` | both, detail `(while loading P) P: file too short` / `…cannot open shared object file…` |
| Draft decoy, 8 builds | `build.sh`: `-Wall -Werror -shared -fPIC` | 0.06 s each, compiled, volatile form accepted |
| Every switch and lacking build against current native | `run.sh` (30 runs) | reason, detail and log as §2.1 and §2.2 state; also `lacks-sodium_memzero` under `below-floor`, `init-fails`, `init-other` and `lacks-sodium_init` under `below-floor` give the earlier reason |
| Row 21, real library | `initbefore.sps`, `loadfirst.sps` | before: `(init-before 0)`, load `(init . 1)`, `(init-after 1)`; load first: `(init . 0)`, `(init-after 1)` |
| Row 21 under the gate's Valgrind options | `vgib.sh` | exit 0, 3.8 s, 0 errors, nothing definitely lost |
| One child under the gate | `vgtime.sh`, `vgtime2.sh` | 3.87 s (preflight), 3.85 s (decoy load), 3.83 s (not-sodium), 3.82 s (no dlopen), oracle 0.25 s; plain 0.07 s |
| The wipe through the decoy | `wipe.sps` | `((block . 0))`; log ends `sodium_memzero(p,5) sodium_memzero(p,1)` |
| The BOM through stdout and `capture-command` | `bom.sps`, `bomrt.sps` | `(0 #t)` |
| The REPL forms of `check-dev` | `repl.sh` | prints the two `check-dev: ok` lines; exit 0; banner once |
| A suite under the gate, parent cost | `make test-memory MEMORY_SUITES="tests/test-discovery.sps tests/test-native.sps tests/test-wipe.sps"` | 8 s, 8 s, 6 s |

Not measured: CI's per-child time (estimated 8.5 s); GCC 13 and Valgrind 3.22 against the decoy;
the decoy against 1.0.18's header (not in the container).

## 5. Flags

- **F1. The plan lists `preflight.sps` under §2.2 slice 3's reading, but slice 2 built it.** It
  already has the plan's shape; slice 3 only runs it. No change owed.
- **F2. `(again . (same same))` changes meaning for a success.** `loaded-libsodium` answers a fresh
  list each call, so `eq?` never says `same`. The probe compares loaded answers by `equal?`. The
  proof that a success loaded once is then the decoy's whole log plus `--then-override` showing a
  different path (LC2), not object identity. Refusals keep `eq?`.
- **F3. The plan names `--init-before yes` and `(init-after . N)`; row 21's second half ("the load
  first, after which a direct call answers 1") has no call before it.** A second option,
  `--init-after yes`, is needed. Printing `init-after` always would put a probe-made `sodium_init()`
  into every decoy log, and then no log could say "C was not reached" cleanly.
- **F4. The decoy's `sodium_memzero` logging and zeroing is code no M1 row reaches** (the load binds
  and never calls it). The plan's rule (pointers through `volatile uintptr_t`) is therefore applied
  to dead code. Recommend the `--wipe N` row of §3.8 (one child). The owner chooses; without it
  the builder writes the body and says in the decoy's header that no row calls it yet.
- **F5. `tests/test-conventions.sps` is not in slice 3's "owns" list,** yet the owed row is its
  edit (one import, one row). The builder edits it; nobody else touches it in slice 3.
- **F6. The nine suites do not carry over.** Six: `-decoys`, `-missing`, `-combined`, `-real`,
  `-discovery`, `-preflight`. `-extension` and `-missing-1..4` are gone (five entries, no optional
  one). `-discovery` is split from `-real` to keep each suite within the budget.
- **F7. Nothing holds the decoy's pointer rule in M1.** `-Werror=nonnull-compare` only fires on a
  `nonnull` function, and none of the five is. "Prefer a check to a comment" is unmet here. A
  mutant (the ternary on `pnt`) compiles and every row passes. M2's `randombytes_buf` decoy is the
  first place the compiler holds it. Not fixed here; the mutation log should say so.
- **F8. Not-found in a Guix world outside the container** can find `/run/current-system/profile`
  holding a libsodium and fail. The container has none. The row's expected list is the ten
  candidates, so a Guix System host that runs `make test` bare (not through `scripts/guix-env`)
  can see LV2 and LP7 fail. AGENTS.md already says to run through the container.
- **F9. The partition returns.** Dropping `deal-pattern` and its relatives is right for five
  entries. M2 adds `randombytes_buf`, `crypto_generichash`, its six sizes and `sodium_memcmp`:
  about ten more entries, so `-missing` is past 14 children then. Record it in the slice's
  close-out; M2's plan decides the split.
- **F10. The plan's measurement says "GUIX_ENVIRONMENT at an empty directory": 8 candidates.** v0.1.1
  unset it (6). Recommended: three empty directories (10), which lists every source and so holds
  all five in order. Say so in the close-out.
- **F11. Child time is 3.85 s here, not the plan's 2.6 s,** since the probe imports `src/`
  libraries. The budget (14 children) is set from this measurement, not the plan's.
- **F12. `-real`'s `(init . 0)` against the oracle holds only in a fresh process.** True of the
  probe (one load, no direct call before it) in both worlds; it would fail on a library the process
  already initialised, so the probe never uses `--init-before` in LR1 to LR4.
- **F13. `refusal-probe.sps` prints no `library` line,** unlike v0.1.1: no condition carries a
  report (ADR-0006). A reader of the logs used to see the version a refused library claimed; now
  only the decoy's call log shows which entries ran.
- **F14. v0.1.1's `-combined` order rows used threadsafe;** here three rows replace them (LM7 to LM9).
  A fourth, `lacks-sodium_library_version_minor` under `version-null`, would prove the same order as
  LM2 and LM3 and is left out.
- **F15. A decoy compile prints "guile: warning: failed to install locale"** on stderr in the
  container (from `$CC`'s wrapper). `compile-decoy` keeps only the exit status on success, so no row
  sees it. A probe child's stderr must still be `""`: the child is Chez, which prints none (measured).
- **F16. Copied record numbers re-pointed** per §0's table. The traps: v0.1.1's ADR-0008 and 0005
  are different subjects here.

## 6. Order of work for the builder (suggestion)

1. `decoy-libsodium.c`; compile all builds; run §4's `run.sh` equivalent as the first red/green.
2. `library-loading.sls`, `refusal-probe.sps`, the fixture.
3. `-decoys`, `-missing`, `-combined`: watch each red against a stub native that skips its check.
4. `-real`, `-discovery`, `-preflight`.
5. The tie row in `test-conventions.sps`; watched: delete and swap an entry.
6. `check-dev.sh`, Makefile; watched cases (§3.6).
7. Time each suite under the gate; split if over budget; mutation log.

## 7. Counts

**23 rows marked dropped:** decoy 6 (rows 3, 9, 11, 13, 15, 16), probe 4 (5, 8, 9, 10), `library-loading.sls` 7 (9, 10, 13, 14, 17, 18, 19), suites 5 (3, 5, 10, 15, 17), fixture 1 (3). Several "changed" rows also drop a part inline (1.3 rows 2 and 15; 1.4 rows 18, 20 and 21), and each says what.
