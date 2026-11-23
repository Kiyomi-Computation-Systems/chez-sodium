# ADR-0007: Each verb's whole extent is one critical section, and inputs are capped at 64 KiB

- **Status:** Accepted (the owner, 2026-11-22), brief §11.3. Decision 5's cap is brief §11.5.
- **Date:** 2026-11-22
- **Scope:** every public verb
- **Settles:** [brief](../2026-11-22-chez-sodium-project-brief.md) §4.4, §6.2, §11.3 and
  §11.5's cap
- **Related:** chez-sqlite3 ADR-0012 and chez-sqlite3's global constraints, for the parts that
  raise · [ADR-0001] (which calls are collect-safe) · [ADR-0006] (raised after the section) ·
  [ADR-0008] (the wipe, in the cleanup) · [ADR-0009] (the hash string over the cap)

## Context

- **An engine's expiry escapes a verb's extent and runs its cleanup** (X-M1). So does a timer
  handler that captures a continuation. Resuming re-enters, and `call-with-block` refuses the
  re-entry: a correct caller gets "re-entered after its block was freed".
  - Fuel burns only in Scheme code, never inside C, so an expiry falls in a copy loop or
    between steps.
  - Inside a critical section, the expiry waits until the section ends.
- **A guard that does not match re-enters the extent to raise again** (X-M2), and the refusal
  replaces the caller's condition. Reproduced (`ffi/p07-guard-reentry.sps`).
- **A `__collect_safe` call deactivates its thread,** so another thread's collection completes
  at once, even inside the section (probed, X). What holds up collections there is Scheme's
  copying. A byte-by-byte copy costs about 30 ms per MiB (X-M4).
- **Techo's stack uses no engines today.** circuit and chez-http-server set no timer and make
  no engine. chez-http-server's coroutines switch with `call/cc` only at an `await`, and no
  verb awaits.

## Decision

1. **A verb checks its arguments first,** outside any section.
2. **One `critical-section` holds the rest:** making the blocks, copying in, the C call,
   copying out, the wipe and the free ([ADR-0008]).
3. **The section answers data:** C's answer and what was copied out. The verb raises, if it
   must, after the section ([ADR-0006]).
4. **Nothing inside may raise.** A failure to make a block is caught inside and answered as
   data, as `call-with-block` already does.
5. **Every byte or string input, and `random-bytes`' output, is at most 64 KiB, counted in
   bytes.** A string counts its UTF-8 bytes, summed from its characters: `string->utf8` would
   make the Scheme copy of a secret that [ADR-0008] forbids. Above that is a caller's mistake,
   raised before C. A hash string over the cap fails the pre-check instead, and is answered, not
   raised ([ADR-0009]).
6. **chez-sqlite3's claims, positions and sweeps are not copied.** They protect state shared
   across sections, and a stateless verb has none.

### Rejected

- **Documenting that the verbs are not safe under engines** (brief §11.3). Its failures would
  be rare and dependent on timing.

## Consequences

- **Interrupts on the verb's thread wait until its section ends:** an engine's expiry, Ctrl-C,
  and the thread's answer to a collect request.
- **A section's copying stays near 2 ms at the cap.** Tier 1's inputs are far smaller: a
  password, a 32-byte key, a hash string of about 100 characters.
- **The cap bounds the plain calls too** ([ADR-0001]): BLAKE2b over 64 KiB takes about 50 µs,
  and 64 KiB of random bytes about 0.1 ms.
- **Techo doesn't need it today.** The rule is for every other caller, whose failures would
  otherwise be rare and dependent on timing.
- **A non-ASCII row holds the count:** a password of 2-byte characters, one past the cap in
  bytes and under it in characters, is refused (brief §4.4).
- **One row holds it** (brief §8.1, row 18): every verb under an engine, at each fuel from 1
  until it completes. Each run answers right, raises nothing, and leaves no live block.
- **Tier 2 revisits the cap,** since a blob can be large. The options then are a word-by-word
  copy, about 5 ms per MiB (X-M4), or a plain `memcpy` that takes the bytevector itself, which
  chez-libuv's rule 3 allows and [ADR-0001] does not.

[ADR-0001]: 0001-bind-libsodium-directly.md
[ADR-0006]: 0006-errors-and-no-secret-shown.md
[ADR-0008]: 0008-every-block-wiped-before-free.md
[ADR-0009]: 0009-what-needs-rehash-means.md
