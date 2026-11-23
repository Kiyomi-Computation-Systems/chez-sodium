# Progress ledger

Where chez-sodium stands. Read it with [global-constraints.md](global-constraints.md) before
starting slice work. When a slice merges, update **Now**, and add a close-out under
**Close-outs**, newest first.

## Now

- **M0 is done and merged** (PR #2; [the M0 plan](2026-11-22-m0-plan.md); its close-out is
  below).
  - **The records:** ADR-0001 to ADR-0011, `global-constraints.md` and `traps.md`. Each is
    Accepted: the owner settled it in brief §11, or approved it with the brief.
  - **The container,** pinned to Guix `b532aa7`. It has Chez 10.4.0, threaded, and libsodium
    1.0.22 as `libsodium.so.26` ([research/m0-container/](research/m0-container/README.md)).
  - **The harness.** `make test` runs seven suites, and `make check-test-fails` plants a fault
    in each of its 12 cases.
  - **The memory gate.** Valgrind ran the container's Chez loading libsodium clean, with
    `default.supp` alone ([research/m0-memory-gate/](research/m0-memory-gate/README.md)).
  - **CI:** `main`, `memory` and `nothreads`.
- **Next: M1's plan:** `conditions`, discovery, the load and the floor, `sodium-version`, and
  the block helper.

## Owed to M1

Questions the records leave to M1, each needing an answer in M1's plan:

- **The reason for a version string that is not three naturals.** ADR-0003 parses it
  strictly, and ADR-0006's six reasons name none for this case.
- **`&sodium-failed`'s fields,** and whether conditions carry `&who`, as chez-sqlite3
  ADR-0013's do.
- **Whether the load registers an exit check.** `(chez-sodium private counters)` keeps
  `register-exit-check!`, which `suite-exit-status` runs. chez-sqlite3 registered SQLite's
  memory check there, and libsodium has no such check. If nothing registers one, M1 removes
  it.
- **The C oracle's name is fixed: `libsodium-oracle`.** The gate's rule for child logs names
  it (ADR-0011).
- **The decoy logs each pointer through a `volatile uintptr_t`** (brief §7.2, P-F7). AGENTS.md
  carries the rule, and no record does: M1's plan restates it.

## Owed to M2

- **Brief §4.3's ranges are in the brief alone,** with no record: `blake2b`'s size and key
  lengths, checked before C; `random-bytes 0` answering `#vu8()` without C; and
  `constant-time-bytevector=?` answering `#f` on unequal lengths without C. M2's plan restates
  them.

## Owed to M4

- **The docs rule of `check-floors`** waits for `docs/`.
- **The install-line checks of `test-manifest`** wait for the first release, which writes the
  install lines.

## Close-outs

### 2026-11-22 — M0: the records and the harness (PR #2)

- **Built** on `m0-harness`, from `527170d` ([the plan](2026-11-22-m0-plan.md)). Five agents
  did the work, and each hand-back was rerun before it was built on:
  - the records (Opus): ADR-0001 to ADR-0011, `global-constraints.md` and `traps.md`;
  - the container and harness (Sonnet): seven suites, and `check-test-fails` with 12 plants
    ([the mutation log](m0-harness-mutation-log.md));
  - the memory gate (Sonnet): 59 cases ([the mutation log](m0-memory-gate-mutation-log.md));
  - CI (Sonnet): `main`, `memory` and `nothreads`, held by `check-ci`
    ([the mutation log](m0-ci-mutation-log.md)).
- **Added after the hand-backs:** the `floors-script` plant, which v0.1.1 has. Watched to fail
  alone when `check-floors` reads a clean directory in place of `scripts/ci`.
- **Reviewed:** one Opus review, read-only, found no blocker, 2 majors and 11 minors, and each
  is fixed ([research/m0-review/](research/m0-review/README.md)).
  - The majors were in the records: ADR-0006 lacked the hash-string exception to the cap, and
    no record said the cap counts UTF-8 bytes.
  - One check could not fail: `counters` without its critical section passed every row. The
    mutant left the mutex held under an abandoned engine at fuel 5. A row now kills it.
  - The brief's §4.3 ranges and the decoy's pointer rule are owed to M2's and M1's plans
    (above).
- **CI's first run** passed all three jobs, from a cold cache, in about 11 minutes:
  - `main`: the runner's libsodium is `1.0.18-1ubuntu0.24.04.1`, the package ADR-0003 names;
    `make test` 7 of 7, and `check-test-fails` all 12 cases;
  - `memory`: the gate's 59 cases, then 7 of 7 suites under it, none slow;
  - `nothreads`: every library under `src/` refused by name.
