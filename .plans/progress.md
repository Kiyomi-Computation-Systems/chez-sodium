# Progress ledger

Where chez-sodium stands. Read it with [global-constraints.md](global-constraints.md) before
starting slice work. When a slice merges, update **Now**, and add a close-out under
**Close-outs**, newest first.

## Now

- **M0 is done and merged** (PR #2; [the M0 plan](2026-11-22-m0-plan.md); its close-out is
  below).
  - **The records:** ADR-0001 to ADR-0011, `global-constraints.md` and `traps.md`. Each is
    Accepted: the owner settled it in brief §11, or approved it with the brief. M1 adds
    ADR-0012.
  - **The container,** pinned to Guix `b532aa7`. It has Chez 10.4.0, threaded, and libsodium
    1.0.22 as `libsodium.so.26` ([research/m0-container/](research/m0-container/README.md)).
  - **The harness.** `make test` runs seven suites, and `make check-test-fails` plants a fault
    in each of its 12 cases.
  - **The memory gate.** Valgrind ran the container's Chez loading libsodium clean, with
    `default.supp` alone ([research/m0-memory-gate/](research/m0-memory-gate/README.md)).
  - **CI:** `main`, `memory` and `nothreads`.
- **M1 is under way** ([the M1 plan](2026-11-22-m1-plan.md), accepted by the owner on
  2026-11-23). Six slices, one PR each: 0, the plan and the records; 1, the pure core; 2, the
  load and the checks of the FFI; 3, refusals end to end; 4, the public library; 5, the `floor`
  and `current` lanes. Then M1's closing review.
- **Slice 0 is on `m1-plan`:** the plan; ADR-0002, ADR-0003, ADR-0006, ADR-0007 and ADR-0011
  amended; ADR-0012 new; the constraints, the brief, `traps.md` and AGENTS.md to match; the
  plan's probes in [research/m1-plan/](research/m1-plan/README.md).
  - **Its review** ([research/m1-slice-0-review/](research/m1-slice-0-review/README.md)) found
    a blocker, six majors and thirteen minors, each fixed. The owner chose the wipe fused with
    the free (ADR-0008, amended) and native's load in one section (ADR-0007, amended); ADR-0001
    is amended for the allow-lists.
- **Slice 1 is on `m1-slice-1`,** stacked on slice 0: `conditions`, `load-state`, `discovery`
  and `verify`, built from chez-sqlite3 v0.1.1 by trim tables checked before any code, and the
  exit checks removed ([its mutation log](m1-slice-1-mutation-log.md)).
- **Slice 2 is on `m1-slice-2`,** stacked on slice 1: the load in one section, the block
  helper with the wipe fused with the free, `check-seam` with rule (m), the convention table
  and `test-constants` ([its mutation log](m1-slice-2-mutation-log.md)).
  - **Its three builders shared the main tree,** on disjoint files, by the owner's choice: the
    harness's worktrees came from `main`, and fast-forwarding one was denied.
  - **Native exports 13 names,** among them `call-with-block`, `call-in-section` and the five raw
    bindings; never `foreign-block` or `free-foreign-block!`.
  - **Its review** found no blocker, two majors and six minors, each fixed.
- **Slice 3 is on `m1-slice-3`,** stacked on slice 2: refusals end to end, through the decoy,
  the probe and six `test-library-loading-*` suites; `make dev` and `check-dev`; CI's `main`
  running `make build` by discovery; and the row tying `every-entry` to the convention table
  ([its mutation log](m1-slice-3-mutation-log.md)).
  - **Its builders shared the main tree** with slice 4's, on disjoint files.
  - **For its close-out:**
    - a child under the gate takes 3.85 s in the container, not the plan's 2.6 s, so each suite
      runs at most 14 children;
    - not-found's world is three empty directories, so it lists all ten candidates;
    - `version-bom`, `--init-after` and `--wipe` were added (plan §2.2);
    - CI's first measured times, which plan §5.2 owes.
  - **Its first CI run is the first by discovery.** The container always exports
    `CHEZ_SODIUM_LIBRARY`, so discovery's FHS arm, `make build` and `check-dev` run by
    discovery on `main` alone. The review simulated that world against Ubuntu's 1.0.18, and
    every arm passed.
  - **Its review** ([research/m1-slice-3-review/](research/m1-slice-3-review/README.md)), over
    slices 3 and 4 together, found no blocker, five majors and nine minors, each fixed.
- **Slice 4 is on `m1-slice-4`,** stacked on slice 3: `(chez-sodium)`, which defines nothing and
  re-exports ADR-0012's eight M1 names, each `eq?` to its definition; `test-public`; and
  `test-never-loads`, whose child references every condition export with no libsodium to load
  ([its mutation log](m1-slice-4-mutation-log.md)). CI's `nothreads` now refuses nine libraries
  by name, `(chez-sodium)` among them.
  - **Its review** was slice 3's, over both slices: two majors and two minors on slice 4, each
    fixed.
- **Next: slice 5,** the `floor` and `current` lanes: `build-sodium.sh`, `check-sodium.sh` with
  `--discovery`, and `test-ci-sodium`.

## Answered for M1

M0 left five questions to M1. The M1 plan, §4.1, answers each, and the owner accepted them on
2026-11-23:

- **A version string that is not three naturals,** or NULL, is `below-floor` (ADR-0003,
  amended).
- **`&sodium-failed`'s fields are `function` and `code`;** every raise carries `&who`; a
  refusal's irritants lead with the rule's symbol; a secret is shown as `(kind K)` (ADR-0006,
  amended).
- **No exit checks:** M1 removes them, in slice 1 (ADR-0011, amended).
- **The C oracle is `libsodium-oracle`** (ADR-0011).
- **The decoy's pointer rule** is in ADR-0011, amended.

## Owed to M2

- **Brief §4.3's ranges are in the brief alone,** with no record: `blake2b`'s size and key
  lengths, checked before C; `random-bytes 0` answering `#vu8()` without C; and
  `constant-time-bytevector=?` answering `#f` on unequal lengths without C. M2's plan restates
  them.
- **From the M1 plan, §3:**
  - `randombytes_buf`, `crypto_generichash` with its six sizes, and `sodium_memcmp`: their
    bindings, rows, decoy entries and return-code rows;
  - the input cap and its check;
  - how row 24 reaches a verb's blocks;
  - whether `test-constants` gains a constants half, each size function against its header's
    macro.
  - a check of ADR-0001 decision 2, that every constant is read through libsodium's own
    function: nothing holds it once v0.1.1's constants half is dropped (slice 2's tables);
  - `unsigned-64` joins the argument allow-list with its first row, `crypto_generichash`'s
    `inlen` (ADR-0001, amended);
  - a check of the decoy's `volatile uintptr_t` rule, which nothing holds in M1: no M1 entry is
    `nonnull`. A `-Werror` compile holds it only for a `nonnull` parameter, and `nonnull` is per
    function: in 1.0.22, `randombytes_buf`'s `buf` and `crypto_generichash`'s `out` alone. Its
    `in` and `key`, and `sodium_memcmp`'s and `sodium_memzero`'s pointers, would compile tested
    directly. So the check reads the decoy's source: each pointer parameter's only use is its
    `volatile uintptr_t` read ([slice 3's review](research/m1-slice-3-review/README.md),
    S3-F3);
  - the missing-entry rows split again, four ways as in v0.1.1, once M2's entries arrive: one
    suite holds the five M1 entries today, within its 14 children
    ([slice 3's mutation log](m1-slice-3-mutation-log.md)).

## Owed to M3

From the M1 plan, §3 and §4.2, item 6:

- the password verbs and their bindings, two of them collect-safe;
- `call-with-c-string` for the hash string, and the password's UTF-8 writer. v0.1.1's makes two
  Scheme copies of its string, which ADR-0008 forbids for a secret, so M3's writers bound every
  write by the block's size, and answer a string changed mid-write as data;
- `&sodium-failed`'s first raise, and its export;
- the oracle's hex mode (row 4), and the FIFO decoy (row 19);
- `test-conventions`' rows for the collect-safe calls, the first to use `collect-safe`.

## Owed to M4

- **The documents' notes from M1:** the first reference under an engine (ADR-0007, amended),
  `sodium_init`'s 1, and what wiping cannot reach.
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
