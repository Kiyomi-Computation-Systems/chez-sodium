# ADR-0006: Errors are a small condition tree, and no condition shows a secret

- **Status:** Accepted (the owner, 2026-11-22), approved with the brief.
- **Date:** 2026-11-22
- **Scope:** every condition chez-sodium raises, and every refusal of a caller's mistake
- **Settles:** [brief](../2026-11-22-chez-sodium-project-brief.md) §5
- **Related:** chez-sqlite3 ADR-0013, whose shape and helpers this follows · [ADR-0002] (the
  load's reasons) · [ADR-0007] (raised after the section) · [ADR-0009] (what
  `password-needs-rehash?` answers instead of raising)

## Context

- **libsodium tells little apart** (L-F2). `crypto_pwhash_str_verify` answers -1 for a wrong
  password, a string it cannot parse, and no memory; at 1.0.18, errno reads `EINVAL` either
  way.
- **Some failures never reach libsodium's answer** (L-F2):
  - in a container with a memory limit, a hash that asks for more than is left gets the
    process killed by the kernel's OOM killer. argon2 touches its pages as it takes them, so
    libsodium never sees a failure;
  - libsodium aborts the process on misuse, a NULL pointer with a nonzero length, and when no
    entropy source is available.
- **chez-sqlite3's `shown-value` shows numbers, symbols, characters and lists of them as they
  are** (L-F9). Used on a secret parameter, it would put a password of the wrong type in a
  condition (P-F8).

## Decision

1. **The tree, smaller than chez-sqlite3's, with the same shape and helpers:**

   ```
   &error
    └ &chez-sodium-error
       ├ &sodium-library-unavailable    reason path source detail candidates
       └ &sodium-failed                 the verb, and what libsodium answered
   ```

2. **`&sodium-library-unavailable` carries one of [ADR-0002]'s reasons:** `invalid-override`,
   `not-found`, `load-failed`, `below-floor`, `missing-api` or `init-failed`. `init-failed` is
   `sodium_init` answering -1 only.
3. **`&sodium-failed` has one case:** `crypto_pwhash_str` answering -1 for limits that passed
   their range check, which means it could not get the memory. It carries the verb and
   libsodium's answer, and no secret.
4. **What is not a condition.** The documents say so:
   - `password-verify`'s -1 answers `#f`, whether the password was wrong, the hash unreadable,
     or the memory short;
   - the OOM kill. Size a container for the memory limit times the number of hashes that can
     run at once: 64 MiB each at `'interactive`;
   - libsodium's aborts. The binding's checks rule out the misuse.
5. **A caller's mistake is an assertion violation, raised before C:** a wrong type; a size, key
   length or limit out of range; an input over the cap ([ADR-0007]); an empty key. A hash string
   over the cap is the exception: it fails the pre-check, and is answered ([ADR-0009]).
6. **No secret ever reaches a condition** (L-F9, P-F8).
   - Every string and bytevector parameter is secret: a password, a hash string,
     `blake2b`'s input (Techo's API key) and key, `constant-time-bytevector=?`'s operands,
     and Tier 2's inputs and HMAC key.
   - A refusal of a secret parameter names the parameter and its kind only, whatever the
     value's type.
   - `shown-value` is used only for sizes, limits and preset names.
7. **Raised after the section** (X-M2). A verb's critical section answers data, and the verb
   raises only once it is out ([ADR-0007]).
8. **Tests assert the reason symbol, never the message.**

### Rejected

- **`shown-value` on every refusal,** as chez-sqlite3 uses it. A password passed as a symbol
  would be shown as it is (L-F9).
- **A raise from `password-needs-rehash?` for a hash it cannot read** ([ADR-0009]).

## Consequences

- **The refusals have rows** (brief §8.1):
  - row 15: each verb's wrong types, out-of-range values, inputs over the cap other than a
    hash string (row 9), and empty key each raise `&assertion`, and the decoy's log shows no
    libsodium call (P-F9);
  - row 16: a secret-looking symbol, number and character list, passed as each verb's secret
    parameters, appear in no message or irritant;
  - row 17: a decoy `crypto_pwhash_str` answers -1 under a guard for something else, and the
    outer guard catches the `&sodium-failed` itself.
- **A caller who needs to tell verify's three `#f`s apart cannot.** libsodium does not tell them
  apart either.

[ADR-0002]: 0002-runtime-discovery-and-the-sonames.md
[ADR-0007]: 0007-one-critical-section-per-verb.md
[ADR-0009]: 0009-what-needs-rehash-means.md
