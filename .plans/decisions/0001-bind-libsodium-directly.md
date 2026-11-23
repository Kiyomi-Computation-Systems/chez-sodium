# ADR-0001: Bind libsodium directly, with no C shim, loaded at runtime

- **Status:** Accepted (the owner, 2026-11-22), approved with the brief. Decision 3's integer
  types are brief §11.7.
- **Date:** 2026-11-22
- **Scope:** chez-sodium: every binding to libsodium
- **Settles:** [brief](../2026-11-22-chez-sodium-project-brief.md) §2, §3.4, §6.1 and §6.4
- **Related:** chez-sqlite3 ADR-0001 and chez-sqlite3 ADR-0011, which this follows ·
  [ADR-0002] (loading) · [ADR-0003] (the floor) · [ADR-0007] (the section and the cap) ·
  [ADR-0008] (the wipe)

## Context

- **libsodium gives every constant as a function:** `crypto_pwhash_strbytes()`, the limits,
  `crypto_generichash_bytes()` and the rest. Nothing needs a header at build time (brief §2).
  That is chez-sqlite3's shape, not chez-libuv's, which keeps a C shim.
- **Every signature was read in libsodium 1.0.18's headers.** The host's 1.0.18,
  `libsodium.so.23`, exports every function bound, and none is a macro (brief §3.4).
- **libsodium's headers mark its pointers `nonnull`.** At runtime it accepts NULL with a length
  of 0, and aborts the process on NULL with a nonzero length (brief §3.4; L-F8).
- **An opslimit comes back as `size_t` and is passed as `unsigned long long`** (brief §3.4).
- **The siblings differ on Scheme memory** (X-m2). chez-libuv's rule 3 passes `u8*` to plain
  calls, and its rule 4 bans Scheme memory only in collect-safe ones. chez-sqlite3 ADR-0011 bans
  it in every call: Chez accepts `u8*` in a collect-safe call without a word, and a collection
  can move the bytevector during the call.
- **argon2 runs long.** On the development machine, hash and verify each take about 55 ms at
  `'interactive`, 0.3 s at `'moderate` and 1.8 s at `'sensitive` (brief §6.4; L-F12). A plain
  call holds every other thread's collection for as long as it runs.

## Decision

1. **No C shim; nothing is compiled at install.** Every binding is a `foreign-procedure` in a
   `(chez-sodium private …)` library, evaluated after libsodium loads ([ADR-0002]).
2. **Every constant is read through libsodium's own function for it.** None is written in
   Scheme.
3. **A binding uses the type C names** (brief §11.7): `size_t` for `size_t`, as argument and as
   result; `unsigned-64` for `unsigned long long`; `uptr` for every pointer. So an opslimit is
   read as `size_t` and passed as `unsigned-64`.
4. **No Scheme object crosses into C.** Every buffer is copied into a counted foreign block, and
   every pointer is a `uptr`: never `u8*`, `string`, `utf-8` or a bytevector. One rule covers
   plain and collect-safe calls alike, as chez-sqlite3 ADR-0011's decision 1 has it.
   [ADR-0007]'s cap is its cost.
5. **No pointer is NULL,** even with a length of 0. An empty input gets a block of at least one
   byte (brief §3.4; P-F6).
6. **Every value fits its C type, checked before C** (X-m1). `int` is C's range; `size_t` and
   `unsigned-64` run from 0 to 2⁶⁴−1. A length is never longer than its block. Chez's `int`
   takes 2³¹ to 2³²−1 and hands them to C as negatives, and `size_t`, `unsigned-64` and `uptr`
   take −1 as 2⁶⁴−1.
7. **`crypto_pwhash_str` and `crypto_pwhash_str_verify` are `__collect_safe`.** Every other call
   is plain, bounded by [ADR-0007]'s cap. Tier 2's calls follow the same rule.
8. **No `lock-object` for data.**
9. **One library holds `foreign-procedure`, and one holds `foreign-alloc`,** so `check-seam` can
   read the seam.
10. **Every binding has a row in a convention table** (X-M6). `test-conventions` holds each
    `foreign-procedure` form to its row. `test-constants`' prototype half compiles against
    `sodium.h` and holds each row's prototype to the header. `size_t` joins both allow-lists,
    for arguments and for results, and the prototype map gains `size_t` → `size_t` and
    `unsigned long long` → `unsigned-64` (brief §7.2; P-F20).

### Rejected

- **A C shim, as chez-libuv has.** Nothing here needs a header at build time.
- **chez-libuv's rule 3,** `u8*` for plain calls. This project takes chez-sqlite3's stricter
  rule, and pays for it with the cap (brief §6.1).
- **`unsigned-long-long`.** Both types are 8 bytes here, so the choice is for the checks, and
  chez-sqlite3's lists already hold `unsigned-64` (brief §11.7).
- **`lock-object` instead of copying.** Every raising path would need an unlock, and a missed
  one is invisible (chez-sqlite3 ADR-0011, "Rejected").

## Consequences

- **A binding with the wrong convention fails by name.** A binding and its row written wrong
  alike pass `test-conventions`, and fail the header check (X-M6).
- **A row confirms every return code brief §3.4 states against the real library,** before code
  relies on it (brief §8.1, row 22).
- **`randombytes_buf`'s bound, `randombytes_BYTES_MAX`, is a macro only** (brief §3.4).
  [ADR-0007]'s cap bounds `random-bytes`.
- **A collect-safe call costs about 55 ns, a plain one about 13 ns** (brief §6.4).
- **Every input costs one counted block and one copy** ([ADR-0011]), and every block is wiped
  before it is freed ([ADR-0008]).

[ADR-0002]: 0002-runtime-discovery-and-the-sonames.md
[ADR-0003]: 0003-libsodium-floor-1-0-18.md
[ADR-0007]: 0007-one-critical-section-per-verb.md
[ADR-0008]: 0008-every-block-wiped-before-free.md
[ADR-0011]: 0011-the-harness-after-chez-sqlite3.md
