# ADR-0012: `(chez-sodium)` re-exports and defines nothing, and `check-seam` reads `src/`

- **Status:** Accepted (the owner, 2026-11-23), proposed in [the M1 plan](../2026-11-22-m1-plan.md),
  §4.2, items 1 and 7. Decisions 6 and 7 widened after slice 0's review (S0-F3). Decision 7
  amended 2026-11-23, after slice 2's review, and accepted by the owner that day
  ([amendment](#amendment-2026-11-23-memory-imported-once)).
- **Date:** 2026-11-23
- **Scope:** the public library, and what `make check-seam` holds under `src/`
- **Settles:** the M1 plan §4.2, items 1 and 7
- **Related:** chez-sqlite3 ADR-0009, amended (what `check-seam` reads), and chez-sqlite3
  ADR-0012's slice-4 note (the empty-bodied re-export), which this follows · chez-sqlite3 ADR-0013,
  amended (predicates and accessors only) · [ADR-0001] (the two FFI names) · [ADR-0006] (the
  condition tree) · [ADR-0008] (the wipe)

## Context

- **No record held the public library.** [ADR-0001], decision 9, holds the two FFI names alone:
  one library holds `foreign-procedure`, one holds `foreign-alloc`.
- **chez-sqlite3's `(chez-sqlite3)` re-exports and defines nothing,** and exports predicates and
  accessors, never a `&` name or a constructor (chez-sqlite3 ADR-0012's slice-4 note, and
  ADR-0013, amended).
- **chez-sqlite3's `check-seam` keeps rules (c) to (i), (k) and (l)** at v0.1.1; it has no (j).
  Its rule (l) makes `(chez-sqlite3 private utf8)`'s strict decoder the only one, because Chez's
  `utf8->string` drops a leading U+FEFF. Every string libsodium hands back here is ASCII: the
  version, the prefix, a hash string.
- **Every block is wiped in `call-with-block`** ([ADR-0008]). A library that made a block
  through `(chez-sodium private memory)` directly would free one unwiped, and no check would see
  it.

## Decision

1. **`(chez-sodium)` is the public library.** It defines nothing: it re-exports names its private
   libraries define, each `eq?` to its definition.
2. **It exports predicates and accessors, never a `&` name or a constructor.** In M1:
   `sodium-version`, `chez-sodium-error?`, `sodium-library-unavailable?`, and
   `sodium-library-unavailable-reason`, `-path`, `-source`, `-detail` and `-candidates`.
   `sodium-failed?`, `sodium-failed-function` and `sodium-failed-code` join in M3, with its first
   raise ([ADR-0006], amended).
3. **`check-seam` reads `src/` alone,** as chez-sqlite3's does: under `src/`, only
   `(chez-sodium)` and `(chez-sodium private …)` libraries exist. Tests and the test helpers may
   import private libraries.
4. **Its rules are chez-sqlite3's (c) to (i) and (k), for one family, `(chez-sodium …)`.**
   `library-only-chez-names` gives `foreign-alloc` and `foreign-free` to `memory`, and
   `load-shared-object`, `foreign-procedure`, `foreign-entry`, `foreign-entry?`, `foreign-ref`,
   `foreign-set!`, `getenv`, `machine-type`, `format`, `format-condition?` and
   `display-condition` to `native`. `allowed-chez-names` is exactly what `src/` imports.
5. **Rule (l) is dropped.** No text needs a strict decoder.
6. **A new rule (m): only `native` imports `(chez-sodium private memory)`, and no library
   exports a name it imports from `memory`.**
7. **Inside native, `foreign-block` and `free-foreign-block!` appear only in `call-with-block`'s
   definition.** A `test-native` row reads native's body as data and holds it. With decision 6,
   every block is made and freed by `call-with-block`, and its wipe covers every block. Amended:
   see [below](#amendment-2026-11-23-memory-imported-once).

### Rejected

- **Exporting the `&` names,** which would let a caller build or extend our conditions
  (chez-sqlite3 ADR-0013, amended).
- **Exporting `sodium-failed`'s names in M1,** before anything raises it.

## Consequences

- **Rule (m) and decision 7's row are row 24's structural half,** which no other check holds:
  `test-wipe` reads the blocks `call-with-block` frees, and these hold that no other path makes
  or frees one. Rule (m) alone would leave two: native's own code outside `call-with-block`, and
  a re-export of memory's names (slice 0's review, S0-F3).
- **Rule (m) and the row have no source,** so their rows are written and watched failing like
  any new check.
- **`check-nothreads` refuses `(chez-sodium)` by name,** as every library under `src/`.

## Amendment, 2026-11-23: memory imported once

Accepted (the owner, 2026-11-23), from M1 slice 2's review, S2-F1. Slice 2 wrote it into the
consequences in place; M1's closing review (M1-F9) moved it here, as a decision.

- **A renamed second import got past decision 7 and rule (m) both.** Native could import
  `(chez-sodium private memory)` a second time, with `foreign-block` under another name, and
  make a block outside `call-with-block`. The rows read only memory's own names.
- **Decision 7 now also says: native imports `(chez-sodium private memory)` exactly once, as the
  plain import set,** with no `only`, `rename`, `prefix`, `except` or `for` around it, and no
  other import spec mentions memory. So memory's names appear in native under memory's own
  spelling, and decision 7's rows find every use of them.
- **`test-native`'s E11 holds it,** reading native's import clause as data.

[ADR-0001]: 0001-bind-libsodium-directly.md
[ADR-0006]: 0006-errors-and-no-secret-shown.md
[ADR-0008]: 0008-every-block-wiped-before-free.md
