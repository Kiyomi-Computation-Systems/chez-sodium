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
- **M2 is done and merged** (PRs #10 to #13: #10 and #11 squashed onto `main` on 2026-11-23,
  #12 on 2026-11-24, and #13 after it; [the M2 plan](2026-11-23-m2-plan.md); the close-outs
  below): the plan and the records, #10; the bindings, #11; the verbs, #12; then the closing
  review's fixes, #13.
  - **Three verbs,** `random-bytes`, `blake2b` and `constant-time-bytevector=?`, in
    `(chez-sodium private byte-verbs)` beside native, with the cap, `input-cap`, in
    `(chez-sodium private cap)`. `(chez-sodium)` exports them, and `&sodium-failed`'s three
    names, since `blake2b` raises it for any answer of `crypto_generichash` but 0.
  - **Thirteen entry points** bound, and `crypto_generichash`'s five sizes read once, at the load.
  - **The harness:** `make test` runs 31 suites; the decoy has four switches for the verbs, and
    `test-decoy-source` holds its pointer rule against an honest mistake, and refuses by name
    each form it cannot read; row 24 reaches each verb's blocks through it.
- **M3 is under way** ([the M3 plan](2026-11-24-m3-plan.md)): the password verbs, collect-safe,
  with brief §4.2's rules (brief §9).
  - **Slice 0, the plan and the records,** is on `m3-plan`. The owner accepted every
    recommendation on 2026-11-24.
  - **Next: slice 1,** the bindings, the writers and the pure core; then slice 2, the verbs; then
    M3's closing review.

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

## Answered for M2

M1 left these to M2. [The M2 plan](2026-11-23-m2-plan.md) answers each, and the owner answered
its questions on 2026-11-23:

- **Brief §4.3's ranges** are restated in plan §4.1, item 1, and recorded in ADR-0007's
  amendment.
- **The bindings:** eight, in plan §4.1, item 2. `crypto_generichash_keybytes` is not bound
  (ADR-0005, amended). `unsigned-64` and `size_t` join the allow-lists as ADR-0001's amendment
  says, and the missing-entry rows split, M1's and M2's, at most 14 children a suite.
- **Each verb's rows 15, 16, 18 and 24:** plan §1's table. Row 24 reaches a verb's blocks
  through the decoy, which names them to the interposer (plan §4.1, item 3; ADR-0011, amended).
- **The input cap:** `input-cap`, in `(chez-sodium private cap)`, checked for every operand
  before the section (plan §4.1, item 4; ADR-0007, amended).
- **The refusals' shape:** plan §4.1, item 5's table of rule symbols (ADR-0006, amended).
- **Where the verbs live:** `(chez-sodium private byte-verbs)`, beside native (plan §4.1,
  item 6; ADR-0012, amended).
- **How a verb reads a size:** once, at the load, in a new step 7, held to the library by the
  decoy's `sizes-other` (plan §4.1, item 7; ADR-0001 and ADR-0002, amended).
- **No constants half in `test-constants`:** the oracle prints each size and its macro, and
  `test-native` holds native's to both (plan §4.1, item 8).
- **The decoy's pointer rule** is held by `test-decoy-source` (plan §4.1, item 9). At 1.0.18 and
  1.0.22, `nonnull` covers `randombytes_buf`'s `buf` and `crypto_generichash`'s `out` alone.
- **New:** `crypto_generichash`'s answer other than 0 raises `&sodium-failed`, so its first raise
  and its three names move from M3 to M2 (plan §4.2, item 2; ADR-0006 and ADR-0012, amended).
  - They join `test-never-loads`' condition names, which come from `(chez-sodium)`'s exports, so
    its condition children make a `&sodium-failed` and check the three names, and their expected
    lines gain them; the export row fails by name until they do (M1's closing review, M1-F6;
    plan §2.2).

## Answered for M3

M2 left these to M3. [The M3 plan](2026-11-24-m3-plan.md) answers each, and the owner answered
its questions on 2026-11-24, accepting every recommendation:

- **The bindings:** seventeen, the three password calls and fourteen constants, in plan §4.1,
  item 1. `crypto_pwhash_str` and `_str_verify` are the first `__collect_safe` bindings, and the
  convention table names each binding's convention (ADR-0001 and ADR-0002, amended).
  `_passwd_min` and `_passwd_max` are bound and checked (plan §4.2, item 1).
- **The writers:** native's `call-with-c-string` and `call-with-utf8`, which bound every write
  by the block and answer a string changed mid-write as data, through a CHANGED thunk (plan
  §4.1, item 2; ADR-0007, amended). `password-hash` and `password-verify` then refuse it as
  `changed-during-call`, and `password-needs-rehash?` answers `#t` (plan §4.2, item 6;
  ADR-0006 and ADR-0009, amended).
- **`crypto_pwhash_str`'s `&sodium-failed`:** any answer but 0, its code the answer, and row 17's
  M3 half from the decoy's -1 and 1 (plan §4.1, item 3; §4.2, item 3; ADR-0006, amended).
- **The oracle's hex mode and the FIFO decoy:** plan §4.1, item 4. Row 19's verbs block inside
  their sections, which §5.1 measured: another thread's collection still ends, within 17 ms
  under Valgrind (ADR-0007 and ADR-0011, amended).
- **Rows 11, 15, 16, 18, 22 and 24 for the password verbs:** plan §4.1, items 5 and 8.
- **How M3's constants are read:** once, at the load, in step 7, held to the library by the
  decoy's `pwhash-limits-other` (plan §4.1, item 6; ADR-0001 and ADR-0002, amended).
- **The shape rows for the password verbs:** plan §4.1, item 7, reading `password-verbs.sls`
  alone.
- **Row 24 through the decoy:** plan §4.1, item 8. Every pointer of the three calls is
  `nonnull` at both releases, so the compile holds the pointer rule for each.
- **R16 for the password verbs:** three passwords under each bound refusal, two of one UTF-8
  length, one of them non-ASCII (plan §4.1, item 10).
- **The every-file row:** any new `tests/*.c` joins it (plan §4.1, item 10).
- **New:**
  - **the pure core,** `(chez-sodium private password-text)`, with the UTF-8 count, the
    pre-check and needs-rehash's exact shape check (plan §4.1, item 11; ADR-0009 and ADR-0012,
    amended);
  - **`make-password-limits` checks its ranges when it is called** (plan §4.2, item 2;
    ADR-0009, amended), and is exported alone: ADR-0012's "no constructor" means a condition's
    (plan §4.2, item 5; ADR-0012, amended);
  - **Techo's question,** whether `password-verify` can tell short memory from a wrong
    password. Techo's session asked on 2026-11-24, in its brief
    `.plans/briefs/chez-sodium-verify-out-of-memory.md`. At 1.0.18 libsodium itself makes the
    two one, so the owner chose no change in M3: `#f` covers all three causes, and the documents
    give Techo's fallback (plan §4.2, item 4; ADR-0006, amended). Techo's session was told.

## Owed to M4

- **The documents' notes from M1:**
  - the first reference under an engine (ADR-0007, amended);
  - the first reference on two threads at once (M1-F10);
  - `sodium_init`'s 1;
  - what wiping cannot reach.
- **The documents' notes from M2:** what the cap is; that the compare leaks only the lengths;
  that `random-bytes` aborts the process without an entropy source; that `blake2b` can raise
  `&sodium-failed`.
- **The documents' notes from M3** (plan §3):
  - `password-verify` answers `#f` for a wrong password, an unreadable hash and short memory
    alike, with a caller's fallback: after a `#f`, hash a throwaway string at the same limits.
    It sees only a failure libsodium is told of, under `ulimit` or with no overcommit, since a
    container's memory limit kills the process instead, and it fits only hashes made at the
    caller's current limits;
  - a hash's own limits set what verifying it costs, so hashes come from trusted storage;
  - a container's memory limit can get the process killed;
  - the login pattern: `password-needs-rehash?` only after `password-verify` answers `#t`;
  - a password changed by another thread during the call is refused.
- **The docs rule of `check-floors`** waits for `docs/`.
- **The install-line checks of `test-manifest`** wait for the first release, which writes the
  install lines.

## Close-outs

### 2026-11-24 — M3 slice 0: the plan and the records (PR #14)

- **Measured first,** by two Sonnet agents on disjoint directories, each rerun by the caller, at
  1.0.18 and 1.0.22 on four libraries ([research/m3-plan/](research/m3-plan/README.md)):
  - set A: the declarations, the prototypes, the decoy's pointer rule, the constants, every
    return code, and short memory against a wrong password;
  - set B: the costs, the UTF-8 writer, collect-safe by behaviour inside a critical section, and
    the types `__collect_safe` takes.

  What it found:
  - every pointer of the three password calls is `nonnull`, and `str` is spelled differently at
    each release;
  - a collect-safe call blocked inside `critical-section` lets another thread's collection end,
    within 17 ms under Valgrind;
  - a hash at the minimum costs about 0.4 ms under Valgrind;
  - at 1.0.18 libsodium itself turns short memory into a mismatch.
- **Written** on `m3-plan` by the caller:
  - [the M3 plan](2026-11-24-m3-plan.md);
  - ADR-0001, ADR-0002, ADR-0006, ADR-0007, ADR-0009, ADR-0011 and ADR-0012, amended;
  - the brief, the constraints, AGENTS.md and this ledger, to match.
- **The owner decided, on 2026-11-24,** each with the plan's recommendation:
  - `_passwd_min` and `_passwd_max` bound and checked;
  - `make-password-limits` checking its ranges when called;
  - no change for Techo's question: `password-verify`'s `#f` covers short memory. Techo's
    session was told;
  - the constants read once, at the load;
  - any answer but 0 from `crypto_pwhash_str` raising `&sodium-failed`;
  - `make-password-limits` exported alone;
  - the names.
- **Reviewed:** one Opus review found no blocker, 7 majors and 10 minors, each fixed
  ([research/m3-slice-0-review/](research/m3-slice-0-review/README.md); plan §4.5). The majors:
  - **row 19 passed with a plain binding,** 8 runs of 8, reproduced by the caller. It now waits
    for a marker the decoy leaves once the call is in C;
  - **the loaders row expected the pure library to load libsodium;**
  - **R16 for `length-out-of-range` could not run in process;**
  - **`&sodium-failed`'s code 0 had no row;**
  - **`changed-during-call` made `password-needs-rehash?` raise because of the hash,** against
    ADR-0009, decision 3. It answers `#t` instead;
  - **nothing held "no Scheme copy" outside the writers;**
  - **the twins `opslimit_max` and `passwd_max`** passed every real-library row.
- **CI's run** 45445152423 passed all five jobs.

### 2026-11-24 — M2's closing review and its fixes (PR #13)

- **Reviewed:** M2's closing review, on Opus, read-only, over the plan and both slices, found no
  blocker, 1 major and 6 minors
  ([research/m2-closing-review/](research/m2-closing-review/README.md)).
  - It reran every suite at 1.0.22 and at the floor, `check-test-fails`, `check-dev`,
    `make build`, `check-memory-gate`, the gate over M2's suites, and `make check-guix` on the
    host.
  - It met the verbs through `(chez-sodium)`: under engines abandoned at every fuel; on eight
    threads at once, 2,000 rounds each, every answer right and every count zero; and beside
    another thread's collection, which waited at most 5.4 ms behind 64 KiB compares.
  - It planted 14 mutants in whole copies; 11 were killed, and 3 survived.
- **The major (M2-F1):** slice 1's log and close-out said `sizes-other` kills the oracle's
  equal-valued F twins. Those rows hold native's sizes, and nothing ran the oracle against the
  decoy. Both texts are corrected, and a gated oracle child under `sizes-other` now kills the
  twins.
- **The minors:**
  - `test-decoy-source` refuses a `##`, a line splice outside a directive, and a local include,
    by name (M2-F2);
  - two plan-listed mutants are added to slice 2's log, each killed (M2-F3);
  - ADR-0007 and ADR-0011 gain slice 2's two review fixes, accepted by the owner (M2-F4);
  - three more items owed to M3 (M2-F5);
  - the refusals' messages state their bounds, by the owner's choice (M2-F6);
  - wording (M2-F7).
- **Fixed** on `m2-closing` by one Sonnet fixer, on the code, and the caller, on the records.
  Every mutant is logged ([the closing fixes' log](m2-closing-mutation-log.md)).
- **The fixes' second review,** on Opus, read-only, since they change rules, found no blocker,
  2 majors and 6 minors
  ([research/m2-closing-fix-review/](research/m2-closing-fix-review/README.md)). Each is fixed.
  - **M2C-F1:** M2-F6's fix gave `refuse-secret` a free-text DETAIL, held by a comment alone.
    Mutants that wrote the key's text, or the input's length, into the message passed every
    suite, since R16 reached only the type refusals. The owner chose, on 2026-11-24, bounds as
    numbers: `refuse-secret` takes LOW and HIGH, two exact naturals, and writes the sentence
    itself; anything else there is its own refusal, by kind (which settles M2C-F6). R16 now
    reaches the refusals that state a bound, with secrets of `hunter2` that pass the type
    check, and finds neither their text, their bytes as written, nor their length.
  - **M2C-F2:** `test-decoy-source` joined a directive's continuation with a space, where C
    joins with nothing, and missed a CRLF continuation. A name or a `##` cut inside a `#define`
    passed it. It joins with nothing now, and reads a CRLF continuation.
  - **The minors:** a splice that ends a comment or a string outside a directive is refused,
    read from the raw line (M2C-F3); a `%:` digraph is refused (M2C-F4); `"sodium.h"` in quotes is a local include,
    and the include rule reads every `tests/*.c` (M2C-F5); this close-out's dates (M2C-F7); and
    wording (M2C-F8).
  - **Fixed** by two Sonnet fixers on disjoint files, the scanner and the bound, and the caller
    on the records and R16's bytes needle. The caller rebuilt seven of their mutants by hand,
    and each failed.
- **The third review,** on Opus, read-only, over the second round alone, found no blocker,
  2 majors and 7 minors
  ([research/m2-closing-third-review/](research/m2-closing-third-review/README.md)). No code
  showed a secret. Each is fixed.
  - **M2C3-F1:** R16 searched for three spellings of a secret, and mutants that printed a
    prefix, the excess over the cap, or a byte as the bound passed every suite. R16 now holds
    each bound refusal's print the same for three secrets under one rule: two contents of one
    length, and another length.
  - **M2C3-F2:** `test-decoy-source` stripped comments before it joined lines, the reverse of
    C's order, so a comment that wraps inside a `#define`, a splice inside a comment or a
    string in a directive, a split `%:` or a lone CR hid a name. It now reads line ends,
    splices, comments and literals in C's order, and refuses a lone CR.
  - **The minors:** a literal prefix or a digit separator is refused (M2C3-F3); a `<...>`
    include by an absolute path or `..` (M2C3-F4); every file refusal runs over every
    `tests/*.c` (M2C3-F5); the records (M2C3-F6); the arity rows pass a string secret, and
    call with 7 (M2C3-F7); a row holds WHO before RULE before PARAMETER (M2C3-F8); and R16's
    control reads the whole message, not its words (M2C3-F9).
  - **Fixed** by two Sonnet fixers on disjoint files, and the caller on the records.
- **The review loop stops here, by the owner's choice of 2026-11-24.** The plan has each round
  of rule-changing fixes reviewed again on Opus. Each round cost about 300k tokens, and the
  scanner kept yielding new forms written to deceive it. So there is no fourth review: the
  caller rebuilt all 17 of the third review's mutants by hand, and each failed. The scanner's
  header says what it guards against: an honest mistake in a decoy, not a file written to
  deceive it.

### 2026-11-23 — M2 slice 2: the verbs (PR #12)

- **Written first by the caller:** a stub `byte-verbs` exporting the three names, each present
  and wrong. `test-byte-verbs` failed 110 of its rows against it, by name.
- **Built** on `m2-slice-2` by two Sonnet builders, on disjoint files in one tree:
  - **the verbs:**
    - `cap` and `byte-verbs`;
    - `test-byte-verbs`: rows 1, 13 to 16 and 18, and the shape rows S1 to S5;
    - `verb-probe` and `test-library-loading-verbs`: the decoy's halves of rows 13 to 15 and
      17, `memcmp-other` and `sizes-other`;
    - the known answers' fixture, from the BLAKE2 reference at `ed1974e`;
  - **the public library and the wipe:**
    - `(chez-sodium)`'s six new exports, held by `test-public`;
    - `test-never-loads`' condition children, which check the three `sodium-failed` names
      (M1-F6);
    - the interposer's ordered names, the decoy's weak `watch_set`, and `test-wipe`'s second
      child: row 24 for each verb.

  The weak `watch_set` was measured first: NULL in a plain child, resolved under the
  interposer alone, at both releases. 79 mutants on the verbs are logged, none surviving both
  suites, with the public half's beside them ([its mutation log](m2-slice-2-mutation-log.md)).
- **Reviewed:** one Opus review found no blocker, 2 majors and 10 minors, each fixed
  ([research/m2-slice-2-review/](research/m2-slice-2-review/README.md)).
  - **The majors:**
    - a check moved into a let-bound lambda and called inside the section passed every row.
      Now S3 lists every symbol inside each section, whole, and S2 refuses a `lambda` outside
      it;
    - row 17's watched mutant was the wrong one. Its own, a raise inside the extent with no
      section, is now logged, killed by row 17; the plan's literal one is logged under row 18
      and the shape rows.
  - **Among the minors:** `refuse-secret`'s message names the parameter and the rule; S5 counts
    each verb's `input-cap`, and holds libsodium's greatest size and key length within it; the
    fixture's size and first and last hash are written in the suite.
- **CI's run** 45304409226 passed all five jobs. Under its gate, `test-byte-verbs` took 12 s,
  `test-library-loading-verbs` 49 s and `test-wipe` 11 s, of 450; the slowest suite was
  `test-check-ci`, at 154 s.
- **Merged** after #10 and #11 by squash, bottom up, each after a merge commit that keeps its own
  tree, and each merge's tree equal to the head CI passed (`traps.md`).

### 2026-11-23 — M2 slice 1: the bindings (PR #11)

- **Written first by the caller:** native's eight bindings in step 6, step 7's five size reads,
  and the new exports.
- **Built** on `m2-slice-1` by three Sonnet builders, on disjoint files in one tree:
  - **the load:** `test-native`'s rows for thirteen bindings, the oracle's size lines, and
    `test-native-codes` for row 22;
  - **the conventions:** eight convention rows, the allow-lists with `unsigned-64` and `size_t`,
    and `test-constants`' prototype rows;
  - **the decoy:** its eight entries, four switches and loud overflow; the missing-entry split;
    and `test-decoy-source`.

  Every mutant is logged, each killed but the oracle's equal-valued twins
  ([its mutation log](m2-slice-1-mutation-log.md)). No value at either release tells a size's
  macro from its twin's. This close-out first said `sizes-other` killed the size functions'
  twins too; it held native's sizes, not the oracle's, and M2's closing review found the oracle's
  twins surviving (M2-F1). Its fixes add an oracle child under `sizes-other`.
- **Reviewed:** one Opus review found no blocker, 2 majors and 8 minors, each fixed
  ([research/m2-slice-1-review/](research/m2-slice-1-review/README.md)).
  - **The majors:**
    - two sizes stored under each other's keys passed every suite, since the real sizes are
      equal in pairs. Now `refusal-probe --sizes` holds native's five to the decoy's
      `sizes-other`;
    - the overflow row's C driver ran outside the gate. It now runs, with a child for each
      switch, in gated Chez children (`refusal-probe --drive`).
  - **ADR-0011 amended, accepted by the owner:** `test-constants`' prototype check, a C program
    that calls no libsodium function, has run outside the gate since M1, and is now the
    recorded second exception.
- **CI's run** 45294352684 passed all five jobs. Under its gate, `-decoys` took 79 s and
  `-combined` 75 s, of 450.

### 2026-11-23 — M2 slice 0: the plan and the records (PR #10)

- **Measured first,** by a Sonnet agent, rerun by the caller, at 1.0.18 and 1.0.22: the
  prototypes and their `nonnull`, the sizes, the return codes, the RFC 7693 self-test, the BLAKE2
  reference's known answers, and the costs ([research/m2-plan/](research/m2-plan/README.md)).
  - `nonnull` covers two of the verbs' six pointers, at both releases.
  - Every -1 from `crypto_generichash` leaves `out` as it was.
  - At the cap, the copy into the block costs 36 times the hash.
- **Written** on `m2-plan` by the caller: [the M2 plan](2026-11-23-m2-plan.md); ADR-0001, ADR-0002,
  ADR-0005, ADR-0006, ADR-0007, ADR-0011 and ADR-0012 amended; the brief, the constraints,
  AGENTS.md and this ledger to match.
- **The owner decided, on 2026-11-23,** each with the plan's recommendation:
  - `&sodium-failed` for `crypto_generichash`'s answers other than 0, so its first raise and its
    names move to M2;
  - `crypto_generichash_keybytes` unbound;
  - the verbs in `(chez-sodium private byte-verbs)`, and the cap in `(chez-sodium private cap)`,
    beside native;
  - the sizes read once, at the load, confirmed with the records.
- **Reviewed:** one Opus review found no blocker, 5 majors and 15 minors, each fixed
  ([research/m2-slice-0-review/](research/m2-slice-0-review/README.md); plan §4.5). The majors:
  - a decoy-source rule that refused the decoy's own helper;
  - a row 24 that could pass with a block unnamed or all zero;
  - two mutants no row could kill, since `call-in-section` raises again after the section, so
    the verbs' bodies are read as data instead;
  - one failure code where two are needed;
  - an item owed from M1-F6 dropped from this ledger.
- **CI's run** 45282952407 passed all five jobs.

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
