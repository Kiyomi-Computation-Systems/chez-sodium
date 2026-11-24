# M2 slice 0 review: the M2 plan and its records

Reviewer: Opus, read-only and adversarial. Tree: `m2-plan` over `main` at `4243017`, with the work
uncommitted. Probes ran in a copy, `build/m2-s0-review/tree/`, in the container. The copy has
since been removed, so each probe's text and output is quoted below.

**Counts: 0 blockers, 5 majors, 15 minors.**

---

## Majors

### M2S0-F1 (major): `test-decoy-source`'s rule fails on the decoy as written, and misses array parameters

- **Where:**
  - `.plans/2026-11-23-m2-plan.md:218-226` (§4.1, item 9);
  - `.plans/decisions/0011-the-harness-after-chez-sqlite3.md:138-141` ("in each function, each
    pointer parameter occurs once, as the value of a `volatile uintptr_t`");
  - `.plans/global-constraints.md:238-240`;
  - `tests/decoy-libsodium.c:73-84`.
- **Evidence:**
  - The rule reads "In each function definition, each parameter declared with a `*` occurs in
    the body exactly once, as `(uintptr_t) NAME` in a `volatile uintptr_t` declaration".
  - The decoy's own static helper `called(const char *format, ...)` (line 73) uses `format`
    twice, `va_start(args, format)` (81) and `vsnprintf(..., format, args)` (82), and neither use
    is through a volatile. So a check built to the rule as written refuses the real decoy.
  - M3's prototypes declare pointer parameters as arrays: `crypto_pwhash_str(char out[...]`,
    `crypto_pwhash_str_verify(const char str[...]` and `crypto_pwhash_str_needs_rehash(const
    char str[...]` (1.0.18's `crypto_pwhash.h:116,128,134`). A decoy that copies the header's
    spelling has no `*` there, so "declared with a `*`" skips them.
  - The weak `watch_set` declaration that slice 2 adds, `extern void watch_set(void *p, size_t
    n) __attribute__((weak));`, is a declaration with a `*` parameter and no body. The parser
    must not read it as a definition.
  - Text matching must work on identifier tokens with comments and strings stripped: `in` occurs
    inside `inlen` and `int`, and `key` inside `keylen`.
  - M3's FIFO decoy (row 19) may be a second C file. A check that reads only
    `decoy-libsodium.c` would not see it.
- **Fix:**
  - Scope the rule to the functions `sodium.h` declares: the decoy's `sodium_*`,
    `randombytes_*` and `crypto_*` definitions.
  - Count `T name[...]` as a pointer parameter.
  - Skip declarations.
  - Match whole identifiers, after stripping comments and string literals.
  - Read every `tests/*.c` that includes `sodium.h`.
  - Say all of this in the plan, in ADR-0011's amendment and in the constraint.

### M2S0-F2 (major): row 24's verb half can pass when a decoy entry names nothing, or names a block that is all zero

- **Where:**
  - `.plans/2026-11-23-m2-plan.md:137-158` (§4.1, item 3), `:400-405` (slice 1's "Fixed"),
    `:428` (slice 2: "`decoy-libsodium.c` (the weak `watch_set` alone)");
  - `.plans/decisions/0011-the-harness-after-chez-sqlite3.md:127-136`.
- **Evidence:**
  - **The standing control covers one entry.** It is the decoy's `randombytes_buf`, called through
    native's raw binding on a block freed unwiped. It does prove that the weak symbol resolves
    and that the interposer can answer 2.
  - **The other entries are not covered.** Suppose `crypto_generichash` or `sodium_memcmp` never
    calls `watch_set`, or names the wrong pointer. Then a child that reads "each named block
    freed all zero" passes whenever its verdict sums over the blocks it was handed. The plan does
    not say the child asserts how many blocks each call names, nor their lengths.
  - **No slice owns the non-zero output pattern.** "The decoy writes a non-zero pattern into every
    output" (`:149-151`) appears in neither slice 1's work nor its "Fixed" list. Slice 2's wipe
    agent may change "the weak `watch_set` alone". If the slice 1 decoy writes zeros into `out`
    (or nothing, which leaves fresh `malloc` memory that is often zero), blake2b's out block reads
    1 with or without the wipe, and the control, on `randombytes_buf`, cannot see it.
  - **Inputs are not required to be non-zero.** "The input blocks hold the caller's bytes", and
    nothing requires the child's inputs to hold a non-zero byte. An all-zero input or key
    witnesses nothing.
  - **Some blocks cannot be witnessed at all:**
    - the unkeyed key block, and both blocks of a length-0 compare, are named with length 0, so
      they read 1 whatever happens;
    - `random-bytes 0` makes no block;
    - under `generichash-fails`, `out` is left as it was, and so holds whatever `malloc` gave it.
  - **The weak symbol itself works as planned.** Probe `weak-user.c` (an M2 entry with `extern
    void watch_set(void *, size_t) __attribute__((weak))` that writes `0xA5` through its volatile
    copy, then `if (watch_set) watch_set((void *) b, size)`). It compiled with `-Wall -Werror
    -Wextra` on GCC 16.2, `nm -D` shows `w watch_set`, and `weak_resolved()` answered:
    - `(resolved 0)` under plain `scheme`;
    - `(resolved 1)` with `LD_PRELOAD=libfreewatch.so` (the real `tests/free-watch.c`).
- **Fix:**
  - The interposer keeps each name in order, with its length. The child asserts, per call, the
    whole list of (length verdict) pairs. For example, keyed `blake2b` of 3 bytes at size 32 with
    a 16-byte key is `((32 1) (3 1) (16 1))`, so a missing name makes the list shorter.
  - Put "every M2 output entry writes a fixed non-zero pattern over its whole length, under every
    switch" into slice 1's "Fixed for all three".
  - Require a non-zero byte in every input, key and operand the child passes.
  - Name the blocks row 24 cannot witness.
  - Tell slice 2 that `watch_set` and the pattern write go through the volatile copy, or
    `test-decoy-source` refuses them.

### M2S0-F3 (major): row 17's watched mutant, "the raise moved inside the section", cannot be killed, and neither can row 15's "before any block"

- **Where:** `.plans/2026-11-23-m2-plan.md:441` (slice 2's watched list), `:51` and `:85` (row
  15's "each before any block"); brief §8.1 row 17 (`brief.md:579`).
- **Evidence:**
  - `call-in-section`'s catch-all guard takes a raise from inside THUNK and raises it again after
    the section (ADR-0007, decision 7). So moving `blake2b`'s raise inside the section changes
    nothing observable. The probe `raise-inside.sps` defines three model verbs over
    `call-with-block`, each failing with -1:
    - `after`: the section answers the code, and the verb raises after it;
    - `inside`: `raise-sodium-failed` inside PROC, inside `call-in-section`;
    - `no-section`: the same raise, with no `call-in-section`.
  - Each was run under `(guard (c ((string? c) 'something-else)) ...)` inside an outer guard that
    reports what arrives:

    ```
    (after (sodium-failed "crypto_generichash" -1) ((block . 0)))
    (inside (sodium-failed "crypto_generichash" -1) ((block . 0)))
    (no-section (assertion "re-entered after its block was freed") ((block . 0)))
    ```

  - Only the missing section is visible. Brief row 17's X-M2 catch is that one, and row 18
    already lists it.
  - In the same way, a refusal raised inside the section but before any block or C call looks
    like one raised before the section: the handler runs at depth 1, the counts are zero, and the
    decoy log is empty. So "each before any block" is a claim with no row behind it.
- **Fix:**
  - Drop "the raise moved inside the section" from row 17's list, and watch row 17 against a
    verb with no `call-in-section`.
  - Hold the verbs' shape the way test-native's E rows hold native's: read `byte-verbs.sls` as
    data. No `raise`, `raise-sodium-failed`, `assertion-violation` or `refuse-secret` occurs
    inside `call-in-section`'s argument, and each verb's checks come before its
    `call-in-section`.
  - Watch that row with the raise moved in.

### M2S0-F4 (major): `generichash-fails` answers only -1, so neither the code field nor the failure test is held

- **Where:** `.plans/2026-11-23-m2-plan.md:236-249` (§4.2, item 2), `:81` (the switches),
  `:441` ("the code ignored"); ADR-0006's amendment (`0006-...md:128-133`).
- **Evidence:**
  - With the decoy answering -1, two wrong verbs pass:
    - one that raises with a constant -1, not the answer;
    - one that tests `(= rc -1)` rather than "not 0".
  - The plan decides only the -1 case. What `blake2b` does on any other non-zero answer is left
    open, though the compare's rule is explicit (§4.2, item 3: "Any other code is `#f`").
  - The project's own pattern for this is `init-other`, a second code "so that no single value
    passes for refused" (decoy header, `decoy-libsodium.c:41-42`; ADR-0002, amended).
- **Fix:**
  - Decide that any answer but 0 is `&sodium-failed`, its code the answer.
  - Have a second switch, or `generichash-fails` itself, answer a second code, such as 1 or -2.
    Row 17 then asserts the code whole.
  - Record both in ADR-0006's amendment.

### M2S0-F5 (major): the condition-children half of `&sodium-failed`'s export, owed from M1-F6, is dropped

- **Where:**
  - `main`'s `.plans/progress.md:105-109` ("They join `test-never-loads`' condition names, which
    come from `(chez-sodium)`'s exports, and its child's expected lines; its export row fails by
    name until they do (M1's closing review, M1-F6)");
  - the new `.plans/progress.md:88-89`;
  - `.plans/2026-11-23-m2-plan.md:88` and `:444-446`;
  - `tests/test-never-loads.sps:322-405`.
- **Evidence:**
  - The ledger's rewrite replaces the item with "The type's first raise and its three names
    arrive in M2". The plan's `test-never-loads` row says only "`verb-names` gains the three
    verbs; the loaders row gains `byte-verbs`".
  - `condition-names` is `(chez-sodium)`'s exports less `verb-names`, so it gains
    `sodium-failed?`, `sodium-failed-function` and `sodium-failed-code`.
  - Three things must then change, and neither the plan's table nor slice 2's watched list names
    them:
    - `checked-names` (`:335-344`);
    - `conditions-program`, which makes only a `&sodium-library-unavailable` and calls only its
      accessors (`:353-382`);
    - `conditions-expected` (`:390-401`).
  - The "exactly the names the condition children check" row turns red, so nothing passes
    silently. But the owed item has left the ledger, and slice 2's brief would not carry it.
- **Fix:**
  - Restore the item, under "Answered for M2" with its new home, or as slice 2 work.
  - The child makes a `&sodium-failed` with `make-sodium-failed` and distinct field values,
    calls the three names on it and on a non-condition, and the expected lines gain them.
  - Watch it fail with a condition export missing from the child.

---

## Minors

### M2S0-F6 (minor): no row-1 vector has a key length other than its size

- **Where:** `.plans/2026-11-23-m2-plan.md:255-266` (§4.2, item 5).
- **Evidence:**
  - The self-test sets keylen = outlen for every keyed hash (`research/m2-plan/README.md`, the
    Appendix E row: "key = `selftest_seq(key, outlen, seed=outlen)`, keylen = outlen").
  - The known answers are all 64-byte keys with 64-byte outputs, and `"abc"` is unkeyed.
  - So a verb that passes the size as `keylen` on the keyed path, `(crypto-generichash out size
    in n key size)`, passes every vector in row 1.
  - Only `sizes-other`'s accepted keys (18 and 62 at the default 33) could see it, and only if
    those rows assert the decoy's log line whole. The plan does not say they do.
- **Fix:** do one of these:
  - add a keyed vector with key length ≠ size from `hashlib`, measured once (for example a
    16-byte key at size 32);
  - say that the `sizes-other` rows assert `crypto_generichash(p,33,p,N,p,18)` whole.

  Add "keylen taken from the size" to slice 2's watched list.

### M2S0-F7 (minor): `sizes-other`'s values cannot catch a literal bound added to the read one

- **Where:** `.plans/2026-11-23-m2-plan.md:209-212`; ADR-0001's amendment
  (`0001-...md:116-119`).
- **Evidence:**
  - The five values (33, 17, 63, 18, 62) are distinct, so each catches a size written in Scheme
    *instead of* the read one, and a size read from the wrong function.
  - They lie inside the real ranges, so a verb that checks `(and (<= 16 size 64) (<= min size
    max))`, or `(max 16 min)`, passes every row.
  - So "A size written in Scheme fails one of these" overclaims.
- **Fix:** do one of these:
  - use values that straddle the real ranges for the bounds, for example `_bytes_min` 8,
    `_bytes_max` 80, `_keybytes_min` 9 and `_keybytes_max` 81, with the default kept distinct;
  - narrow the claim to "instead of".

### M2S0-F8 (minor): stale `nonnull` text survives, and AGENTS.md's new "most are unmarked" is false

- **Where:**
  - ADR-0001's Context (`0001-...md:23-24`: "libsodium's headers mark its pointers `nonnull`");
  - brief §3.4's "What this changes" (`brief.md:163-166`: "but the headers say `nonnull`";
    "NULL with a nonzero length aborts the process");
  - `AGENTS.md:249-251`.
- **Evidence:**
  - M2's measurements: of M2's six pointers, only `buf` and `out` are marked, and `sodium_memzero`
    is unmarked. `sodium_memcmp` given NULL with length 4 crashes; it does not abort
    (`run-6.out`, rerun identical).
  - Over the brief's whole subset, the 1.0.18 headers mark 13 pointer parameters and leave 7
    unmarked:
    - marked: `randombytes_buf`'s; `crypto_generichash`'s `out`; every pointer of the three
      pwhash functions; `crypto_hash_sha256`'s `out`; HMAC's state, key and out;
    - unmarked: `pnt`, `in`, `key`, `b1`, `b2`, and SHA-256's and HMAC update's `in`.
  - Tier 1 alone is 7 marked and 5 unmarked, so "most are unmarked" is false either way.
- **Fix:**
  - Amend ADR-0001's context in M2's amendment.
  - Correct the brief's bullet: "some headers mark a pointer `nonnull`; NULL with a nonzero
    length aborts or crashes".
  - In AGENTS.md, say "many are unmarked", or drop the clause.

### M2S0-F9 (minor): "the load's last step" is now step 7, which reads sizes, not bindings

- **Where:**
  - ADR-0002, decision 4 (`0002-...md:52`: "Each milestone binds its own verbs' entry points in
    the last step");
  - its M1 amendment (`:96-97`) and its M2 amendment (`:105`: "appended to the last step after
    `sodium_memzero`");
  - `.plans/global-constraints.md:97` ("in the load's last step");
  - `tests/foreign-conventions.sls:92` (`sodium_memzero`'s row cites "ADR-0002 amendment: bound
    last, for the block helper").
- **Evidence:** after M2 the load ends with "read the sizes". An M3 builder told to bind "in the
    last step" would put its bindings in step 7. The convention row's text becomes false once the
    eight are bound after `sodium_memzero`. Also `global-constraints.md:93` is a leftover short
    line ("is optional. The load runs once, and a").
- **Fix:** write "step 6, bind the rest" in the M2 amendment and the constraint, and have slice 1
    change the convention row's text. Reflow `:91-94`.

### M2S0-F10 (minor): the constraint reads every constant at the load, wider than the record, and item 7's consent is thin

- **Where:** `.plans/global-constraints.md:57-60` ("every constant is read through libsodium's
  own function for it, once, at the load"); ADR-0001's amendment (`:111-115`, which speaks of
  `crypto_generichash`'s five); `.plans/2026-11-23-m2-plan.md:5-8` and `:213`.
- **Evidence:**
  - The constraint binds M3's `crypto_pwhash_strbytes`, its limits and `crypto_pwhash_strprefix`
    to be read at the load, a decision the M2 question did not put. Where a rule and its record
    disagree, the record wins, so the two should say the same thing.
  - Your brief says item 7 was mentioned in the item 6 question and "the owner did not object".
    The plan, ADR-0001 and ADR-0002 record it as "the owner's answer".
- **Fix:**
  - Scope the constraint to the generichash sizes, or widen ADR-0001's amendment on purpose.
  - At acceptance, have the owner name item 7, and the constraint's scope, explicitly.

### M2S0-F11 (minor): `byte-verbs`' import rules are partly unwritten and partly unchecked

- **Where:**
  - `.plans/2026-11-23-m2-plan.md:68-69` and `:192-196`;
  - ADR-0012's amendment (`0012-...md:92-97`);
  - `.plans/global-constraints.md:44-46` and `:141-143`.
- **Evidence:**
  - **require-threaded is missing.** It must be `byte-verbs`' first import (ADR-0004;
    `tests/test-require-threaded.sps` checks it for every `src/` library). The plan's list for
    `cap` includes it; the lists for `byte-verbs` in the plan, ADR-0012 and the constraint omit
    it.
  - **"Nothing from `(chezscheme)`" has no check.** `check-seam` lets any library import
    `critical-section`, `dynamic-wind`, `make-mutex`, `with-mutex` and the version names, which
    are in `allowed-chez-names` and not in `library-only-chez-names`
    (`tests/check-seam.sps:180-211`). So a `byte-verbs` that wrapped its own `critical-section`
    instead of `call-in-section` passes `check-seam`.
  - **Nothing checks "the cap written once".** No row looks for a second 65536.
  - **check-nothreads refuses `byte-verbs` by name whatever its order,** through native.
- **Fix:**
  - Name require-threaded first in each list.
  - Add a row that reads `byte-verbs`' and `cap`'s import clauses whole, as test-never-loads holds
    the testing library's allowlist.
  - Add a row that `src/` writes the cap's literal in `cap.sls` alone.

### M2S0-F12 (minor): "a fresh `#vu8()`" cannot hold in Chez

- **Where:** `.plans/2026-11-23-m2-plan.md:112`; `.plans/decisions/0007-...md:154`.
- **Evidence:** probe `empty.sps` evaluated these five on Chez 10.4.0:
  - `(eq? (make-bytevector 0) (make-bytevector 0))`;
  - `(eq? (make-bytevector 0) #vu8())`;
  - `(eq? (bytevector-copy #vu8()) #vu8())`;
  - `(eq? (bytevector) (bytevector))`;
  - `(eq? (make-string 0) (make-string 0))`.

  It printed `(#t #t #t #t #t)`. Chez has one empty bytevector, so a freshness row on
  `random-bytes 0` fails on every implementation.
- **Fix:** write "answers `#vu8()`, which has no byte to change".

### M2S0-F13 (minor): "brief §4.4's 2 ms holds" is not true of the compare

- **Where:** `.plans/2026-11-23-m2-plan.md:326-327`; `.plans/decisions/0007-...md:167-170`.
- **Evidence:** the compare copies two capped operands in one section. At §5.1's 1.8 ms per
  64 KiB, that is about 3.6 ms plain and about 96 ms under Valgrind (48 ms each).
- **Fix:** write "about 2 ms per capped input; the compare, with two, about 3.6 ms".

### M2S0-F14 (minor): §5.1 says "all four libraries" for rows that ran on three

- **Where:** `.plans/2026-11-23-m2-plan.md:319` and `:321`.
- **Evidence:** `research/m2-plan/run-4c.sh:7` runs three libraries: the two tarball builds and
  the workstation copy. The profile's 1.0.22 is not among them, and `run-4c.out` has three
  `########` headers. The README's "all four" means the four hashes.
- **Fix:** write "on three libraries", or rerun on the profile's.

### M2S0-F15 (minor): the stated reason the interposer cannot wrap is imprecise

- **Where:** `.plans/2026-11-23-m2-plan.md:139-141`; `.plans/decisions/0011-...md:129-131`
  ("can load the interposer by path only after that").
- **Evidence:**
  - The interposer is preloaded before the load. It still cannot wrap, because Chez resolves a
    name in the most recently loaded object first.
  - Probe: `libwrap.so` defines `sodium_memcmp` to answer 42. With and without
    `LD_PRELOAD=libwrap.so`, a program that loads libsodium and binds `sodium_memcmp` printed
    `(memcmp-answer 0)`: libsodium's definition won.
  - The conclusion stands; the reason given is wrong.
- **Fix:** write "Chez binds each name from the most recently loaded object, libsodium, even with
  the interposer preloaded (probed)".

### M2S0-F16 (minor): slice 2's verbs suite has no child program, owner or child count, and two slice 1 details are unstated

- **Where:**
  - `.plans/2026-11-23-m2-plan.md:83`, `:85`, `:396-399` and `:425-431`;
  - `tests/library-loading.sls:2-7` and `:344-357`.
- **Evidence:**
  - **No child program.** `test-library-loading-verbs` must run verbs in a child against the
    decoy and read the log. `probe-with` runs only `refusal-probe.sps`, which references
    `loaded-libsodium` alone.
  - **No owner.** Neither a new child program nor `library-loading.sls` is owned in slice 2.
  - **No child count.** About 25 refusal and size rows, at one child each, would far pass the
    14-children rule.
  - **No shared list in slice 2.** Slice 1 has "Fixed for all three"; slice 2 has nothing
    equivalent.
  - **`missing-api-rows`' `else` branch is wrong for M2's eight.** It expects an empty log, but
    each of the eight is bound after `sodium_init`, so each refusal's log is the version calls
    then `sodium_init()`.
  - **Unnamed.** The split's new suite has no name, and `library-loading.sls`'s header says "six
    suites".
- **Fix:**
  - Name the verbs child program, and give it and `library-loading.sls` an owner in slice 2.
  - Plan one child per switch, with rows read from the log's growth.
  - Add a "Fixed for both" list to slice 2.
  - Say that M2's missing-api logs are the post-init log.
  - Name the new missing suite by what it holds, not by milestone.

### M2S0-F17 (minor): gaps in the watched-to-fail lists

- **Where:** `.plans/2026-11-23-m2-plan.md:408-415` and `:432-446`.
- **Evidence:** these mutants are not listed:
  - the 65536/65537 boundary for `blake2b`'s input and for each compare operand (only
    `random-bytes`' boundary is listed);
  - the compare comparing lengths before the cap;
  - the order of checks (left to right, type before range);
  - a NULL key, input or operand at length 0 (libsodium accepts these, so only the decoy log's
    `p` shows them);
  - keylen taken from the size (F6);
  - for slice 1, a size read before every entry is bound. The missing-api logs kill this: a
    lacking `sodium_memcmp` build would log size calls.
- **Fix:** add them.

### M2S0-F18 (minor): the decoy's call log truncates silently

- **Where:** `tests/decoy-libsodium.c:70-84`.
- **Evidence:** `calls` is 4096 bytes. Once it is full, `called` writes nothing further and says
  nothing. A row that reads "no C was called" as "the log did not grow" then passes for every
  later call.
- **Fix:** when the log is full, make it loud: write a fixed `overflow` entry and refuse further
  entries. A row then asserts the absence of `overflow`.

### M2S0-F19 (minor): three texts left behind

- **Where:** brief §8.1 row 17 (`brief.md:579`); brief §4.3 (`brief.md:289`);
  `.plans/progress.md:102-103` (Owed to M4).
- **Evidence:**
  - Brief row 17's How names only `crypto_pwhash_str`.
  - Brief §4.3's "Different lengths answer `#f` at once" now has the cap exception, which
    ADR-0007's amendment records.
  - M4's notes from M2 omit that `blake2b` can raise `&sodium-failed`.
- **Fix:** add a phrase to each.

### M2S0-F20 (minor): the research README wraps past 100

- **Where:** `.plans/research/m2-plan/README.md:42-76`, at 103 to 111 characters.
- **Fix:** reflow it.

---

## Checked and found sound

1. **"Owed to M2" on `main`:** every item has an answer in the plan, each tied to a record, apart
   from F5's dropped sub-item.
   - The missing-entry split is now two ways, not v0.1.1's four. The counts allow it: M1's suite
     keeps 5 lacking builds, `not-sodium` and 3 order rows (9 children); M2's has 8 or 9.
2. **Row 13's bound:** P(one position constant over 8 calls) is 256·2⁻⁶⁴ = 2⁻⁵⁶. Over 64
   positions that is at most 2⁻⁵⁰. Correct.
3. **Row 1's vectors catch what brief row 1 says they catch:** a dropped key (the known answers
   and the self-test), a wrong or ignored size, and BLAKE2b-512 truncated (the self-test at 20,
   32 and 48, and `"abc"` at 256).
4. **`sizes-other`:** all five values are distinct, and each boundary pair catches a literal used
   instead of the read size, a size read from the wrong function, and an off-by-one in either
   comparison. F7 is the exception.
5. **The weak symbol:** it resolves under `LD_PRELOAD` and is NULL without it, and `-Wall -Werror
   -Wextra` accepts the test (F2's probe).
6. **The verbs beside native, against `check-seam`:** rules (c) to (m) as `check-seam.sps`
   implements them, rule (h) and (i)'s paths, (g), (k) and (m) all pass with no change.
   - `check-nothreads` refuses `byte-verbs` and `cap` by name.
   - `test-require-threaded` checks the first-import order for every `src/` library.
   - The `test-never-loads` loaders row gains `byte-verbs` and not `cap`.
7. **Step 7 inside the load's section:**
   - it can raise nothing;
   - `missing-api`'s whole-log rows show binding before reading, because a lacking build logs no
     size call;
   - E2 gains five steps, E3 gains eight forms (13 in all), and E5 gains 3 raw bindings and 5
     sizes;
   - `loaded-calls` gains the five, and the refusal rows before step 7 are unchanged.
8. **`&sodium-failed` in M2:**
   - the type, its checked accessors and `raise-sodium-failed` already exist in `conditions.sls`;
   - `test-public`'s whole-exports and `eq?` rows catch a missing name;
   - no test or `src/` comment assumes M3 apart from F5's child.
9. **The no-op FILL!:**
   - it is within `call-with-block`'s contract;
   - C writes every byte of a success;
   - a -1 path reads nothing;
   - the wipe writes and never reads, so Valgrind has nothing to flag.
10. **The refusal table:**
    - it has the shape of `refuse-secret`, `(RULE PARAMETER (kind K))`;
    - `n` and `size` are shown by `shown-value`, and a bytevector or string slipped into either
      shows only its kind;
    - the parameter names match brief §4 and §4.3;
    - the order is consistent;
    - an over-cap key falls under the key's range check.
11. **The cap before the compare's lengths:** brief §4.4 wins over §4.3's "at once", and ADR-0007's
    amendment records it.
12. **Engine rows:**
    - an engine spends no ticks inside `call-in-section`;
    - the probe `engine-sweep.sps` models `blake2b` as one section around an out block, an input
      block, a key block, the real `crypto_generichash` and `foreign-bytes`;
    - it completes at fuel 5 (6 once) for inputs of 0 to 65,536 bytes, plain and under Valgrind;
    - a whole sweep at 64 KiB takes 9 ms plain and 272 ms under Valgrind, well within the gate.
13. **Slice 1's files are disjoint,** and `decoy-libsodium.c` is owned once per slice.
    - The cross-agent rows, `every-entry` against the table, are named red until the join.
    - Every "Done" can be checked.
14. **The amendment form:**
    - each heading is "Amendment, 2026-11-23: M2's plan", matching `#amendment-2026-11-23-m2s-plan`;
    - each status line says "proposed, and waiting";
    - "with the owner's answer" appears exactly on the owner's items, and not on ADR-0011's;
    - every new link definition (`[ADR-0005]`, `[ADR-0007]`, `[ADR-0012]`) is used and resolves.
15. **The brief's edited rows** match `headers-decls.txt`, `run-2.out`, `run-3.out` and
    `run-6.out`.
16. **The reruns:**
    - `run-1.sh` (prototypes and the decoy compiles) and `run-6.sh` (NULL pointers) reproduce
      byte for byte;
    - `run-2.sh` reproduces but for the scrubbed path spelling;
    - `codes.sps`' exhaustive memcmp pass covers all 65,536 pairs, though its label says `a /= b`;
    - the fetched vectors' SHA-256s match the README.
17. **The research copy** holds no user name, home path, host or distribution name. Store paths
    and `<repo>` are all that appear.
18. **Prose:** wraps at 100 outside tables, except F20, and sibling records are cited by
    repository name. The claim that chez-sqlite3's `native.sls` alone holds `foreign-procedure`,
    beside its verb libraries, is true.

## Permission denials

None.
