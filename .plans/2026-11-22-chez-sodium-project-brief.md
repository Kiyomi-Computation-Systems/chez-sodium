# Brief: chez-sodium, a small libsodium binding for Chez Scheme

Date: 2026-11-22

Status: draft, revised after an adversarial review on 2026-11-22.
- §11 records the owner's decisions.
- [The review](research/brief-review/review.md) records every finding, its evidence, and
  where this brief answers it. Findings are cited by ID: (L-F1), (X-B1), (P-F1).

For: Techo's accounts and API keys, and later its attachments.

Read against:
- chez-sqlite3 v0.1.1 (`960d9f0`) at `../chez-sqlite3`, the pattern to copy;
- chez-libuv at `9226698` (four commits past v0.11.0, which is `afe79a5`), at
  `../chez-libuv`, for its FFI rules.

**libsodium's behaviour here was read in its source, at 1.0.18 and 1.0.22, and probed
in C against 1.0.18** during the review. Every C signature was read in 1.0.18's headers.
**A suite row still confirms each return code against the real library before code
relies on it** (§8.1, row 22).

## 1. Why

Techo needs three things Chez does not have:

1. a slow, salted password hash (argon2id);
2. random bytes from the system, for API keys;
3. a fast hash, to store API keys without storing the keys.

The library adds one general verb that Techo v1 does not use: a comparison that does
not leak where two byte strings differ (§3.1).

libsodium has all of these, is packaged everywhere, and is hard to misuse. No Chez
binding was found; the only Scheme one is a work in progress for CHICKEN.

## 2. Shape: copy chez-sqlite3

**No C shim. The system's libsodium is loaded when the program runs.** libsodium gives
every constant as a function (`crypto_pwhash_strbytes()` and the rest), so nothing needs
a header at build time. That is chez-sqlite3's shape, not chez-libuv's.

**The library is far smaller than chez-sqlite3.**
- libsodium's calls here are stateless: bytes in, bytes out.
- There is no handle to own, no thread to belong to, and no statement to track.
- Tier 2 keeps this so: `hmac-sha256` is one call, and streaming SHA-256 is out (§3.2).

## 3. The subset

A function is in only if Techo has a named use for it. Each one added is more to test
on every libsodium version. `constant-time-bytevector=?` is the one exception, by
decision (§11.4).

### 3.1 Tier 1: Techo v1

| C function | Scheme verb | Use |
|---|---|---|
| `sodium_init` | none; run at load | libsodium needs it before every call but the version functions (§3.4) |
| `sodium_version_string`, `sodium_library_version_major`, `_minor` | `sodium-version` | the load's floor check, from the string (§7.2), and a report for bug reports |
| `crypto_pwhash_str` | `password-hash` | hash a password at account creation and at a password change |
| `crypto_pwhash_str_verify` | `password-verify` | check a login |
| `crypto_pwhash_str_needs_rehash`, `crypto_pwhash_strprefix` | `password-needs-rehash?` | at login, re-hash a hash that is not what `password-hash` would make now (§4.2) |
| `crypto_pwhash_strbytes`, `_opslimit_*`, `_memlimit_*`, `_passwd_min`, `_passwd_max` | the limits | ranges, and the three presets: interactive, moderate, sensitive |
| `randombytes_buf` | `random-bytes` | make an API key |
| `crypto_generichash`, with `_bytes`, `_bytes_min`, `_bytes_max`, `_keybytes_min` and `_keybytes_max` (ADR-0005, amended) | `blake2b` | store an API key as its BLAKE2b hash |
| `sodium_memcmp` | `constant-time-bytevector=?` | general: compare a secret or a MAC in constant time. Techo v1 has no such compare (§11.4). |
| `sodium_memzero` | none; used inside | wipe every block before it is freed (§6.3) |

Why these and not their neighbours:

- **`crypto_pwhash_str`, not `crypto_pwhash`.** The `_str` form picks the salt and
  writes the algorithm, salt and limits into one ASCII string. There is nothing for a
  caller to get wrong, and `needs-rehash` can read the limits back.
- **`crypto_generichash`, not SHA-256, for keys.** It is libsodium's recommended hash.
  A fast hash is right for an API key, which is long and random; a slow one would tax
  every request.
  - Unkeyed is enough. A pepper is not warranted: anyone who can write the database can
    already replace the password hashes, which have none either.
  - What makes a fast hash safe is the key's entropy, at least 128 bits. Techo makes 32
    random bytes (Techo ADR-0006, amendment proposed).
- **`sodium_memzero` is internal.** The library wipes every block it frees (§6.3).
- **`constant-time-bytevector=?` is kept without a Techo use.** Techo looks a key up
  by its hash, which needs no constant-time compare (Techo ADR-0006, amendment
  proposed). But the first time a Techo developer compares a raw secret or a MAC, the
  verb at hand would otherwise be `bytevector=?`, which is not constant time. One
  binding and a few rows are cheap insurance.
- **The two verbs are named for what they are, not for libsodium's calls** (§11.7).
  - `blake2b`, not libsodium's `generic-hash`: Techo keeps these hashes for good, so
    the name says which algorithm made them. Row 1's vectors hold it to BLAKE2b on
    every version run.
  - `constant-time-bytevector=?`, not `bytes=?`: Racket's `bytes=?` and Chez's
    `bytevector=?` are plain equality. This verb's one point is that it isn't.

### 3.2 Tier 2: Techo's attachments, later

Specified now so the design leaves room; built when Techo needs it.

| C function | Scheme verb | Use |
|---|---|---|
| `crypto_hash_sha256` | `sha256` | a blob's content address; the hash of a signed request's canonical form |
| `crypto_auth_hmacsha256_init`, `_update`, `_final`, `_statebytes` | `hmac-sha256` | sign S3 requests (AWS Signature Version 4) |

- **`hmac-sha256` is one call:** `hmac-sha256 : Bytevector Bytevector -> Bytevector`,
  taking the key and the message.
  - It runs `_init`, `_update` and `_final` inside one call, in one section (§6.2).
  - Its state is a block like any other, wiped before it is freed (§6.3), so there is no
    handle. `_final` wipes the state itself; the block wipe covers every other path,
    since an abandoned state holds key material (L-F13).
- **Not the one-shot `crypto_auth_hmacsha256`.** It takes a key of a fixed 32 bytes.
  Signature Version 4's first key is `"AWS4"` plus a 40-character secret, which is 44
  bytes; later keys are 32 bytes. AWS's published example was reproduced through
  `_init`, `_update` and `_final`.
- **A key over 64 bytes is pre-hashed** by `_init`. RFC 4231's cases 6 and 7 test that
  path.
- **At 1.0.18, `_init` declares its key `nonnull`.** An empty key is passed as a
  one-byte block (§3.4).
- **Inputs are capped (§4.4).** Tier 2 revisits the cap and the copy method, since a
  blob can be large.

### 3.3 Out

| Left out | Why |
|---|---|
| Secret-key and public-key encryption, signatures, key exchange, AEAD, streams | Techo encrypts nothing itself. TLS is the proxy's. |
| Streaming SHA-256: `crypto_hash_sha256_init`, `_update`, `_final` as verbs | No use: clients upload straight to the store (Techo ADR-0010), and signing hashes only a short canonical request. Its state would be a handle, with the ownership and wiping that brings (X-M7, L-F13). It comes back, with a design for its state, if a use appears. |
| `crypto_pwhash` as a key-derivation function, scrypt, `crypto_pwhash_str_alg` | No use. |
| `sodium_malloc`, `sodium_mprotect_*`, `sodium_mlock` | Guarded memory needs a design of its own, and the Scheme copies of §6.3 defeat it anyway. |
| Hex and base64 helpers | Plain Scheme does these. |
| `randombytes_uniform`, `randombytes_random` | No use; `random-bytes` covers keys. |
| Short hashes, one-time auth, `crypto_verify_*` | No use. |

### 3.4 The C functions at the floor

- **Signatures** were read in libsodium 1.0.18's headers (Guix's build,
  `include/sodium/*.h`).
- **Behaviour** was read in the source at 1.0.18 and 1.0.22, and probed against 1.0.18
  (review, `libsodium/` and `verify/`).
- The host's `/lib/x86_64-linux-gnu/libsodium.so.23` (Ubuntu 22.04's package, 1.0.18)
  exports each one. Chez binds every row: no macro is used.

| C function | Signature | Behaviour |
|---|---|---|
| `sodium_init` | `int (void)` | 0 the first time, then 1; -1 only if its mutex fails. Thread-safe. **1 is not a failure.** |
| `sodium_version_string` | `const char *(void)` | `"1.0.18"`. Answers before `sodium_init`. |
| `sodium_library_version_major`, `_minor` | `int (void)` | libtool numbers, not the release: 10.3 at 1.0.18; 26.1 to 26.4 at 1.0.19 to 1.0.22 (L-F14). Answer before `sodium_init`. |
| `crypto_pwhash_str` | `int (char out[STRBYTES], const char *passwd, unsigned long long passwdlen, unsigned long long opslimit, size_t memlimit)` | 0; or -1 for limits out of range or no memory, with `out` zeroed. All of `out` is written either way: the string and zeros after it, or zeros (M3 plan §5.1). Memory is floored to whole KiB. `nonnull` on every pointer. |
| `crypto_pwhash_str_verify` | `int (const char str[STRBYTES], const char *passwd, unsigned long long passwdlen)` | 0 on a match. -1 for a wrong password, a string it cannot parse, **and no memory**: at 1.0.18 errno reads `EINVAL` either way (L-F2). At 1.0.22 errno reads `ENOMEM` for no memory, which the binding does not read (M3 plan §4.2, item 4). `str` is an array of `STRBYTES` at 1.0.18 and a pointer at 1.0.22, `nonnull` at both. Reads `str` to its first NUL, and refuses any byte after the hash (L-F1). Costs what the string's own t and m say. |
| `crypto_pwhash_str_needs_rehash` | `int (const char str[STRBYTES], unsigned long long opslimit, size_t memlimit)` | 0 when t and m/1024 match; 1 when either differs, lower or higher; -1 when it cannot parse the string, even a long one verify accepts, and for any string of `strbytes` characters or more, a salt or tag of the wrong length, or ops above 2³²−1. Ignores the algorithm, since it dispatches on the prefix: an argon2i hash at ops 3 or more answers 0. Ignores p where the string decodes: `p=4` at 32 KiB or more answers 0 (L-F6; M3 plan §5.1). A byte of 0x80 or more in the salt answers 0 at 1.0.18 and -1 at 1.0.22. |
| `crypto_pwhash_strprefix` | `const char *(void)` | `"$argon2id$"` at 1.0.18 and 1.0.22: the default algorithm's prefix |
| `crypto_pwhash_strbytes`, `_opslimit_{min,max,interactive,moderate,sensitive}`, `_memlimit_{min,max,interactive,moderate,sensitive}`, `_passwd_min`, `_passwd_max` | `size_t (void)` | At 1.0.18: ops 1 to 2³²−1; memory 8192 to 4398046510080 bytes; password 0 to 2³²−1 bytes; `strbytes` 128. The presets are interactive (2, 64 MiB), moderate (3, 256 MiB) and sensitive (4, 1 GiB). **An opslimit comes back as `size_t` and is passed as `unsigned long long`;** every value fits both. The same at 1.0.22, each equal to its header macro, and every memory constant a whole number of KiB (M3 plan §5.1). |
| `randombytes_buf` | `void (void *buf, size_t size)` | Backed by `getrandom`, with no state, so safe across threads and `fork`. `nonnull` even at size 0. Aborts if no entropy source is available. Its bound, `randombytes_BYTES_MAX`, is a macro only: 2³²−1 at 1.0.18 and 1.0.22. |
| `crypto_generichash` | `int (unsigned char *out, size_t outlen, const unsigned char *in, unsigned long long inlen, const unsigned char *key, size_t keylen)` | 0; or -1 for an output of 0 or over 64 bytes, or a key over 64. **Accepts sizes and keys of 1 to 15 bytes**, below the published 16. A key of length 0 gives the unkeyed hash, whatever its block holds. A -1 leaves `out` as it was. A NULL key or input with a nonzero length aborts (L-F8), though the header marks only `out` `nonnull` (M2 plan §5.1). |
| `crypto_generichash_bytes`, `_bytes_min`, `_bytes_max`, `_keybytes`, `_keybytes_min`, `_keybytes_max` | `size_t (void)` | 32, 16, 64; 32, 16, 64. `_keybytes` is not bound: it has no use (ADR-0005, amended). |
| `sodium_memcmp` | `int (const void *b1, const void *b2, size_t len)` | 0 equal, -1 different, in constant time, and never another answer; 0 at length 0. No `nonnull`; NULL with a nonzero length crashes (M2 plan §5.1). |
| `sodium_memzero` | `void (void *pnt, size_t len)` | |
| `crypto_hash_sha256` | `int (unsigned char *out, const unsigned char *in, unsigned long long inlen)` | |
| `crypto_auth_hmacsha256_init`, `_update`, `_final`; `_statebytes` | `int (state *, const unsigned char *key, size_t keylen)`; `int (state *, const unsigned char *in, unsigned long long inlen)`; `int (state *, unsigned char *out)`; `size_t (void)` | The state is 208 bytes with 8-byte alignment, which a `malloc`'d block meets. `_final` wipes it. `key` is `nonnull` at 1.0.18. |

What this changes in the brief:

- **A password may hold U+0000.** `passwd` comes with its length.
- **A hash string may not, and its block ends in a 0.** libsodium reads it as a C
  string, so it would judge `"<good hash>\0junk"` as the good hash (§4.1).
- **No pointer is ever NULL.**
  - At runtime, libsodium accepts NULL with a length of 0, but some headers say
    `nonnull`: of M2's six pointers, `randombytes_buf`'s and `crypto_generichash`'s `out`
    (M2 plan §5.1).
  - NULL with a nonzero length aborts the process, or crashes it.
  - So every pointer is a block of at least one byte (§6.1).
- **Every Tier 1 call is thread-safe once `sodium_init` has run.**

## 4. The public API

```scheme
;; sodium-version : -> String

;; password-hash : String [Limits] -> String
;; password-verify : String String -> Boolean            ; hash, password
;; password-needs-rehash? : String [Limits] -> Boolean    ; hash
;; Limits is (U 'interactive 'moderate 'sensitive Password-limits); the default is 'interactive
;; make-password-limits : Nat Nat -> Password-limits      ; ops, memory in KiB

;; random-bytes : Nat -> Bytevector
;; blake2b : Bytevector [Nat] [Bytevector] -> Bytevector   ; input, size, key
;; constant-time-bytevector=? : Bytevector Bytevector -> Boolean
```

- The names are decided (§11.5, §11.7). None clashes with a name `(chezscheme)`
  exports. They carry no prefix, as chez-sqlite3's carry none. A user who wants one
  adds it on import: `(import (prefix (chez-sodium) sodium:))`.
- Every exported procedure has a Typed Racket style signature comment, and
  `docs/reference.md` is held to them by a test, as chez-sqlite3's is.

### 4.1 Passwords

- **A password is a string, hashed as its UTF-8 bytes, exactly as given.** The binding
  does not normalise it; Techo decides whether to, before it calls. Its UTF-8 is
  written straight into its block, and no Scheme bytevector holds it (§6.3).
- **Custom limits are made by `make-password-limits`, with memory in KiB** (§11.5).
  - KiB is the unit of argon2's own strings, of OWASP's guidance and of other argon2
    libraries.
  - In bytes, OWASP's `m=19456` would silently give a hash at 19 KiB, about 1000 times
    weaker. `password-needs-rehash?` would then call it current (L-F3).
  - In KiB, nothing is floored.
  - The ranges are checked by `make-password-limits`, when it is called: ops from
    `_opslimit_min` to `_opslimit_max`; memory from `_memlimit_min` to `_memlimit_max`,
    divided by 1024, the least rounded up and the greatest rounded down (ADR-0009, amended).
- **A password's UTF-8 length runs from 0 to the cap,** then from `_passwd_min` to
  `_passwd_max`, each checked before C (ADR-0007, amended).
- **`password-verify` answers `#f` in three cases, which libsodium does not tell apart:**
  - a wrong password;
  - a hash it cannot read;
  - libsodium could not get the memory the hash asks for (L-F2).

  The documents say so.
- **A hash's own limits decide what verifying it costs.** A tampered row could ask for
  hours of work or terabytes of memory. Hashes must come from trusted storage, and the
  documents say so (L-F10).
- **A hash string is checked before C:** printable ASCII (U+0021 to U+007E), with no
  U+0000, and no longer than the cap (§4.4).
  - One that fails gets `#f` from `password-verify` and `#t` from
    `password-needs-rehash?`, without reaching C.
  - Without the check, `"<good hash>\0junk"` would verify as the good hash.
  - The check sets no limit tied to `crypto_pwhash_strbytes()`: libsodium verifies
    longer hashes (L-F7).
- **The hash string's block holds its bytes and a terminating 0** (L-F1).

### 4.2 `password-needs-rehash?`

**What `#t` means:** this hash is not what `password-hash` would make now, at these
limits. The caller replaces it, using the password it has just verified.

It answers `#t` when any of these holds:

1. **The limits differ.** libsodium answers 1 because t or memory differs from the
   limits given, higher or lower.
2. **libsodium cannot read the hash.** It answers -1: the string is corrupt, truncated,
   or made elsewhere with a salt or tag it does not parse. Such a hash can still verify
   (L-F7).
3. **The string fails the pre-check** of §4.1.
4. **The algorithm or parallelism differs.** The string does not begin with
   `crypto_pwhash_strprefix()`, or its parameters do not read `p=1`. libsodium ignores
   both, so without this an argon2i hash, or a hash with p=4, at the same limits would
   read as current (L-F6, P-F17).

It answers `#f` only when libsodium answers 0 and the string passes items 3 and 4.

It never raises because of the hash, even one another thread changes during the call, which
answers `#t`. It raises only for a caller's mistake, before C: a hash that is not a string, or
limits that are no preset and no `Password-limits`. `make-password-limits` refuses limits out
of range when it is called (ADR-0009, amended).

**Call it only after `password-verify` answers `#t`.** The documents show the login
pattern:

```scheme
(if (password-verify hash password)
    (begin
      (when (password-needs-rehash? hash)
        (store-hash! account (password-hash password)))
      (log-in account))
    (refuse))
```

- **Why the order matters.** A caller that re-hashes on `#t` without verifying first
  stores a password nobody verified. The documents say so in those words.
- **That bug belongs to the order, not to this answer.** After the limits rise, every
  valid hash answers `#t` too. Raising on an unreadable hash would have protected only
  corrupt rows from that bug. It would also have locked out a user whose right password
  verified against an imported hash (§11.1).
- **A batch job** that checks stored hashes without passwords gets `#t` for stale and
  unreadable hashes alike. Both read as "replace at the next login". If a job ever
  needs to tell them apart, that is a new verb with three answers, not a raise.
- **libsodium's default algorithm** is argon2id at 1.0.18 and 1.0.22.
  `password-hash` uses whatever the library's default is. `password-needs-rehash?`
  reads the expected prefix from that same library, so if a future release changes the
  default, every older hash answers `#t` and is migrated at its next login. A test
  shows a string with another prefix answering `#t` (§8.1, row 8).
- **Memory is compared in whole KiB**, which the KiB unit of §4.1 makes exact.

### 4.3 Random bytes, the fast hash, and the compare

- **`random-bytes n`.**
  - `n` runs from 0 to the cap (§4.4).
  - At 0 it answers `#vu8()` without calling C.
  - The block that held the new key is wiped once the key is copied out. The returned
    bytevector is the key itself, and is the caller's.
- **`blake2b input [size] [key]`.**
  - The size defaults to `crypto_generichash_bytes()` (32) and must be from
    `_bytes_min` to `_bytes_max` (16 to 64), checked before C, since C accepts 1 to 15.
  - A key, when given, must be from `_keybytes_min` to `_keybytes_max` (16 to 64) bytes.
    **An empty key is an assertion violation**, so a pepper read from an unset
    variable cannot silently mean no key (L-F8).
  - With no key, the binding passes a one-byte block with a length of 0, never NULL.
- **`constant-time-bytevector=? a b`.**
  - Different lengths answer `#f` at once, once each operand is within the cap (§4.4;
    ADR-0007, amended). Equal lengths go to `sodium_memcmp` over the whole length, in
    constant time.
  - Only the lengths leak. It is not an ordering.
  - It is general: Techo v1 does not use it.

### 4.4 The input cap

- **Every byte or string input, and `random-bytes`' output, is at most 64 KiB**
  (§11.5), counted in bytes: a string counts its UTF-8 bytes. Above that is a caller's
  mistake, raised before C.
  - **The hash string is the exception.** One over the cap fails the pre-check, and is
    answered, not raised (§4.1, §4.2).
- **Why a cap.** Each verb's whole extent runs in one critical section (§6.2), and
  Scheme's copy loops there hold up every thread's collection. A byte-by-byte copy
  costs about 30 ms per MiB (X-M4), so 64 KiB keeps a section's copying near 2 ms.
- **Tier 1's inputs are far smaller:** a password, a 32-byte key, a hash string of
  about 100 characters.
- **The cap bounds the plain calls too** (§6.4): BLAKE2b over 64 KiB takes about
  50 µs, and 64 KiB of random bytes about 0.1 ms.
- **Tier 2 revisits it**, since a blob can be large. The options then:
  - a word-by-word copy, about 5 ms per MiB (X-M4);
  - a plain `memcpy` that takes the bytevector itself. chez-libuv's rule 3 allows this;
    chez-sqlite3's rule does not (§6.1).

## 5. Errors

Smaller than chez-sqlite3's tree, with the same shape and helpers.

```
&error
 └ &chez-sodium-error
    ├ &sodium-library-unavailable    reason path source detail candidates
    └ &sodium-failed                 function code
```

- **The reasons a library is unavailable:** `invalid-override`, `not-found`,
  `load-failed`, `below-floor`, `missing-api`, `init-failed`.
  - A decoy library reaches `below-floor`, `missing-api` and `init-failed`.
  - The other three need no decoy, as in chez-sqlite3 (P-F12):
    - `invalid-override`, from a bare name in the override;
    - `load-failed`, from a text file or a missing path;
    - `not-found`, from discovery's own tests with made-up inputs.
- **`init-failed` is `sodium_init` answering anything but 0 or 1** (ADR-0002, amended). An
  answer of 1 means libsodium was already initialised, and the load goes on.
- **`below-floor` covers a version string the load cannot read:** NULL, or a string that
  is not three naturals (ADR-0003, amended).
- **`&sodium-failed` has two cases** (ADR-0006, amended):
  - `crypto_pwhash_str` answering anything but 0 for limits that passed their range check,
    which means it could not get the memory (ADR-0006, amended in M3's plan), or answering 0
    but leaving no readable string, with code 0, which only a decoy does;
  - `crypto_generichash` answering -1 for a size and key that passed theirs, which no
    release does: a decoy reaches it.

  Its fields are `function` and `code`, with the verb as its `&who`. It carries no secret.
  `crypto_generichash`'s case is any answer but 0 (ADR-0006, amended).
- **What is not a condition** (L-F2). The documents say so:
  - `password-verify`'s -1 for no memory reads as `#f` (§4.1).
  - **In a container with a memory limit, a hash that asks for more than is left gets
    the process killed** by the kernel's OOM killer. argon2 touches its pages as it
    takes them, so libsodium never sees a failure. Size a container for the memory
    limit times the number of hashes that can run at once: 64 MiB each at
    `'interactive`.
  - libsodium aborts the process on misuse, a NULL pointer with a nonzero length, and
    when no entropy source is available. The binding's checks rule out the misuse.
- **A caller's mistake is an assertion violation, raised before C.** The mistakes are:
  - a wrong type;
  - a size, key length or limit out of range;
  - an input over the cap, except a hash string, which is answered (§4.1);
  - a password outside libsodium's length range;
  - an empty key;
  - a password, or `password-verify`'s hash, that another thread changed during the call,
    refused after the section (ADR-0006, amended).
- **No secret ever reaches a condition** (L-F9, P-F8).
  - **Every string and bytevector parameter is secret:**
    - a password and a hash string;
    - `blake2b`'s input, which is Techo's API key, and its key;
    - `constant-time-bytevector=?`'s operands;
    - Tier 2's inputs and HMAC key.
  - A refusal of a secret parameter names the parameter and its kind only, whatever the
    value's type.
  - chez-sqlite3's `shown-value` shows numbers, symbols, characters and lists of them
    as they are. It is used only for sizes, limits and preset names.
- **Raised after the section** (X-M2). A verb's critical section answers data, and the
  verb raises only once it is out (§6.2).
- Tests assert the reason symbol, never the message.

## 6. FFI rules

### 6.1 The rules

These come from the siblings, and each was paid for with a bug, or from this brief's
review. Each row names its record.

| Rule | Why | From |
|---|---|---|
| No Scheme object crosses: every buffer is copied into a counted foreign block, and every pointer is a `uptr`. | A collection can move a bytevector during a collect-safe call. Chez accepts `u8*` there without a word, though it refuses `string` and `utf-8`. | chez-sqlite3 ADR-0011, decision 1. chez-libuv is looser: its rule 3 passes `u8*` to plain calls, and its rule 4 bans Scheme memory only in collect-safe calls. This project takes chez-sqlite3's rule, and §4.4 is its cost (X-m2). |
| A call that can block or run long is `__collect_safe`. | A plain call holds every other thread's collection for as long as it runs. | chez-sqlite3 ADR-0011 |
| No `lock-object` for data. | Every raising path would need an unlock, and a missed one is invisible. | chez-sqlite3 ADR-0011, "Rejected" |
| Every value fits its C type, checked before C. `int` is C's range; `size_t` and `unsigned-64` run from 0 to 2⁶⁴−1. A length is never longer than its block, and no pointer is NULL. | Chez's `int` takes 2³¹ to 2³²−1 and hands them to C as negatives. `size_t`, `unsigned-64` and `uptr` take −1 as 2⁶⁴−1. A NULL pointer with a nonzero length aborts the process (X-m1). | chez-sqlite3 `.plans/traps.md` |
| Each verb's extent is one critical section that answers data; the verb raises after it. | §6.2 | chez-sqlite3 global constraints and ADR-0012, for the parts that raise; this brief, for the whole extent |
| Every block is wiped before it is freed, inside the block helper. | §6.3 | this brief |
| Only one library holds `foreign-procedure`; only one holds `foreign-alloc`. | So a check can read the seam. | chez-sqlite3 `make check-seam` |
| Every binding has a row in a convention table, and a test compares the two. A compiled prototype check holds the table to `sodium.h`. | A binding with the wrong convention fails by name. A binding and its row written wrong alike pass the first check, but not the second (X-M6). | chez-sqlite3 `tests/test-conventions.sps`, `tests/test-constants.sps` |
| The load runs once, and a failure is remembered and raised again. | Chez wedges on a library body that failed with a non-serious raise; reproduced on 10.4.0. | chez-sqlite3 `private/load-state.sls` |

### 6.2 One critical section per verb

Decided by the owner (§11.3).

**What it is.**
- A verb checks its arguments first, outside any section.
- One `critical-section` then holds the rest: making the blocks, copying in, the C call,
  copying out, the wipe and the free.
- The section answers data: C's answer and what was copied out. The verb raises, if it
  must, after the section.

**Why.**
- **Engines.** An engine's expiry, or a timer handler that captures a continuation,
  escapes the verb's extent and runs its cleanup. Resuming re-enters, and
  `call-with-block` refuses the re-entry. So a correct caller gets "re-entered after
  its block was freed" (X-M1).
  - Fuel burns only in Scheme code, never inside C, so an expiry falls in a copy loop
    or between steps.
  - Inside a section, the expiry waits until the section ends.
- **A guard that does not match.** Such a guard re-enters the extent to raise again,
  and the refusal would replace the caller's condition. Raising after the section
  avoids this (X-M2).

**What it costs.**
- **Interrupts on this thread wait until the section ends:** an engine's expiry,
  Ctrl-C, and this thread's answer to a collect request.
- **The C hash itself costs nothing here.** A `__collect_safe` call deactivates the
  thread, so another thread's collection completes at once even inside the section
  (probed, X).
- **What holds up collections is Scheme's copying**, so inputs are capped (§4.4).
- **Nothing inside may raise.** The arguments are checked first. A failure to make a
  block is caught inside and answered as data, as `call-with-block` already does.

**Who needs it.**
- Techo's stack uses no engines today. circuit and chez-http-server set no timer and
  make no engine. chez-http-server's coroutines switch with `call/cc` only at an
  `await`, and no verb awaits.
- The rule is for every other caller, whose failures would otherwise be rare and
  dependent on timing (§11.3).

**How it is tested.** One row: every verb under an engine, at each fuel from 1 until
it completes (§8.1, row 18).

**What is not copied:** chez-sqlite3's claims, positions and sweeps. They protect state
shared across sections, and a stateless verb has none.

### 6.3 Every block is wiped

Decided by the owner (§11.2).

**Where the wipe goes.** Fused with the free, inside `call-with-block`'s critical
cleanup: `free-foreign-block!` checks that the block is live, wipes it with one plain
`sodium_memzero` call over its size, then frees it (ADR-0008, amended). A block that is
not live is never wiped.
- **Not in a wrapper.** The block is already freed by the time a wrapper's cleanup
  runs. Wiping freed memory corrupted glibc's heap and aborted the process (X-B1).
- **Not inside the callback.** An engine's expiry freed the block unwiped in 24 of 52
  runs. §6.2 rules that path out as well, but the wipe sits next to the free so that no
  path can free a block unwiped.

**Which blocks.** Every block the library frees, secret or not:
- the password, the hash string and keys;
- random bytes;
- `blake2b`'s input and output, and `constant-time-bytevector=?`'s operands;
- the HMAC key and state.

One rule means there is no list of which blocks are secret, and one test covers all of
them (§8.1, row 24).

**What it costs.** Next to nothing:

| Size | Wipe |
|---|---|
| 32 B | 3 ns |
| 4 KiB | 19 ns |
| 1 MiB | 15 µs |

That is about 2% of BLAKE2b over the same bytes, plus about 13 ns for the foreign call.
A `foreign-set!` loop would cost as much as the copy, so the wipe is never written as
one.

**No Scheme copy of a secret** (§11.5).
- The password's UTF-8 is written straight into its block, character by character.
- The block helper copies a caller's bytevector straight into its block, without
  `call-with-bytes`' `bytevector-copy`. A bytevector's length cannot change, so reading
  it in place is memory-safe. A caller who changes the bytes from another thread
  meanwhile hashes what it wrote.

**What it cannot reach.** The documents say so:
- the caller's own copies: the password string, the HTTP body, a JSON parser's strings;
- the bytevectors the verbs return (the key `random-bytes` returns is the key);
- copies the collector leaves behind.

`string-fill!` wipes a mutable string in place, but not those copies. This is hygiene
for the C heap: it limits what a crash dump, swap, or another C library's over-read can
expose. It is not a guarantee.

### 6.4 Which calls are collect-safe

- **`crypto_pwhash_str` and `crypto_pwhash_str_verify`.** On the development machine,
  hash and verify alike take about 55 ms at `'interactive`, 0.3 s at `'moderate`, and
  1.8 s at `'sensitive`.
  - Techo's off-loop hashing depends on this: trap 1 of
    [the chez-http-server proposal](references/chez-http-server-await-outside.md), a
    copy kept here for reference.
- **Every other call is plain, bounded by the cap** (§4.4).
  - BLAKE2b over 64 KiB takes about 50 µs, and 64 KiB of random bytes about 0.1 ms.
  - `sodium_memcmp`, `sodium_memzero` and the constants take far less.
  - A collect-safe call costs about 55 ns against 13 ns for a plain one (X).
- Tier 2's calls follow the same rule under the cap.

## 7. What to reuse

From a survey of chez-sqlite3 and chez-libuv during the review (X, P).

### 7.1 Copy nearly as it is

| What | File in chez-sqlite3 |
|---|---|
| The Guix launcher and its checks | `scripts/guix-env`, `guix-env-enter`, `guix-env-selftest`, `require-tools`, `channels.scm` |
| Building and checking Chez in CI | `scripts/ci/build-chez.sh`, `check-chez.sh`, `floor.sh`, `check-action-pins.sh` |
| Fetching a locked Akku archive | `scripts/fetch-akku-lock` |
| SRFI-64 as a pinned submodule | `.gitmodules`, `vendor/chez-srfi`, `make deps` |
| Refusing an old or unthreaded Chez | `private/require-threaded.sls` (90 lines) |
| The planted overrun and leak | `tests/memory-plant-overrun.sps`, `memory-plant-leak.sps`; they use `foreign-alloc` only |
| The docs site, at M4 | `build-site.sps`, `site/*.sls`, `pages.yml` |

### 7.2 Adapt

| What | Change |
|---|---|
| `private/conditions.sls` | §5's tree, and the raise helpers. Keep `shown-value` for values that are not secret, and add a refusal form for secrets that shows only the kind. Adapt it first: `load-state` and `memory` import its root type. |
| `private/load-state.sls` (70 lines), `private/memory.sls` (97) | Renames, once `conditions.sls` is adapted. |
| `private/counters.sls` (129) | Drop the connection and statement kinds, and the `sqlite3_memory_used` exit check. Count blocks only. |
| `private/discovery.sls` (220) | The env var becomes `CHEZ_SODIUM_LIBRARY`. Linux only (Techo ADR-0001). In each directory of chez-sqlite3 ADR-0002's order, try `libsodium.so.26` (1.0.19 to 1.0.22), then `libsodium.so.23` (1.0.17 and 1.0.18). Never try the bare `libsodium.so` development link. The floor check refuses 1.0.17, not the name. A test uses a directory that holds both. |
| `private/native.sls` | Keep `bind-required`, `call-with-block` (gaining §6.3's wipe), `call-with-bytes` (without its copy), `call-with-c-string` (for the hash string, ending in 0), `c-string->bytevector`, `c-string->string`, `foreign-bytes`, `check-who`, `holds-nul?`, `maps-text`, `required-entry`, `loader-message`, and the ordered load. Drop `bind-optional`: every entry exists at the floor (X-m3). The load becomes: choose, load, bind the version entries, check the floor, `sodium_init`, bind the rest (X-m4). |
| `private/verify.sls` | The floor reads `sodium_version_string`, parsed strictly as three naturals and compared with `floors.sexp`. Major and minor are reported beside it, never compared: they are libtool numbers (§3.4; X-M5, P-F2). |
| `packaging/floors.sexp` | `(sodium "1.0.18")`. `floor.sh` and `check-floors` keep their `x.y.z` form. |
| `tests/foreign-conventions.sls`, `test-conventions.sps` | `size_t` joins both allow-lists, for arguments and for results. `test-conventions` drops it from the forms it refuses (P-F20). |
| `tests/test-constants.sps`, its prototype half | Compiles against `sodium.h`. Its map from C types to Chez types gains `size_t` → `size_t` and `unsigned long long` → `unsigned-64` (X-M6). |
| `tests/check-seam.sps`, `test-check-seam.sps` | New allow-lists. |
| A decoy libsodium, from `tests/decoy-libsqlite3.c` | Includes `sodium.h`. It logs each pointer through a `volatile uintptr_t`: libsodium's `nonnull` attributes make `p ? … : …` an error under `-Wall -Werror`, and let GCC drop the check (P-F7). It logs every call, so a row can assert that no C was reached. |
| The C oracle | Opens the exact path with `dlopen` and takes its prototypes by `__typeof__`, as chez-sqlite3's does. Needs `libsodium-dev`, and Guix's libsodium. |
| The memory gate: `make test-memory`, `check-memory-gate.sh` (1,704 lines) | **One job, no shards.** Drop `MEMORY_SHARD`, `MEMORY_SUITES_1` and `_2`, `check-memory-shards`, and `check-ci`'s two memory jobs. Drop the two SQLite plants and keep the two `foreign-alloc` plants. Rename the oracle child and `CHEZ_SQLITE3_GATE_CHILD`. Use Valgrind's `default.supp` only: libsodium ran clean with no suppression (P-F15). |
| The Makefile | Its skeleton: `help`, `check-help`, `deps`, `test`, `clean`, `check-clean`, `check-pins`, `check-guix`, `dev`. Change every target that names SQLite. |
| `tests/check-suites.sps`, the shared exit form, the testing library | The testing library imports `private counters`, so `counters` is in `src/` from M0. |
| Scripts that name SQLite | `check-test-fails.sh`, `check-dev.sh`, `check-floors`, `tests/preflight.sps`, `report-sqlite.sh`, `test-ci-sqlite.sps`, `library-loading.sls`, `refusal-probe.sps` (P-F18) |
| `manifest.scm`, `packaging/debian-prereqs.txt` | `libsodium` for `sqlite`; `libsodium-dev` for `libsqlite3-dev`. |
| `scripts/ci/build-sqlite.sh`, `check-sqlite.sh` | A libsodium build from a point-release tarball, never `-stable` or `LATEST`, which are rebuilt in place. Pin a SHA-256 the project computes itself, checked once against the `.minisig` with libsodium's published minisign key. Fall back to `releases/old/`, where older tarballs move (P-F16). |
| `.github/workflows/ci.yml`, `tests/check-ci.sh` | M0's shape, then M1's (§9). Linux only. |
| `Akku.manifest` | A new name; development dependencies only; no `scripts` clause, since nothing is built. |

### 7.3 Leave out

chez-sqlite3 carries these because a connection is long-lived shared state. libsodium
has none.

- Thread ownership and `&sqlite-wrong-thread`.
- The close latch and the interrupt exclusion.
- Statement tracking, caches and the statement state machine.
- chez-sqlite3's engine claims, positions and sweeps. §6.2's one section per verb needs
  one row instead (§8.1, row 18).
- The variadic-call check, and `bind-optional`.
- Everything of chez-libuv's shim: the C file, the generated config, the relink guard.

## 8. Tests

Watch each one fail first, as `AGENTS.md` asks. Each row names the wrong implementation
it catches.

### 8.1 The rows

| # | What | How | Catches |
|---|---|---|---|
| 1 | The fast hash | RFC 7693 Appendix E's self-test through `blake2b`: unkeyed and keyed, sizes 20, 32, 48 and 64, six input lengths, one published result. The BLAKE2 reference's keyed known answers (`blake2b-kat.txt`). BLAKE2b-256(`"abc"`) = `bddd813c…d52319`, from a source independent of libsodium. | a dropped key; a wrong or ignored size; BLAKE2b-512 truncated to 256 |
| 2 | Tier 2 | NIST's SHA-256 vectors; RFC 4231 for HMAC-SHA256, cases 6 and 7 among them; AWS's published Signature Version 4 example | a long key not pre-hashed; a wrong key length |
| 3 | A password round trip | a non-ASCII password hashes and verifies; changing its last character verifies false | a length taken from the character count (P-F5) |
| 4 | The C oracle, both ways | C hashes and Scheme verifies; Scheme hashes and C verifies. Passwords are sent as hex of their UTF-8 bytes, among them a non-ASCII one and `"a\x0;b"`, through the oracle's `hash HEX` and `verify STRING HEX` (ADR-0011, amended). | hashes no other libsodium reads |
| 5 | The limits used | hash at `(make-password-limits 2 16)`, which is neither the minimum nor a preset, and assert the whole parameter field: `m=16,t=2,p=1` | limits ignored; KiB and bytes mixed up |
| 6 | The presets | `password-needs-rehash?` on hand-written strings, which hashes nothing. Each preset's string is current at its own preset and stale at the others. | presets swapped |
| 7 | The default | one hash with no limits reads `m=65536,t=2`; about 0.7 s under Valgrind | a wrong default |
| 8 | Needs rehash | `#f` at the limits it was made with. `#t` at higher limits and at lower ones. `#t` for an argon2i hash at ops 3 or more, a p=4 hash at 32 KiB or more, and another prefix, each at the same limits, where libsodium answers 0 (M3 plan §5.1). `#t` for a long hash that verifies but that libsodium cannot parse. `#t` for a malformed string, and for one the pre-check refuses. Nothing is raised. | each of §4.2's rules |
| 9 | The pre-check | A good hash, then U+0000 and junk: verify answers `#f`, needs-rehash `#t`. A byte of 0x80 or more inside the salt, where libsodium's needs-rehash answers 0 at 1.0.18 and -1 at 1.0.22. A string over the cap. Each row asserts from the decoy's log that no libsodium function was called. | a missing pre-check. C refuses the other bad strings itself, so only these rows can fail (P-F10) |
| 10 | The hash string's block | Under the gate, verify reads no byte past its block. The decoy logs the C string's length as equal to the string's. | a block without its terminating 0 (L-F1) |
| 11 | An empty password | It hashes and verifies true, and a one-byte password verifies false. The block helper's own row: an empty bytevector gets a non-NULL block of at least one byte. | NULL for an empty input. libsodium accepts NULL with length 0, so only the helper's row can see it (P-F6) |
| 12 | A password with U+0000 | `"a\x0;b"` verifies against its own hash, and not against `"a"`'s | a C-string length |
| 13 | Random bytes | The length asked for. Every byte position varies across k calls. 0 gives `#vu8()` and calls no C. Over the cap raises. | a short copy |
| 14 | `constant-time-bytevector=?` | Equal pairs; pairs that differ only in the first byte, or only in the last; a prefix pair; different lengths; both empty. The decoy logs `sodium_memcmp`'s length as the whole length. | `bytevector=?`; a short length; comparing only the shorter length |
| 15 | A caller's mistakes | For each verb: each wrong type; each size, key length or limit out of range; an input over the cap, other than a hash string (row 9); an empty key. Each raises `&assertion`, and the decoy's log shows no libsodium call. | a missing range check. C will not catch sizes of 1 to 15 bytes (P-F9) |
| 16 | Secrets in conditions | Pass a secret-looking symbol, number and character list as each verb's secret parameters. No message or irritant holds any of it. | `shown-value` used on a secret |
| 17 | Raised after the section | A decoy `crypto_pwhash_str` answers -1, and a decoy `crypto_generichash` answers -1 and 1 (ADR-0006, amended), each under a guard for something else. The outer guard catches the `&sodium-failed` itself. | a raise from inside the extent (X-M2) |
| 18 | Engines | Each verb under an engine, at every fuel from 1 until it completes. Each run answers right, raises nothing, and leaves no live block. | §6.2's section missing (X-M1) |
| 19 | Collect-safe | chez-sqlite3's FIFO pattern. Decoy `crypto_pwhash_str` and `_verify` block on a FIFO. Each verb's call blocks inside its section. Once the decoy's marker shows the call is in C, and a second has passed, another thread's `collect-rendezvous` ends within 5 s while they block, then the test releases them; a watchdog releases them after 10 s. Every writer opens the FIFO read-write, and each call has its own FIFO and marker. No high limit is used, and it runs under Valgrind (ADR-0011, amended). | either call bound as plain (X-M3). A test-side plain binding, the standing control, is released by the watchdog |
| 20 | The load | Decoys reach `below-floor`, `missing-api` and `init-failed`, and a `sodium_init` that answers 1, which loads. A decoy whose version string and major/minor disagree shows that the string decides. `invalid-override`, `load-failed` and `not-found` are reached as chez-sqlite3 reaches them, without a decoy. | a floor read from the wrong numbers |
| 21 | An earlier `sodium_init`, for real | A child process calls the real `sodium_init` through its own binding, then loads chez-sodium. It loads, and a second direct call answers 1. | treating 1 as a failure (P-F13) |
| 22 | The return codes | every return code §3.4 states, checked against the real library | a stated code that is not true |
| 23 | Memory | the whole suite under Valgrind, in one job; the planted overrun and leak each turn it red | |
| 24 | The wipe | A child process with a preloaded `free()` interposer: every block the library frees reads all zeros. Outside Valgrind, whose allocator bypasses the interposer. | a block freed unwiped (X-m6) |

### 8.2 Limits in tests

- **Password rows hash at libsodium's minimum**, read from `_opslimit_min` and
  `_memlimit_min`. The exceptions are row 5's cheap pair and row 7's one default hash.
  Under Valgrind, a minimum hash takes about 0.4 ms, and an interactive one about 0.7 s
  (M3 plan §5.1; the review's 5 ms and 0.8 s were (P)'s).
- **No row needs a high limit.** The collect-safe row uses a decoy.

### 8.3 Versions to run on

| libsodium | Where | Why |
|---|---|---|
| 1.0.18, Ubuntu 24.04's package (`1.0.18-1ubuntu0.24.04.1`) | CI's `main`, found by discovery. `main` asserts that it loaded the floor. | a distribution's build, with its own patches |
| 1.0.18, built from `libsodium-1.0.18.tar.gz` | CI's `floor`, through `CHEZ_SODIUM_LIBRARY` and `C_INCLUDE_PATH` | ours, with known flags. chez-sqlite3 runs both for the same reason (P-F3). |
| 1.0.22, Guix's at the pinned channel `b532aa7` | the development container | |
| the latest point release, built from source | CI's `current`, through `CHEZ_SODIUM_LIBRARY` and `C_INCLUDE_PATH` | 1.0.22 today |

Ubuntu's own packages confirm the floor and the newer soname (packages.ubuntu.com,
2026-11-22):
- 22.04, 24.04 and 26.04 all ship 1.0.18, as `libsodium23`;
- 26.10 ships 1.0.22, as `libsodium26`.

Versions 1.0.19 to 1.0.21 share `libsodium.so.26` and are not run. §11.5 gives the
policy for which versions are tested.

## 9. Milestones

| # | Delivers | Unblocks |
|---|---|---|
| M0 | The records (below); the repository; the part of §7 that runs with no verb. That means CI's `main` (without `make build` and `check-dev`), `memory` and `nothreads`; `src/` holding `require-threaded`, and `counters` with what it imports; the harness suites as the "empty" suite; and `check-ci` holding M0's shape (P-F1). | |
| M1 | `conditions`, discovery, the load, the floor, `sodium_init`, `sodium-version`; the block helper, with its wipe and one section; the decoy, the C oracle, the header prototype check; CI's `floor` and `current`; `make build` and `check-dev` | |
| M2 | `random-bytes`, `blake2b`, `constant-time-bytevector=?`, built on M1's helper, so M3 reworks nothing | |
| M3 | The password verbs, collect-safe, with §4.2's rules | Techo's slice 3 (accounts, login, keys), at a commit. Techo pins its siblings as git submodules (Techo ADR-0011), so it needs no release (P-F19). |
| M4 | `docs/`, and `docs/reference.md` with `test-reference`; the site and its job; `CHANGELOG.md`; release 0.1.0 | |
| M5 | Tier 2: `sha256` and `hmac-sha256` | Techo's attachments |
| Later | Publication on Akku, once Techo has battle-tested chez-sodium (§11.8) | Chez users outside Techo |

**The records M0 writes** (§11.5), as chez-sqlite3 began with its own:

1. Bind libsodium directly, with no C shim, loaded at runtime.
2. Runtime discovery, and the sonames.
3. The floor, 1.0.18, read from the version string.
4. A threaded Chez.
5. The subset rule, and `constant-time-bytevector=?` as its one exception.
6. Errors: the condition tree, and no secret ever shown.
7. One critical section per verb.
8. Every block wiped before it is freed.
9. What `password-needs-rehash?` means.
10. Linux only.
11. The memory gate and the pinned Guix container, after chez-sqlite3's.

## 10. Open

Nothing is open.

No longer open:
- whether Techo's slice 2 needs `password-hash`. The owner decided in Techo, on
  2026-11-22, that it does not:
  - `techo user add` lands in Techo's slice 3, and slice 2's CLI does schema and
    migrations only (Techo `progress.md`);
  - so M3 is needed before Techo's slice 3, as §9 has it;
  - Techo's slice 2 also waits for chez-http-server's `await-outside` (Techo ADR-0008,
    amended), so nothing in Techo needs chez-sodium soon;
- the sonames, which §7.2 has;
- the input cap and the supported versions, which §11.5 decides;
- a threaded Chez, which §11.6 decides;
- the integer types, the floor, the default limits and the names, which §11.7 decides;
- publishing on Akku, which §11.8 decides.

## 11. Decisions

The owner's decisions, 2026-11-22, on the questions the review left open.

1. **`password-needs-rehash?` answers `#t` for a hash it cannot read.** §4.2 documents
   its meaning and call order in detail. Raising was rejected:
   - it would lock out a user whose right password verified against an imported hash;
   - it needs a condition of its own;
   - it protects only corrupt rows from a caller that re-hashes before verifying.
2. **Every block is wiped before it is freed, not only the password's** (§6.3).
3. **Each verb's whole extent is one critical section, with inputs capped** (§6.2,
   §4.4). Documenting that the verbs are not safe under engines was rejected: its
   failures would be rare and dependent on timing.
4. **The Tier 2 shape and `constant-time-bytevector=?`.**
   - Streaming SHA-256 is out, and `hmac-sha256` is one call (§3.2).
   - `constant-time-bytevector=?` stays, as a general verb (§3.1).
   - Techo was told to look keys up by their hash, and recorded that as a proposed
     amendment to its ADR-0006.
5. **The revision's own proposals, approved.**
   - **Custom limits** are made by `make-password-limits ops memory-kib`, with memory
     in KiB (§4.1).
   - **Every input**, and `random-bytes`' output, is capped at 64 KiB (§4.4).
   - **`crypto_pwhash_strprefix`** is bound. `password-needs-rehash?` reads the
     expected prefix from the loaded library, so a new default algorithm migrates old
     hashes (§4.2).
   - **The binding keeps no Scheme copy of a secret.** `call-with-bytes` loses its
     `bytevector-copy` (§6.3).
   - **Supported versions:**
     - Test the floor, Guix's version and the latest point release (§8.3).
     - Bump `current` at each point release.
     - Raise the floor only by a record.
   - **M0 writes the eleven records of §9.**
6. **A threaded Chez, 10.4.0 or later, is required**, as the siblings require one. The
   deciding reasons:
   - `counters` and `memory` import `make-mutex`, which an unthreaded Chez lacks;
   - Techo hashes on worker threads.
7. **The rest of what was open.**
   - **Integer types.** Chez's `size_t` is used where C says `size_t`, for arguments
     and results, and `unsigned-64` for `unsigned long long`. Both go in the
     allow-lists and in the prototype map (§7.2). All four are 8 bytes here, so the
     choice is for the checks: C types map one for one to Chez types. `unsigned-64`
     over `unsigned-long-long`, since chez-sqlite3's lists already hold it.
   - **The floor** is libsodium 1.0.18, read from the version string (§7.2). It is the
     only version on every Ubuntu LTS still supported, so a higher floor would exclude
     them all (§8.3).
   - **The default limits** are `'interactive`. A hash takes about 55 ms here, which
     is the stall Techo's one loop pays per login until hashing leaves it. That uses
     64 MiB, more than three times OWASP's minimum memory. `password-needs-rehash?`
     migrates hashes if the default rises.
   - **The names** are §4's. Two were renamed from the first draft: `generic-hash`
     became `blake2b`, and `bytes=?` became `constant-time-bytevector=?` (§3.1).
8. **chez-sodium will be published on Akku, once Techo has battle-tested it.**
   - That may come later than 0.1.0, so 0.1.0 is not published there.
   - Techo pins its siblings as git submodules (Techo ADR-0011), so it needs no Akku
     release to use chez-sodium.
