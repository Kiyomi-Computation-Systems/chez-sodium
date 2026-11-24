# ADR-0006: Errors are a small condition tree, and no condition shows a secret

- **Status:** Accepted (the owner, 2026-11-22), approved with the brief. Amended 2026-11-23 in
  M1's plan, and accepted by the owner that day ([amendment](#amendment-2026-11-23-m1s-plan)).
  Amended 2026-11-23 after slice 0's review, and accepted by the owner that day
  ([amendment](#amendment-2026-11-23-slice-0s-review)).
  Amended 2026-11-23 in M2's plan, and accepted by the owner that day, after M2 slice 0's
  review ([amendment](#amendment-2026-11-23-m2s-plan)).
  Amended 2026-11-24 after the second review of M2's closing fixes, the design the owner's
  choice that day ([amendment](#amendment-2026-11-24-a-secrets-refusal-states-its-bound-as-numbers)).
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
       └ &sodium-failed                 function code
   ```

2. **`&sodium-library-unavailable` carries one of [ADR-0002]'s reasons:** `invalid-override`,
   `not-found`, `load-failed`, `below-floor`, `missing-api` or `init-failed`. `init-failed` is
   `sodium_init` answering anything but 0 or 1 ([ADR-0002], amended).
3. **`&sodium-failed` has one case:** `crypto_pwhash_str` answering -1 for limits that passed
   their range check, which means it could not get the memory. Its fields are `function`, the C
   function's name as a string, and `code`, the integer it answered. The verb is its `&who`. It
   carries no secret.
4. **What is not a condition.** The documents say so:
   - `password-verify`'s -1 answers `#f`, whether the password was wrong, the hash unreadable,
     or the memory short;
   - the OOM kill. Size a container for the memory limit times the number of hashes that can
     run at once: 64 MiB each at `'interactive`;
   - libsodium's aborts. The binding's checks rule out the misuse.
5. **A caller's mistake is an assertion violation, raised before C:** a wrong type; a size, key
   length or limit out of range; an input over the cap ([ADR-0007]); an empty key. A hash string
   over the cap is the exception: it fails the pre-check, and is answered ([ADR-0009]).
   - **Every raise carries `&who`.** The load's refusals name `chez-sodium`, since no one
     procedure raises them. A refusal raised through the public surface names the public verb,
     and carries a `&message`; a helper raises with the WHO it is given. An internal invariant
     (`memory`, `counters`, `load-state`) names its own procedure, and a condition Chez raises
     is passed on as raised.
   - **A refusal raised through the public surface leads its irritants with a symbol** naming
     the rule: an accessor's `not-a-sodium-library-unavailable`, for example.
6. **No secret ever reaches a condition** (L-F9, P-F8).
   - Every string and bytevector parameter is secret: a password, a hash string,
     `blake2b`'s input (Techo's API key) and key, `constant-time-bytevector=?`'s operands,
     and Tier 2's inputs and HMAC key.
   - A refusal of a secret parameter names the parameter and its kind only, whatever the
     value's type: an assertion violation from the verb, irritants `(RULE PARAMETER (kind K))`,
     K being the value's kind, never its length.
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

## Amendment, 2026-11-23: M1's plan

Accepted (the owner, 2026-11-23), proposed in [the M1 plan](../2026-11-22-m1-plan.md), §4.1,
items 2 and 3.

- **`&sodium-failed`'s fields are `function` and `code`,** and the verb is its `&who`, as
  chez-sqlite3 ADR-0013 names the verb by `&who` alone. Neither field is a secret. M1 builds
  the type; M3 raises it first, and exports its predicate and accessors then.
- **`&who` on every raise, and the rule symbol first among a refusal's irritants,** so rows
  assert who and irritants, never a message (chez-sqlite3 ADR-0013, decision 2, and its slice-4
  amendment).
- **A secret's refusal is `(RULE PARAMETER (kind K))`.** That a secret is named by its kind alone
  was decision 6. The layout is new.
- **`init-failed` follows [ADR-0002]'s amendment:** any answer but 0 or 1.

## Amendment, 2026-11-23: slice 0's review

Accepted (the owner, 2026-11-23), from M1 slice 0's review, S0-F5 and S0-F6.

- **The rules on `&who` and the rule symbol were wider than the code.** M0's `counters` names
  `count-up!` and `count-down!`, `memory` names its own procedures, and v0.1.1's
  `checked-accessor` carried no rule symbol. chez-sqlite3 scoped the same rule. Now both rules
  bind refusals raised through the public surface, and `checked-accessor`'s refusal is
  `(RULE (kind K))`.
- **Every helper that refuses a secret refuses it through `refuse-secret`,** `call-with-bytes`
  among them: v0.1.1's showed its bytevector parameter through `shown-value`.

## Amendment, 2026-11-23: M2's plan

Accepted (the owner, 2026-11-23), proposed in [the M2 plan](../2026-11-23-m2-plan.md), §4.1, item 5,
and §4.2, item 2, with the owner's answer of 2026-11-23.

- **`&sodium-failed` has two cases.** Decision 3's `crypto_pwhash_str`, from M3, and
  `crypto_generichash` answering anything but 0 for a size and key that passed their range
  checks, from M2: `blake2b` then has no hash to answer, since a -1 leaves `out` as it was
  (measured, at 1.0.18 and 1.0.22). Its function is `"crypto_generichash"`, its code the answer,
  its `&who` `blake2b`, and it is raised after the section ([ADR-0007]). libsodium answers -1 only
  for sizes the checks refuse, so only a decoy reaches it: row 17's M2 half. The decoy answers
  -1 and 1, so that no single value passes for failed, as it answers -1 and 2 for
  `sodium_init`.
- **So the first raise is M2's, and `sodium-failed?`, `sodium-failed-function` and
  `sodium-failed-code` join `(chez-sodium)` in M2** ([ADR-0012], amended), not M3 as the
  first amendment said.
- **The rule symbols M2's verbs lead with:** `not-a-natural` and `over-the-cap` for
  `random-bytes`' `n`; `not-a-bytevector`, `over-the-cap`, `not-a-natural`,
  `size-out-of-range`, `empty-key` and `key-length-out-of-range` for `blake2b`'s `input`, `size`
  and `key`; `not-a-bytevector` and `over-the-cap` for each of the compare's operands. A secret is
  `(RULE PARAMETER (kind K))`; `n` and `size` are shown by `shown-value`. Each verb checks its
  parameters left to right, each one's type before its range, and refuses the first mistake.
  `over-the-cap` and `not-a-natural` are M3's too.

## Amendment, 2026-11-24: a secret's refusal states its bound as numbers

The design is the owner's choice of 2026-11-24, from M2's closing review, M2-F6, and the second
review of its fixes, M2C-F1 ([research](../research/m2-closing-fix-review/README.md)).

- **A secret's refusal may state its bound, and nothing else of the call.** The owner chose on
  2026-11-23 that the refusals' messages state their bounds. A refusal over the cap says the
  cap, and one of `blake2b`'s key says libsodium's range, read from native.
- **The bound is two exact naturals, LOW and HIGH, never text.** `refuse-secret` takes them as
  its fifth and sixth arguments and writes the sentence itself: "PARAMETER is LOW to HIGH
  bytes", or "at most HIGH bytes" when LOW is 0. Anything else in their place, a string
  included, is `refuse-secret`'s own refusal, by kind: `(low (kind K))` or `(high (kind K))`.
  The irritants are unchanged, `(RULE PARAMETER (kind K))`.
- **A free-text detail was rejected.** The first fix took a string, and only a comment kept the
  value out of it. Mutants that wrote the key's text or the input's length there passed every
  suite. M3's secrets are strings, so a swapped argument would have printed a password whole.
- **R16 reaches every refusal that states a bound,** each with a secret that passes the type
  check, and finds neither its text, its bytes as written, nor its length.

[ADR-0002]: 0002-runtime-discovery-and-the-sonames.md
[ADR-0007]: 0007-one-critical-section-per-verb.md
[ADR-0009]: 0009-what-needs-rehash-means.md
[ADR-0012]: 0012-the-public-library-and-the-seam.md
