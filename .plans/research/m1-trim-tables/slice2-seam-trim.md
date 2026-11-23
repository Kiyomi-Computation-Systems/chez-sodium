# Slice 2, the seam: trim tables and design note

Phase one, no code. Sources: chez-sqlite3 v0.1.1 (`960d9f0`) `tests/check-seam.sps`,
`tests/test-check-seam.sps`, `tests/fixtures/seam/` (all 127 files), the `seam` case of
`tests/check-test-fails.sh`, the Makefile's `check-seam`/`build`/`test`; chez-sodium's M0
Makefile and `tests/check-test-fails.sh`; the plan §2.2, §2.3, §4.2 items 7, §4.4, §6 slice 2;
ADR-0012; ADR-0001 decision 9; constraints; traps; review S0-F3, F13, F15, F20.

Reading of "kept": copied with only the rename `chez-sqlite3` -> `chez-sodium` (library names,
fixture directory names, messages, comments), nothing else.

Every drop is numbered D1 to D7 in the tables, and listed in section 1.6.

---

## 1. Trim tables

### 1.1 `tests/check-seam.sps` (v0.1.1 `tests/check-seam.sps`), piece by piece

| Piece | Verdict | What changes / what the drop protected |
|---|---|---|
| Header comment, rules (c) to (i), (k) | Changed | Name `(chez-sodium ...)`; "ADR-0009" -> "ADR-0012". Rule (f)'s text drops `foreign-sizeof` and `get-thread-id` and the `connection` sentences (D3, D4). `lock-object` "(ADR-0011 rejected it)" -> "(ADR-0001, decision 8)". The "v1 reads no C struct / v1 has no callbacks" phrases lose "v1". `fork-thread (a connection belongs to its caller's thread)` -> "(no verb starts a thread)". "ADR-0002's one load" stays: chez-sodium ADR-0002 holds the one load too. Comment rules (AGENTS): no milestone or slice words. |
| Header: rule (l) paragraph | **Dropped (D1)** | see 1.6 |
| Header: "The letters are chez-curl's ... (k) and (l) are new" | Changed | "chez-sqlite3's letters, which took chez-curl's: there is no (a), (b), (j) or (l); (k) and (m) are new here" (m is new to this repo; k came from chez-sqlite3). |
| Header: new rule (m) paragraph | New | text in section 2.1 |
| `(import (rnrs) (only (chezscheme) directory-list file-directory? file-symbolic-link? display-condition library-extensions parameterize print-graph))` | Kept | every name is still used (`written` uses `print-graph`/`parameterize`; `walk` the others). `allowed-chez-names` is about `src/`, not this program. |
| `family-prefix?`, `public-name?`, `private-name?` | Changed | `'chez-sqlite3` -> `'chez-sodium`, `'(chez-sqlite3)` -> `'(chez-sodium)`. Nothing else. |
| `chez-names` | Kept | |
| `allowed-chez-names` | Changed | The list is section 2.2's. Comment: drop `foreign-sizeof`, `get-thread-id` sentences; "counters' counts and memory's live table" stays (memory has a live table: plan keeps v0.1.1's memory; if the load builder drops the table, say so, the sentence only needs "memory's"); "ADR-0009" -> "ADR-0012". Shape must stay `(define allowed-chez-names '(...))`: the suite reads it as data (`declared`). |
| `library-only-chez-names` | Changed | Entries per ADR-0012 decision 4: `foreign-alloc`, `foreign-free` -> `(chez-sodium private memory)`; `load-shared-object`, `foreign-procedure`, `foreign-entry`, `foreign-entry?`, `foreign-ref`, `foreign-set!`, `getenv`, `machine-type`, `format`, `format-condition?`, `display-condition` -> `(chez-sodium private native)`. Dropped entries: `foreign-sizeof` (D4), `get-thread-id` (D3). Comment rewritten: drop the `foreign-sizeof` and `get-thread-id` sentences; "ADR-0011" (string copy) -> "ADR-0001, decision 4"; "ADR-0002's one load" kept; "(ADR-0009)" -> "(ADR-0012)"; the sentence on counted blocks cites ADR-0011 (counts) and ADR-0008 (wipe), not "ADR-0005" (which is the subset rule here, see flag F7). Same quoted-list shape. |
| `utf8-string-libraries` | **Dropped (D1)** | see 1.6 |
| `rnrs-libraries`, `eval-libraries`, `unread-extensions`, `wrappers`, `max-depth` | Kept | |
| `written`, `abbreviated`, `describe`, `suffix?`, `prefix?`, `joined`, `unread-ending`, `read-data`, `lock-file?`, `walk`, `reference-name`, `spec-name`, `headed?`, `library-form?`, `chez-only-names`, `cannot-read`, `name-complaints`, `chez-complaints`, `undefined-complaints`, `chez-imported`, `export-pairs`, `syntax-names`, `only-imported`, `library-path`, `placement-complaints`, `check-file`, `say`, `data-complaints`, `defined-libraries` | Kept | strings that name the family change: `name-complaints` and `chez-complaints` name `tests/check-seam.sps` (unchanged); `undefined-complaints` says "(chez-sodium ...)"? It does not name the family; unchanged. |
| `import-complaints` | Changed | (1) message of the `else` branch and the unlisted tail: "(chez-sqlite3 ...) libraries" -> "(chez-sodium ...) libraries". (2) In the `family-prefix?` branch, rule (m) part 1 (section 2.1) before the rule-(h) call. |
| `export-complaints` | Changed | New third cond clause, after (g) and (k): rule (m) part 2 (section 2.1). Gains the memory-bound names beside `chez` and `guarded`. |
| `mentions?` | **Dropped (D2)** | see 1.6 |
| `utf8-string-complaints` and its call in `library-complaints` | **Dropped (D1)** | see 1.6 |
| `library-complaints` | Changed | rule (d)'s message: "(chez-sodium) or (chez-sodium private name ...)"; no rule (l) call; takes the memory exports (section 2.1) down to `export-complaints`. |
| `main` | Changed | computes `memory-exports` once from the files (section 2.1) and passes it down with `defined`; everything else (no-files, links, unread, pass line, FAILED line, exit 0/1, usage) kept. The pass line text is kept: `check-seam: the seam holds (N libraries in M files checked)`. |
| New: `memory-library`, `memory-importers`, `import-bound`, `memory-bound`, `memory-exports-of` | New | section 2.1 |

### 1.2 `tests/test-check-seam.sps` (v0.1.1), by piece

| Piece | Verdict | Change / protection |
|---|---|---|
| Header comment | Changed | "(ADR-0009)" -> "(ADR-0012)"; add the line "rule (m) has no source: its rows were written and watched failing here". The variant paragraph stays: the variant is still the program with `allowed-chez-names` widened by the `library-only` names; here `foreign-entry` is the one name it allows that the real table does not. |
| Imports | Changed | `(chez-sqlite3-testing)` -> `(chez-sodium-testing)`; its exports hold `capture-command`, `call-with-temp-directory`, `make-process-temp-directory`, `describe`, `suite-exit-status` (checked in `tests/chez-sodium-testing.sls:23-25`). |
| runner, failure-printing hook, `chez`, `program`, `fixtures`, `written`, `joined` | Kept | |
| `table-allowed` | Changed | exactly section 2.2's 19 names. Comment: "counters', require-threaded's, memory's and native's". |
| `table-only` | Changed | the 13 entries of section 1.1's table (11 native, 2 memory). Comment "foreign-entry's library, native, does not import it" kept. |
| `table-general` | Kept | still the names of `table-allowed` that `table-only` lacks: now 7 (`critical-section dynamic-wind make-mutex scheme-version scheme-version-number threaded? with-mutex`). |
| `read-forms`, `declared`, `declared-names`, `declared-library-only`, `variant-text`, variant directory, `ensure-directory!`, `dir-of`, `put-file!`, `run-program`, `run`, `at`, `holds`, `refused`, `refused-list`, `chez-only`, `not-listed`, `library-only`, `re-exports`, `macro-export`, `undefined-tail`, `not-read-tail`, `unread`, `holds-several`, `off-path`, `no-such-file`, `P`/`p` | Kept | |
| `unlisted-tail`, `outside` | Changed | "(chez-sqlite3 ...)" -> "(chez-sodium ...)", "(chez-sqlite3) or (chez-sqlite3 private name ...)" -> "(chez-sodium) or (chez-sodium private name ...)". |
| `utf8-string-tail`, `utf8-string-complaint` | **Dropped (D5)** | rule (l) is gone |
| `p` helper path | Changed | `chez-sodium/private/` |
| `cases` list | Changed | see 1.4: every case kept, renamed, except `utf8-string` (D5); the `unreadable` case's position 64 -> 63 (flag F5); new cases of section 3. |
| "CHEZ names the Chez" row, variant-written row, fixture-directory-is-a-case row | Kept | |
| `sls-files`, `chez-imports`, `imported-names`, `symbols<?`, `sorted`, the scan rows | Kept | |
| Row "allowed-chez-names is exactly the names the libraries under src/ import" | Kept | red until native/memory exist, see 2.3 |
| Rows on `library-only-chez-names` (entries shape, allowed-or-unimported, no unlisted importer, written out whole) | Changed | the written-out row's label names the 13 entries; the table is `table-only`. |
| `rnrs-libraries` row | Kept | |
| tree helpers `library-text`, `library-file`, `call-with-tree`, `refusals-at`, `tree-verdict`, `library-in` | Kept | |
| complement rows | Changed | the whole-complement-names row drops the trailing `utf8-string-tail` (D5): `(chezscheme)` exports `utf8->string`, now an ordinary not-listed name; the expected list is `(map not-listed complement-names)` alone. The library-complement and rnrs rows kept. |
| positions rows (`p0..`, `c0..2`, `e0..4`) | Kept | `table-general` now has 7 names |
| `only-libraries` | Changed | `(chez-sqlite3 private connection)` and `... connection extra` -> `(chez-sodium private verify)` and `(chez-sodium private verify extra)`: any other private library does the job of "a library no entry lists" (D3). Rest renamed. |
| `reexporters` | Changed | native's list is the 11 native-only names (drops `foreign-sizeof`); the `connection` entry dropped (D3). |
| empty-dir, missing-dir, usage rows | Kept | |
| `(exit (suite-exit-status runner))` | Kept | `make check-suites` reads it |

### 1.3 `tests/fixtures/seam/`: groups (127 files in v0.1.1; every group renamed `chez-sqlite3` -> `chez-sodium`, `chez-sqlite3-testing` -> `chez-sodium-testing`)

| Group | Verdict | Change |
|---|---|---|
| `legal` (4 libs, 4 files + `notes.txt`) | Kept | still passes on the real table: its names are `threaded?`, `with-mutex`, `critical-section`, `make-mutex`, `scheme-version`, `scheme-version-number`, all general. |
| `second-library`, `off-path`, `import-undefined`, `outside-family` (11 files), `outside-imports` | Kept | one rename beyond the family name: `outside-family/sqlite3.sls` (library `(sqlite3)`) becomes `sodium.sls` (library `(sodium)`); `(curl)` and `(util)` stay; the suite's `outside` row follows. Flag F10. |
| `chez-whole`, `scheme-alias`, `chez-wrapped` (w1..w10), `name-import-only`, `name-top-level-value`, `name-primitive`, `names-several`, `names-denylisted`, `names-not-symbols`, `rnrs-eval`, `export-wrapped-chez` | Kept | |
| `names-refused` (memory, native, other) | Kept | |
| `ftype-with-unlisted` | Kept | variant. |
| `memory-native-listed` | Changed | memory imports `foreign-alloc foreign-free critical-section make-mutex with-mutex`; native imports `load-shared-object foreign-procedure foreign-entry foreign-entry? foreign-ref foreign-set! getenv machine-type make-mutex with-mutex` today. New native line: `critical-section display-condition dynamic-wind foreign-entry? foreign-procedure foreign-ref foreign-set! format format-condition? getenv load-shared-object machine-type` plus `foreign-entry` (so the variant is still the only thing that lets this tree pass) and `make-mutex with-mutex`; native must not import `memory` (keeps this fixture free of rule (m)). Still `(holds 3 3)`, variant. |
| `export-chez` (7 files) | Kept | variant. `r.sls` exports `with-mutex` and `(rename (make-mutex mk))`, h exports `critical-section`: fine on the new table. |
| `export-unreadable` (3 files) | Kept | |
| `macro-export`, `macro-internal` (3 files) | Kept | variant. |
| `unlisted-libraries` u1..u9 | Changed | u6 `(chez-sqlite3-extras)` -> `(chez-sodium-extras)`; u5 `(chez-sodium-testing)`; u8 `(sqlite3)` -> `(sodium)`; the suite's expected strings follow. Flag F10. |
| `unread-ss`, `unread-so`, `unread-extensions` (7 files) | Kept | |
| `dir-symlink` (`linked` -> `../legal`) | Kept | symlink (mode 120000). Depends on the sibling `legal` directory. |
| `lock-symlink`, `lock-symlink-live`, `lock-regular`, `lock-directory`, `dangling-link`, `dangling-dot-link`, `dangling-hash-link` | Kept | 6 of the 7 hold git symlinks (mode 120000): `.#legal.sls` -> `user@host.12345:67890`, `.#real.sls` -> `real.sls`, the three dangling ones -> `no-such-file.sls`, `linked` -> `../legal`. The builder creates each with `ln -s` and checks `git ls-files -s` shows 120000. `lock-regular`/`lock-directory` are plain files holding `\x2e;\x23;` spelled names; those spellings do not contain the family name. |
| `no-datum`, `not-a-library`, `eof-literal`, `cannot-read-import`, `unreadable` | Kept | `unreadable/.../broken.sls` is 64 bytes in v0.1.1, 63 here (one fewer character in the name); expected `file-position 63` (flag F5). |
| `utf8-string` (6 files) | **Dropped (D5)** | |
| New: `memory-import`, `memory-native-ok`, `memory-own-name`, `memory-undefined`, `memory-reexport` | New | section 3. The suite's every-fixture-is-a-case row holds the group's case names. |

### 1.4 Case-by-case map (v0.1.1 cases -> here)

All kept, same expected text with the rename, except: `utf8-string` dropped; `unreadable` position; `outside-family` (sqlite3 name); `unlisted-libraries` (u6, u8 names); `memory-native-listed` (names); complement row (no trailing line). Every other case: kept.

### 1.5 Makefile (v0.1.1 vs M0) and `tests/check-test-fails.sh`

| Piece | Verdict | Change / protection |
|---|---|---|
| `check-seam` target and its comment | Kept, changed | v0.1.1's recipe: `@scripts/require-tools "$(GOAL)" $(CHEZ)` then `@$(CHEZ) --program tests/check-seam.sps src`. Comment: "(ADR-0009)" -> "(ADR-0012)", family names, add "and which library may import `(chez-sodium private memory)`". Help text: `Fail unless every library under src/ keeps to the seam: the family, the import lists, the names only some libraries may import, and who imports memory`. |
| `build` target and its comment | Kept, changed | recipe v0.1.1's, owned here: `@scripts/require-tools "$(GOAL)" $(CHEZ)` then `@$(CHEZ) --libdirs src --program tests/preflight.sps`. Comment: "Loads libsodium as chez-sodium would, through tests/preflight.sps, and names it: its path and source, its version and `major.minor`. A refused libsodium fails it, exit 1, with the reason, the path, the detail, the candidates checked and a remedy. Its last line, on either stream, is its counts, all zero (ADR-0011). chez-sodium compiles nothing (ADR-0001), so this is the question an install asks. It writes nothing. build is in .PHONY: the build/ directory exists, and without it make would answer that build is up to date and run nothing. make test does not depend on it." Do **not** name `test-library-loading-*.sps` or `-preflight.sps` (slice 3 writes them, flag F6). Help: `Load libsodium as chez-sodium would and name it; fail with the reason when it is refused`. `build` has no prerequisite. |
| `test`'s prerequisites | Changed | `test: deps check-help check-suites check-seam check-floors check-ci ##` (v0.1.1's place: after check-suites). Comment above: "check-help, check-suites, check-seam, check-floors and check-ci each stop it." |
| `.PHONY` line | Changed | add `build` after `deps` and `check-seam` after `check-suites`; stays one physical line (check-help refuses a trailing backslash). |
| `check-test-fails` help | Changed | `Plant bad suites, none at all, a leaked block, a stale README, a bad workflow and a bad import, in a copy; make test must fail on each, by name`. (M0's help omitted the `ci` plant that already exists; this adds both. Flag F9.) Comment above it also names the seam plant. |
| `dev`, `check-dev` | Not here | plan §2.3 lists them in the Makefile row, §6 gives them to slice 3's refusals agent. |
| `check-variadic` | **Dropped (D6)** | protected the variadic convention of `sqlite3_db_config`. |
| `check-memory-shards` + `MEMORY_SHARD`, `MEMORY_SUITES_1/2` | **Dropped (D7)** | protected the two memory jobs' split. ADR-0011: one memory job, no shards; M0's Makefile has none. |
| `site*` targets | **Dropped (D7)** | no site in M1 (plan §3: M4). |
| `check-test-fails.sh`: `seam` case | Kept, changed | section 2.5. |
| `check-test-fails.sh`: `site-*`, `shards-*` cases | **Dropped (D7)** | their targets are not here. |

### 1.6 Every drop: what it protected, where it lives now, checked against the kept rules

| # | Drop | What it protected | Where that protection lives now, and the check against every kept rule |
|---|---|---|---|
| D1 | Rule (l): the `utf8-string-libraries` table, `utf8-string-complaints`, its call, header text | Chez's `utf8->string` drops a leading U+FEFF; one strict decoder (`utf8.sls`) was the only way text reached Scheme. | Nothing here decodes a caller's or a secret's text, and `utf8.sls` is never built (plan §3). The strings libsodium hands back (version, prefix, hash) are ASCII. Checked against kept rules: (e) lets every library import `(rnrs bytevectors)`'s `utf8->string`, so no kept rule holds the decoder. **One residual, flag F2:** native's `c-string->string` reads the version string; a decoy or odd library answering a version with a leading U+FEFF would be read with the BOM dropped and accepted. Not a seam matter: a `test-native` or `test-verify` row (the load builder's, the caller's call). |
| D2 | `mentions?` | A walk of a datum for an identifier, cycle-safe, used only by rule (l) (read: the only call is in `utf8-string-complaints`). | Nothing else used it. The kept scanners read elements to `max-depth` or fixed shapes, never tails or arbitrary depth, so need no cycle-safe walk. `make-eq-hashtable` use disappears with it; `(rnrs)` still imports. |
| D3 | `get-thread-id`: its `allowed-chez-names` and `library-only-chez-names` entries, `connection` in `only-libraries` and `reexporters`, comment | One owner-thread check per connection (chez-sqlite3 ADR-0010). | No connection, no handle, no owner thread (AGENTS: no verb holds state). With the entry gone, rule (c)'s not-listed branch refuses `get-thread-id` in every library, which is stronger than "connection alone". The whole-complement row now holds it as an ordinary refused name. Rule (f)/(g)/(k) never named it except through the dropped entry. |
| D4 | `foreign-sizeof`: both tables, `reexporters`' native list | Sizing the slot of an out-pointer (native's alone). | M1 drops `call-with-out-pointer` and `call-with-int-cell` (plan §2.1 `native.sls` row); the fixed native import list holds no `foreign-sizeof`. Not allowed, so refused everywhere by (c); the complement row holds that. A later use is a reviewed seam change. Kept rules (f), (g), (k) consult tables only: nothing else mentions it. |
| D5 | `utf8-string` fixture group (6 files), its case, `utf8-string-tail`/`-complaint`, the complement row's trailing line | D1's rows. | Gone with D1. Residual of the complement row: it now fails if (l) comes back (the extra trailing complaint), so D1's removal is itself held. |
| D6 | `check-variadic` | A variadic C function bound without its convention. | None of M1's five bindings is variadic, and the subset has none; `test-conventions` still reads every form. Plan §3 "Never". |
| D7 | `check-memory-shards`, shard lists, `site*`, the `site-*` and `shards-*` cases | Shard completeness; the docs site. | ADR-0011: one memory job. The site is M4. M0's Makefile and script already lack all of them, so nothing is removed from a file that has them; recorded because the plan's table lists them. |

---

## 2. Design note

### 2.1 Rule (m), widened (ADR-0012, decisions 6 and 7)

Statement: only `(chez-sodium private native)` imports `(chez-sodium private memory)`, and no
library exports a name it imports from `memory`. It has no source: v0.1.1 has nothing like it.
Decision 7's half (native's `foreign-block`/`free-foreign-block!` only inside `call-with-block`)
is `test-native`'s row, not the seam's.

**Constants** in `check-seam.sps` (data, so the suite can write them out whole, as it does for
`library-only-chez-names`):

```
(define memory-library   '(chez-sodium private memory))
(define memory-importers '((chez-sodium private native)))   ; the libraries that may import it
```

**Part 1: who imports it.** In `import-complaints`, in the branch for a family import
(`family-prefix? imported`): when `imported` equals `memory-library` and the importing library
`name` is not a member of `memory-importers`, the complaint list is
`(m1-complaint) ++ (undefined-complaints ...)` (m first, then (h), so a tree where memory is
absent shows both, in that order). `imported` comes from `spec-name`, so it sees through `only`,
`except`, `prefix`, `rename`, `for` and `(library ...)`, and drops a version reference. A name
that merely begins like memory (`(chez-sodium private memory-x)`, `(chez-sodium private memory extra)`)
is a different library: compare with `equal?`, never a prefix.

Text, whole (tests write it by hand):

```
PATH: NAME imports (chez-sodium private memory), but only (chez-sodium private native) may: every block is made and freed through native's call-with-block, which wipes it
```

(`NAME` is `(written name)`. The `only` list is `(joined ", " (map written memory-importers))`.)

**Part 2: no re-export.** Needs the names `memory` binds into a library. Mini import-set
evaluator, `(import-bound spec exports)`, answering the local names an import set `spec` of
memory binds, or `#f` when it cannot read it (fail closed):

- `(library REF)` (length 2) -> the same as `REF`; a plain reference (version dropped) -> `exports`,
  memory's own external names;
- `(for S level ...)` -> `S`; `(only S id ...)` -> the ids (all must be symbols, else `#f`);
  `(except S id ...)` -> `S` minus the ids; `(prefix S p)` -> `p` joined to each name (p a
  symbol, else `#f`); `(rename S (a b) ...)` -> each `a` replaced by `b` (pairs of two symbols,
  else `#f`);
- recursion bounded by `max-depth`, like `spec-name`.

`memory-bound` = for each import set of the library whose `spec-name` is `memory-library`, the
union of `import-bound`. An unreadable one (`#f`) contributes nothing there and is named once, in
`import-complaints`, with `cannot-read` (that function already names "has an import it cannot
read: SPEC"; call it for a memory import whose `import-bound` is `#f`).

`exports` = memory's external export names, read once in `main` from the file that defines
`memory-library` (`export-pairs`, taking each pair's cdr; an unreadable export spec contributes
nothing: rule (g) already names it). If no library defines memory, `exports` is `'()`: a plain
import binds nothing to check, and rule (h) is the complaint.

In `export-complaints`, after the (g) clause and the (k) clause, a third clause: when an export
pair's **internal** name (car) is in `memory-bound`, one complaint. Text, whole:

```
PATH: NAME exports WHAT, but it imports LOCAL from (chez-sodium private memory), and no library under src/ may export a name it imports from (chez-sodium private memory)
```

`WHAT` is spelled as (g)'s is (`foreign-block`, or `foreign-block as grab`); `LOCAL` is the local
name (the internal name, which for a prefix or rename is the local spelling). Order within a
library: exports in export order, as (g).

`library-complaints`, `data-complaints`, `check-file` and `export-complaints` take `memory-exports`
beside `defined`.

**Is memory itself touched?** `memory` exports its own `foreign-block`: those are not imported
from memory, so no complaint. A library that defines its own `foreign-block` (not imported) is
fine too (fixture `memory-own-name`).

**Not read, said in the header, as (k) says it for its gap:** a macro native binds with
`define-syntax` whose template uses `foreign-block` and which native exports. Rule (k) guards
only library-only chez names. Held instead by decision 7's `test-native` row, which reads native's
body as data and refuses any `foreign-block`/`free-foreign-block!` outside `call-with-block`'s
definition, a macro template included (a scanner of elements, not tails). Flag F3: say so in the
header; do not extend (k) unless the caller asks (cost: one more list in `only-imported`).

### 2.2 `library-only-chez-names` and `allowed-chez-names`

`library-only-chez-names`: exactly ADR-0012 decision 4: memory: `foreign-alloc`, `foreign-free`;
native: `load-shared-object`, `foreign-procedure`, `foreign-entry`, `foreign-entry?`, `foreign-ref`,
`foreign-set!`, `getenv`, `machine-type`, `format`, `format-condition?`, `display-condition`.

What `src/` imports from `(chezscheme)` today (read from the files):

| Library | Names |
|---|---|
| `require-threaded` | `threaded?`, `scheme-version`, `scheme-version-number` |
| `counters` | `critical-section`, `make-mutex`, `with-mutex` |
| `conditions`, `discovery`, `load-state`, `verify` | none |

Once native and memory exist, with the plan's fixed lists:

- native: `critical-section`, `display-condition`, `dynamic-wind`, `foreign-entry?`,
  `foreign-procedure`, `foreign-ref`, `foreign-set!`, `format`, `format-condition?`, `getenv`,
  `load-shared-object`, `machine-type` (12);
- memory: `critical-section`, `foreign-alloc`, `foreign-free`, `make-mutex`, `with-mutex` (5).

`allowed-chez-names` (19, the union, in v0.1.1's alphabetical order):

```
(critical-section display-condition dynamic-wind foreign-alloc foreign-entry? foreign-free
 foreign-procedure foreign-ref foreign-set! format format-condition? getenv load-shared-object
 machine-type make-mutex scheme-version scheme-version-number threaded? with-mutex)
```

Notes: `foreign-entry` (no `?`) is in `library-only` but not allowed: refused everywhere as
unlisted until a library imports it (v0.1.1 behaviour, ADR-0012 text; flag F4). `dynamic-wind`,
`critical-section`, `make-mutex`, `with-mutex` are general (not library-only), as v0.1.1.
Versus v0.1.1 the list loses `foreign-sizeof` and `get-thread-id` (D3, D4). Table-general (7):
`critical-section dynamic-wind make-mutex scheme-version scheme-version-number threaded? with-mutex`.

### 2.3 Stub headers, and which rows are red until the join

Worktree-only, never added or reported as work product; the caller discards them at the join. Both
under `src/chez-sodium/private/`, with the fixed import lists and an inert body:

`memory.sls`:
```
#!r6rs
(library (chez-sodium private memory)
  (export foreign-block free-foreign-block!)
  (import (chez-sodium private require-threaded)
          (rnrs)
          (only (chezscheme) critical-section foreign-alloc foreign-free make-mutex with-mutex)
          (chez-sodium private counters)
          (chez-sodium private conditions))
  (define (foreign-block size) size)
  (define (free-foreign-block! address wipe) address))
```
`native.sls`:
```
#!r6rs
(library (chez-sodium private native)
  (export call-with-block)
  (import (chez-sodium private require-threaded)
          (rnrs)
          (only (chezscheme) critical-section display-condition dynamic-wind foreign-entry?
                foreign-procedure foreign-ref foreign-set! format format-condition? getenv
                load-shared-object machine-type)
          (chez-sodium private memory)
          (chez-sodium private conditions))
  (define (call-with-block size proc) (proc size)))
```
Native's import of memory is plain and its exports hold none of memory's names, so with the stubs
rule (m) passes on the real `src/` and rows exercise the positive case.

Red until the join:
- **Without stubs:** exactly one row, `allowed-chez-names is exactly the names the libraries under
  src/ import from (chezscheme)`, and with it `make check-seam` stays green (it checks only that
  nothing outside the tables is imported; an unused allowed name fails nothing there).
- **With the stubs:** none. At the join the same row, and `make check-seam`, go red if the load
  builder's native or memory imports a name beyond the fixed lists (or fewer): that is the
  reconciliation the plan describes ("a builder that needs another name says so").
- Not mine, red until the load agent's `tests/preflight.sps` lands: `make build`.
- The `seam` plant (`check-test-fails`) is green from the start: its copy rebuilds `src/` from
  the two M0 libraries plus the plant, so the stubs never enter it.

Also needed for the worktree to run anything: a populated `vendor/chez-srfi` (the container has no
git; a worktree has the submodule empty and `make deps` refuses). Flag F11.

### 2.4 The Makefile, whole change list

1. `.PHONY` (one line): add `build` after `deps`, `check-seam` after `check-suites`.
2. `build:` target as in 1.5, placed after `deps` and before `check-pins`, with its comment.
3. `check-seam:` target as in 1.5, placed after `check-suites`, before `check-floors`.
4. `test:` prerequisites `deps check-help check-suites check-seam check-floors check-ci`; its
   comment lists `check-seam`.
5. `check-test-fails` help and its comment (section 1.5).
6. `check-help`'s expectations (it reads the Makefile, nothing else): every name in the `.PHONY`
   line has a `name: ... ## text` line and the reverse; the `.PHONY` line is one physical line, no
   trailing backslash. After the change: `build` and `check-seam` each have a `##` description
   (above), and both are in `.PHONY`. `make check-help` must pass; watched failing by deleting
   each `##` and each `.PHONY` entry.
7. Nothing else: `dev`/`check-dev` are slice 3's, CI's `main` make line already runs `make test`
   (and v0.1.1's line did not list `check-seam` either).

### 2.5 The `seam` plant for `check-test-fails`

Position: after the `leaks` case and its `rm -f "${copy:?}/${plant:?}"`, before `floors` (as
v0.1.1), so the copy holds one suite (`checked 1`).

Header table row (like the others), after `leaks`:
```
#   seam         a private library that      check-seam names the import,
#                imports foreign-alloc, a    and no suite runs
#                name only (chez-sodium
#                private memory) may import
```
Comment paragraph "A case requires ... compares the lines starting ..." gains "the seam case those
starting "check-seam: "".

Case body:
```
cat >"$plant_dir/seam" <<'EOF'
#!r6rs
;;; Planted by tests/check-test-fails.sh: a private library that allocates
;;; foreign memory itself, which only (chez-sodium private memory) may.
(library (chez-sodium private planted)
  (export planted)
  (import (chez-sodium private require-threaded)
          (rnrs)
          (only (chezscheme) foreign-alloc))
  (define planted 1))
EOF
cp "$plant_dir/seam" "$copy/src/chez-sodium/private/planted.sls"
run_case "seam: check-seam names a private library that imports foreign-alloc, and no suite runs" \
  "$(checked 1
     echo 'check-seam: src/chez-sodium/private/planted.sls: (chez-sodium private planted) imports foreign-alloc from (chezscheme), but library-only-chez-names in tests/check-seam.sps allows it only in (chez-sodium private memory)'
     echo 'check-seam: FAILED (problems: 1)')" \
  '^(check-suites|check-seam|test): '
rm -f "${copy:?}/src/chez-sodium/private/planted.sls"
```
A comment above it as v0.1.1's (without the ADR-0011 style slice words): the copy's `src/` holds
no memory library and the rule needs none; without `check-seam` among `make test`'s prerequisites,
or with it reading a directory but `src/`, no check sees the plant and `make test` passes, which
fails the case (each new prerequisite comes with its plant).

Why `foreign-alloc` still names a complaint in the copy: it is in `allowed-chez-names` (memory
imports it), so the not-listed branch is not taken and (f) fires. If `allowed-chez-names` ever
lost `foreign-alloc`, the plant's line would read "does not list it" and the case would fail:
intended.

Every other case now also runs `check-seam` (a prerequisite) on the copy's two-library `src/`:
it passes (`the seam holds (2 libraries in 2 files checked)`), a line the default filter
`^(check-suites|test): ` does not match. A failure there would drop the `test:` lines and fail the
case loudly.

---

## 3. The rows `test-check-seam` holds, and what each is watched against

Method (v0.1.1's, plus the review's two lessons): each row is watched to fail by a **rule-off
mutant**: a scratch copy of the worktree, one edit to `tests/check-seam.sps` only, the suite run
unedited, the red rows named. Never a red run against a check that refuses the whole input (that
proves no row). A mutant must turn off one rule only; the rows of every other rule stay green,
which is also checked. Log: mutant, edit, rows red, rows that should be green and are.

Suite shape: kept as v0.1.1's, plus new cases and rows listed under R. "variant" = run against
the program with `allowed-chez-names` widened.

### 3.1 Kept rows, by rule, and the mutant that kills each (names are the fixture directories)

| Rule | Rows (cases) | Mutant (edit to `check-seam.sps`) |
|---|---|---|
| (c) shape | `chez-whole`, `scheme-alias`, `chez-wrapped`, `export-wrapped-chez`, row "(chezscheme) imported whole in the first, middle and last clause", complement-libraries row's `(chezscheme)`/`(scheme)` entries | **C1**: `chez-complaints` answers `'()` when `(not names)` |
| (c) alias | `scheme-alias`, `chez-wrapped` w9, complement `(scheme)` | **C4**: `chez-names` = `'((chezscheme))` |
| (c) not-listed | `name-import-only`, `name-top-level-value`, `name-primitive`, `names-several`, `names-denylisted`, `names-refused` real and variant, `ftype-with-unlisted`, complement-names row, "refused at every position" | **C2**: `name-complaints` skips the not-allowed branch |
| (c) non-symbol | `names-not-symbols` | **C3**: drop the `(not (for-all symbol? names))` clause |
| (c) `(rnrs eval)` | `rnrs-eval`, complement-libraries `(rnrs eval)` | **C5**: `eval-libraries` = `'()` |
| (d) boundary | `outside-family`, `outside-imports` (util2, util) | **D-1**: `library-complaints` drops the `(or (public-name? ...) (private-name? ...))` complaint; **D-2**: `private-name?` drops `(pair? (cddr name))`; **D-3**: `private-name?` drops the `(eq? (cadr name) 'private)` test (kills `privateer`, `foo private`-type rows) |
| (e) allowlist | `unlisted-libraries`, `outside-imports` y3, complement-libraries row | **E1**: the `else` branch of `import-complaints` answers `'()` |
| (e) rnrs list | `rnrs-libraries` row, "all (rnrs ...) accepted" row, `legal` | **E2**: drop `(rnrs sorting)` from `rnrs-libraries` |
| (f) | `ftype-with-unlisted`, `names-several` (format), "each library-only name refused in every library but the one listed" (variant), the `seam` plant | **F1**: `name-complaints` skips the `(and only (not (member ...)))` clause |
| (f) table | the whole-table row, the entry rows | **F2**: remove the `foreign-alloc` entry; **F3**: give `foreign-free` the library `native`; **F4**: add `foreign-sizeof` to the table |
| lists exact | "allowed-chez-names is exactly what src/ imports", "... written out whole", complement-names row, `table-general` row | **A1**: add `foreign-sizeof` to `allowed-chez-names`; **A2**: remove `with-mutex`; **A3**: add `get-thread-id`. Rows A1 and A3 fail on the exact/whole/complement rows; A2 on exact/whole/general and on `make check-seam` against `src/` |
| (g) | `export-chez`, "exports at every position", "each name re-exported, plain and renamed (variant)" | **G1**: drop the `(memq (car pair) chez)` clause; **G2**: compare `(cdr pair)` (the external) instead of `(car pair)` |
| (g) unreadable | `export-unreadable` | **G3**: `export-pairs` never answers `#f`; **G4**: its `rename` accepts any arity |
| (h) | `import-undefined`, `outside-imports` y1 | **H1**: `undefined-complaints` answers `'()` |
| (i) | `second-library`, `off-path`, `lock-symlink-live` | **I1**: `placement-complaints` answers `'()`; **I2**: drop only the `> 1` clause; **I3**: drop only the path comparison |
| (k) | `macro-export`, `macro-internal` | **K1**: drop the macro clause; **K2**: `syntax-names` drops its `begin` recursion (third macro of `macro-export`); **K3**: the clause fires with no `(pair? guarded)` test (`macro-internal`'s `plain.sls` goes red) |
| unread files | `unread-ss`, `unread-so`, `unread-extensions` | **U1**: `walk` drops the `unread-ending` clause; **U2**: `unread-extensions` loses `.chezscheme.so` |
| links | `dir-symlink` | **S1**: `walk` drops the link clause |
| lock files | `lock-symlink`, `lock-regular`, `lock-directory`, `lock-symlink-live`, `dangling-*` | **L1**: `lock-file?` never true; **L2**: true for every `.#` name; **L3**: drops `(not (file-exists? path))`; **L4**: prefix test becomes "starts with ." (kills `dangling-dot-link`); **L5**: becomes "contains .#" (kills `dangling-hash-link`) |
| fails closed | `no-datum`, `not-a-library`, `unreadable`, `eof-literal`, `cannot-read-import`, empty and missing directory, usage rows | **Z1** `data-complaints` loses its `(null? data)` branch; **Z2** `library-form?` accepts any list; **Z3** `read-data` loses the `port-eof?` check; **Z4** `read-data` loses its `guard`; **Z5** `spec-name` loses the depth guard (`m4`); **Z6** `main` loses the no-files complaint; **Z7** the argument-count check |
| (l) absent | complement-names row (whole output, no trailing complaint) | **R-L**: re-add a rule (l) call: the complement row goes red |

### 3.2 New rows: rule (m)

Fixtures (static, run on the real program):

| Case | Tree | Whole answer |
|---|---|---|
| `memory-import` | `memory.sls` (exports `foreign-block free-foreign-block!`, defined), `memory-x.sls`, `require-threaded.sls`, `native.sls` (plain import of memory, legal), `near.sls` (imports `(chez-sodium private memory-x)`, legal), `chez-sodium.sls` (public, imports memory), and one private library per import form of memory: `a` plain, `b` `(only M foreign-block)`, `c` `(prefix M m:)`, `d` `(rename M (foreign-block fb))`, `e` `(except M foreign-block)`, `f` `(for M expand)`, `g` `(library M)`, `h` `(M (1))` (versioned) | `refused 9`: the public library first (`chez-sodium.sls` sorts before `chez-sodium/private/`), then `a` to `h`, each line `PATH: NAME imports (chez-sodium private memory), but only ... may: ...`. native and near pass. |
| `memory-native-ok` | `memory.sls`, `native.sls` (plain import; exports its own `call-with-block`), `require-threaded.sls` | `(holds 3 3)` |
| `memory-own-name` | `native.sls` imports `(only M free-foreign-block!)`, exports its own defined `foreign-block`; `memory.sls`; `require-threaded.sls` | `(holds 3 3)`: a name that is not the imported one is not named |
| `memory-undefined` | a library `a` (not native) imports memory, which no file defines | `refused 2`: rule (m) line, then rule (h)'s `undefined-tail` line, in that order |
| `memory-reexport` | `native.sls` plain-imports memory, exports `call-with-block`, `foreign-block`, `(rename (free-foreign-block! release))`; `memory.sls`; `require-threaded.sls` | `refused 2`, in export order: `exports foreign-block, but it imports foreign-block from ...` and `exports free-foreign-block! as release, but it imports free-foreign-block! from ...` |

Generated trees (rows written in the suite with `tree-verdict`, one `test-equal` per variant, each
tree native + memory + `require-threaded`; native is the only importer, so rule (m) part 1 never
fires and each row isolates part 2):

| Variant | native imports | native exports | Expect |
|---|---|---|---|
| only | `(only M foreign-block)` | `foreign-block` | 1 complaint |
| except | `(except M free-foreign-block!)` | `foreign-block` | 1 complaint; and exporting `free-foreign-block!` instead: none |
| prefix | `(prefix M m:)` | `m:foreign-block` | 1 complaint |
| rename | `(rename M (foreign-block fb))` | `fb` | 1 complaint; exporting `foreign-block` instead: none |
| for | `(for M expand)` | `foreign-block` | 1 complaint |
| library form | `(library M)` | `foreign-block` | 1 complaint |
| nested | `(only (prefix M m:) m:free-foreign-block!)` | `m:free-foreign-block!` | 1 complaint |
| versioned | `(M (1))` | `foreign-block` | 1 complaint |
| memory renames its export | memory `(export (rename (make-block foreign-block)))`, native plain | `foreign-block` | 1 complaint; exporting `make-block` instead: none (the external name is the bound one) |
| every position | plain import | `foreign-block` at positions 0..3 of an export clause | 1 complaint each tree |
| unreadable | `(only M 42)` | none | `has an import it cannot read: (only (chez-sodium private memory) 42)` |
| memory not defined | plain | `foreign-block` | only rule (h)'s complaint: an unknown export binds nothing |

List row: `memory-importers`, written out whole, equals the declared one (`(((chez-sodium private native)))`
as the written value), like `library-only-chez-names`'s row; and `memory-library` equals
`(chez-sodium private memory)`.

### 3.3 Mutants for rule (m), watched

Each turns one part of (m) off and leaves every other rule's rows green; also verify the green.

| Mutant | Edit | Rows red |
|---|---|---|
| **M1-off** | part 1 clause answers `'()` | `memory-import`, `memory-undefined` |
| **M1-prefix** | compare "starts with" `memory` instead of `equal?` | `memory-import` (near.sls refused), `memory-native-ok` no |
| **M1-all** | `memory-importers` = `'()` | `memory-native-ok`, `memory-own-name`, `memory-import` (native named), generated rows |
| **M1-wide** | `memory-importers` also lists `(chez-sodium)` | `memory-import` (public line missing), importers-whole row |
| **M2-off** | part 2 clause answers `'()` | `memory-reexport`, every generated row |
| **M2-internal** | compare the external (cdr) name | `memory-reexport` (the rename line), "rename" |
| **M2-wrappers** (five mutants) | `import-bound` ignores `only` / `except` / `prefix` / `rename` / `(library ...)` and `for` in turn (treats it as a pass-through of its inner set) | the matching generated row each; `memory-own-name` for `only` (over-matches if `only` yields all exports) |
| **M2-plain** | plain import binds `'()` | `memory-reexport`, plain generated rows |
| **M2-external** | read memory's export clause by internal (car) names | "memory renames its export" |
| **M2-fail-open** | `import-bound` answers `'()` on a shape it cannot read | the `unreadable` row |
| **M2-first-only** | the export scan stops at the first match or first spec | "every position" |
| **M-order** | put (h) before (m) | `memory-undefined` |

### 3.4 The `seam` plant, watched

Mutants of the Makefile and the program, each making the case fail by name: `check-seam` removed
from `test`'s prerequisites; the recipe reading `tests` instead of `src`; `check-seam.sps` with
rule (f) off (**F1**); and `foreign-alloc` removed from `allowed-chez-names` (the line then reads
"does not list it"). Plus `check-help`: delete `build`'s or `check-seam`'s `##`, then each from
`.PHONY`.

### 3.5 What "stays green" is held to

For each mutant above, every row not named stays green, with the real program. In particular
the (g) rows must not go red under M1/M2 (a `memory.sls` fixture exports its own names only), and
no (m) fixture may trip rules (c) to (k) (all use `(rnrs)`, `require-threaded`, and no
`(chezscheme)` import).

---

## 4. Flags

- **F1. Rule letters in the plan.** Plan §2.2's seam row says "Rules (c) to (k)" and §4.2/§6/the
  table at plan line 348 say "(c) to (k), no (l), and the new (m)". v0.1.1 has no (j) (its header:
  "there is no (a), (b) or (j)"), and S0-F15 fixed ADR-0012 to "(c) to (i) and (k)" but not the
  plan. Build with (c) to (i), (k), (m). Plan lines 100 and 348 want the same edit.
- **F2. Dropping rule (l) leaves one real hole, not the seam's.** native keeps `c-string->string`
  (plan §2.1) and `utf8.sls` is never built. `check-version` reads `sodium_version_string`
  through it. If `c-string->string` uses `(rnrs bytevectors)`'s `utf8->string`, bytes
  `EF BB BF 31 2E 30 2E 31 38` read as `"1.0.18"` and are accepted as at the floor, since the BOM
  is dropped. test-verify's malformed list (`" 1.0.18"`, `"01.0.18"`, ...) has no BOM row, and the
  decoy's `version-malformed` may not either. Owed by the load builder or the caller: either
  decode ASCII-only (refuse any byte above 127 as `below-floor`, which the plan's one rule already
  says "refuses everything else") or add a row with a BOM-prefixed version. Not seam work.
- **F3. Rule (m) has a macro gap, covered elsewhere.** A macro native exports whose template uses
  `foreign-block` would hand blocks on; (k) does not watch memory's names. Covered only if
  decision 7's `test-native` row scans macro templates as well as definitions. Tell that builder
  or extend (k) (add memory-bound names to `guarded`; a 3-line change, new rows). I recommend
  leaving (k) alone and saying so in the header.
- **F4. `foreign-entry` is in `library-only-chez-names` and not in `allowed-chez-names`.** That is
  v0.1.1's state and ADR-0012's, so it is refused everywhere until a library imports it. The
  variant is what lets a tree use it. Not a disagreement: recorded because the plan's fixed native
  list and the table differ by it.
- **F5. `unreadable` fixture's expected text has a position.** `broken.sls` is 64 bytes in v0.1.1 and
  the error says "file-position 64"; with `chez-sodium` it is 63. Recompute it by running (the
  text also holds the path).
- **F6. Makefile `build`.** `tests/preflight.sps` is the load agent's, so `make build` is red until
  the join, and the plan already says so. Its comment must not cite suites slice 3 writes
  (`test-library-loading-real`, `-preflight`): they do not exist yet. Plan §2.3's Makefile row
  lists `dev` and `check-dev` too: they belong to slice 3 (§6), not here.
- **F7. Record numbers in copied comments, re-pointed.** chez-sqlite3 ADR-0009 (the seam) -> chez-sodium
  ADR-0012. ADR-0010 (owner thread) -> dropped with `get-thread-id`. ADR-0011 (string copy,
  `lock-object` rejected) -> chez-sodium ADR-0001 decisions 4 and 8; (chez-sodium's ADR-0011 is the
  harness). ADR-0005 (counted blocks, the memory check in v0.1.1) -> chez-sodium ADR-0011 for the
  counts and ADR-0008 for the wipe; chez-sodium ADR-0005 is the subset rule: a bare "ADR-0005" copied
  here would point at the wrong record. ADR-0002 (one load) and ADR-0001 (nothing compiled): same
  number, same subject, keep. ADR-0013 (messages): not in these files. In `check-test-fails.sh`
  M0 already cites its own ADR-0011. A sibling's record is cited with its repository name.
- **F8. Time under the gate.** `test-check-seam` becomes a suite `test-memory` runs under
  Valgrind. v0.1.1 put it in a shard because of its time (about 80 child Chez runs and two
  complement runs of thousands of names). Children are plain `capture-command`s, outside the
  gate, but the parent's work is not. Measure it first in the container
  (`make test-memory MEMORY_SUITES=tests/test-check-seam.sps`); the SLOW line is 450 s. If it
  nears it, split the complement rows into a suite of their own, not shards (ADR-0011).
- **F9. M0's `check-test-fails` help omitted its `ci` plant.** The help line also gets "a bad
  workflow" here, since I am rewriting the line anyway; the caller may keep to "and a bad import"
  alone.
- **F10. Family-name-bearing fixtures.** `outside-family/sqlite3.sls` -> `sodium.sls` with
  `(library (sodium) ...)`, `u8.sls` -> `(sodium)`, `u6.sls` -> `(chez-sodium-extras)`; the
  suite's `outside` row and `u*` table follow. `(curl)` and `(util)` stay.
- **F11. A seam worktree cannot run `make deps`.** The container has no git, a fresh worktree has
  `vendor/chez-srfi` empty, and `make deps` refuses; `make check-suites`, `make test` and the
  suite itself need SRFI-64. The caller populates it on the host
  (`git submodule update --init` in the worktree) before the builder starts. Same for the other
  two agents.
- **F12. Symlink fixtures.** Six are git symlinks. A builder that copies the tree with a tool that
  dereferences, or writes them as files, silently turns `dir-symlink`, the `lock-symlink*` and
  `dangling-*` cases into other cases (`diff -r` follows links: chez-sqlite3's traps). The
  check-test-fails copy uses `cp -a`, which keeps them. Check `git ls-files -s | grep ^120000`
  lists the six.
- **F13. ADR-0012 decision 4 text vs the plan's fixed list.** Consistent. One thing neither says:
  `dynamic-wind`, `critical-section`, `make-mutex`, `with-mutex` are general, not library-only,
  so native can import `dynamic-wind` and any library `critical-section`; v0.1.1 does the same.
  Kept.
- **F14. Not placed.** Where the plan says "the `seam` plant in `check-test-fails`" is the only
  seam-related plant; rule (m) is proven by `test-check-seam` alone (the plant shows the
  prerequisite runs on `src/`, nothing more). A second plant for (m) is possible but the plan does
  not ask for one.
