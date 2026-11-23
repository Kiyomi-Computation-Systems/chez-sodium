# ADR-0005: Bind only what Techo has a named use for; `constant-time-bytevector=?` is the one exception

- **Status:** Accepted (the owner, 2026-11-22), brief §11.4. Decision 7's names are brief §11.7.
  Amended 2026-11-23 in M2's plan, and accepted by the owner that day, after M2 slice 0's
  review ([amendment](#amendment-2026-11-23-m2s-plan)).
- **Date:** 2026-11-22
- **Scope:** what chez-sodium binds and exports
- **Settles:** [brief](../2026-11-22-chez-sodium-project-brief.md) §3, §4's names, §11.4 and
  §11.7's names
- **Related:** [ADR-0001] (how a function is bound) · [ADR-0007] (the cap) · [ADR-0008]
  (guarded memory) · [ADR-0009] (`password-needs-rehash?`)

## Context

- **Techo needs three things Chez does not have** (brief §1): a slow, salted password hash
  (argon2id); random bytes from the system, for API keys; and a fast hash, to store API keys
  without storing the keys.
- **Each function bound is more to test on every libsodium version** (brief §3).
- **A handle brings ownership and wiping.** chez-sqlite3 carries thread ownership, a close
  latch and statement tracking because a connection is long-lived shared state (brief §7.3).
  Streaming SHA-256's state would be such a handle (X-M7, L-F13).
- **Techo looks an API key up by its hash,** which needs no constant-time compare
  (Techo ADR-0006, amendment proposed; L-F11).

## Decision

1. **A function is bound only if Techo has a named use for it.** Adding one takes a row in the
   brief's subset, a row in the convention table ([ADR-0001]), and a test on every supported
   libsodium (AGENTS.md).
2. **`constant-time-bytevector=?` is the one exception** (brief §11.4). The first time a Techo
   developer compares a raw secret or a MAC, the verb at hand would otherwise be
   `bytevector=?`, which is not constant time. One binding and a few rows are cheap insurance.
3. **No verb holds state between calls: no handles** (brief §2, §3.2).
4. **Tier 1, for Techo v1** (brief §3.1, §4):

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

   They bind `sodium_version_string` and `sodium_library_version_major` and `_minor`;
   `crypto_pwhash_str`, `_str_verify`, `_str_needs_rehash` and `_strprefix` ([ADR-0009]),
   with the limits' functions; `randombytes_buf`; `crypto_generichash`, with its sizes'
   functions; and `sodium_memcmp`. `sodium_init` runs at load ([ADR-0002]), and
   `sodium_memzero` is used inside ([ADR-0008]).
5. **Tier 2, for Techo's attachments, is built when Techo needs it** (brief §3.2):
   - `sha256`, through `crypto_hash_sha256`;
   - `hmac-sha256 : Bytevector Bytevector -> Bytevector`, the key then the message, as one
     call. It runs `crypto_auth_hmacsha256_init`, `_update` and `_final` in one section
     ([ADR-0007]). Its state is a block like any other, wiped before it is freed
     ([ADR-0008]). A key over 64 bytes is pre-hashed by `_init`.
6. **Out** (brief §3.3): encryption, signatures, key exchange, AEAD and streams; streaming
   SHA-256 as verbs; `crypto_pwhash` as a key-derivation function, scrypt and
   `crypto_pwhash_str_alg`; guarded memory ([ADR-0008]); hex and base64 helpers;
   `randombytes_uniform` and `randombytes_random`; short hashes, one-time auth and
   `crypto_verify_*`.
7. **The names are decided** (brief §11.7).
   - `blake2b`, not libsodium's `generic-hash`: Techo keeps these hashes for good, so the name
     says which algorithm made them.
   - `constant-time-bytevector=?`, not `bytes=?`: Racket's `bytes=?` and Chez's `bytevector=?`
     are plain equality. This verb's one point is that it isn't.
   - None clashes with a name `(chezscheme)` exports, and none carries a prefix. A user who
     wants one adds it on import: `(import (prefix (chez-sodium) sodium:))`.
8. **Every exported procedure has a Typed Racket style signature comment,** and
   `docs/reference.md` is held to them by a test (brief §4).

### Rejected

- **`crypto_pwhash`, rather than its `_str` form.** The `_str` form picks the salt and writes
  the algorithm, salt and limits into one ASCII string. There is nothing for a caller to get
  wrong, and `password-needs-rehash?` can read the limits back.
- **SHA-256 for API keys.** `crypto_generichash` is libsodium's recommended hash. A fast hash
  is right for a long, random key, safe at 128 bits of entropy or more; Techo makes 32 random
  bytes. A slow one would tax every request.
- **A pepper.** Anyone who can write the database can already replace the password hashes,
  which have none either.
- **Streaming SHA-256.** No use: clients upload straight to the store (Techo ADR-0010), and
  signing hashes only a short canonical request. It comes back, with a design for its state,
  if a use appears.
- **The one-shot `crypto_auth_hmacsha256`.** It takes a key of a fixed 32 bytes. Signature
  Version 4's first key is `"AWS4"` plus a 40-character secret, 44 bytes.

## Consequences

- **chez-sodium has no thread ownership, close latch, statement tracking, claims or sweeps**
  (brief §7.3).
- **`blake2b`'s name is held by its vectors:** row 1 holds it to BLAKE2b on every version run
  (brief §3.1).

## Amendment, 2026-11-23: M2's plan

Accepted (the owner, 2026-11-23), proposed in [the M2 plan](../2026-11-23-m2-plan.md), §4.2, item 1,
with the owner's answer of 2026-11-23.

- **`crypto_generichash_keybytes` is not bound.** It answers the recommended key size, and
  `blake2b` has no default key, so it has no use. The other five size functions are bound: the
  default size, the size's range and the key's range ([ADR-0002], amended).
- **Brief §3.1 and §3.4 name the five.** The brief wrote the family as `_keybytes*`.

[ADR-0001]: 0001-bind-libsodium-directly.md
[ADR-0002]: 0002-runtime-discovery-and-the-sonames.md
[ADR-0007]: 0007-one-critical-section-per-verb.md
[ADR-0008]: 0008-every-block-wiped-before-free.md
[ADR-0009]: 0009-what-needs-rehash-means.md
