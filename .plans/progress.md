# Progress ledger

Where chez-sodium stands. Read it with [global-constraints.md](global-constraints.md) before
starting slice work. When a slice merges, update **Now**, and add a close-out under
**Close-outs**, newest first.

## Now

- **M0 is done and merged** (PR #2; [the M0 plan](2026-11-22-m0-plan.md); its close-out is
  below).
- **M1 is done and merged** (PRs #3 to #9, squashed onto `main` on 2026-11-23; [the M1
  plan](2026-11-22-m1-plan.md); the close-outs below): six slices, #3 to #8, then the closing
  review's fixes, #9. The closing review
  ([research/m1-closing-review/](research/m1-closing-review/README.md)) found no blocker, 4 majors
  and 10 minors, and a second review of the fixes 5 majors and 7 minors; each is fixed in #9,
  with the owner's amendments of ADR-0001, ADR-0003, ADR-0007 and ADR-0012 (2026-11-23). Each
  builder's trim tables, what
  every copied part of chez-sqlite3 v0.1.1 protected, are in
  [research/m1-trim-tables/](research/m1-trim-tables/README.md).
  - **Merged by squash, bottom up.** A stacked PR conflicts once the one below is
    squash-merged; each was merged after a merge commit that keeps its own tree, and each
    merge's tree equals the head CI passed (`traps.md`).
  - **One verb, `sodium-version`,** exported by `(chez-sodium)` with the predicates and
    accessors of `&sodium-library-unavailable` (ADR-0012).
  - **The load:** discovery, one load in one critical section, the floor read from
    `sodium_version_string`, then `sodium_init`, in ADR-0002's order; five entry points bound.
  - **The block helper:** counted blocks, `call-with-block` with the wipe fused with the free
    (ADR-0008), and `call-in-section` (ADR-0007).
  - **The checks of the FFI:** the decoy, the C oracle, the convention table, `test-constants`'
    prototypes against `sodium.h`, and `check-seam` with rule (m).
  - **The harness:** `make test` runs 26 suites, and `check-test-fails` plants 13 cases;
    `make build`, `make dev` and `check-dev`.
  - **CI:** five jobs. `main` finds Ubuntu 24.04's 1.0.18 by discovery and asserts it is the
    floor; `memory`; `nothreads`; `floor` and `current` build their pinned tarballs and run the
    suites against them.
- **Next: M2,** `random-bytes`, `blake2b` and `constant-time-bytevector=?`, built on M1's helper
  (brief §9). Its plan starts from "Owed to M2" below.

## Answered for M1

M0 left five questions to M1. The M1 plan, §4.1, answers each, and the owner accepted them on
2026-11-23:

- **A version string that is not three naturals,** or NULL, is `below-floor` (ADR-0003,
  amended).
- **`&sodium-failed`'s fields are `function` and `code`;** every raise carries `&who`; a
  caller's mistake's refusal leads its irritants with the rule's symbol; a secret is shown as
  `(kind K)` (ADR-0006, amended).
- **No exit checks:** M1 removes them, in slice 1 (ADR-0011, amended).
- **The C oracle is `libsodium-oracle`** (ADR-0011).
- **The decoy's pointer rule** is in ADR-0011, amended.

## Owed to M2

- **Brief §4.3's ranges are in the brief alone,** with no record: `blake2b`'s size and key
  lengths, checked before C; `random-bytes 0` answering `#vu8()` without C; and
  `constant-time-bytevector=?` answering `#f` on unequal lengths without C. M2's plan restates
  them.
- **The bindings:** `randombytes_buf`, `crypto_generichash` with its six sizes, and
  `sodium_memcmp`, each with its convention row, its decoy entry, its `missing-api` row and its
  return codes (row 22), at the floor and the current release.
  - `unsigned-64` joins the argument allow-list with `crypto_generichash`'s `inlen`, and `size_t`
    joins the result allow-list with the first size function (ADR-0001, amended).
    `test-conventions`' row that only an argument uses `size_t` changes then, and the rows that
    count five entry points (`test-native` E3 and E5, `test-conventions`) grow.
  - The missing-entry rows split again, four ways as in v0.1.1: one suite holds M1's five
    within its 14 children (slice 3's mutation log).
- **Each verb's rows from plan §1's "Waits" column:**
  - 15: its refusals, each before any block, the decoy's log showing no call;
  - 16: its secret parameters refused by kind;
  - 18: under an engine, at every fuel;
  - 24: its blocks, which `test-wipe`'s child names from inside PROC today, so row 24 needs a way
    to reach a verb's.
- **The input cap and its check** (ADR-0007, decision 5), before the section.
- **The refusals' shape.**
  - Each verb refuses its own parameters by their own names, before its section, each leading
    with a rule symbol (ADR-0006, decision 5). `call-with-bytes`' `(not-a-bytevector bytes ...)`
    names its own parameter, and is a net.
  - Each verb joins `test-never-loads`' `verb-names`, the names that load libsodium; its row
    on `(chez-sodium)`'s exports fails by name until it does.
- **Where the verbs live.** In native, or in a library beside it. If beside it:
  - `check-seam`'s rule (f) keeps `foreign-ref` and `foreign-set!` in native, and rule (m) keeps
    every block in `call-with-block`;
  - `test-never-loads`' loaders row, asserted whole, gains the new library.
- **How a verb reads a size,** at the load or at each call, so that ADR-0001 decision 2 (every
  constant read through libsodium's own function) gets the check it lacks.
- **Whether `test-constants` gains a constants half,** each size function against its header's
  macro.
- **A check of the decoy's `volatile uintptr_t` rule,** which nothing holds in M1, since no M1
  entry is `nonnull`.
  - A `-Werror` compile holds it only for a `nonnull` parameter, and `nonnull` is per function.
    In 1.0.22 only `randombytes_buf`'s `buf` and `crypto_generichash`'s `out` are marked.
  - So the check reads the decoy's source: each pointer parameter's only use is its
    `volatile uintptr_t` read ([slice 3's review](research/m1-slice-3-review/README.md),
    S3-F3).

## Owed to M3

- The password verbs and their bindings, two of them collect-safe, and `test-conventions`' rows
  for them, the first to use `collect-safe`.
- `call-with-c-string` for the hash string, and the password's UTF-8 writer.
  - v0.1.1's makes two Scheme copies of its string, which ADR-0008 forbids for a secret.
  - So M3's writers bound every write by the block's size, and answer a string changed
    mid-write as data.
- `&sodium-failed`'s first raise, row 17's M3 half, and its export.
  - `sodium-failed?`, `-function` and `-code` join `(chez-sodium)` (ADR-0012, decision 2).
  - They join `test-never-loads`' condition names, which come from `(chez-sodium)`'s exports,
    and its child's expected lines; its export row fails by name until they do (M1's closing
    review, M1-F6).
- The oracle's hex mode (row 4); the FIFO decoy (row 19).
  - Row 19 references the library once before its first fork: a library first reached on two
    threads at once refuses the second (ADR-0007, amended; M1-F10).
- Rows 11 (the password half), 15, 16, 18, 22 and 24 for the password verbs (plan §1).

## Owed to M4

- **The documents' notes from M1:**
  - the first reference under an engine (ADR-0007, amended);
  - the first reference on two threads at once (M1-F10);
  - `sodium_init`'s 1;
  - what wiping cannot reach.
- **The docs rule of `check-floors`** waits for `docs/`.
- **The install-line checks of `test-manifest`** wait for the first release, which writes the
  install lines.

## Close-outs

### 2026-11-23 — M1's closing review and its fixes (PR #9)

- **Reviewed:** M1's closing review, on Opus, over `main` at `49e7e3b`, found no blocker, 4
  majors and 10 minors ([research/m1-closing-review/](research/m1-closing-review/README.md)).
  It read slice 1, which had no review of its own, and killed ten further mutants there.
- **The owner decided, on 2026-11-23:**
  - ADR-0003 amended: what a floor raise moves, and what its record must decide (M1-F3);
  - ADR-0001's decision 10 and ADR-0012's decision 7 restored to their first texts, with dated
    amendments for the allow-lists and for memory imported once (M1-F9);
  - both rule changes in this PR: `check-ci` holds each job's runner-image step, its use in the
    Chez cache key, and each `timeout-minutes` (M1-F4); and the first reference on two threads,
    as an ADR-0007 amendment (M1-F10; R2-F3).
- **Built** on `m1-closing` by two Sonnet builders, on disjoint files, and the caller:
  - `check-ci`'s new rules, with 91 new rows in `test-check-ci`, 766 in all, at 118 s of 450
    under the gate;
  - `test-never-loads`' condition names from `(chez-sodium)`'s exports, and the discovery
    suite's hand-written FHS list, held to discovery's own by a row that runs everywhere;
  - `--proto '=https'`, `sha256sum` alone and signal traps in five M0 scripts, which no row holds;
  - the records, the ledger, AGENTS.md, the trim tables and the comments, by the caller.

  31 mutants are logged, each killed, in [the closing fixes' log](m1-closing-mutation-log.md).
- **Reviewed again** on Opus, since the fixes change rules: no blocker, 5 majors and 7 minors,
  each fixed ([research/m1-closing-review/second-review.md](research/m1-closing-review/second-review.md)).
  The majors were: the image id not held in the Chez keys; ADR-0007's probe note, which
  misread two programs as two runs; the thread rule with no record behind it; this ledger
  calling M1 done before this PR; and a false cause in the thread rule, which the caller
  reproduced.
- **The caches go cold** on this PR's first run and on `main`'s push after it. Every Chez key
  hashes `build-chez.sh`, `check-chez.sh` and `packaging/floors.sexp`, and the floor lane's
  libsodium key hashes `floors.sexp` too, whose comment changed: about 4 minutes a job for Chez,
  and a minute for the floor's libsodium.

### 2026-11-23 — M1 slice 5: the `floor` and `current` lanes (PR #8)

- **Measured first,** on the host: 1.0.18's tarball is under `releases/old/`, and 1.0.22's
  under `releases/`; three tools agree on each SHA-256; each verifies against its `.minisig`
  with libsodium's published key. In the container, each built with `--prefix` alone and passed
  `make test`, 25 of 25
  ([research/m1-slice-5-measurements/](research/m1-slice-5-measurements/README.md)).
- **Built** on `m1-slice-5` by two Sonnet builders, on disjoint files in one tree, from trim
  tables the caller checked first:
  - `build-sodium.sh`, `check-sodium.sh` (with `--discovery`) and `test-ci-sodium`;
  - the lanes in `ci.yml`, `check-ci` and `test-check-ci`.

  158 mutants are logged (101 on the scripts, 57 on `check-ci`)
  ([its mutation log](m1-slice-5-mutation-log.md)). The caller ran `check-sodium.sh` by hand
  against real builds of both releases.
- **Reviewed:** one Opus review found no blocker, 2 majors and 10 minors
  ([research/m1-slice-5-review/](research/m1-slice-5-review/README.md)).
  - The majors were an unguarded top-level read of the floors file, and two build rows that
    ended before the calls that would show the check's env. Both are fixed and watched to fail.
  - Four items went to M1's closing review: the floor-raise list, the image step,
    `build-chez.sh`, and CI's times.
- **CI's run** 45242596732 passed all five jobs twice.
  - **Attempt 1,** with the libsodium caches cold and Chez's warm from earlier PRs, built each
    release serially: the floor in 66 s, falling back to `releases/old/`, and the current one in
    50 s. Each lane's `make test` ran 26 of 26.
  - **Attempt 2** restored both.
  - **`memory`:** the gate's 59 cases, then 26 of 26 suites in about 600 s, the slowest
    `test-check-ci` at 113 s of 450.
  - **`main`:** `check-sodium.sh --discovery` passed on
    `/usr/lib/x86_64-linux-gnu/libsodium.so.23 (system)`, 1.0.18 (library 10.3).
  - **The push run on `main`,** 45249131058, passed too.

### 2026-11-23 — M1 slice 4: the public library (PR #7)

- **Built** on `m1-slice-4` by one Sonnet builder, beside slice 3's, on disjoint files in one
  tree, from a trim table the caller checked first:
  - `(chez-sodium)`, which defines nothing and re-exports ADR-0012's eight M1 names, each `eq?`
    to its definition;
  - `test-public`, and `test-never-loads`, whose children reference the condition exports with no
    libsodium to load.

  38 mutants are logged, with no survivor ([its mutation log](m1-slice-4-mutation-log.md)).
- **Reviewed** with slice 3, in one Opus review
  ([research/m1-slice-3-review/](research/m1-slice-3-review/README.md)): 2 majors and 2 minors on
  slice 4, each fixed. The majors were an unguarded top-level definition, and an engine row that
  read the counts in no fixed order.
- **CI's run** 45233248425 passed all three jobs. `nothreads` refuses nine libraries by name,
  `(chez-sodium)` among them. In the container, the slowest suite under the gate took 69 s of
  450.

### 2026-11-23 — M1 slice 3: refusals end to end (PR #6)

- **Built** on `m1-slice-3` by two Sonnet builders, beside slice 4's, on disjoint files in one
  tree, from trim tables the caller checked first:
  - the decoy, the refusal probe, `library-loading.sls` and six `test-library-loading-*` suites;
  - `make dev` and `check-dev`;
  - CI's `main` running `make build` by discovery;
  - the row tying `every-entry` to the convention table, owed from slice 2.

  53 mutants are logged, and `check-dev`'s eight ([its mutation log](m1-slice-3-mutation-log.md)).
- **Added beyond the plan:** the decoy's `version-bom`, and the probe's `--init-after` and
  `--wipe` (plan §2.2).
- **Measured:**
  - **A child under the gate** takes 3.85 s in the container, not the plan's 2.6 s, so each
    suite runs at most 14 children. On CI's runner the six suites take 46 to 55 s each under the
    gate, about 3.6 to 3.9 s a child (run 45242596732).
  - **The not-found world** is three empty directories, so it lists all ten candidates.
- **Reviewed:** one Opus review over slices 3 and 4 found no blocker, 5 majors and 9 minors,
  3 majors and 7 minors of them on slice 3, each fixed.
  - The majors: a mutant logged as equivalent that was not; eight rows that depended on argument
    order; and an M2 item that misstated what a `-Werror` compile checks.
  - `traps.md` gained "An exit status cannot tell which raise reached the default handler".
- **CI's first run by discovery,** 45211022814, passed.
  - The container always exports `CHEZ_SODIUM_LIBRARY`, so this was the first run of
    discovery's FHS arm, `make build` and `check-dev` by discovery.
  - `make build` named `/usr/lib/x86_64-linux-gnu/libsodium.so.23 (system)`.

### 2026-11-23 — M1 slice 2: the load and the checks of the FFI (PR #5)

- **Built** on `m1-slice-2` by three Sonnet builders, from trim tables the caller checked first:
  - the load and the block helper;
  - `check-seam` with rule (m);
  - the convention table and `test-constants`.

  They shared one tree, on disjoint files, by the owner's choice: the harness's worktrees came
  from `main`, and fast-forwarding one was denied. About 190 mutants are logged
  ([its mutation log](m1-slice-2-mutation-log.md)).
- **Native exports 13 names,** among them `call-with-block`, `call-in-section` and the five raw
  bindings; never `foreign-block` or `free-foreign-block!`.
- **Reviewed:** one Opus review found no blocker, 2 majors and 6 minors, each fixed
  ([research/m1-slice-2-review/](research/m1-slice-2-review/README.md)).
  - The majors: a renamed second import of `memory` got past every check (now E11), and nothing
    held `call-with-block`'s critical before thunk (now D4 and E12).
  - The reviewer ran the load against Ubuntu's 1.0.18 and Guix's 1.0.18 headers, and it passed.
  - `traps.md` gained "A wipe over a freed block passes a plain run".
- **CI's first run,** 45176193659, was the first on the runner's toolchain, GCC 13.3 and
  Valgrind 3.22, against Ubuntu's `1.0.18-1ubuntu0.24.04.1`. It passed all three jobs.
  - `memory` ran 17 of 17, with `test-native` at 12 s under the gate (8 s in the container).
  - The slowest suite was `test-check-ci`, at 68 s.

### 2026-11-23 — M1 slice 1: the pure core (PR #4)

- **Built** on `m1-slice-1` by two Sonnet builders, on disjoint files: `conditions`, `load-state`,
  `discovery` and `verify`, from trim tables of eight v0.1.1 files that the caller checked before
  any code; and the exit checks removed from `counters` and the testing library (ADR-0011,
  amended). Every suite ran red against a stub first. 67 mutants were killed
  ([its mutation log](m1-slice-1-mutation-log.md)).
- **Not reviewed on its own,** against plan §6. M1's closing review read the four libraries and
  their suites, and killed ten further mutants.
- **CI's run** 45226809762 passed all three jobs. `nothreads` refused each new library by name.

### 2026-11-23 — M1 slice 0: the plan and the records (PR #3)

- **Written** on `m1-plan`, from `0b800ed`, by the caller:
  - the M1 plan;
  - ADR-0002, ADR-0003, ADR-0006, ADR-0007 and ADR-0011 amended, and ADR-0012 new;
  - the constraints, the brief, `traps.md` and AGENTS.md to match;
  - the plan's probes, in [research/m1-plan/](research/m1-plan/README.md).
- **Reviewed:** one Opus review found a blocker, six majors and thirteen minors, each fixed
  ([research/m1-slice-0-review/](research/m1-slice-0-review/README.md)).
  - The blocker: v0.1.1's free-failure path would have wiped freed memory. The owner chose the
    wipe fused with the free (ADR-0008, amended).
  - The owner also chose native's load in one section (ADR-0007, amended), which narrows the
    engine wedge to the load's prologue.
  - ADR-0001 is amended for the allow-lists.
- **Accepted:** every record, by the owner, on 2026-11-23, as each status line says. CI's run
  45160419954 passed on its second attempt: the first's `memory` job hung 31 minutes in
  `apt-get install` and was cancelled.

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
