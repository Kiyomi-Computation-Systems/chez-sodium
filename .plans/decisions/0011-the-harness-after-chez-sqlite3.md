# ADR-0011: The harness is chez-sqlite3's: the memory gate, the pinned Guix container, floors in one file, and SRFI-64 vendored

- **Status:** Accepted (the owner, 2026-11-22), approved with the brief. Amended 2026-11-23 in
  M1's plan, and accepted by the owner that day ([amendment](#amendment-2026-11-23-m1s-plan)).
  Its "Changing a floor" consequence points at [ADR-0003]'s amendment, "raising the floor",
  since 2026-11-23, after M1's closing review.
  Amended 2026-11-23 in M2's plan, and accepted by the owner that day, after M2 slice 0's
  review ([amendment](#amendment-2026-11-23-m2s-plan)). Amended 2026-11-23 after M2 slice 1's
  review, and accepted by the owner that day
  ([amendment](#amendment-2026-11-23-a-c-program-that-calls-no-libsodium-function)); its last
  point added after M2's closing review, and accepted by the owner that day.
- **Date:** 2026-11-22
- **Scope:** development tooling, the suites and CI; no library change
- **Settles:** [brief](../2026-11-22-chez-sodium-project-brief.md) §7, §8.2, §9's M0, and
  §11.5's supported versions for CI's lanes; [the M0 plan](../2026-11-22-m0-plan.md) §2
- **Related:** chez-sqlite3 ADR-0005, chez-sqlite3 ADR-0006, chez-sqlite3 ADR-0007 and
  chez-sqlite3 ADR-0008, which this adopts · [ADR-0003] (the versions CI runs) · [ADR-0004]
  (the Chez floor) · [ADR-0008] (the wipe row) · [ADR-0010] (Linux only)

## Context

- **chez-sqlite3's harness is built and paid for.** At v0.1.1 (`960d9f0`) its files and
  records carry every fix made since its own M0 (the M0 plan).
- **libsodium is stateless** (brief §2). There is no connection or statement to count.
- **libsodium runs clean under Valgrind** at every limit, with no suppression (P-F15).
- **Under Valgrind, a hash at libsodium's minimum limits took about 5 ms once warm, and an
  interactive one about 0.8 s** (brief §8.2).
- **The pinned channel `b532aa7` has libsodium 1.0.22** (the review).

## Decision

This adopts chez-sqlite3 ADR-0005 (the memory gate), chez-sqlite3 ADR-0006 (the container),
chez-sqlite3 ADR-0007 (SRFI-64 and the suite rules) and chez-sqlite3 ADR-0008 (the floors'
one source), as they stand at v0.1.1. Their names change with the project: `chez-sqlite3`
becomes `chez-sodium`, `CHEZ_SQLITE3_*` becomes `CHEZ_SODIUM_*`, and `sqlite` becomes `sodium`
where the text means the library. Only what differs is written here.

1. **The memory gate** (chez-sqlite3 ADR-0005):
   - **It has two parts, Valgrind and our counters.** The counters count one kind, `block`.
     The connection and statement kinds, and SQLite's two checks, are dropped (brief §7.2).
   - **One memory job, with no shards:** no `MEMORY_SHARD`, `MEMORY_SUITES_1` or `_2`, no
     `check-memory-shards`, and one memory job in `check-ci` (brief §7.2; P-F15).
   - **The plants are the two that use `foreign-alloc` alone,** the leak and the overrun. The
     SQLite plants are dropped.
   - **Valgrind's `default.supp` only,** since libsodium ran clean with no suppression (P-F15).
   - **The gate's child variable is `CHEZ_SODIUM_GATE_CHILD`.**
   - **Children run under the gate only through `gated-command`.** It runs each child under a
     Valgrind of its own, and the gate reads that child's log. A child started any other way
     runs outside Valgrind, unseen. So every suite that starts a child that reaches native code
     starts it through `gated-command`.
   - **The C oracle is a program named `libsodium-oracle`.** The gate's rule for child logs
     names it.
   - **Password rows hash at libsodium's minimum limits,** read from `_opslimit_min` and
     `_memlimit_min`, so the one job stays fast. The exceptions are one cheap pair that is
     neither the minimum nor a preset, `(make-password-limits 2 16)`, and one hash at the
     default. No row needs a high limit: the collect-safe row blocks a decoy on a FIFO
     (brief §8.2).
   - **The wipe row's child runs outside Valgrind,** whose allocator bypasses the row's
     `free()` interposer ([ADR-0008]). Its `LD_PRELOAD` is set to the interposer alone, never
     appended: under the gate, a suite's own `LD_PRELOAD` holds Valgrind's preloads.
   - **No exit checks.** `counters` keeps no `register-exit-check!` or `exit-checks`, and the
     testing library runs none. libsodium keeps no count of its own, so the block count is a
     suite's one check at its end. chez-sqlite3 ADR-0005 registers SQLite's memory check.
   - **A decoy reads each pointer it logs through a `volatile uintptr_t`,** and tests only that
     (brief §7.2; P-F7).
2. **The container** (chez-sqlite3 ADR-0006):
   - **The pin stays `b532aa7`,** if M0's measurement of it passes (the M0 plan §5).
   - **The manifest holds `libsodium` for `sqlite`,** and leaves out `cmark-gfm`, `tar` and
     `xz` until the docs site comes, in M4.
   - **`guix-env-enter` requires `lib/libsodium.so.26`,** and exports `CHEZ_SODIUM_LIBRARY` as
     its absolute path. It exports no `CHEZ_CMARK_GFM_LIBS` until the site.
3. **SRFI-64** (chez-sqlite3 ADR-0007):
   - **`vendor/chez-srfi` is at the commit chez-sqlite3 pins,** `7879b52`.
   - **`Akku.manifest` is `("chez-sodium" "0.0.0")`,** with chez-srfi alone in `depends/dev`
     and no `scripts` clause, since nothing is built. `Akku.lock` locks chez-srfi alone.
     chez-cmark-gfm joins for the docs site alone, in M4.
   - **The testing library is `tests/chez-sodium-testing.sls`.** Its counters check reads
     blocks only. It imports `private counters`, so `counters` is in `src/` from M0
     (brief §7.2).
4. **The floors** (chez-sqlite3 ADR-0008):
   - **`packaging/floors.sexp` is `((chez "10.4.0") (sodium "1.0.18"))`** ([ADR-0003],
     [ADR-0004]).
   - **A floor is written in its dotted form, `x.y.z`, alone.** SQLite's version-number and
     amalgamation-number forms have no libsodium counterpart, and `check-floors` drops them.
     The dotted form stays refused wherever `check-floors` reads (brief §7.2; the M0 plan §2).
5. **CI** (chez-sqlite3 ADR-0005, as amended), Linux only ([ADR-0010]):
   - **M0's shape is three jobs:** `main`, without `make build` and `check-dev`; `memory`; and
     `nothreads`. `check-ci` holds that shape (brief §9; P-F1). M1 adds `floor` and `current`
     ([ADR-0003]).
   - **Actions stay pinned to the SHAs chez-sqlite3 uses.** The package list takes
     `libsodium-dev` for `libsqlite3-dev`, and drops `openssl`, which only SQLite's digests
     need.
   - **`scripts/ci/report-sodium.sh` reports the runner's libsodium and checks nothing.** From
     M1, `main` asserts the floor through discovery.

### Rejected

- **Shards,** which chez-sqlite3's memory gate has. One job suffices (P-F15).

## Consequences

- **M0's suite is the harness's own:** the testing library's, the counters', `require-threaded`'s,
  those of `check-floors`, `check-nothreads` and `check-ci`, and `test-manifest`. `make test`
  refuses an empty glob, so they are the suite that is not empty, with no verb in it (P-F1;
  the M0 plan §1).
- **A fresh clone runs `git submodule update --init --recursive` on the host** before its first
  `make deps`. The container has no git and no network but loopback.
- **Changing a floor** edits the file, README.org's Requirements, the code's check and the
  literal rows that name the old floor. Each place left behind fails by name. A libsodium floor
  moves only by a new record, and [ADR-0003]'s amendment "raising the floor" lists every place it
  moves and what the raise's record must decide.

## Amendment, 2026-11-23: M1's plan

Accepted (the owner, 2026-11-23), proposed in [the M1 plan](../2026-11-22-m1-plan.md), §4.1,
items 4 and 6, and §4.2, item 8.

- **No exit checks.** The M0 plan kept them for M1 to decide. Nothing registers one: libsodium
  has no counterpart to `sqlite3_memory_used`, and M2 and M3 add none. M1 removes them.
- **The decoy's pointer rule is recorded here.** Brief §7.2 and AGENTS.md carried it, and no
  record did. `-Werror=nonnull-compare` fires only on a function `sodium.h` marks `nonnull`:
  `randombytes_buf` does, `sodium_memzero` does not (measured on GCC 16.2,
  [research/m1-plan/](../research/m1-plan/README.md)). None of M1's entry points can show the
  trap, so the rule is applied, not discovered.
- **The wipe child's `LD_PRELOAD` is set alone** (measured: a parent under Valgrind holds
  `vgpreload_core` and `vgpreload_memcheck` in its own).

## Amendment, 2026-11-23: M2's plan

Accepted (the owner, 2026-11-23), proposed in [the M2 plan](../2026-11-23-m2-plan.md), §4.1, items 3
and 9.

- **Row 24's verb half runs against the decoy.** The interposer cannot wrap the real
  `crypto_generichash`: Chez binds each name from the most recently loaded object, which is
  libsodium, even with the interposer preloaded (probed in M2 slice 0's review). So each of the
  decoy's M2 entries names every pointer it is handed to the interposer, with the length it is
  handed, through a weak `watch_set`. It resolves in the wipe child, whose `LD_PRELOAD` is the
  interposer alone; everywhere else it is NULL, and the decoy skips it.
  - The interposer keeps every name in order, with its length, and a second child of
    `test-wipe`, its library the decoy, asserts each verb call's whole list of (length verdict)
    pairs, so a block left unnamed makes the list shorter.
  - Every witnessed block holds a non-zero byte before its wipe: the decoy writes `A5` over every
    output, under every switch, and the child's inputs each hold a non-zero byte.
  - A block named with length 0 reads 1 whatever happens; `random-bytes 0` makes no block.
  - Its standing control: each M2 entry, called through native's raw binding on blocks the child
    frees unwiped, reads 2 for each.
- **The decoy's pointer rule is held by `test-decoy-source`,** which reads every `tests/*.c` that
  includes `sodium.h`, comments and strings stripped. In each definition of a function `sodium.h`
  declares, each pointer parameter, written with a `*` or as an array, occurs once, as the value
  of a `volatile uintptr_t`. The decoy's own helpers are outside it. A `-Werror` compile holds the
  rule only for a `nonnull` parameter, and at 1.0.18 and 1.0.22 that is `randombytes_buf`'s `buf`
  and `crypto_generichash`'s `out` alone, of M2's six pointers (measured).
- **The decoy's call log is loud when full:** its last entry is `overflow`, and it takes no more,
  so a row that reads "no C was called" from the log's growth cannot pass on a full log.

## Amendment, 2026-11-23: a C program that calls no libsodium function

Accepted (the owner, 2026-11-23), from M2 slice 1's review, M2S1-F2.

- **`test-constants`' prototype check runs a C program outside the gate.** It takes the address
  of each bound function and prints the `_Generic` verdicts, which are fixed at compile time. It
  links libsodium and calls no libsodium function. It has run so since M1's slice 2, and no
  record named it.
- **It stays outside, the second exception after the wipe row's children.** The gate takes a
  child's log only from Chez or `libsodium-oracle`, and a program that calls nothing of
  libsodium's gives Valgrind nothing of ours to read.
- **Any other C program a suite runs starts through `gated-command`, or is named here.** The
  decoy's overflow row, which a C driver first ran, now runs in a gated Chez child.
- **The wipe row has two children now,** the helper's and the verbs', where decision 1 and the
  M1 amendment say "the wipe row's child". Each runs outside the gate, and sets `LD_PRELOAD` to
  the interposer alone. Added after M2's closing review (M2-F4), accepted by the owner that
  day.

[ADR-0003]: 0003-libsodium-floor-1-0-18.md
[ADR-0004]: 0004-a-threaded-chez.md
[ADR-0008]: 0008-every-block-wiped-before-free.md
[ADR-0010]: 0010-linux-only.md
