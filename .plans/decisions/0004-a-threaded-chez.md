# ADR-0004: A threaded Chez, at 10.4.0 or later

- **Status:** Accepted (the owner, 2026-11-22), brief §11.6.
- **Date:** 2026-11-22
- **Scope:** every Chez chez-sodium runs on
- **Settles:** [brief](../2026-11-22-chez-sodium-project-brief.md) §11.6, the floor, 10.4.0,
  among it. [The M0 plan](../2026-11-22-m0-plan.md) writes it into `floors.sexp` (§2, §4).
- **Related:** chez-sqlite3 ADR-0001, amended 2026-11-13, which this follows ·
  [ADR-0011] (the floors file and the `nothreads` job)

## Context

- **The siblings require a threaded Chez** (brief §11.6). chez-sqlite3's floor is 10.4.0
  (chez-sqlite3 ADR-0001).
- **`counters` and `memory` import `make-mutex`,** which an unthreaded Chez lacks (brief §11.6).
  On a `--nothreads` Chez, a library importing it dies at import with a bare "missing import",
  as chez-libuv measured (chez-sqlite3 ADR-0001, amended).
- **Techo hashes on worker threads** (brief §11.6). Every Tier 1 call is thread-safe once
  `sodium_init` has run (brief §3.4).

## Decision

1. **Chez Scheme 10.4.0 or later, built with threads.** The floor is written once, as
   `(chez "10.4.0")` in `packaging/floors.sexp` ([ADR-0011]).
2. **`(chez-sodium private require-threaded)` refuses an unthreaded Chez, and one below the
   floor, by name, while it is being expanded.** It is chez-sqlite3's
   `private/require-threaded.sls`, renamed (brief §7.1). Every library under `src/` imports it
   first.
3. **CI's `nothreads` job runs `make check-nothreads` on a Chez built `--nothreads`.** Every
   library under `src/` must be refused there by name (brief §9; the M0 plan §2).

## Consequences

- **`test-require-threaded` builds its rows from the file:** it accepts the floor and refuses
  the versions below it (chez-sqlite3 ADR-0008, amended).
- **On a threaded Chez, `check-nothreads` fails,** naming each library. That is its red run, and
  why `make test` doesn't run it (chez-sqlite3 ADR-0001, amended).
- **Changing the Chez floor** edits what [ADR-0011] lists.

[ADR-0011]: 0011-the-harness-after-chez-sqlite3.md
