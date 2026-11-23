# ADR-0011: The harness is chez-sqlite3's: the memory gate, the pinned Guix container, floors in one file, and SRFI-64 vendored

- **Status:** Accepted (the owner, 2026-11-22), approved with the brief.
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
     `free()` interposer ([ADR-0008]).
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
  moves only by a new record ([ADR-0003]).

[ADR-0003]: 0003-libsodium-floor-1-0-18.md
[ADR-0004]: 0004-a-threaded-chez.md
[ADR-0008]: 0008-every-block-wiped-before-free.md
[ADR-0010]: 0010-linux-only.md
