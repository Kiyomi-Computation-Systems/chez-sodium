# ADR-0009: `password-needs-rehash?` answers `#t` for a hash not made with today's algorithm and limits

- **Status:** Accepted (the owner, 2026-11-22), brief §11.1. Decision 4's KiB unit and the
  bound `crypto_pwhash_strprefix` are brief §11.5; the default limits are brief §11.7.
  Amended 2026-11-24 in M3's plan, and accepted by the owner that day
  ([amendment](#amendment-2026-11-24-m3s-plan)).
  Its last points added after M3's slice reviews and closing review.
  Amended 2026-11-25 in M4's plan, and accepted by the owner that day
  ([amendment](#amendment-2026-11-25-the-rule-as-built-m4s-plan)): the title, decision 1 and
  the batch-job consequence restated.
- **Date:** 2026-11-22
- **Scope:** `password-needs-rehash?`, the limits, and the hash-string checks it shares with
  `password-verify`
- **Settles:** [brief](../2026-11-22-chez-sodium-project-brief.md) §4.1's limits and pre-check,
  §4.2, §11.1
- **Related:** [ADR-0005] (the verbs) · [ADR-0006] (what `password-verify` answers) ·
  [ADR-0007] (the cap)

## Context

- **libsodium's `crypto_pwhash_str_needs_rehash` compares t and m/1024 alone** (L-F6). It
  answers 0 when both match the limits given; 1 when either differs, lower or higher; and -1
  when it cannot parse the string, even a long one that verify accepts (L-F7). It ignores the
  algorithm, since it dispatches on the prefix, and ignores p and the salt and tag lengths.
  So an argon2i hash, or one with p=4, at the same limits reads as current (L-F6, P-F17).
- **libsodium reads a hash string to its first NUL,** and refuses any byte after the hash. So
  `"<good hash>\0junk"` would verify as the good hash (L-F1).
- **libsodium verifies hashes longer than `crypto_pwhash_strbytes()`:** a 136-character one
  verifies. The header's `str[crypto_pwhash_STRBYTES]` documents a buffer and binds nothing
  (L-F7).
- **Memory in bytes invites a KiB-for-bytes mistake** (L-F3). OWASP's `m=19456`, read as
  bytes, gives a hash at 19 KiB, about 1000 times weaker, which needs-rehash then calls
  current.
- **libsodium's default algorithm is argon2id** at 1.0.18 and 1.0.22, and
  `crypto_pwhash_strprefix()` answers `"$argon2id$"` at both.

## Decision

1. **What `#t` means:** this hash was not made with today's algorithm, parallelism and limits,
   or libsodium cannot read it (amended 2026-11-25; the first wording was "not what
   `password-hash` would make now"). The caller replaces it, using the password it has just
   verified.
2. **It answers `#t` when any of these holds:**
   1. the limits differ: libsodium answers 1;
   2. libsodium cannot read the hash: it answers -1;
   3. the string fails the pre-check (decision 5);
   4. the algorithm or parallelism differs: the string does not begin with
      `crypto_pwhash_strprefix()`, read from the loaded library, or its parameters do not
      read `p=1`.

   It answers `#f` only when libsodium answers 0 and the string passes 3 and 4.
3. **It never raises because of the hash.** It raises only for a caller's mistake, before C: a
   hash that is not a string, or limits out of range.
4. **Limits are `'interactive`, `'moderate`, `'sensitive`, or made by
   `make-password-limits ops memory-kib`, with memory in KiB** (brief §11.5).
   - KiB is the unit of argon2's own strings, of OWASP's guidance and of other argon2
     libraries. In KiB nothing is floored, so memory is compared in whole KiB, exactly.
   - The ranges are checked before C: ops from `_opslimit_min` to `_opslimit_max`; memory from
     `_memlimit_min` to `_memlimit_max`, divided by 1024.
   - **The default is `'interactive`** (brief §11.7): 64 MiB, more than three times OWASP's
     minimum memory, and about 55 ms a hash here.
5. **The pre-check, shared with `password-verify`** (brief §4.1). A hash string is printable
   ASCII, U+0021 to U+007E, with no U+0000, and within the cap ([ADR-0007]).
   - One that fails gets `#f` from `password-verify` and `#t` from `password-needs-rehash?`,
     without reaching C.
   - The check sets no limit tied to `crypto_pwhash_strbytes()`.
   - The hash string's block holds its bytes and a terminating 0.
6. **Call it only after `password-verify` answers `#t`.** The documents show the login pattern:

   ```scheme
   (if (password-verify hash password)
       (begin
         (when (password-needs-rehash? hash)
           (store-hash! account (password-hash password)))
         (log-in account))
       (refuse))
   ```

   They say in those words that a caller who re-hashes on `#t` without verifying first stores a
   password nobody verified.

### Rejected

- **Raising for a hash it cannot read** (brief §11.1):
  - it would lock out a user whose right password verified against an imported hash;
  - it needs a condition of its own;
  - it protects only corrupt rows from a caller that re-hashes before verifying. That bug
    belongs to the order: after the limits rise, every valid hash answers `#t` too.
- **Limits as `(ops . bytes)`** (L-F3).

## Consequences

- **A new default algorithm migrates old hashes.** `password-hash` uses the library's default,
  and `password-needs-rehash?` reads the expected prefix from that same library. If a future
  release changes the default, every older hash answers `#t` and is migrated at its next login.
- **A batch job** that checks stored hashes without passwords gets `#t` for stale and
  unreadable hashes alike. Both read as "replace at the next login". If a job ever needs to tell
  them apart, that is a new verb with three answers, not a raise. It cannot find a damaged hash
  that libsodium still reads (amended 2026-11-25).
- **A hash's own limits decide what verifying it costs.** A tampered row could ask for hours of
  work or terabytes of memory, so hashes must come from trusted storage, and the documents say
  so (L-F10).
- **Rows hold each rule** (brief §8.1): row 5, that `password-hash` uses the limits given; 6, the
  presets; 7, the default; 8, each of decision 2's items, with nothing raised; 9, the pre-check,
  from the decoy's log (P-F10); 10, the terminating 0.

## Amendment, 2026-11-24: M3's plan

Accepted (the owner, 2026-11-24), proposed in [the M3 plan](../2026-11-24-m3-plan.md), §4.1, items
6 and 11, and §4.2, item 2.

- **Decision 2's item 4, exactly.** `current-hash-shape?`, in the pure library
  `(chez-sodium private password-text)`, holds it.
  - The hash begins with the loaded prefix. It then reads `v=` and digits, `$m=` and digits,
    `,t=` and digits, `,p=1$`, and at least one character more.
  - Anything else answers `#t`.
  - It is stricter than libsodium's parser, so a hash it refuses is only rehashed.
- **Why the rule is needed, measured.** libsodium's needs-rehash answers 0 in two cases where
  the binding must answer `#t`:
  - an argon2i hash at its own limits, ops 3 or more;
  - a `p=4` or `p=2` string at 32 KiB or more.

  Below those limits libsodium answers -1 itself, so each rule's row uses a string libsodium
  answers 0 for ([research/m3-plan/](../research/m3-plan/README.md), set A).
- **The prefix is read once, at the load** ([ADR-0001], amended). A NULL prefix is recorded as
  `#f`, and then every hash answers `#t`, without C.
- **libsodium answers -1, so the binding `#t`:**
  - for any string of `strbytes` characters or more;
  - for a salt of 21 characters, or a tag of 42;
  - for ops above 2³²−1, which the limits' ranges rule out.

  At 1.0.22 it also answers -1 for a byte of 0x80 or more in the salt, where 1.0.18 answers 0.
  The pre-check refuses that string first.
- **The checks that answer `#t` without C run after every refusal and before any section:** the
  pre-check, then item 4. A refusal comes first, so a bad hash with bad limits is refused. Only
  a hash that passes both reaches libsodium.
- **A hash another thread changed during the call answers `#t`.** Decision 3 stands: the writer
  that copies it into its block answers the change as data, and needs-rehash reads it as a hash
  that is not current (slice 0's review, M3S0-F5).
- **`make-password-limits` checks decision 4's ranges when it is called.** The owner chose this
  on 2026-11-24. A `Password-limits` is always in range. The memory range runs from
  `_memlimit_min` / 1024, rounded up, to `_memlimit_max` / 1024, rounded down.
- **Decision 3, restated:** `password-needs-rehash?` raises only for a caller's mistake, before
  C: a hash that is not a string, `not-a-string`, or limits that are no preset and no
  `Password-limits`, `not-password-limits`. Limits out of range are `make-password-limits`'
  refusal, when they are made (M3C-F3).
- **Decision 5's pre-check is `readable-hash-string?`:** every character is U+0021 to U+007E, so
  there is no U+0000, and there are at most `input-cap` characters. The empty string fails it.

## Amendment, 2026-11-25: the rule as built (M4's plan)

Accepted (the owner, 2026-11-25: "go with A"), proposed in [the M4 plan](../2026-11-25-m4-plan.md),
§2.1, Q1, and §2.2.

- **What it checks, as built.** It answers `#t` when the string fails the pre-check; when it does
  not have item 4's shape; when libsodium cannot read it, which includes any string of
  `strbytes` characters or more; or when its `m` or `t` differ from the limits given. Otherwise
  `#f`.
- **What it never checks:** the salt's or the tag's size, or whether the hash is whole. libsodium
  decodes a tag at whatever length it finds, at 16 bytes or more. Measured at 1.0.18 and 1.0.22
  ([research/m4-plan/b/](../research/m4-plan/b/README.md), D2 and D3, rerun by the caller):
  - an argon2id hash with a 16-byte tag, which `password-hash` never makes, verifies `#t` and
    answers `#f`;
  - a hash with a character appended verifies `#f` and answers `#f`;
  - a hash with its last character dropped verifies `#f`, and answers `#f` about 1 time in 16,
    when the tag's spare bits happen to be zero, at either release.
- **So decision 1's first wording overstated it.** "Not what `password-hash` would make now" read
  wider than decision 2's rules, which are what the code holds. Decision 1 now says what decision 2
  checks.
- **Why not tighten it.** The owner chose to restate the rule:
  - no string check can find a damaged hash, since one changed tag character keeps the shape and
    the length. Only `password-verify`, with the password, can;
  - the tag's size is libsodium's `STR_HASHBYTES`, 32, for which it has no function, so a check
    would write a constant. A release that changed it would make every new hash read as stale;
  - the only gain would be an imported hash in another shape moving to libsodium's at its next
    login. Techo makes every hash it stores with `password-hash`.
- **The login pattern is unchanged, and unaffected.** It asks only after `password-verify`
  answers `#t`, and a damaged hash verifies `#f`.
- **The documents say it:** needs-rehash tells whether a hash was made with today's algorithm and
  limits; it is no check that the hash is intact.
- **Decision 4's "about 55 ms a hash here"** was M3's measurement. M4's pre-work measured medians
  of 49.0 to 50.5 ms on the same machine, and the documents say "about 50 ms here".

[ADR-0001]: 0001-bind-libsodium-directly.md
[ADR-0005]: 0005-the-subset-rule.md
[ADR-0006]: 0006-errors-and-no-secret-shown.md
[ADR-0007]: 0007-one-critical-section-per-verb.md
