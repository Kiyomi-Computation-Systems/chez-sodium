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
  Amended 2026-11-24 in M3's plan, and accepted by the owner that day
  ([amendment](#amendment-2026-11-24-m3s-plan)).
  Its last points added after M3's slice reviews, its closing review and that review's
  re-review; gating the no-memory children is the owner's choice of 2026-11-24.
  Amended 2026-11-25 in M4's plan, and accepted by the owner that day
  ([amendment](#amendment-2026-11-25-the-docs-and-the-site-m4s-plan)).
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
     (brief §8.2). M3 adds row 22's code rows and the no-memory rows to these (amended,
     below).
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
- **The wipe row has two children now,** the helper's and the verbs', where decision 1 says "the
  wipe row's child" and the M1 amendment "the wipe child". Each runs outside the gate, and sets
  `LD_PRELOAD` to the interposer alone. Added after M2's closing review (M2-F4), accepted by the
  owner that day.

## Amendment, 2026-11-24: M3's plan

Accepted (the owner, 2026-11-24), proposed in [the M3 plan](../2026-11-24-m3-plan.md), §4.1, items
4 and 8.

- **The decoy's seventeen new entries:**
  - each logs its call, every pointer through its `volatile uintptr_t`, and a C string as `p[L]`
    with its `strlen`;
  - each names every block to `watch_set`, with its length;
  - `crypto_pwhash_str` writes `A5` over all of `out` before a fixed hash string.
- **Its new switches:**
  - `pwhash-limits-other`: constants no release has ([ADR-0001], amended). Under it, a gated
    oracle child and `refusal-probe --constants` print the fourteen, which tells twins apart;
  - `pwhash-str-fails` and `pwhash-str-other`: `crypto_pwhash_str` answers -1, or 1;
  - `pwhash-str-unreadable`: it answers 0 and leaves `out` all `A5` ([ADR-0006], amended);
  - `pwhash-str-empty`: it answers 0 with a 0 at `out`'s first byte, an empty string, added after
    slice 2's review;
  - `pwhash-limits-odd`: `pwhash-limits-other`'s values, but memory from 16385 to 1048575 bytes,
    neither a whole KiB, so `test-library-loading-password-limits` holds the memory range's
    rounding, added after M3's closing review;
  - `verify-other`: verify answers 1 for a match;
  - `strprefix-null`: a NULL prefix;
  - `pwhash-blocks`: row 19's FIFO.
- **Row 19, by behaviour.**
  - Under `pwhash-blocks`, `crypto_pwhash_str` and `crypto_pwhash_str_verify` create the marker
    `$CHEZ_SODIUM_DECOY_FIFO.entered`, then open the FIFO, and block until a writer opens it.
    With the variable unset, each answers -1 at once.
  - A gated child, `collect-probe`, references the library once, and forks a thread that calls
    the verb.
  - **It waits for the marker, then 1 s,** as chez-sqlite3's row waits for its opener. Only then
    does it run `collect-rendezvous`, and release the FIFO. Without the wait the rendezvous can
    end before the call is in C, and a plain binding passes: slice 0's review saw it pass 8 runs
    of 8 (M3S0-F1).
  - The child starts the watchdog before it forks, outside the process, so no rendezvous can
    stop it: a shell that polls for the marker, bounded, then waits 1 s and 10 s and releases
    the FIFO, and exits early once the child is gone. The rendezvous must end within 5 s. The
    suite bounds each child with `timeout 180`, outside Valgrind, and each child prints whether
    its watchdog is gone before it exits, which the rows assert (M3S2-F3, M3C-F5). The control's
    row asserts only that the watchdog released it: a collection the child's own allocation
    starts can do the waiting first.
  - Every writer, the collector and the watchdog, opens the FIFO read-write, `: 1<>"$FIFO"`. A
    write-only open blocks until a reader comes, and the decoy reads once, so the second writer
    would block for ever (slice 1's review, M3S1-F4, probed). The child kills the watchdog
    before it exits, and each call has a FIFO and a marker of its own, since a marker outlives
    its call.
  - Its standing control, a test-side plain binding of the decoy's verify called the same way,
    is released by the watchdog.
  - The FIFO's writer and the watchdog are shells, which run no Scheme and no libsodium. They run
    outside the gate.
- **The decoy spells each array parameter as its header does.** `out` is an array at both
  releases. `str` is an array at 1.0.18 and a pointer at 1.0.22. A definition spelled otherwise
  fails `-Werror=array-parameter` (measured).
  - So the two functions that take `str` are each defined twice, whole, under
    `#if SODIUM_LIBRARY_VERSION_MAJOR < 26` and `#else`, and `test-decoy-source` reads both.
  - Its scanner refuses a parameter of one identifier with no type words as unreadable, which a
    parameter macro would otherwise pass as a scalar (M3S0-F8).
- **The C oracle gains a hex mode,** `hash HEX` and `verify STRING HEX`, for row 4, in gated
  children. It also gains the constants' lines.
- **Row 24's password half:** the second wipe child runs each password verb at the decoy's
  limits.
- **The no-memory codes are held by `test-no-memory`, under the gate.** Brief §3.4 states that
  `crypto_pwhash_str` and `_verify` answer -1 when libsodium cannot get the memory, and row 22
  confirms every code it states (M3C-F2).
  - **Every child starts through `gated-command`,** the capped ones inside `sh -c 'ulimit -v
    524288; exec "$@"'`, so the cap sits outside Valgrind. Each asserts its counts and the
    Valgrind line as the gate asked.
  - **Under the cap,** a hash at `'sensitive` raises `&sodium-failed` with code -1, and a real
    `'sensitive` hash's right password verifies `#f`. Outside the cap, it verifies `#t`.
  - **The measurement:** Valgrind 3.27.0 with the gate's options runs Chez inside the cap, with
    0 errors, at 1.0.18 and 1.0.22. Under Valgrind, `'interactive` needs about 256 MiB, so
    512 MiB keeps about 2x headroom (M3C2-F1).
  - **The history.** The owner first chose a third exception to the gate's child rule, on the
    premise that Valgrind cannot run under `ulimit -v`. The closing review's fix had stated
    that premise; no one had measured it. The re-review measured it false. The owner then chose
    on 2026-11-24 to gate every child, and there is no third exception.
- **Rows that hash above the minimum, beside decision 1's pair and default hash:**
  - row 22's code rows, at the few cheap limits each code needs: (3, 8 KiB), (1, 32 KiB),
    (1, 64 KiB), (2, 16 KiB) and (2, 16 KiB + 1 byte);
  - the no-memory rows, the only rows at a high limit, `'sensitive`. The hash and the verify that
    run outside the cap each take about 1 GiB, and about 26 s under the gate; the capped ones
    fail at once.
- **Row 22's tripwire.** `test-native-codes` holds a byte of 0x80 or more in a salt (it uses 0xC3)
  to the answer measured at each release, 0 at 1.0.18 and -1 at 1.0.22, and fails on any other.
  So a new release on any lane needs that answer measured first: `current`'s pin bumped, a
  `channels.scm` bump that moves Guix's libsodium, or a distribution's package (M3C-F3,
  M3C2-F3).

## Amendment, 2026-11-25: the docs and the site (M4's plan)

Accepted (the owner, 2026-11-25), proposed in [the M4 plan](../2026-11-25-m4-plan.md), §4.3 to
§4.7, with [ADR-0013].

- **Decisions 2 and 3's M4 parts, as built from chez-sqlite3's:**
  - the manifest gains `cmark-gfm`, `tar` and `xz`. `guix-env-enter` requires both cmark-gfm
    libraries and exports `CHEZ_CMARK_GFM_LIBS`, the core first, and the self-test checks that it
    names two files Chez loads;
  - chez-cmark-gfm joins `depends/dev`, and `Akku.lock` locks it, chez-sqlite3's entry byte for
    byte. `scripts/fetch-akku-lock` fetches it into `build/akku`, on the host, by `make site-deps`;
  - the generator and its suites import nothing under `src/`, so Ubuntu's Chez, below the floor,
    runs them in CI. `tests/test-site-testing.sps`, which imports the testing library, runs in
    `make test`.
- **The docs' password examples hash at the default,** a named exception to decision 1's limits
  rule. The owner chose this on 2026-11-25, so the examples show the call a reader copies.
  - `test-docs` runs them at `'interactive`, in process for a `scheme run` block, and through
    `gated-command` for a whole program.
  - Measured under the gate (pre-work A, §4.2): about 0.7 s a hash or a verify in process, and
    about 4.9 s for each gated whole program before it does anything.
  - No docs example that runs hashes above the default. A fragment, read but never run, may
    show a preset, as the passwords page's `'moderate` does (M4's closing review, M4C-F14).
- **`check-floors` reads `docs/`:** no line of a page holds either floor's dotted text, so a page
  names a floor by a link to README.org's Requirements. Decision 4's dotted form is the one form
  refused, as everywhere `check-floors` reads.
- **`test-manifest` holds the clone lines,** as "Owed to M4" asked: every `git clone` line of
  README.org and `docs/` clones the repository at `--branch vX.Y.Z`, the manifest's version, or
  with no branch at 0.0.0. It is held on fixture trees first.
- **CI gains a sixth job, `site`, and a second workflow, `pages.yml`.** `check-ci` holds both:
  - `ci.yml`'s shape, `site` with `timeout-minutes: 10`, and the image step in every job, `site`
    included, so the rule keeps no exception;
  - `pages.yml` line for line against `check-ci.sh`'s copy, but for comments and blank lines
    outside a run block;
  - `SITE_REF` and `CHEZ_CMARK_GFM_LIBS` among the banned words;
  - `packaging/debian-site-prereqs.txt` as the site's one package list, read by both workflows.
- **`test-check-ci`'s time is read after the port.** It splits if it passes a third of
  `MEMORY_TIMEOUT`.

[ADR-0001]: 0001-bind-libsodium-directly.md
[ADR-0003]: 0003-libsodium-floor-1-0-18.md
[ADR-0004]: 0004-a-threaded-chez.md
[ADR-0006]: 0006-errors-and-no-secret-shown.md
[ADR-0008]: 0008-every-block-wiped-before-free.md
[ADR-0010]: 0010-linux-only.md
[ADR-0013]: 0013-the-first-release.md
