# ADR-0008: Every block is wiped before it is freed, and the binding keeps no Scheme copy of a secret

- **Status:** Accepted (the owner, 2026-11-22), brief §11.2. Decisions 3 and 4, no Scheme copy,
  are brief §11.5.
- **Date:** 2026-11-22
- **Scope:** every foreign block chez-sodium frees, and every secret it copies into C
- **Settles:** [brief](../2026-11-22-chez-sodium-project-brief.md) §6.3, §11.2, §11.5's "no
  Scheme copy", and §4.1's password encoding
- **Related:** chez-sqlite3 ADR-0011 (counted blocks) · [ADR-0005] (guarded memory, out) ·
  [ADR-0007] (the cleanup runs inside the section) · [ADR-0011] (the `block` counter)

## Context

- **A wrapper's wipe runs after the free** (X-B1). By the time a wrapper's cleanup runs,
  `call-with-block` has freed the block. In the review's model the wipe came after the free in
  51 of 51 runs, and wiping freed memory corrupted glibc's heap and aborted the process.
- **A wipe inside the callback misses an escape** (X-B1). An engine's expiry freed the block
  unwiped in 24 of 52 runs. The wipe fused with the free was clean in 28 of 28
  (`ffi/p06-secret-wipe-model.sps`).
- **A list of secret blocks leaves gaps.** The brief's first draft wiped the password's block
  alone, and freed other secrets unwiped (L-F4, X-M8).
- **chez-sqlite3's `call-with-bytes` copies a caller's bytevector with `bytevector-copy`**
  before it reaches a block. That copy is the binding's own, and nothing wipes it (L-F4).

## Decision

1. **The wipe sits in `call-with-block`'s critical cleanup, just before
   `free-foreign-block!`:** one plain `sodium_memzero` call over the block's size. Never in a
   wrapper, never inside the callback, and never as a `foreign-set!` loop, which would cost as
   much as the copy.
2. **Every block the library frees is wiped, secret or not:** the password, the hash string and
   keys; random bytes; `blake2b`'s input and output; `constant-time-bytevector=?`'s operands;
   the HMAC key and state. One rule means there is no list of which blocks are secret, and one
   test covers all of them.
3. **A password is hashed as its UTF-8 bytes, exactly as given** (brief §4.1). The binding never
   normalises it; Techo decides whether to, before it calls. Its UTF-8 is written straight into
   its block, character by character, and no Scheme bytevector holds it.
4. **The block helper copies a caller's bytevector straight into its block,** without
   `call-with-bytes`' `bytevector-copy`. A bytevector's length cannot change, so reading it in
   place is memory-safe. A caller who changes the bytes from another thread meanwhile hashes
   what it wrote.
5. **The documents say what wiping cannot reach:**
   - the caller's own copies: the password string, the HTTP body, a JSON parser's strings;
   - the bytevectors the verbs return: the key `random-bytes` returns is the key;
   - copies the collector leaves behind.

   `string-fill!` wipes a mutable string in place, but not those copies.

### Rejected

- **Wiping the password's block alone** (brief §11.2).
- **Guarded memory:** `sodium_malloc`, `sodium_mprotect_*`, `sodium_mlock`. It needs a design
  of its own, and the copies decision 5 names defeat it anyway (brief §3.3).

## Consequences

- **The wipe costs next to nothing:** 3 ns for 32 B, 19 ns for 4 KiB, 15 µs for 1 MiB. That is
  about 2% of BLAKE2b over the same bytes, plus about 13 ns for the foreign call.
- **It is hygiene for the C heap, not a guarantee.** It limits what a crash dump, swap, or
  another C library's over-read can expose.
- **One row holds it** (brief §8.1, row 24; X-m6): a child process with a preloaded `free()`
  interposer finds that every block the library frees reads all zeros. It runs outside
  Valgrind, whose allocator bypasses the interposer ([ADR-0011]).
- **Rows 3 and 12 hold the password's encoding:** a non-ASCII password whose last character
  changes verifies false (P-F5), and `"a\x0;b"` verifies against its own hash and not `"a"`'s.

[ADR-0005]: 0005-the-subset-rule.md
[ADR-0007]: 0007-one-critical-section-per-verb.md
[ADR-0011]: 0011-the-harness-after-chez-sqlite3.md
