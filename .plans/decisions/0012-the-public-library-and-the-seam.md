# ADR-0012: `(chez-sodium)` re-exports and defines nothing, and `check-seam` reads `src/`

- **Status:** Accepted (the owner, 2026-11-23), proposed in [the M1 plan](../2026-11-22-m1-plan.md),
  §4.2, items 1 and 7. Decisions 6 and 7 widened after slice 0's review (S0-F3). Decision 7
  amended 2026-11-23, after slice 2's review, and accepted by the owner that day
  ([amendment](#amendment-2026-11-23-memory-imported-once)).
  Amended 2026-11-23 in M2's plan, and accepted by the owner that day, after M2 slice 0's
  review ([amendment](#amendment-2026-11-23-m2s-plan)).
  Amended 2026-11-24 in M3's plan, and accepted by the owner that day
  ([amendment](#amendment-2026-11-24-m3s-plan)).
  Its last points added after M3's slice reviews and closing review.
  Amended 2026-11-25 in M4's plan, and accepted by the owner that day
  ([amendment](#amendment-2026-11-25-a-signature-comment-is-its-type-alone-m4s-plan)).
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

## Amendment, 2026-11-23: M2's plan

Accepted (the owner, 2026-11-23), proposed in [the M2 plan](../2026-11-23-m2-plan.md), §4.1, item 6,
and §4.2, item 2, with the owner's answers of 2026-11-23.

- **The verbs live beside native.** `(chez-sodium private byte-verbs)` holds `random-bytes`,
  `blake2b` and `constant-time-bytevector=?`. It imports `require-threaded` first, then `(rnrs)`,
  native, conditions and cap, and nothing from `(chezscheme)`, which a row holds whole: `check-seam`
  lets any library import `critical-section`. It holds no `foreign-procedure`, `foreign-ref`,
  `foreign-set!` or block of its own, so rules (f) and (m) and decision 7 stand as they are.
  `(chez-sodium private cap)` holds `input-cap` alone ([ADR-0007], amended). Native keeps the load,
  the raw bindings and the helpers, as chez-sqlite3's native does beside its verbs' libraries. M3's
  password verbs go beside it in the same way.
- **M2's exports:** the three verbs, and `sodium-failed?`, `sodium-failed-function` and
  `sodium-failed-code`, which decision 2 put in M3; their first raise is M2's ([ADR-0006],
  amended).

## Amendment, 2026-11-24: M3's plan

Accepted (the owner, 2026-11-24), proposed in [the M3 plan](../2026-11-24-m3-plan.md), §4.1, items
2 and 11, and §4.2, item 5.

- **`(chez-sodium private password-verbs)` holds the three verbs and `make-password-limits`,**
  beside native, as `byte-verbs` does.
  - It imports `require-threaded` first, then `(rnrs)`, native, conditions, cap and
    password-text, and nothing from `(chezscheme)`.
  - A row holds the import clause whole.
- **`(chez-sodium private password-text)` is pure:** `utf8-length`, `readable-hash-string?` and
  `current-hash-shape?`. It imports `require-threaded`, `(rnrs)` and cap alone, and loads no
  libsodium.
  - `test-never-loads`' loaders row holds that: it gains `password-verbs` alone, and a
    `password-text` that imported native would join it (M3S0-F2).
- **No Scheme copy of a secret, read as data.** Rows read `password-text.sls`,
  `password-verbs.sls` and native's two writers, and hold the whole set of symbols each may
  reference to an allow-list written in the suite: `test-password-text`'s, `test-password-verbs`'
  S6, and `test-native`'s E13. `string-append` appears only inside a top-level `-message`
  definition of no parameters (S7). The value rows cannot see a copy: `string->utf8`'s length is
  the right count (M3S0-F6). A deny-list of the copying procedures came first, and let
  `make-string` and `string-set!` through (M3S1-F2).
- **Native gains the writers, `call-with-c-string` and `call-with-utf8`, and
  `foreign-ascii-string`.** Only native reads and writes foreign memory (rule (f)), and every
  block is made by `call-with-block` (decision 7).
- **M3's exports:** `password-hash`, `password-verify`, `password-needs-rehash?` and
  `make-password-limits`.
- **Decision 2's "never a `&` name or a constructor" means a condition's.**
  - The rule keeps a caller from building or extending our conditions.
  - `make-password-limits` builds limits, not a condition.
  - Its record type is opaque and sealed. Neither the type, nor a predicate, nor an accessor is
    exported, so the constructor is the only way to make a `Password-limits`.

  The owner chose this on 2026-11-24.

## Amendment, 2026-11-25: a signature comment is its type alone (M4's plan)

Accepted (the owner, 2026-11-25), proposed in [the M4 plan](../2026-11-25-m4-plan.md), §2.1, Q4
item 3, and §4.2, with [ADR-0013], decision 3.

- **Each export's signature comment, in `src/chez-sodium.sls`, is `;; NAME : TYPE` and nothing
  more.** A note on the arguments, such as `input, size, key`, goes on a comment line of its own
  below, whose second word is not `:`. Four comments carried one at the end: `blake2b`'s,
  `password-verify`'s, `password-needs-rehash?`'s and `make-password-limits`'.
- **`test-reference` holds each to `docs/reference.md`,** character for character, and the
  exports to the reference's entries as whole lists. That is AGENTS.md's one exception to "no test
  reads a comment": the signature comments are the contract.

[ADR-0001]: 0001-bind-libsodium-directly.md
[ADR-0006]: 0006-errors-and-no-secret-shown.md
[ADR-0007]: 0007-one-critical-section-per-verb.md
[ADR-0008]: 0008-every-block-wiped-before-free.md
[ADR-0013]: 0013-the-first-release.md
