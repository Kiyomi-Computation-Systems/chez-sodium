# M2's closing review

Read-only and adversarial, over the M2 plan and both slices: `git diff 4243017..m2-slice-2`
(`34e3ad7`), the three stacked PRs #10, #11 and #12. Every probe ran in a copy,
`build/m2-close/tree/` (with `build/slice5` copied in for the floor), and each mutant in a whole
copy of its own, `build/m2-close/mut/NAME/`, through that copy's own `scripts/guix-env`, after
`make deps` in it. Nothing in the checkout was changed. No network fetch was made; `gh` was used
read-only (`gh pr list`, `gh pr checks`, `gh run view`).

The container: Chez 10.4.0 threaded, GCC 16.2, Valgrind 3.27, libsodium 1.0.22 (the profile's);
the floor, 1.0.18, from `build/slice5/prefix-1.0.18`, its headers first in `C_INCLUDE_PATH`.

**Counts: 0 blockers, 1 major, 6 minors.**

- **M2-F1 (major):** the slice 1 log and `progress.md` say the oracle's equal-valued F twins are
  killed by the decoy's `sizes-other` rows. No row runs the oracle against the decoy, and the
  mutant passes every suite that runs the oracle.

---

## Findings

### M2-F1 (major): the oracle's F twins are recorded as killed, and they survive

- **Where:**
  - `.plans/m2-slice-1-mutation-log.md:76-82`, "Corrected after slice 1's review (M2S1-F5)": "The
    F twins are killed instead by the decoy's `sizes-other` rows, where the five answers differ
    (the decoy builder's "Review fixes", below)".
  - `.plans/progress.md:128-130`, slice 1's close-out: "each killed but the oracle's equal-valued
    twins: `sizes-other` kills the size functions' twins, and no value can tell the macros'
    apart".
  - The code: `tests/libsodium-oracle.c:103-107` (the five `FIND`s); `tests/test-native.sps:413-420`
    (native's size against the oracle's F and M).
- **What is wrong:**
  - The "Review fixes" the log points to are M2S1-F1's `refusal-probe --sizes` rows in `-decoys`.
    They hold *native's* five sizes to the decoy, so they kill native's twins (the review's
    `answers-twin`).
  - The oracle's F twins are a different mutant, M2S1-F5's: the C oracle reading a size through
    the wrong function. The oracle runs only against the real library, in `test-native`, `-real`
    and `-discovery`, where each size equals its twin. Nothing runs it under `sizes-other`.
  - So the log and the ledger say a mutant was killed that no row can kill. M2S1-F5 suggested the
    fix that would kill it ("run the oracle once against the decoy under `sizes-other`"). It was
    not done, but it was recorded as done.
- **Probe (mutant `oracle-f-twins`):** two replacements in `tests/libsodium-oracle.c`:

  ```
  FIND(bytes, crypto_generichash_bytes)            -> FIND(bytes, crypto_generichash_keybytes)
  FIND(keybytes_min, crypto_generichash_keybytes_min) -> FIND(keybytes_min, crypto_generichash_bytes_min)
  ```

  ```
  == tests/test-native.sps                    exit=0  # of expected passes 77
  == tests/test-library-loading-decoys.sps    exit=0  # of expected passes 20
  == tests/test-library-loading-combined.sps  exit=0  # of expected passes 18
  == tests/test-blocks.sps                    exit=0  # of expected passes 19
  == tests/test-library-loading-real.sps      exit=0  # of expected passes 23
  == tests/test-library-loading-discovery.sps exit=0  # of expected passes 21
  ```

- **What it costs:** little in the code. Native's binding names are held by E3, and an
  unbound `_keybytes` would be `missing-api` against the decoy. But the instrument's lines are
  not held to their functions, and the record says they are. That is the M2S2-F2 pattern: a
  mutant logged as watched failing when it never was. M3 adds oracle lines for its constants,
  and some of those also have equal-valued twins (several `_min` answers are small and equal).
- **Fix (either):**
  - Correct both texts: "the oracle holds the numbers, not which function or macro gave them.
    Its F and M twins survive by value at both releases; `sizes-other` kills native's twins,
    through `--sizes`."
  - Or kill the F twins: one gated `libsodium-oracle` child against the decoy under
    `sizes-other`, asserting its five lines whole, `(generichash-bytes 33 32)` … `(generichash-
    keybytes-max 81 64)`. The gate already takes an oracle child's log. `-verbs` has 6 children,
    so there is room.

### M2-F2 (minor): `test-decoy-source` misses a parameter name the preprocessor builds

- **Where:** `tests/test-decoy-source.sps:159-174` (`code-text`), `:178-188` (`tokens`), and
  `:43-46`, the header's list of what it does not read.
- **What:** the scanner matches whole identifiers in the text. A name that only the
  preprocessor makes is never seen:
  - a pasted name, `#define DECOY_PARAM(n) b##n`, then `DECOY_PARAM(1)`. The replacement list's
    words are `b` and `n`, so the macro rule sees no parameter;
  - a line splice inside an identifier, `b\` followed by a newline and `1`. `code-text` joins
    continuations only on directive lines.

  Either one lets a plain test of a pointer through. `sodium_memcmp`'s `b1` is not `nonnull`, so
  the compile accepts it too. The header lists "a function whose name a macro builds" as unread,
  but not a parameter's name.
- **Probes**, on the real decoy, in `sodium_memcmp`'s `called(...)` line, `p1 ? "p"` replaced:
  - `decoy-paste`: `DECOY_PARAM(1) ? "p" : "NULL"`, with `#define DECOY_PARAM(n) b##n` after
    `DECOY_OVERFLOW`;
  - `decoy-splice`: `b\` + newline + `1 ? "p" : "NULL"`.

  ```
  decoy-paste:  test-decoy-source exit=0, 37 passes; test-library-loading-decoys exit=0, 20 (every build compiled)
  decoy-splice: test-decoy-source exit=0, 37 passes; test-library-loading-decoys exit=0, 20
  ```

- **Why only minor:** both are deliberate. No one writes either by accident, and the whole-list
  row still holds which functions are read.
- **Fix:** refuse, by name, any `##` in a scanned file's directives, and any backslash-newline
  outside one: `(FILE unreadable paste)` and `(FILE unreadable splice)`, each with a plant.
  Then name both in the header's "What it does not read". The same goes for an `#include` of a
  local file, which could bring in a definition the glob never reads; refuse any include but a
  system header and `sodium.h`.

### M2-F3 (minor): two mutants plan §6 lists for slice 2 are not in its log

- **Where:** plan §6, slice 2, "Watched to fail" (`.plans/2026-11-23-m2-plan.md:532`, row 14's
  "the shorter length compared"; `:549`, the exports' "an extra … name"), against
  `.plans/m2-slice-2-mutation-log.md`. Its R14 table has `bytevector=?`, length−1, at most one
  byte and "1 read as equal". The public half logs a missing name, a wrapper, `verb-names` and
  the condition children.
- **Probes:** both are killed. Neither is a survivor; the gap is in the log.
  - `ct-shorter-length`: the length test made `#f`, and `sodium_memcmp` given
    `(min (bytevector-length a) (bytevector-length b))`.

    ```
    test-byte-verbs exit=1: R14 a is a prefix of b; b is a prefix of a; a is empty, b is not;
      b is empty, a is not; lengths 1 and 65536; R18 operands of other lengths; S3
    test-library-loading-verbs exit=1: "verbs on control: …"; "verbs on control under "memcmp-other": …"
    ```

  - `extra-export`: `input-cap` exported from `(chez-sodium)`, imported from cap.

    ```
    test-public exit=1: FAIL (chez-sodium) exports exactly the version, the three byte verbs and the condition predicates and accessors, and nothing private
    test-never-loads exit=1: FAIL the condition exports of (chez-sodium), its exports less the verbs, are exactly the names the condition children check
    ```

- **Fix:** add both rows to the log, with these results.

### M2-F4 (minor): two slice 2 review fixes stopped short of the records

- **Where:**
  - `.plans/global-constraints.md:142-144` and `:149-152`, which cite "[ADR-0007], amended";
  - `.plans/decisions/0007-one-critical-section-per-verb.md:58` (decision 8) and `:148-172` (the
    M2 amendment);
  - `.plans/decisions/0011-the-harness-after-chez-sqlite3.md:57` and `:163`.
- **What:**
  - **The paths with no section.** M2S2-F9 asked for "a path that makes no block and calls no C
    holds no section: `sodium-version`, `random-bytes 0`, and the compare of different lengths"
    in ADR-0007's amendment, the constraints and AGENTS.md. The constraints (:150-152) and
    AGENTS.md (:199-201) have it and cite ADR-0007, amended. The record does not: decision 8
    names `sodium-version` alone, and the amendment says only that those two paths "call no C".
    The constraints' header says the record wins where the two disagree.
  - **The key's and the output's cap.** M2S2-F11 asked to say in ADR-0007's amendment that the
    key and the output block are capped only through libsodium's `_keybytes_max` and
    `_bytes_max`. That went into plan §4.1, item 5 (:198-200) and row S5. The constraint
    (:142-144) still says the cap is "checked for every operand, whatever the verb does next".
    `blake2b`'s key is never compared with `input-cap` (`byte-verbs.sls:104-107`).
  - **ADR-0011** says "the wipe row's child" at :57 and, in slice 1's amendment, "the second
    exception after the wipe row's child" at :163. `test-wipe` has two children. The constraints
    (:233) say "the wipe row's children". M2S2-F9 asked for "children" in the wipe texts.
- **Fix:** add one ADR-0007 amendment line for each of the first two, and "children" in
  ADR-0011's slice-1 amendment. Each is the owner's to accept.

### M2-F5 (minor): `progress.md` carries some of what M2 leaves for M3, but not all

- **Where:** `.plans/progress.md:85-98` ("Owed to M3"); plan §3 (`:100-107`).
- **Not carried:**
  - **How M3's constants are read.** ADR-0001's M2 amendment (:121-122): "Only
    `crypto_generichash`'s five sizes are read at the load … M3's constants decide their own
    reading." So M3's plan owes a decision: the opslimit and memlimit bounds, `_strbytes` and
    `_strprefix`, read at the load in a step 8 or at each call. Neither the ledger nor plan §3
    names it.
  - **The shape rows for the password verbs.** Plan §4.1, item 10 and M2S2-F1's lesson: one
    `call-in-section` per verb, every check before it, the section's symbols listed whole, and
    the import clauses whole. `test-byte-verbs`' S1 to S4 read `byte-verbs.sls` alone, so M3's
    library needs its own.
  - **Row 24 for the password verbs.** It goes through the decoy, so M3's decoy entries name
    their blocks through `watch_set`. The `test-decoy-source` real-files list and `every-entry`
    gain the new entries. "Rows … 24 for the password verbs" says the row, not the mechanism.
  - ADR-0007 and ADR-0012 already record the rest: M3's verbs import `input-cap`, sit beside
    native, and reuse `over-the-cap` and `not-a-natural`.
- **"Owed to M4" is complete for M2:** the cap, the lengths the compare leaks, the abort with
  no entropy, and `&sodium-failed` from `blake2b`.
- **Fix:** three bullets under "Owed to M3".

### M2-F6 (minor): the size and cap refusals name no bound

- **Where:** `src/chez-sodium/private/byte-verbs.sls:62`, `:98` (and `refuse-secret`'s
  `key-length-out-of-range` message, `conditions.sls:98-101`).
- **Probe** (`build/probes/user.sps`, through `(chez-sodium)` at 1.0.22):

  ```
  blake2b size 65  => "Exception in blake2b: size is out of range with irritants (size-out-of-range size 65)"
  blake2b key short => "Exception in blake2b: key is refused: key-length-out-of-range, shown by its kind alone with irritants (key-length-out-of-range key (kind bytevector))"
  random-bytes 2^70 => "Exception in random-bytes: n is over the cap with irritants (over-the-cap n 1180591620717411303424)"
  ```

- **What:** a user learns that the size is out of range, but not what the range is.
  - The bounds are libsodium's numbers, read at the load. They are not secrets, so the message
    could say "size is from 16 to 64", "a key is 16 to 64 bytes" and "the cap is 65536".
  - The key's message would still show nothing of the key.
  - No row reads messages, so nothing changes in the suites.
- **Fix:** give the bounds in the messages, or owe them to M4's documents. The messages are
  this plan's; `refuse-secret`'s is M1's helper, the owner's call (M2S2-F10).

### M2-F7 (minor): wording

- `tests/test-byte-verbs.sps:42`: a header line of 105 columns ("…Every engine row follows a
  reference to each library at"), left over from M2S2-F8's rewrap.
- `tests/test-byte-verbs.sps:441`: "R15 random-bytes the greatest fixnum is refused, over-the-cap,
  before any block". The row can show the refusal, not "before any block": it runs in process,
  with no decoy log. L's 65537 row shows that. Drop "before any block" from the name, or say
  "by the cap check".
- `tests/decoy-libsodium.c:52-53` and `:362-366`: the comments say -1 "with exactly one NULL
  operand". The code (`:380`, `if (!p1 || !p2) return -1;`) answers -1 for either or both.
- Plan §2.2 (`:89`) says `test-library-loading-verbs` runs "one child per switch". The control
  has two, its answers and its refusals: six children, five switches.

---

## 1. Is M2 done (plan §7 and §1)?

**Not yet, as plan §7 expects at this point:**

- the three PRs are open and stacked, not merged;
- `progress.md` lacks slice 2's close-out and this review's (drafted below);
- AGENTS.md's "Where the project stands" says M2 "is under way" (drafted below);
- this review's fixes are owed.

**Done:**

- In the copy, `make test` passed 31 of 31 at 1.0.22 and at the floor, and so did
  `check-test-fails` (13 of 13), `check-dev`, `make build`, `check-memory-gate` and the gate on
  M2's suites (§7 below). On the host, `make check-guix` passed too.
- CI is green on #10, #11 and #12, all five jobs each (§7).
- The ADR status lines say every §4.3 record is accepted. The constraints carry each rule, but
  for M2-F4.

### Each row of §1's table, with the suite and row that hold it

| Row | Held by | Can it fail? |
|---|---|---|
| 1 | `test-byte-verbs`: R1's RFC 7693 self-test, the 256 known answers, the fixture's size and first and last hash, the four `hashlib` hashes, the three keyed hashes, and the default size | Yes. The log kills a dropped key, the size ignored, BLAKE2b-512 cut, a key length taken from the size, and each self-test edit |
| 13 | `test-byte-verbs` R13 (lengths 1, 32 and 65536; `#vu8()`; 8×64 positions; two calls differ) and R15 (65536 and 65537). `-verbs`' control row: `random-bytes 0` grows the log by `""`, and `random-bytes 5` is `randombytes_buf(p,5) sodium_memzero(p,5)` | Yes. The log has n−1, the same bytes, 0 reaching C and both caps. I killed `rb-copy-before-fill` (R13 ×4, S3, and L ×3) |
| 14 | `test-byte-verbs` R14 (14 pairs). `-verbs`' control (`sodium_memcmp(p,p,N)` for the whole length, `""` for other lengths) and `memcmp-other` | Yes. The log, plus `ct-shorter-length` (M2-F3) |
| 15 | `test-byte-verbs` R15 (every refusal whole, both ends of each bound, the order) and S1 to S3 (the body as data). `-verbs`' control refusals, each with growth `""` | Yes. The log has each check removed and each order swapped |
| 16 | `test-byte-verbs` R15's `(kind K)` rows and R16's search of the whole text. `test-conditions`' `refuse-secret` rows, bytevectors among them | Yes. The log has `shown-value` on each of the four secrets |
| 17 | `-verbs` under `generichash-fails` and `generichash-other`: `(failed blake2b "crypto_generichash" -1)`, and 1 | Yes. P2 (a raise inside the extent) is logged killed |
| 18 | `test-byte-verbs` R18, seven sweeps | Yes. The log has no section per verb. I killed `rb-`, `b2-` and `ct-section-inner` (a section that holds only the C call) and `native-section-not-critical` (R18 ×5, `re-entered after its block was freed` at fuel 1) |
| 22 | `test-native-codes` (13 rows) and `test-native`'s size rows (oracle F, oracle M, and brief §3.4's numbers), on every lane | Yes, for the codes (30 planted expectations in the slice 1 log). The oracle's F lines are not held to their functions (M2-F1) |
| 23 | `make test-memory`, CI's `memory` job: 29 of 29 on #11, 31 of 31 on #12 | Yes. `check-memory-gate` sees its plants fail, and runs first in CI |
| 24 | `test-wipe`, "row 24 for the verbs …", and M1's first child | Yes. The log has the wipe made a no-op, an unnamed block and the controls. I killed `wipe-skips-3` (only the verb row fails: `(blake2b-keyed ran ((32 1) (3 2) (16 1)))`) and `interposer-says-1` (both rows) |

### Each "Owed to M2" item on `main` (`4243017:.plans/progress.md`)

| Item | Answered by |
|---|---|
| Brief §4.3's ranges, in no record | ADR-0007's M2 amendment. Code: `byte-verbs.sls`. Rows R13 to R15 |
| The bindings, their rows, the allow-lists, the missing-entry split | native step 6; `foreign-conventions.sls`; `test-constants`; `test-native-codes`; `-missing-verbs`; ADR-0001 and ADR-0002, amended. The split is two suites, not main's "four ways as in v0.1.1", and plan §2.2 says why |
| Rows 15, 16, 18 and 24 for each verb | §1's table above; row 24 through the decoy (ADR-0011, amended) |
| The input cap and its check | `cap.sls`; each verb's checks; S5 |
| The refusals' shape; `verb-names` | Plan §4.1, item 5, and ADR-0006, amended; `test-never-loads`' `verb-names` |
| Where the verbs live | `byte-verbs`; S4; the loaders row; ADR-0012, amended |
| How a verb reads a size | Step 7; `sizes-other`; ADR-0001 and ADR-0002, amended |
| Whether `test-constants` gains a constants half | No. The oracle's sizes go into `test-native` (with M2-F1's caveat) |
| A check of the decoy's `volatile uintptr_t` rule | `test-decoy-source` (with M2-F2's blind spot) |
| Main's "Owed to M3" item, `&sodium-failed`'s export and M1-F6 | Moved to M2: `(chez-sodium)`, `test-public`, and `test-never-loads`' condition children |

### What M2 owes onward

- **M4:** the documents' notes are carried.
- **M3:** carried, but for M2-F5's three items.
- **M5:** Tier 2's revisit of the cap is in plan §3, and stays in the brief.

## 2. The verbs end to end

Probe `build/probes/user.sps`, through `(chez-sodium)` at 1.0.22:

```
random-bytes 0 => (answered #vu8())       ; eq? to #vu8(): #t
blake2b abc => bddd813c…d52319 (32 bytes); blake2b abc 16 => cf4ab791…287816
blake2b "hello" => blake2b "input is refused: not-a-bytevector, shown by its kind alone" (not-a-bytevector input (kind string))
blake2b key #f => (not-a-bytevector key (kind boolean)); empty key => (empty-key key (kind bytevector))
blake2b four args => #f "incorrect number of arguments ~s to ~s" (4 #<procedure blake2b …>)   ; no argument shown
compare three args => (3 #<procedure constant-time-bytevector=? …>)                        ; no argument shown
random-bytes -0.0 / +nan.0 => (not-a-natural n -0.0) / (not-a-natural n +nan.0)
blake2b size (string->list "hunter2") => (not-a-natural size (#\h #\u …))   ; shown-value on a size, as brief §5 decides
sodium-failed? / chez-sodium-error? on a refusal => #f #f                     ; an assertion violation, per ADR-0006
```

- **Answers, refusals, who and irritants:** each matches plan §4.1, item 5's table. A key passed
  in the size's place by mistake is a bytevector, shown `(kind bytevector)`: `shown-value` shows
  only atoms and lists of them, so the realistic positional mistake leaks nothing.
- **What a secret could leak:**
  - Every secret refusal goes through `refuse-secret`, and S2's counts hold that.
    `test-conditions` holds its text free of the secret for every kind, a bytevector included.
  - The arity conditions show the count and the procedure.
  - No Scheme copy is made: the input, key and operands go to `call-with-bytes` in place. Every
    block is wiped at its free (row 24, and `wipe-skips-3` shows the verb half sees one block
    missed).
- **Engines** (`build/probes/engines.sps`):
  - **Each verb abandoned at its first expiry, never resumed, at every fuel until it completes:**
    `random-bytes` 32 and 65536, `blake2b` of "abc" and keyed over 64 KiB, the compare of two
    64 KiB operands and of different lengths. Every count stayed `((block . 0))`, and nothing
    raised (`abandoned-bad ()`).
  - **One expiry's continuation resumed twice:** at fuels 1 to 5, `blake2b` answered right both
    times, with counts zero.
  - **The records' "an engine spends no ticks inside a section" holds**
    (`build/probes/ticks.sps`):
    - an engine of 100 ticks whose job busy-loops 100,000 times inside `critical-section`
      completes with 98 left;
    - `random-bytes 65536`, whose 64 KiB copy-out runs inside its section, completes at fuel 5.
    - The higher fuels for the 64 KiB jobs come from the job's own `make-bytevector`, outside
      the verb.
- **A second thread** (`build/probes/threads.sps`, the library referenced first):
  - 8 threads × 2,000 rounds of `blake2b` (keyed and not), `random-bytes 64` and two compares
    gave every answer right, with counts `((block . 0))`.
  - `collect-rendezvous` waited at worst 5.4 ms over 200 tries while another thread ran 64 KiB
    compares back to back, as ADR-0007's 3.6 ms copy plus a collection predicts.
  - No M2 suite forks a thread, so the first-reference rule has nothing to hold in M2. No row
    runs a verb on a second thread. Brief §8.1 asks for none, but M3's row 19 forks one and
    could call an M2 verb there at no extra cost.

## 3. The slices' seams

Found: M2-F1. The slice 1 log credits the decoy builder's `--sizes` fix, which holds native's
twins, with killing the load builder's oracle twins.

Checked and sound:

- **Slice 1's decoy** under slice 2's code:
  - the weak `watch_set` and `name_block` take the volatile copy's value, and the real-files row
    is unchanged;
  - the A5 writes, which `-combined`'s drive rows hold, are what row 24's out block relies on;
  - the decoy's `sodium_memzero` zeroes what it is given, which only `test-wipe`'s verb row
    would show, and does (`interposer-says-1`).
- **M1's and slice 1's helpers under slice 2's rows:**
  - a non-critical `call-in-section` fails five R18 sweeps;
  - a wipe skipped for 3-byte blocks fails only the verb row, so it is not redundant with M1's
    child.
- **Slice 1's checks kept their teeth:**
  - `check-seam` (f) and (m), E7 and S4 between them leave `byte-verbs` no foreign memory of
    its own;
  - `test-conventions` and `check-seam` would each catch a `foreign-procedure` there;
  - `test-never-loads`' loaders row grows by import, so `byte-verbs` is in and `cap` is not.
- **The call log's 4,096 bytes:** the largest `verb-probe` child stays well under, and a full
  log is loud.
- **Plan §6's fixed items, against the code:**
  - the eight forms and their order;
  - the raw and size names;
  - the log lines' spelling;
  - the decoy's switches and values;
  - the refusal table, row by row;
  - `byte-verbs`' exports;
  - only the weak `watch_set` changed in slice 1's decoy (`-decoys` 20, `-combined` 18).

  None is contradicted by a later file, but for the "one child per switch" wording (M2-F7).

## 4. The checks themselves: mutants

Each was applied in a whole copy by exact replacement, with counts checked. It ran against the
suites named, at 1.0.22. The real tree passes each suite.

| Mutant | Check | Result |
|---|---|---|
| `rb-section-inner`: `random-bytes`' section holds only the C call and the copy-out | R18, S | Killed: R18 `random-bytes 32` (`re-entered after its block was freed`, fuel 1), S2, S3 |
| `b2-section-inner`: `blake2b`'s section holds only the innermost block | R18, S | Killed: R18 ×2, S2, S3 |
| `ct-section-inner`: the compare's section holds only `sodium_memcmp` | R18, S | Killed: R18 ×2, S2, S3 |
| `native-section-not-critical`: `call-in-section` without `critical-section` | R18 (seam) | Killed: R18 ×5 |
| `ct-shorter-length` (plan's row 14) | R14 | Killed (M2-F3) |
| `size-max-swap`: size bounded by `keybytes-max` | `sizes-other` | Killed by L's `sizes-other` row alone (B 120 pass) |
| `key-min-swap`: key bounded by `bytes-min` | `sizes-other` | Killed by L's `sizes-other` row alone |
| `rb-copy-before-fill`: the block read before `randombytes_buf` | R13 | Killed: R13 ×4, S3, L ×3 |
| `extra-export` (plan's exports) | exports | Killed (M2-F3) |
| `wipe-skips-3`: `call-with-block` skips the wipe for 3-byte blocks | row 24's lists | Killed: the verb row alone |
| `interposer-says-1`: the interposer never answers 2 | row 24's controls | Killed: both rows |
| `oracle-f-twins` | row 22 (sizes) | **Survived** every suite that runs the oracle (M2-F1) |
| `decoy-paste` | `test-decoy-source` | **Survived** (M2-F2) |
| `decoy-splice` | `test-decoy-source` | **Survived** (M2-F2) |

Row 17's raise inside the extent (P2) and the shape rows' P1 are logged killed after the slice 2
review. I did not repeat them.

Mutants I could not kill: the three survivors above. Each is named with its fix.

## 5. The records

- **Each amendment against the code as it is now:**
  - ADR-0001: the sizes read once, `sizes-other`, the oracle and `test-native`, the `nonnull`
    text and the allow-lists. Each holds.
  - ADR-0002: the eight in step 6, in order, and step 7 last in the load's section. Both hold.
  - ADR-0005: `_keybytes` unbound. Holds.
  - ADR-0006: the two cases, the who, the function and the code, and the rule symbols. Each
    holds.
  - ADR-0007: the ranges and the cap written once hold. The no-section paths and the key's cap
    are missing (M2-F4).
  - ADR-0011: the verb half through the decoy, the pointer rule, the loud log and the C-program
    exception hold. "The wipe row's child" is singular (M2-F4).
  - ADR-0012: `byte-verbs` and `cap`, the imports held whole, and the six exports. Each holds.
- **Stale or false texts:**
  - M2-F1 (the log and `progress.md`) and M2-F4.
  - AGENTS.md's "M2 is under way" and `progress.md`'s "Now", which are owed at close.
  - The constraint "test-decoy-source holds it for every pointer parameter of every function
    `sodium.h` declares" (`global-constraints.md:243-244`) is wider than the scanner, which
    reads only `sodium_`, `randombytes_` and `crypto_` names (M2-F2). `sodium.h` also declares
    `randombytes`, `_sodium_alloc_init` and `_sodium_runtime_get_cpu_features`. Of those, only
    `randombytes` takes a pointer, and its `buf` is `nonnull`, so the compile holds it. No gap
    in practice.
  - Nothing else in the brief, the constraints or AGENTS.md is stale for M2.
- **ADR-0011's new exception is the only C program a suite runs outside the gate.**
  - The C programs that run: `libsodium-oracle` (gated), `test-constants`' prototype program
    (the exception), and the interposer, a shared object loaded by `test-wipe`'s two Chez
    children (the wipe exception).
  - `check-sodium.sh` only preprocesses (`cc -E -M`, `cc -dM -E`). The decoy builds are loaded,
    never run.
  - Slice 1's overflow driver now runs in a gated Chez child (`refusal-probe --drive`).
  - Every other `capture-command` child is `sh`, a tool, or a Chez that runs only Scheme.

## 6. The traps and the rules, over every M2 suite

The M2 suites: `test-byte-verbs`, `test-library-loading-verbs`, `verb-probe`, `test-wipe`,
`test-decoy-source`, `test-native-codes`, `-missing-verbs`, and the changed `test-native`,
`test-constants`, `test-conventions`, `test-public`, `test-never-loads`, `-combined` and
`refusal-probe`. Each is sound against AGENTS.md's discipline:

- **Assertions:** reason symbols, who and irritants, never a message. R16 reads the text only
  for the absence of a secret.
- **Guards:** every top-level definition that can raise is guarded or behind an `(exit 1)`
  check. The F4 bounds go through `beside`.
- **`#f`:** no expected `#f` from anything that can raise. The compare's is `(no-raise #f)`.
- **Order:** no assertion depends on order. `map` is used only for independent calls, and
  `test-wipe`'s child `let`s allocate in any order without effect on the lists.
- **Structure:** no test runs inside another's actual expression, and every suite ends with its
  exit line.
- **Engines and threads:** the engines follow the top-level references, and no M2 suite forks a
  thread.
- **The comment rule:** no milestone, slice, research path, date or "the maintainer" in any
  comment M2 adds under `src/`, `tests/`, the Makefile, `scripts/` or `packaging/`. "The brief"
  appears as in M1's suites. `test-conventions`' `.plans/decisions` is M1's citation check.
- **Privacy:** no local path, user name or host distribution in anything M2 commits. The plan
  and research say "the workstation's packaged 1.0.18", and the store paths are the pinned
  profile's.

## 7. CI

| PR | Run | Jobs | `memory` | M2's new suites under the gate | Slowest suite |
|---|---|---|---|---|---|
| #10 | 45282952407 | 5 pass | 18 m 56 s, 26 of 26 | none new | `test-check-ci` 154 s |
| #11 | 45294352684 | 5 pass | 21 m 47 s, 29 of 29 | `test-decoy-source` 7 s, `test-native-codes` 8 s, `-missing-verbs` 59 s | `test-check-ci` 108 s |
| #12 | 45304409226 | 5 pass (finished 01:44 UTC) | 23 m, 31 of 31 | `test-byte-verbs` 12 s, `-verbs` 49 s, `test-wipe` 11 s; `test-decoy-source` 10 s, `test-native-codes` 10 s, `-missing-verbs` 76 s | `test-check-ci` 154 s |

- **Within the gate:** every new suite is well under 450 s, three quarters of `MEMORY_TIMEOUT`.
  The highest is `-missing-verbs` at 76 s, 17% of 450.
- **Run-to-run swing:** #12's runner ran the unchanged suites about 30 to 40% slower than #11's
  (`-decoys` 79 s to 101 s, `test-check-ci` 108 s to 154 s). The margin still holds.
  `-decoys`, at 14 children and 101 s, is the library-loading suite with the least room for
  M3's entries.
- **#12's lanes:**
  - `floor` loaded `sodium-floor/lib/libsodium.so.23`, 1.0.18 (library 10.3), and `current`
    1.0.22 (26.4). Each ran 31 of 31, with `test-byte-verbs`, `-verbs` and `test-wipe` passing.
  - `main` loaded the runner's `libsodium.so.23` by discovery, the floor, and ran 31 of 31.
- **In the copy** (the container, plain): `make test` passed 31 of 31 at 1.0.22 and at 1.0.18.
  At both, `test-byte-verbs` passed 120, `-verbs` 11, `test-wipe` 3, `test-decoy-source` 37,
  `test-native-codes` 13 and `test-native` 77.
- **In the copy, the other "Done" checks:**
  - `make check-test-fails`: "make test failed, as it must, in all 13 cases";
  - `make check-dev` ok, and `make build` loaded the profile's 1.0.22 with counts
    `((block . 0))`;
  - `make check-memory-gate`: "the memory gate failed, as it must, its refusals held, in all
    59 cases";
  - `make check-guix` on the host: "ALL CHECKS PASSED". Its inner `make test` ran 31 of 31.
- **The gate on M2's eleven suites** (`make test-memory MEMORY_SUITES=…`), in the container:
  ran 11, passed 11, slow 0. `test-byte-verbs` took 8 s, `-verbs` 32 s, `test-wipe` 7 s,
  `test-decoy-source` 7 s, `test-native-codes` 6 s, `-missing-verbs` 52 s, `test-public` 7 s,
  `test-never-loads` 16 s, `test-native` 9 s, `test-constants` 7 s and `test-conventions` 14 s.

## Draft close-outs for `progress.md`

### 2026-11-23 — M2's closing review

- **Reviewed:** M2's closing review, on Opus, read-only, over the plan and both slices
  (`4243017..m2-slice-2`), found no blocker, 1 major and 6 minors
  ([research/m2-closing-review/](research/m2-closing-review/README.md)).
  - It reran every suite at 1.0.22 and at the floor, `check-test-fails`, `check-dev`,
    `make build`, `check-memory-gate`, the gate on M2's suites and, on the host,
    `check-guix`.
  - It probed the verbs through `(chez-sodium)`: under engines abandoned at every fuel, on
    eight threads at once, and beside another thread's collection.
  - 14 mutants ran in whole copies. 11 were killed and 3 survived.
- **The major:** the slice 1 log and its close-out say `sizes-other` kills the oracle's
  equal-valued F twins. No row runs the oracle against the decoy, and the mutant passes every
  suite that runs it.
- **The minors:**
  - `test-decoy-source` misses a parameter name built by `##` or a line splice;
  - two plan-listed mutants were missing from slice 2's log, and both are killed;
  - ADR-0007 and ADR-0011 lack two of slice 2's review fixes;
  - three items owed to M3;
  - refusals that name no bound;
  - wording.
- **Its fixes:** in a PR of their own, by Sonnet, reviewed again on Opus where they change a
  rule.

### 2026-11-23 — M2 slice 2: the verbs (PR #12)

- **Written first by the caller:** a stub `byte-verbs` exporting the three names, each present
  and wrong. `test-byte-verbs` failed 110 of 115 against it, by name.
- **Built** on `m2-slice-2` by two Sonnet builders, on disjoint files in one tree:
  - **the verbs:**
    - `cap` and `byte-verbs`;
    - `test-byte-verbs`: rows 1, 13 to 16 and 18, and the shape rows S1 to S5;
    - `verb-probe` and `test-library-loading-verbs`: the decoy's halves of rows 13 to 15 and
      17, `memcmp-other` and `sizes-other`;
    - the known answers' fixture;
  - **the public library and the wipe:**
    - `(chez-sodium)`'s six new exports, held by `test-public`;
    - `test-never-loads`' condition children, which check the three `sodium-failed` names
      (M1-F6);
    - the interposer's ordered names, the decoy's weak `watch_set`, and `test-wipe`'s second
      child: row 24 for each verb.

  The weak `watch_set` was measured first: NULL in a plain Chez, resolved under the
  interposer, at both releases. 79 mutants on the verbs are logged, none surviving both suites,
  and the public half's beside them ([its mutation log](m2-slice-2-mutation-log.md)).
- **Reviewed:** one Opus review found no blocker, 2 majors and 10 minors, each fixed
  ([research/m2-slice-2-review/](research/m2-slice-2-review/README.md)).
  - **The majors:**
    - a check moved into a let-bound lambda and called inside the section passed every row.
      Now S3 lists every symbol inside each section, whole, and S2 refuses a `lambda` outside
      it;
    - row 17's watched mutant was the wrong one. Its own, a raise inside the extent with no
      section, is now logged killed by row 17. The plan's literal one is logged under rows 18
      and S.
  - **Among the minors:**
    - `refuse-secret`'s message now names the parameter and the rule;
    - S5 counts each verb's `input-cap` and holds libsodium's greatest size and key length
      within it;
    - the fixture's size and first and last hash are written in the suite.
- **CI's run** 45304409226 passed all five jobs. Under its gate:
  - `test-byte-verbs` took 12 s, `test-library-loading-verbs` 49 s and `test-wipe` 11 s, of
    450;
  - the slowest suite was `test-check-ci`, at 154 s;
  - `floor` and `current` ran 31 of 31.

### Also at close (plan §7)

- **"Now":** "M2 is done and merged (PRs #10 to #12, then the closing review's fixes in a PR of
  their own; its number when it is opened): three
  verbs, `random-bytes`, `blake2b` and `constant-time-bytevector=?`, in `(chez-sodium private
  byte-verbs)` beside native, with the cap in `(chez-sodium private cap)`; thirteen entry points
  bound; `make test` runs 31 suites. Next: M3, the password verbs."
- **AGENTS.md, "Where the project stands":** "M2 is done: `random-bytes`, `blake2b` and
  `constant-time-bytevector=?` (its plan is `.plans/2026-11-23-m2-plan.md`). M3 comes next: the
  password verbs, collect-safe, with brief §4.2's rules."

## Checked and found sound

- **The verbs' code:**
  - left-to-right checks, type before range, all before any block;
  - one `call-in-section` per verb, answering data, and `&sodium-failed` raised after it;
  - `no-key` an unexported fresh list, so `#f` is refused as a key;
  - the default size read at call time;
  - the unkeyed key and an empty input as one-byte blocks with length 0;
  - the compare checking both caps before the lengths, with only 0 a match;
  - every value within its C type before the section;
  - no Scheme copy of a secret;
  - imports exactly as ADR-0012's amendment says;
  - signature comments that match.
- **Native's step 6 and step 7, and the five sizes** recorded and exported, under E2, E3 and E5,
  `--sizes` and the oracle rows.
- **Every M2 row I read can fail** (§1's table), and each mutant I planted against them was
  killed but M2-F1's and M2-F2's.
- **Row 24's verb lists and their standing controls:**
  - the lists catch a single block skipped;
  - the controls catch an interposer that never says 2;
  - the length-0 blind spots are stated in the suite and in ADR-0011.
- **`sizes-other`:** all five values differ from each other and from a release's, so every swap
  of two bounds is killed, and every bound written in Scheme, in place or beside.
- **Engines and threads** (§2), and the "no ticks inside a section" claim the records make,
  measured.
- **No secret** in any condition, message, irritant, log line or test name of M2.
- **CI's five jobs** on all three PRs. The gate times are far inside the limit.
- **The comment rule and privacy** over everything M2 commits.

The copy, `build/m2-close/`, was removed after this report.
