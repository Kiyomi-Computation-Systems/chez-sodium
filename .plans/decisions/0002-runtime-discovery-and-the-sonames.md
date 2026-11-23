# ADR-0002: Find libsodium at runtime: an override, else one candidate list, the newer soname first, loaded once

- **Status:** Accepted (the owner, 2026-11-22), approved with the brief. Amended 2026-11-23 in
  M1's plan, and accepted by the owner that day ([amendment](#amendment-2026-11-23-m1s-plan)).
- **Date:** 2026-11-22
- **Scope:** chez-sodium, on Linux distributions and Guix environments
- **Settles:** [brief](../2026-11-22-chez-sodium-project-brief.md) §7.2's discovery and load,
  with §3.1, §3.4 and §5's load reasons
- **Related:** chez-sqlite3 ADR-0002, which this follows · [ADR-0001] (no build step) ·
  [ADR-0003] (the floor) · [ADR-0006] (the condition) · [ADR-0010] (Linux only) ·
  [ADR-0011] (the container's override)

## Context

- **[ADR-0001] compiles nothing,** so libsodium is found when the program runs.
- **Two sonames are in use,** from the libtool versions in `configure.ac` (the review):
  `libsodium.so.23` for 1.0.17 and 1.0.18, and `libsodium.so.26` for 1.0.19 to 1.0.22.
- **Ubuntu 22.04, 24.04 and 26.04 ship 1.0.18, as `libsodium23`;** 26.10 ships 1.0.22, as
  `libsodium26`. Guix's, at the pinned channel `b532aa7`, is 1.0.22 (brief §8.3).
- **libsodium needs `sodium_init` before every call but the version functions** (brief §3.1).
  `sodium_init` answers 0 the first time, then 1, and -1 only if its mutex fails. It is
  thread-safe. **1 is not a failure** (brief §3.4; P-F13).
- **Every function bound exists at the floor** (X-m3).
- **Chez wedges on a library body that failed with a non-serious raise,** reproduced on 10.4.0.
  chez-sqlite3's `private/load-state.sls` remembers the first failure and raises it again
  (brief §6.1).

## Decision

1. **The override.** If `CHEZ_SODIUM_LIBRARY` is set, it names a libsodium by its absolute
   path, loaded as given, with no search and no fallback. Anything else is `invalid-override`,
   as in chez-sqlite3 ADR-0002.
2. **Otherwise, chez-sqlite3 ADR-0002's candidate list, by world.** A pure function computes it
   from the machine type, the environment, `/proc/self/maps` and an existence predicate.
   - **Guix world,** when `/proc/self/maps` shows libc mapped from under `/gnu/store/`: `lib/`
     under `$GUIX_ENVIRONMENT`, `$GUIX_PROFILE`, `$HOME/.guix-home/profile`,
     `$HOME/.guix-profile` and `/run/current-system/profile`, in that order. No standard
     directory is a candidate there.
   - **FHS world:** `/usr/local/lib`, `/usr/lib/<triple>`, `/usr/lib64` and `/usr/lib`, in that
     order. No Guix profile is a candidate there.

   The first candidate that exists is chosen.
3. **In each directory, `libsodium.so.26`, then `libsodium.so.23`.** The newer soname comes
   first, so a directory that holds both loads the newer library. The bare `libsodium.so`
   development link is never tried: it is installed only with the headers, and names no ABI.
   1.0.17 is refused by the floor ([ADR-0003]), not by its name.
4. **One load, in order, never fall through** (X-m4): choose; load; bind the version entries;
   check the floor; call `sodium_init`; bind the rest. Every entry point is required, so there
   is no `bind-optional` (X-m3). The load runs once, and a failure is remembered and raised
   again. Each milestone binds its own verbs' entry points in the last step.
5. **`sodium_init` answering 0 or 1 loads,** and the load records the answer. Any other answer
   is `init-failed`, its detail the answer.
6. **Every refusal is a `&sodium-library-unavailable`** ([ADR-0006]) carrying a reason:
   `invalid-override`, `not-found`, `load-failed`, `below-floor`, `missing-api` or
   `init-failed`. `not-found` lists every candidate it checked.

### Rejected

- **macOS candidates,** which chez-sqlite3 has ([ADR-0010]).
- **Trying candidates until one verifies,** and a bare soname through the platform loader, for
  chez-sqlite3 ADR-0002's reasons: a refused library can't be unloaded, a second load redirects
  later bindings, and a bare name finds nothing under Guix's Chez.

## Consequences

- **Nothing reads `LD_LIBRARY_PATH` on chez-sodium's behalf.** Any other libsodium is named
  with `CHEZ_SODIUM_LIBRARY`.
- **Development never depends on the search.** The container exports the override, by absolute
  path, to its `lib/libsodium.so.26` ([ADR-0011]). Discovery's own tests use made-up inputs,
  among them a directory that holds both sonames (brief §7.2).
- **CI's `main` job finds Ubuntu 24.04's 1.0.18 by discovery,** and asserts that it loaded the
  floor. The `floor` and `current` jobs name their builds through the override ([ADR-0003]).
- **Rows reach every reason** (brief §8.1, rows 20 and 21; P-F12):
  - decoys reach `below-floor`, `missing-api` and `init-failed`, from a `sodium_init` that
    answers -1 and one that answers 2, and a `sodium_init` that answers 1, which loads;
  - `invalid-override` comes from a bare name in the override, `load-failed` from a text file
    or a missing path, and `not-found` from discovery's tests, with no decoy;
  - a child calls the real `sodium_init` through its own binding, then loads chez-sodium. It
    loads, and a second direct call answers 1.
- **The reason symbols are the contract.** Tests assert the reason, never the text.

## Amendment, 2026-11-23: M1's plan

Accepted (the owner, 2026-11-23), proposed in [the M1 plan](../2026-11-22-m1-plan.md), §4.2,
items 2, 3 and 12.

- **Decision 5 refused only -1, so an undocumented 2 would have loaded.** libsodium documents 0,
  1 and -1 alone (brief §3.4), and answered 0, then 1, at 1.0.18 and 1.0.22 (measured,
  [research/m1-plan/](../research/m1-plan/README.md)). Now 0 and 1 load, and any other answer is
  `init-failed`. Decoys answer -1 and 2, so that no single value passes for "refused", as
  chez-sqlite3 refuses any `sqlite3_initialize` answer but `SQLITE_OK`.
- **The load records `sodium_init`'s answer,** for rows 21 and 22 to read.
- **M1 binds five entry points:** `sodium_version_string`, `sodium_library_version_major` and
  `_minor`, `sodium_init` and `sodium_memzero`. Each later milestone appends its own verbs'
  entry points to the load's last step, each with its row in the convention table, the decoy,
  the `missing-api` rows and row 22.

[ADR-0001]: 0001-bind-libsodium-directly.md
[ADR-0003]: 0003-libsodium-floor-1-0-18.md
[ADR-0006]: 0006-errors-and-no-secret-shown.md
[ADR-0010]: 0010-linux-only.md
[ADR-0011]: 0011-the-harness-after-chez-sqlite3.md
