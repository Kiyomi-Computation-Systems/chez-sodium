# ADR-0001: Bind libsodium directly, with no C shim, loaded at runtime

- **Status:** Accepted (the owner, 2026-11-22), approved with the brief. Decision 3's integer
  types are brief §11.7. Decision 10's allow-lists amended 2026-11-23, after M1 slice 0's review,
  and accepted by the owner that day; recorded in this form after M1's closing review
  ([amendment](#amendment-2026-11-23-the-allow-lists)).
  Amended 2026-11-23 in M2's plan, and accepted by the owner that day, after M2 slice 0's
  review ([amendment](#amendment-2026-11-23-m2s-plan)).
  Amended 2026-11-24 in M3's plan, and accepted by the owner that day
  ([amendment](#amendment-2026-11-24-m3s-plan)).
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
    `unsigned long long` → `unsigned-64` (brief §7.2; P-F20). Amended: see
    [below](#amendment-2026-11-23-the-allow-lists).

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

## Amendment, 2026-11-23: the allow-lists

Accepted (the owner, 2026-11-23), from M1 slice 0's review, S0-F7. Slice 0 rewrote decision 10
in place; M1's closing review (M1-F9) restored its first text above and moved the change here.

- **Decision 10 joined `size_t` to both allow-lists at once.** v0.1.1's rows, which this
  project keeps, refuse a list that allows a type no row uses, so `size_t` among the results,
  before any row returns one, fails them. Had those rows been dropped instead, the lists could
  allow a type nothing binds.
- **Now each allow-list is exactly what the convention table's rows use:**
  - the argument list is every type a row uses as an argument or as a non-void result, so `int`
    is in it from `sodium_init`'s result, though no M1 row takes an `int`;
  - the result list is every type a row returns, and `void`.
- **Each type joins with the first row that uses it.** In M1 the lists are `(int uptr size_t)`
  and `(int uptr void)`: `size_t` is an argument only, as `sodium_memzero`'s length. `size_t`
  joins the results with M2's first size function, and `unsigned-64` the arguments with
  `crypto_generichash`'s `inlen`.
- **`test-conventions` holds it:** "the types its rows use are exactly the allowlists'".

## Amendment, 2026-11-23: M2's plan

Accepted (the owner, 2026-11-23), proposed in [the M2 plan](../2026-11-23-m2-plan.md), §4.1, items 7
and 8. Item 7 was put to the owner beside the verbs' home, and confirmed with this amendment.

- **Decision 2's sizes are read once, at the load.** Native's last step calls each of
  `crypto_generichash`'s five size functions once and records its answer ([ADR-0002], amended),
  and the verbs check their arguments against the recorded numbers, before their sections, in
  Scheme. A size is fixed for a build of libsodium; a call at each verb would be a C call outside
  the section, or five more inside it.
- **Decision 2 now has a check, by behaviour.** The decoy's `sizes-other` answers 33, 8, 80, 9
  and 81, which no release answers, and whose bounds lie outside the real ones. Through it,
  `blake2b`'s default answer is 33 bytes; sizes 7 and 81 are refused, and 8 and 80 accepted; keys
  of 8 and 82 bytes are refused, and 9 and 81 accepted. A size written in Scheme, in place of the
  read one or beside it, fails one of these.
- **Only `crypto_generichash`'s five sizes are read at the load** by this amendment. M3's
  constants decide their own reading.
- **The recorded sizes are held to the library on every lane:** the C oracle prints each size
  function's answer and its header macro, and `test-native` holds native's numbers to both, and
  to brief §3.4's (row 22). There is no constants half in `test-constants`.
- **The context's "libsodium's headers mark its pointers `nonnull`" is too wide.** At 1.0.18 and
  1.0.22, of M2's six pointers only `randombytes_buf`'s `buf` and `crypto_generichash`'s `out`
  are marked, and `sodium_memzero`'s is not. A NULL with a nonzero length aborts or crashes
  either way, so decision 5 stands (measured,
  [research/m2-plan/](../research/m2-plan/README.md)).
- **The allow-lists grow as the earlier amendment says:** `unsigned-64` joins the arguments with
  `crypto_generichash`'s `inlen`, and `size_t` the results with the first size function.

## Amendment, 2026-11-24: M3's plan

Accepted (the owner, 2026-11-24), proposed in [the M3 plan](../2026-11-24-m3-plan.md), §4.1, items
1 and 6, and §4.2, item 1.

- **M3's constants are read once, at the load.** Step 7 calls each of the fourteen constant
  functions once, after the five sizes, and records its answer ([ADR-0002], amended):
  `crypto_pwhash_strbytes`, `_strprefix`, the five opslimits, the five memlimits, `_passwd_min`
  and `_passwd_max`. The verbs and `make-password-limits` check against the recorded numbers,
  in Scheme, before any section. The prefix is read with `c-string->string`, and a NULL one is
  recorded as `#f` ([ADR-0009], amended).
- **The check, by behaviour.** The decoy's `pwhash-limits-other` answers values no release has,
  each bound inside the real one:
  - `strbytes` 160;
  - ops 2 to 9, presets 5, 6 and 7;
  - memory 16 to 1024 KiB, presets 24, 32 and 40 KiB;
  - passwords 1 to 100 bytes;
  - the prefix `"$argon2i$"`.

  Through it, each bound is refused one past its edge and accepted at it, and each preset hashes
  at the decoy's numbers. `strbytes` is the out block's size, seen in the wipe's
  `sodium_memzero(p,160)` line, and in the decoy's 140-character hash string, which a reader
  bounded by 128 cannot finish. A constant written in Scheme, in place of the read one or beside
  it, fails one of these.
- **Twins of equal value need the decoy.** `opslimit_max` and `passwd_max` both answer
  4294967295 at every release, and their macros are both `4294967295U`. Against a real library,
  native reading one into the other's key passes, and so does the oracle printing one under the
  other's name. So, as M2 did for its sizes, a gated oracle child and `refusal-probe --constants`
  each print the fourteen under `pwhash-limits-other`, asserted whole (slice 0's review,
  M3S0-F7). A macro swapped with its twin cannot be held by any value.
- **The constants are held to the library on every lane.** The oracle prints each function's
  answer and its header macro, and `test-native` holds native's numbers to both (row 22).
  - Measured at 1.0.18 and 1.0.22 on four libraries: each equals its macro, and every memory
    constant is a whole number of KiB ([research/m3-plan/](../research/m3-plan/README.md)).
- **`_passwd_min` and `_passwd_max` are bound and checked,** as brief §3.1 lists them. The owner
  chose this on 2026-11-24. At every release measured they are 0 and 4294967295, so today the
  cap is the bound that binds. The check matters if a release raises the minimum: an empty
  password would otherwise reach `crypto_pwhash_str` and come back as a memory failure.
- **The convention table's `CONVENTION` column, empty for every earlier row, names it.**
  - `crypto_pwhash_str` and `crypto_pwhash_str_verify` are the first two `__collect_safe`
    bindings. A binding whose convention differs from its row fails by name, and row 19 holds
    them by behaviour.
  - The allow-lists gain no type.
  - Chez accepts a `u8*` argument under `__collect_safe` without a word, and refuses only
    `string` and `utf-8` (measured), so the allow-lists, not Chez, keep `u8*` out.
- **Every pointer of the three password calls is `nonnull`,** at both releases, so the compile
  holds decision 5 for each of them.

[ADR-0002]: 0002-runtime-discovery-and-the-sonames.md
[ADR-0003]: 0003-libsodium-floor-1-0-18.md
[ADR-0007]: 0007-one-critical-section-per-verb.md
[ADR-0008]: 0008-every-block-wiped-before-free.md
[ADR-0009]: 0009-what-needs-rehash-means.md
[ADR-0011]: 0011-the-harness-after-chez-sqlite3.md
