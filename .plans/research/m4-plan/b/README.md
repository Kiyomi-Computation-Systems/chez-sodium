# M4 pre-work, part B: the documents' facts, checked

Read-and-probe work for M4's user documents: `docs/`, `docs/reference.md`, and the README. Every
fact the pages will state is read in the code at `main` `d53e83c` and run against the real
libsodium. Nothing here plans the site, CI or the release.

- **Where it ran:** the development workstation, 18 cores, in the container (`scripts/guix-env`):
  Chez 10.4.0, threaded; libsodium 1.0.22 (Guix's, the container's `CHEZ_SODIUM_LIBRARY`) and
  1.0.18 (`<repo>/build/slice5/prefix-1.0.18/lib/libsodium.so.23`, built from the tarball). One
  check ran on the host: the cgroup kill (item 2, note M3-c).
- **Plain runs only,** not under Valgrind, unless a line says so.
- **Every probe ran at both libraries,** through `probes/both.sh`, unless a line says otherwise.
  Where the two answers are the same, one is given.
- **Evidence:** `probes/` holds every program and script, and `out/` what each printed. A file:line
  cites `<repo>`'s code at `d53e83c`. "Inferred" marks a claim no probe saw.
- **Paths:** `<repo>` is the repository root. Outputs mask it the same way.

Contents: [1. The reference's skeleton](#1-the-references-skeleton) ·
[2. The owed notes, checked](#2-each-owed-to-m4-note-checked) ·
[3. Finding libsodium](#3-finding-libsodium) · [4. Installing](#4-installing) ·
[5. Pages, tests and examples](#5-a-proposed-page-set) · [6. Disagreements](#6-disagreements) ·
[7. Rerun](#7-rerunning-the-measurements)

---

## 1. The reference's skeleton

### 1.1 The exports

Chez's `library-exports` lists 18 names (`out/exports.out`, from `probes/exports.sps`, run with
`CHEZ_SODIUM_LIBRARY=/no/such.so`: `environment` alone loads nothing). Each has exactly one
signature comment in `src/chez-sodium.sls`, written as below. **None lacks one.**

| Export | Signature comment, as written | Line |
|---|---|---|
| `sodium-version` | `sodium-version : -> String` | 16 |
| `random-bytes` | `random-bytes : Natural -> Bytevector` | 20 |
| `blake2b` | `blake2b : Bytevector [Natural] [Bytevector] -> Bytevector   ; input, size, key` | 22 |
| `constant-time-bytevector=?` | `constant-time-bytevector=? : Bytevector Bytevector -> Boolean` | 24 |
| `password-hash` | `password-hash : String [Limits] -> String` | 29 |
| `password-verify` | `password-verify : String String -> Boolean              ; hash, password` | 31 |
| `password-needs-rehash?` | `password-needs-rehash? : String [Limits] -> Boolean      ; hash` | 33 |
| `make-password-limits` | `make-password-limits : Natural Natural -> Password-limits ; ops, memory in KiB` | 35 |
| `chez-sodium-error?` | `chez-sodium-error? : Any -> Boolean` | 39 |
| `sodium-library-unavailable?` | `sodium-library-unavailable? : Any -> Boolean` | 41 |
| `sodium-library-unavailable-reason` | `sodium-library-unavailable-reason : SodiumLibraryUnavailable -> Reason` | 43 |
| `sodium-library-unavailable-path` | `sodium-library-unavailable-path : SodiumLibraryUnavailable -> (U String #f)` | 47 |
| `sodium-library-unavailable-source` | `sodium-library-unavailable-source : SodiumLibraryUnavailable -> (U Symbol #f)` | 49 |
| `sodium-library-unavailable-detail` | `sodium-library-unavailable-detail : SodiumLibraryUnavailable -> Any` | 51 |
| `sodium-library-unavailable-candidates` | `sodium-library-unavailable-candidates : SodiumLibraryUnavailable -> (Listof String)` | 53 |
| `sodium-failed?` | `sodium-failed? : Any -> Boolean` | 55 |
| `sodium-failed-function` | `sodium-failed-function : SodiumFailed -> String` | 57 |
| `sodium-failed-code` | `sodium-failed-code : SodiumFailed -> Integer` | 59 |

For `test-reference`'s writer:

- **Four lines end in a gloss after `;`:** `blake2b`, `password-verify`, `password-needs-rehash?` and
  `make-password-limits`. chez-sqlite3's rule compares "NAME : TYPE" character for character, so
  the plan must say whether the gloss is part of the line, or is cut at the `;`.
- **Two alias lines are not signatures:** `Limits = (U 'interactive 'moderate 'sensitive
  Password-limits), by default 'interactive` (line 28), and `Reason = (U 'invalid-override
  'not-found 'load-failed 'below-floor 'missing-api 'init-failed)` (lines 44-45). They start
  `;;   `, so a reader of ";; NAME : TYPE" lines skips them.
- **The reference's type glossary needs:** `Natural`, `Integer`, `String`, `Symbol`, `Bytevector`,
  `Boolean`, `Any`, `Limits`, `Password-limits`, `Reason`, `SodiumLibraryUnavailable` and
  `SodiumFailed`.

### 1.2 Each verb

Refusals were read in the code and confirmed by `probes/refusals.sps` (`out/refusals.out`). Both
libraries gave the same 70 lines, and a `diff` of the two halves is empty. A refusal is
`(RULE PARAMETER V)`:

- V is `(kind K)` for a secret, whatever its type (`conditions.sls:78-79`);
- for a number, symbol or boolean it is `shown-value`, the value itself, and `(kind K)` for anything
  else (`conditions.sls:71-74`).

**Every refusal of a caller's mistake holds `assertion-violation?` and `violation?`. It never holds
`chez-sodium-error?`** (every `refusals.out` line shows `(assertion violation)` alone). Each verb
checks its arguments left to right, type before range, and refuses the first mistake: `(blake2b 'x
99)` is refused for `input` (`b2-input-and-size-bad`).

#### `sodium-version`

- **Takes** nothing. **Answers** the version string the load read: `"1.0.22"` or `"1.0.18"`, a fresh
  string each call (`out/answers.out`).
- **Refuses** nothing; raises the load's refusal if libsodium was refused.
- **Section:** none, and no C: it copies the string the load read (`native.sls:926-927`;
  ADR-0007, decision 8).

#### `random-bytes n`

- **Answers** a fresh bytevector of N random bytes. `(random-bytes 0)` is `#vu8()`, with no C and
  no section (`byte-verbs.sls:74-75`). `(random-bytes 65536)` gives 65536 bytes.
- **Refusals,** from `random-bytes`:

  | Mistake | Irritants | Message |
  |---|---|---|
  | N is no exact natural: `'x`, `-1`, `2.0`, `"32"` | `(not-a-natural n V)`; `"32"` is `(kind string)` | `n is not an exact natural` |
  | N over 65536 | `(over-the-cap n 65537)` | `n is over the cap, 65536` |

- **`&sodium-failed`:** never.
- **Section:** one, `byte-verbs.sls:76-81`.
- **C:** `randombytes_buf`, then `sodium_memzero`, the wipe at the free (`native.sls:300`). libsodium
  aborts the process if its entropy source fails (item 2, note M2-c).

#### `blake2b input [size] [key]`

- **Answers** a fresh bytevector: the BLAKE2b hash of INPUT, SIZE bytes long, keyed by KEY.
  - SIZE defaults to `crypto_generichash_bytes()`, 32.
  - The optionals are positional, so a key needs a size.
  - `(blake2b (string->utf8 "abc"))` is `BDDD813C…D52319`, as brief §8.1 row 1 has it.
    BLAKE2b-512 of `"abc"`, and the keyed known answer for key 00..3F over an empty input, match
    the suite's copies of the published values at both releases (`out/answers.out`;
    `test-native-codes.sps:182-183`, `test-byte-verbs.sps:266`).
- **Refusals,** from `blake2b`, in this order (`byte-verbs.sls:100-119`):

  | Mistake | Irritants | Message |
  |---|---|---|
  | INPUT not a bytevector | `(not-a-bytevector input (kind K))` | `input is refused: not-a-bytevector, shown by its kind alone` |
  | INPUT over 65536 bytes | `(over-the-cap input (kind bytevector))` | `…; input is at most 65536 bytes` |
  | SIZE no exact natural, `#f` included | `(not-a-natural size V)` | `size is not an exact natural` |
  | SIZE outside 16 to 64 | `(size-out-of-range size 15)` | `size is from 16 to 64` |
  | KEY not a bytevector, `#f` included | `(not-a-bytevector key (kind K))` | `key is refused: not-a-bytevector, shown by its kind alone` |
  | KEY empty | `(empty-key key (kind bytevector))` | `…; key is 16 to 64 bytes` |
  | KEY outside 16 to 64 bytes | `(key-length-out-of-range key (kind bytevector))` | `…; key is 16 to 64 bytes` |

  The ranges are libsodium's, read at the load; both releases answer 16 and 64.
- **`&sodium-failed`:** function `"crypto_generichash"`, code its answer, for any answer but 0
  (`byte-verbs.sls:137-139`). No release reaches it (item 2, note M2-d).
- **Section:** one, `byte-verbs.sls:122-136`.
- **C:** `crypto_generichash`. Three blocks are wiped with `sodium_memzero`: the input, the key (a
  one-byte block passed with length 0 when there is none), and the output.

#### `constant-time-bytevector=? a b`

- **Answers** `#t` when A and B hold the same bytes. Both empty is `#t`.
  - Operands of different lengths answer `#f` with no C and no section
    (`byte-verbs.sls:157-158`).
  - Equal lengths go to `sodium_memcmp` over the whole length, and only its 0 is `#t`.
- **Refusals,** from `constant-time-bytevector=?`: A's type, then A's cap, then B's type, then B's
  cap. Both caps are checked before the lengths, so a short A against a B over the cap is refused
  for B (`ct-b-over-cap-short-a`).

  | Mistake | Irritants |
  |---|---|
  | A or B not a bytevector | `(not-a-bytevector a (kind K))`, or `b` |
  | A or B over 65536 bytes | `(over-the-cap a (kind bytevector))`, or `b`. The message ends `; a is at most 65536 bytes` |

- **`&sodium-failed`:** never.
- **Section:** one, `byte-verbs.sls:159-165`.
- **C:** `sodium_memcmp`, and `sodium_memzero` on its two blocks.

#### `password-hash password [limits]`

- **Answers** a fresh hash string of PASSWORD's UTF-8 bytes, exactly as given, at LIMITS. LIMITS
  defaults to `'interactive`. The salt is fresh each call (`hash-is-fresh-each-call`).
  - Each preset's parameter field, at both releases (`out/answers.out`):

    | Preset | Field |
    |---|---|
    | `'interactive` | `$argon2id$v=19$m=65536,t=2,p=1$` |
    | `'moderate` | `m=262144,t=3` |
    | `'sensitive` | `m=1048576,t=4` |
    | `(make-password-limits 2 16)` | `m=16,t=2` |
    | `(make-password-limits 2 19456)` | `m=19456,t=2` |

  - Length: 93 characters at `(make-password-limits 1 8)`. At the presets it is 97: 31, then 22
    for the salt, `$`, and 43 for the tag. That 97 is computed, not printed.
- **Refusals,** from `password-hash` (`password-verbs.sls:124-133`, `106-117`):

  | Mistake | Irritants | Message |
  |---|---|---|
  | PASSWORD not a string, a bytevector included | `(not-a-string password (kind K))` | `password is refused: not-a-string, shown by its kind alone` |
  | UTF-8 over 65536 bytes: 65537 ASCII characters, or 32769 two-byte ones | `(over-the-cap password (kind string))` | `…; password is at most 65536 bytes` |
  | UTF-8 outside `_passwd_min` to `_passwd_max` | `(length-out-of-range password (kind string))` | the range in bytes |
  | LIMITS no preset and no Password-limits | `(not-password-limits limits V)`: `fast` shown as is; a pair as `(kind list)`; `"interactive"` as `(kind string)` | `limits is not a preset or Password-limits` |
  | PASSWORD changed by another thread during the call, raised after the section | `(changed-during-call password (kind string))` | |

  - Both releases answer 0 to 2³²−1 for the password range, which holds the whole cap, so no
    release reaches `length-out-of-range`.
  - `changed-during-call` is held by `test-password-verbs.sps:972-1003`, with an engine. It was not
    re-run here.
- **`&sodium-failed`:** function `"crypto_pwhash_str"`, who `password-hash`
  (`password-verbs.sls:169-171`).
  - The code is libsodium's answer when that is not 0. The real library answers -1 when it cannot
    get the memory: `out/failed.out` and `out/oom.out`, both libraries, under `ulimit -v 524288` at
    `'sensitive`.
  - The code is 0 when libsodium answers 0 but leaves no readable string. Only a decoy does this
    (`out/failed.out`: `pwhash-str-unreadable` and `pwhash-str-empty`).
- **Section:** one, `password-verbs.sls:155-168`.
- **C:** `crypto_pwhash_str`, `__collect_safe` (`native.sls:619-622`). Two blocks are wiped: the
  password's UTF-8, and the output of `strbytes`, 128 bytes.

#### `password-verify hash password`

Note the order: the hash, then the password.

- **Answers** `#t` when PASSWORD is the one HASH was made from.
  - `#f` for a wrong password, for a hash libsodium cannot read, and for short memory (item 2).
  - `#f` with no C and no section for a hash that fails the pre-check (`password-verbs.sls:189-190`).
    The pre-check needs at least one and at most 65536 characters, each U+0021 to U+007E, so no
    space, no newline, no U+0000 and no non-ASCII (`password-text.sls:57-64`).
- **Refusals,** from `password-verify`: HASH not a string, `(not-a-string hash (kind K))`; then the
  password's three, as for `password-hash`, from `password-verify`.
  - **Every refusal comes before the pre-check:** a password over the cap raises even with the hash
    `""` (`pv-password-over-cap-bad-hash`).
  - A hash over the cap is answered `#f`, never refused (`pv-hash-over-cap`).
  - A hash or password changed during the call is `(changed-during-call hash|password (kind
    string))`, raised after the section.
- **`&sodium-failed`:** never.
- **Section:** one, `password-verbs.sls:192-200`.
- **C:** `crypto_pwhash_str_verify`, `__collect_safe` (`native.sls:625-628`). Two blocks are wiped:
  the hash with its terminating 0, and the password.

#### `password-needs-rehash? hash [limits]`

- **Answers** `#f` only when libsodium answers 0 and the hash passes the pre-check and the shape
  check (`password-verbs.sls:223-232`). Everything else is `#t`.
  - The shape check: the loaded prefix, `v=` digits, `$m=` digits, `,t=` digits, `,p=1$`, and one
    character more (`password-text.sls:74-104`).
  - A hash that fails either check answers `#t` with no C and no section.
  - LIMITS defaults to `'interactive`.
  - An `'interactive` hash answers `(#f #t #t #f)` at `'interactive`, `'moderate`, `'sensitive` and
    the default. `"garbage"` and `""` answer `#t` (`out/answers.out`).
- **Refusals,** from `password-needs-rehash?`: HASH not a string, `(not-a-string hash (kind K))`;
  LIMITS bad, `(not-password-limits limits V)`. **Refusals come before the checks:** `""` with bad
  limits is refused (`pn-bad-hash-bad-limits`).
- It never raises because of the hash. A hash changed during the call answers `#t`.
- **`&sodium-failed`:** never.
- **Section:** one, `password-verbs.sls:226-231`.
- **C:** `crypto_pwhash_str_needs_rehash`, plain, and `sodium_memzero` on its one block.

#### `make-password-limits ops memory-kib`

- **Answers** an opaque, sealed Password-limits (`password-verbs.sls:45-49`).
  - `record?` is `#f`, and `write` prints `#<limits-record>`.
  - Two made from the same numbers are not `equal?`, but every verb compares the numbers, so they
    act alike (`out/login-facts.out`).
- **Refusals,** from `make-password-limits` (`password-verbs.sls:86-98`), the ranges the same at
  both releases:

  | Mistake | Irritants | Message |
  |---|---|---|
  | OPS no exact natural | `(not-a-natural ops V)` | `ops is not an exact natural` |
  | OPS outside 1 to 4294967295 | `(ops-out-of-range ops 0)` | `ops is from 1 to 4294967295` |
  | MEMORY-KIB no exact natural, `64.0` included | `(not-a-natural memory-kib V)` | `memory-kib is not an exact natural` |
  | MEMORY-KIB outside 8 to 4294967295 | `(memory-out-of-range memory-kib 7)` | `memory-kib is from 8 to 4294967295` |

- **Section:** none, and no C. It reads the constants the load read, so naming it runs the load
  (item 2, note D6).

#### The predicates and accessors

- **The predicates** take Any and load nothing. `(chez-sodium-error? 'x)` is `#f`. A program that
  names only them survives a refused load (`out/when-load.out`, `when-predicate-only`).
- **Each accessor checks its argument** (`conditions.sls:147-151`). Anything else is refused from the
  accessor, `(not-a-sodium-failed (kind K))` or `(not-a-sodium-library-unavailable (kind K))`, with
  the message `not a &sodium-failed` or `not a &sodium-library-unavailable`.

#### Arity

A wrong number of arguments is Chez's own refusal. Its who is `#f`, its message `incorrect number
of arguments ~s to ~s`, and its irritants are the count and the procedure (`arity-*` in
`out/refusals.out`).

### 1.3 The condition tree

```
&error
 └ &chez-sodium-error            chez-sodium-error?
    ├ &sodium-library-unavailable  sodium-library-unavailable?   reason path source detail candidates
    └ &sodium-failed               sodium-failed?                function code
```

Defined at `conditions.sls:42-43`, `183-189` and `260-263`. No `&` name and no constructor is
exported (ADR-0012).

| Condition | Raised by | Compounded with | Holds |
|---|---|---|---|
| `&sodium-library-unavailable` | the load: the first reference to any verb or to `make-password-limits`, raised again at every later one | `&who` `chez-sodium`, a `&message` that names the remedy, and `&irritants`: the path, the candidates list, or the override's value (`conditions.sls:246-250`) | `error?`, `serious-condition?`, `chez-sodium-error?` (`out/load.out`) |
| `&sodium-failed` | `password-hash`; `blake2b` (no release) | `&who` the verb, the fixed `&message` `libsodium gave no result for a call that passed its checks`, and no irritants (`conditions.sls:298-303`) | `error?`, `chez-sodium-error?`, not `assertion-violation?` (`out/failed.out`) |
| `&assertion` | every caller's mistake (§1.2) | `&who` the verb, `&message`, `&irritants` `(RULE PARAMETER V)` | not `chez-sodium-error?` |

**Uncaught,** each prints one line, and the program exits 255 (`out/load.out`, `out/failed.out`):

```
Exception in chez-sodium: MESSAGE with irritant X
Exception in password-hash: libsodium gave no result for a call that passed its checks
```

A long `not-found` list is cut to `...` in that line, so the full list comes from
`sodium-library-unavailable-candidates`.

---

## 2. Each "Owed to M4" note, checked

Each row gives the fact as a page could state it, then the evidence, then whether the note needs a
correction.

### From M1

- **M1-a. The first reference under an engine** (ADR-0007, Consequences, `:88-94`; traps.md, "A
  library first reached inside an abandoned engine stays wedged"). Not re-measured.
  - **Fact:** a program that names any chez-sodium procedure loads libsodium before its first line,
    so engines are safe.
  - Only a first reference through `eval` or the REPL can fall inside an engine. If that engine is
    then dropped, every later reference raises Chez's "cyclic dependency involving invocation of
    library", until the process restarts.
  - So reach the library once, for example `(sodium-version)`, before making engines.
  - The verbs themselves are safe inside engines: row 18 runs each one at every fuel.
  - Correction: none.
- **M1-b. The first reference on two threads at once** (ADR-0007, amendment, `:139-150`; traps.md
  `:74-100`; `research/m1-closing-review/`: `#(ready (raised "cyclic dependency involving invocation
  of library ~s") (later ready))`).
  - **Fact:** if two threads first reach chez-sodium at once, through `eval` or the REPL, the second
    gets that same Chez condition, not a `&sodium-library-unavailable`. A later reference works.
  - A program that names a chez-sodium procedure never meets it. Otherwise reach the library once
    on one thread before forking.
  - Correction: none.
- **M1-c. `sodium_init`'s 1.** A program calls `sodium_init` itself, which answers 0, and then
  reaches chez-sodium: it loads, the load records 1, and a later call answers 1, at both releases
  (`out/init-first.out`).
  - **Fact:** if another library in the process already started libsodium, chez-sodium loads all the
    same. The user sees nothing.
  - Correction: none.
- **M1-d. What wiping cannot reach** (ADR-0008, decision 5, `:44-49`; brief §6.3 `:489-496`).
  - Measured (`out/wipe-reach.out`): the caller's password string is untouched by `password-hash`.
    `string-fill!` wipes the caller's own string, a literal included. `random-bytes`' answer is a
    fresh bytevector, the caller's to wipe.
  - **Fact:** chez-sodium wipes the C memory it uses. It cannot wipe your password string, the
    request body or a parser's copies, the bytes a verb returns, or copies the collector leaves.
    `string-fill!` and `bytevector-fill!` clear your own copy, not the others.
  - Correction: none.

### From M2

- **M2-a. What the cap is.** `input-cap` is 65536 (`cap.sls:20`), counted in bytes, and 65536 is
  accepted where 65537 is refused (`out/refusals.out`, `out/login-facts.out`).
  - **Fact:** every input is at most 64 KiB. That covers a password, counted as UTF-8 bytes;
    `blake2b`'s input; both operands of the compare; and `random-bytes`' N.
  - A hash string over 64 KiB is answered (`#f`, or `#t` from needs-rehash), never refused.
  - `blake2b`'s size and key are at most 64 bytes, by libsodium's own bounds.
  - A password of at most 16384 characters is always within the cap, since a character takes at most
    4 bytes. That bound is inferred from UTF-8, not probed.
  - Cost at the cap (`out/timing.out`):

    | Call | 1.0.22 | 1.0.18 | Small input |
    |---|---|---|---|
    | `random-bytes`, 64 KiB | 1.96 ms | 1.79 ms | 2 µs, 32 bytes |
    | `blake2b`, 64 KiB | 1.99 ms | 1.80 ms | 4 µs, 32 bytes |
    | the compare, two 64 KiB operands | 3.84 ms | 3.63 ms | 3 µs, 32 bytes |
    | a 64 KiB password at the least limits | 2.26 ms | 2.09 ms | 22 µs, 13 characters |

  - Correction: none.
- **M2-b. The compare leaks only the lengths.** `sodium_memcmp` ORs every byte's XOR, whatever it
  finds (`utils.c:179-182` at 1.0.18, `:201-204` at 1.0.22).
  - Measured medians (`out/compare-timing.out`):

    | Operands | 32 bytes | 64 KiB |
    |---|---|---|
    | Equal | 2.8 to 3.0 µs | 3652 to 3784 µs |
    | Differ in the first byte | 2.9 µs | 3764 to 3782 µs |
    | Differ in the last byte | 2.9 to 3.0 µs | 3688 to 3735 µs |
    | One byte shorter | 0.0 µs | 0.0 µs |

  - **Fact:** equal-length operands take the same time wherever they differ. Different lengths
    answer `#f` at once, so the time shows whether the lengths match. Compare values of a fixed
    length, such as hashes.
  - Correction: none.
- **M2-c. `random-bytes` aborts without an entropy source.** **Correct the note.**
  - libsodium stirs its generator inside `sodium_init` (`core.c:40` at both releases).
  - On Linux it tries `getrandom`, then opens `/dev/urandom`, and calls `sodium_misuse()` if neither
    works (`randombytes_sysrandom.c:262-283`, misuse at `:281`).
  - `sodium_misuse()` calls `abort()` when no handler is set, and chez-sodium sets none
    (`core.c:187-199` at 1.0.18, `:189-201` at 1.0.22).
  - `randombytes_buf` aborts later only if that source then fails (`:349-352`, `:356-359`). Read,
    not induced.
  - **Fact:** with no entropy source at all, the process aborts when chez-sodium loads libsodium,
    before any verb runs. `random-bytes` aborts only if the source fails after that. Nothing can
    catch either.
- **M2-d. `blake2b` can raise `&sodium-failed`.**
  - `crypto_generichash` answers -1 only for an output of 0 or over 64 bytes, or a key over 64
    (`generichash_blake2b.c:16-18`, the same at both releases). Otherwise it answers what `blake2b()`
    answers, which aborts on NULL misuse and returns 0 (`blake2b-ref.c:340-362`).
  - The verb's checks rule out those sizes, so no release reaches the raise. A decoy does
    (`out/failed.out`: function `"crypto_generichash"`, codes -1 and 1, who `blake2b`).
  - **Fact:** `blake2b` raises `&sodium-failed` only if libsodium fails a call that passed the
    checks, which no release does. Catch it, if at all, beside `password-hash`'s.
  - Correction: none, but the reference should say no release reaches it.

### From M3

- **M3-a. `password-verify` answers `#f` for a wrong password, an unreadable hash and short memory
  alike, with the caller's fallback** (`out/oom.out`; cap `ulimit -v 524288`, 512 MiB).

  | Case | 1.0.22 and 1.0.18 |
  |---|---|
  | `'sensitive` hash, right password, capped | verify `#f`; the fallback's throwaway hash at `'sensitive` raises `&sodium-failed` -1, so it reads as short memory |
  | The same, wrong password, capped | verify `#f`, then the same raise, so it reads as short memory too. A wrong password cannot be told from short memory there |
  | `'sensitive` hash, right password, capped, fallback at `'interactive`, not the hash's limits | verify `#f`; the throwaway hash succeeds, so it **misreads as a wrong password** |
  | `'sensitive` hash, wrong password, uncapped | verify `#f`; the throwaway succeeds, so a wrong password |
  | Stored `"garbage"`, right password, uncapped, fallback at `'interactive` | verify `#f`; the throwaway succeeds, so it reads as a wrong password |

  - **Fact:** `#f` means one of three things, and chez-sodium cannot tell which. To guess at short
    memory, hash a throwaway string at your current limits after a `#f`: a `&sodium-failed` there
    means memory is short.
  - The guess sees only a failure libsodium is told of, as under `ulimit -v`. A container's memory
    limit kills the process instead (M3-c).
  - It fits only hashes made at your current limits.
  - Correction: add that under short memory a wrong password also reads as short memory. Mark "or
    with no overcommit" as unmeasured (§6, D7).
- **M3-b. A hash's own limits set what verifying it costs.** A real `'interactive` hash with its
  parameter field edited, verified with the right password (`out/tampered-cost.out`):

  | Field | Answer | 1.0.22 | 1.0.18 |
  |---|---|---|---|
  | `m=65536,t=2` | `#t` | 51 ms | 49 ms |
  | `m=65536,t=20` | `#f` | 419 ms | 397 ms |
  | `m=262144,t=3` | `#f` | 329 ms | 328 ms |
  | `m=1048576,t=4` | `#f` | 1766 ms | 1760 ms |

  - **Fact:** verifying costs whatever the stored string asks for, whatever limits you use. Keep
    hashes where only you can write them.
  - Correction: none.
- **M3-c. A container's memory limit can get the process killed.** Measured on the host: a
  `systemd-run --user --scope` with `MemoryMax=512M` and `MemorySwapMax=0`, around the container
  (`probes/cgroup.sh`, `out/cgroup.out`).
  - At both releases, `'interactive` hashes, and exits 0.
  - At `'sensitive`, `password-hash` and `password-verify` are both "Killed", exit 137. Nothing is
    raised.
  - This closes the brief review's unrecorded "cgroup kill accepted" (`research/brief-review/
    review.md:47`).
  - **Fact:** under a container's memory limit, a hash that needs more memory than is left gets the
    process killed. Size the container for the limits' memory times the hashes that can run at once,
    64 MiB each at `'interactive`, plus the program's own.
  - Correction: none.
- **M3-d. The login pattern** (ADR-0009, decision 6). `password-needs-rehash?` answers `#t` for
  `"garbage"` and `""` (`out/answers.out`), so a caller who rehashes before verifying would store a
  password nobody checked. The pattern runs in `probes/examples/login.sps`.
  - **Fact:** call `password-needs-rehash?` only after `password-verify` answers `#t`.
  - Correction: none.
- **M3-e. A password changed by another thread during the call is refused**, as
  `changed-during-call` (`password-verbs.sls:172-173`, `202-205`; `test-password-verbs.sps:972-1003`
  makes it deterministic with an engine). Not re-run.
  - **Fact:** don't change a string while a verb reads it. If you do, the call is refused, never
    answered wrongly.
  - Correction: none.
- **M3-f. A password over the cap is refused by `password-verify`, not answered `#f`.** Confirmed at
  both releases: 65537 ASCII characters, or 32769 two-byte ones, are `(over-the-cap password (kind
  string))`; 65536 ASCII, or 32768 two-byte, answer `#f` (`out/login-facts.out`).
  - The refusal comes before the pre-check, so it raises even for an unknown account's dummy check.
    A password that is no string, such as `#f` from a missing form field, is `not-a-string`.
  - **Fact:** check that the password is a string of at most 16384 characters before
    `password-verify`, or catch `assertion-violation?`.
  - Correction: add the non-string case and the 16384-character bound.
- **M3-g. A hash string is stored exactly.** At both releases (`out/login-facts.out`):

  | Stored | Verify | needs-rehash |
  |---|---|---|
  | exact | `#t` | `#f` |
  | a trailing space, newline or CRLF, or a leading space | `#f` | `#t` |
  | `"\x0;junk"` appended | `#f` | `#t` |
  | `x` appended | **`#f`** | **`#f`** |
  | last character dropped | `#f` | `#f` about 1 time in 16, otherwise `#t`, at either release (corrected by the caller; see D3) |

  - libsodium decodes the tag at whatever length it finds (`argon2-encoding.c:193-203`), and checks
    only that it is at least 16 bytes (`argon2-core.c:265` at 1.0.22). So `password-needs-rehash?`
    reads a hash's limits, never whether the hash is whole.
  - **Fact:** store the hash string exactly as `password-hash` gave it. Any change, even one stray
    space or newline, makes it verify `#f` for ever, and `password-needs-rehash?` will not notice.
  - **Correction:** widen "a stray space or newline" to any change, and add that needs-rehash may
    still answer `#f`.
- **M3-h. The calling thread's interrupts wait while a hash runs.** **Correct the numbers.**
  - SIGINT, which Ctrl-C sends, was sent mid-hash (`probes/interrupts.sh`, `out/interrupts.out`, two
    runs at each library). The handler ran the instant the work ended, within 0.1 ms: 53.3 to 57.5 ms
    in at `'interactive`, and 1935 to 2087 ms in at `'sensitive`.
  - The control, a plain Scheme loop, handled it at 302 to 313 ms, as sent.
  - The hash's medians are 49.0 to 50.5 ms at `'interactive` and 1.83 to 1.84 s at `'sensitive`
    (`out/timing.out`).
  - Other threads keep running: while a worker hashed at `'sensitive` for 1847 to 1969 ms, the main
    thread allocated and collected 184 to 196 times. Its longest gap and its longest collection were
    each 0.4 to 0.5 ms (`out/threads.out`).
  - Timers and engine expiries wait too: ADR-0007's Consequences say so, and an engine spends no
    ticks inside a section (traps.md). They were not timed here.
  - **Fact:** on the thread that hashes, Ctrl-C, timers and engine expiries wait for the hash, about
    50 ms at `'interactive` and about 2 s at `'sensitive`. Other threads don't wait, so hash on a
    worker thread.
  - Correction: "about 55 ms" becomes "about 50 ms", and "seconds" becomes "about 2 s".
- **M3-i. An unknown account is checked against a real hash.** **Correct the note.** Medians over 9
  runs (`out/timing.out`):

  | Dummy | 1.0.22 | 1.0.18 |
  |---|---|---|
  | a real `'interactive` hash | 49.7 ms | 47.6 ms |
  | `""`, refused by the pre-check | 0.000 ms | 0.000 ms |
  | `"no such user"`, refused by the pre-check | 0.000 ms | 0.000 ms |
  | `"*"`, which passes the pre-check and fails in C | 0.002 ms | 0.002 ms |
  | `$argon2id$v=19$m=65536,t=2,p=1$c29tZXNhbHQ`, with its tag missing | 0.003 ms | 0.003 ms |

  - **Fact:** for a name with no account, verify the password against one real hash made at your
    current limits, and refuse whatever it answers. Anything that is not a real hash answers about
    20,000 times faster, which tells the two apart.
  - Correction: "never a string the pre-check refuses" becomes "never any string that is not a real
    hash". A string the pre-check passes is just as fast.
- **M3-j. Custom limits go to both `password-hash` and `password-needs-rehash?`.** A hash at
  `(make-password-limits 3 19456)` answers needs-rehash `#f` given those limits, or a fresh
  Password-limits with the same numbers. It answers `#t` given nothing, `'interactive`, or other ops
  or memory. A default hash given `(make-password-limits 2 65536)` answers `#f`
  (`out/login-facts.out`).
  - **Fact:** give your limits to both. Without them needs-rehash compares with `'interactive`, and
    every login rehashes.
  - Correction: none.
- **M3-k. No normalisation.** `"café"` written with U+00E9 is 4 characters and 5 bytes. Written with
  e and U+0301 it is 5 characters and 6 bytes. Each verifies only against its own hash
  (`out/login-facts.out`).
  - **Fact:** a password is hashed as its exact UTF-8. Normalise it yourself, the same way every
    time, if your users' keyboards may differ.
  - Correction: none.
- **M3-l. The rehash can raise `&sodium-failed` after a `#t`.** An `'interactive` hash, capped,
  rehashed to `'sensitive`: verify `#t`, needs-rehash `#t`, then `password-hash` raises
  `&sodium-failed` `"crypto_pwhash_str"` -1, at both releases. Uncapped, it succeeds
  (`out/oom.out`).
  - **Fact:** wrap the rehash. If it fails, keep the old hash and log the user in.
  - Correction: none.

### The other two lines

- **`check-floors`' docs rule.** chez-sqlite3's version reads `docs/` and refuses either floor's
  version text on any page: a page names the floors by a link to README's Requirements
  (chez-sqlite3 `tests/check-floors.sps:10-18`; its Makefile line 390). So no page may write the
  floor's version text, such as the version string `sodium-version` prints at the floor, or the
  Chez floor in the unthreaded refusal's message (§4).
- **`test-manifest`'s install lines** wait for the release, and are not this part's.

---

## 3. Finding libsodium

From `discovery.sls`, `native.sls` and `verify.sls`, run by `probes/load.sh` (`out/load.out`). It
builds `tests/decoy-libsodium.c`, unchanged, against the floor's headers, as `libsodium.so.23`.

### 3.1 The order

1. **`CHEZ_SODIUM_LIBRARY`, when set,** must be an absolute path. It is loaded as given: never
   checked for existence, never searched, never a fallback (`discovery.sls:55-68`).
   - A bare name, a relative path, or `""` is `invalid-override`.
   - Nothing reads `LD_LIBRARY_PATH` (`discovery.sls:13`).
2. **Otherwise the world decides.** It is Guix when `/proc/self/maps` shows `libc.so.6` under
   `/gnu/store/`, and FHS otherwise, an unreadable maps included (`discovery.sls:109-118`;
   `native.sls:188-196`).
3. **In each directory, `libsodium.so.26` comes before `libsodium.so.23`,** and the bare
   `libsodium.so` is never tried (`discovery.sls:46`). The first candidate that exists is loaded,
   and only it.

The candidate lists, from the pure procedure (`out/load.out`, `candidates.sps`):

| World | Directories, in order | Source |
|---|---|---|
| Guix | `lib/` under `$GUIX_ENVIRONMENT`, `$GUIX_PROFILE`, `~/.guix-home/profile`, `~/.guix-profile`, then `/run/current-system/profile` | `guix-environment`, `guix-profile`, `guix-home`, `guix-user-profile`, `guix-system` |
| other Linux | `/usr/local/lib`, `/usr/lib/x86_64-linux-gnu` (`/usr/lib/aarch64-linux-gnu` on arm64), `/usr/lib64`, then `/usr/lib` | `system` |
| any other machine type | none, so `not-found` | |

- The override's source is `override` (`discovery.sls:39-41`).
- An unset, empty or relative `GUIX_ENVIRONMENT` or `GUIX_PROFILE` adds nothing
  (`discovery.sls:147-158`). Measured: with `GUIX_ENVIRONMENT=` empty and `GUIX_PROFILE` holding
  both sonames, the profile's `.so.26` loads.
- Measured in the container, with the override unset: discovery loads
  `$GUIX_ENVIRONMENT/lib/libsodium.so.26`, source `guix-environment` (`out/make-build.out`).
  - A profile holding `.so.23` alone loads 1.0.18.
  - A profile holding both loads the `.so.26`.
- The sonames follow the release: `.so.23` for 1.0.17 and 1.0.18, `.so.26` for 1.0.19 to 1.0.22
  (ADR-0002, Context). Only the version string decides the floor; the soname never does.
- The FHS world could not be run here, since the container's libc is Guix's. Its list is the pure
  procedure's.

### 3.2 When it is refused

Every refusal is a `&sodium-library-unavailable`, raised at the first reference and again, the same
object, at every later one (`second-raise-is-the-same-condition #t`). Setting a good
`CHEZ_SODIUM_LIBRARY` afterwards changes nothing (`out/load-once.out`: `(first load-failed
after-putenv load-failed same-condition #t)`).

| Reason | Reached here by | path | source | detail | candidates | Message (the remedy) | Code |
|---|---|---|---|---|---|---|---|
| `invalid-override` | `libsodium.so.23`, `""`, `lib/libsodium.so.23` | `#f` | `override` | the value | `()` | `CHEZ_SODIUM_LIBRARY must be an absolute path to libsodium, which chez-sodium loads with no search of its own; set one, or unset it to use discovery` | `discovery.sls:64-68` |
| `not-found` | empty profiles, override unset | `#f` | `#f` | `#f` | every path checked, in order | `no libsodium found among the candidates; name one with CHEZ_SODIUM_LIBRARY, an absolute path` | `discovery.sls:74-83` |
| `load-failed` | `/no/such/libsodium.so.23`; a text file | the path | its source | the loader's text, e.g. `… cannot open shared object file: No such file or directory`, `… invalid ELF header` | `()` | `the loader refused this libsodium; name one this Chez can load with CHEZ_SODIUM_LIBRARY, an absolute path` | `native.sls:545-551` |
| `below-floor` | a decoy at 1.0.17; NULL; `1.0.18-stable` | the path | its source | the string, or `#f` for NULL | `()` | `libsodium 1.0.17 is older than chez-sodium's floor, …; name a newer one with CHEZ_SODIUM_LIBRARY`, or `libsodium's version string is NULL, …` | `verify.sls:260-275` |
| `missing-api` | a decoy without `crypto_pwhash_str`; a shared object with no libsodium function | the path | its source | the entry point's C name: `"crypto_pwhash_str"`, or `"sodium_version_string"` | `()` | `the library has no crypto_pwhash_str, so it is not a libsodium chez-sodium can use; name another with CHEZ_SODIUM_LIBRARY` | `native.sls:208-214` |
| `init-failed` | a decoy whose `sodium_init` answers -1 | the path | its source | the integer, -1 | `()` | `sodium_init failed; name another libsodium with CHEZ_SODIUM_LIBRARY` | `verify.sls:284-293` |

- A decoy whose `sodium_init` answers 1 loads.
- The irritants are `(PATH)`; for `not-found`, `(CANDIDATES)`; for `invalid-override`, `(VALUE)`.
- **A guard around a direct call cannot catch a refusal.** A program that names a verb loads before
  its first line: `load-uncaught.sps` printed only the Exception line and exited 255, and its "first
  line ran" never printed.
  - Reach the load through `eval` inside the guard instead, as `probes/examples/version.sps` does. It
    printed `(refused load-failed "/no/such/libsodium.so.23")` and `(refused invalid-override #f)`
    (`out/examples.out`).
  - Naming only a predicate or accessor loads nothing (`out/when-load.out`).
- **There is no public accessor for the loaded path.** `sodium-version` is the one report.
  `make build`, in a clone, prints the path, its source and the libtool numbers
  (`out/make-build.out`; `tests/preflight.sps`). For example:

  ```
  chez-sodium: libsodium loaded and accepted
    path:       …/lib/libsodium.so.26 (guix-environment)
    version:    1.0.22 (library 26.4)
  ```

---

## 4. Installing

- **Requirements** (README.org's Requirements; `packaging/floors.sexp`): Chez Scheme 10.4.0 or
  later, built with threads, and libsodium 1.0.18 or later at run time. A program needs no C
  compiler, no headers, no build step and no submodule.
- **Today, before a release, the steps are a clone and `--libdirs`.** Checked from a fresh local
  clone made on the host, `git clone <repo> build/m4-plan/b/clone`, at `d53e83c`. It has no
  submodules: `vendor/chez-srfi` is empty (`out/clone.out`).
  - **The first program** is `probes/app.sps`, run from `build/m4-plan/b` with `scheme --libdirs
    clone/src --program …/app.sps`. It printed `("1.0.22" #t #f 32)`, and `("1.0.18" #t #f 32)` at
    the floor.
  - **Timing:** 0.28 to 0.29 s with one `'interactive` hash and two verifies. A program that only
    prints the version takes 0.11 s.
  - Chez compiles the libraries from source at each run, and writes no `.so` into `src/`.
  - **`make -C clone build` works without submodules.** It prints the loaded path and version.
  - **No tag exists yet.** A `--branch v0.1.0` line waits for the release, which is the other
    agent's.
- **What `(import (chez-sodium))` needs:** the clone's `src` on the library path, and a threaded
  Chez of 10.4.0 or later. libsodium is needed only when a binding that loads it is referenced.
- **An unthreaded Chez.** Each library under `src/` imports `(chez-sodium private require-threaded)`
  first, and that library raises a syntax violation, who `chez-sodium`, while it is expanded
  (`require-threaded.sls:77-81`). It was not measured on a real `--nothreads` build. Faked as
  `test-require-threaded` fakes it (`probes/nothreads-message.sps`), the default handler prints:

  ```
  Exception in chez-sodium: chez-sodium needs a threaded Chez Scheme, and (threaded?) is #f in this one. Chez builds threaded unless configured with --nothreads (require-supported-chez)
  ```

  - A real run would print the form's source position instead of the bare form. That is inferred.
  - CI's `nothreads` job builds Chez with `--nothreads` and runs `make check-nothreads`, which needs
    each library refused by name (`.github/workflows/ci.yml:251-298`; `tests/check-nothreads.sps`).
  - **A Chez older than the floor** gets `chez-sodium needs Chez Scheme 10.4.0 or later, and this
    one is X` (`require-threaded.sls:82-87`). Read, not run. A page must paraphrase it, since it
    holds the floor's text (item 2).
  - chez-sqlite3's quick start says Ubuntu 24.04's `chezscheme` package, 9.5.8, is too old
    (chez-sqlite3 `docs/quickstart.md:11-13`). Not re-checked here.

---

## 5. A proposed page set

ELI5 and short. A page names the floors only by a link to README's Requirements (item 2). Each
fact below cites its evidence in items 1 to 4.

### 5.1 The pages

1. **`README.org`**, rewritten.
   - What it is, in one paragraph, and the four jobs.
   - Status: every verb is built; Linux only; the versions CI runs (§6, D1).
   - Requirements: the one place the floors are written.
   - Installing: a clone and `--libdirs` (§4).
   - A taste: a twin of a `scheme run` block of the quick start.
   - The documentation list, the AI disclosure, and the licence. No link into `.plans/`.
2. **`docs/quickstart.md`**
   - What you need (§4).
   - Get it.
   - Put it on the library path.
   - A first program: `app.sps` without the version in its output, so the floor lane matches.
   - Which libsodium did it load? The `eval` guard (§3.2), and `make build`.
   - Running the tests: submodules, then `make test`.
   - Next.
3. **`docs/passwords.md`**, the login guide.
   - Hash and check (§1.2).
   - The presets: time and memory, measured here (M3-h, M3-b).
   - Your own limits: KiB, OWASP's `19456`, and give them to both verbs (M3-j).
   - Logging in: the pattern, why the order matters, and a rehash that fails (M3-d, M3-l).
   - No such account (M3-i).
   - Before you verify: a string, at most 16384 characters (M3-f).
   - Store the hash exactly (M3-g).
   - What `#f` means, and the fallback with its limits (M3-a).
   - Memory: `ulimit` against a container, and sizing (M3-c).
   - Where hashes live (M3-b).
   - Threads and Ctrl-C (M3-h).
   - Text: no normalisation, U+0000 allowed (M3-k; `answers.out`'s `nul-password-round-trip`).
4. **`docs/tokens.md`**, API keys and tokens.
   - Make one: `random-bytes`.
   - Store only its hash: `blake2b`.
   - Check one: look it up by its id, then compare in constant time (M2-b).
   - Sizes and keys: 16 to 64, an empty key refused, a key needs a size (§1.2).
   - When the system has no entropy (M2-c).
5. **`docs/examples.md`**: `login.sps` and `token.sps` whole, each with its output (§5.3).
6. **`docs/finding-libsodium.md`**
   - Name it yourself.
   - Or let it look: the table by world.
   - Which soname.
   - When it is refused: the reasons table.
   - Who needs the override.
   - It loads once (§3).
7. **`docs/safety.md`**, what it guards and what it cannot. These can fold into the pages above if
   fewer pages are wanted.
   - The 64 KiB cap (M2-a).
   - No secret in a condition (§1.2).
   - The wipe and its reach (M1-d).
   - Engines and the first reference (M1-a, M1-b).
   - What aborts (M2-c).
   - What raises `&sodium-failed` (M2-d, M3-l).
8. **`docs/reference.md`**
   - The type glossary (§1.1).
   - One `###` entry per export, with its signature and refusals (§1.2).
   - "The library": the load, once, at the first reference; `eval` inside the guard (§3.2).
   - Conditions (§1.3).

### 5.2 Blocks a `test-docs` rule could run

Times are plain unless noted. A version-dependent answer must be read by the suite itself, as
chez-sqlite3's rule reads `sqlite-version`, or left out of the text.

| Block | Kind | Deterministic at both releases | Cost |
|---|---|---|---|
| `(bytevector-length (blake2b (string->utf8 "abc")))` → `32`; `(random-bytes 0)` → `#vu8()`; `(bytevector-length (random-bytes 32))` → `32` | `scheme run` | yes | µs |
| `(constant-time-bytevector=? (bytevector 1 2 3) (bytevector 1 2 3))` → `#t`; different lengths → `#f` | `scheme run` | yes | µs |
| A round trip at cheap limits: `(let ((h (password-hash "correct horse" (make-password-limits 1 8)))) (list (password-verify h "correct horse") (password-verify h "battery staple")))` → `(#t #f)` | `scheme run` | yes | 23 µs a hash |
| The default's field: `(substring (password-hash "correct horse") 0 31)` → `"$argon2id$v=19$m=65536,t=2,p=1$"` | `scheme run` | yes | 50 ms; about 0.7 s under Valgrind (brief §8.2) |
| Custom limits: `(list (password-needs-rehash? h mine) (password-needs-rehash? h))` → `(#f #t)` | `scheme run` | yes | 13.6 ms a hash at `(make-password-limits 2 19456)` (`out/owasp-cost.out`) |
| A stored hash with `"\n"` → `#f`; NFC against NFD → `#f` | `scheme run` | yes | cheap limits |
| Refusals by rule symbol: `(guard (e ((assertion-violation? e) (car (condition-irritants e)))) …)` → `over-the-cap`, `empty-key`, `memory-out-of-range`, `not-a-sodium-failed` | `scheme run` | yes (`refusals.out`) | µs |
| `(string? (sodium-version))` → `#t` | `scheme run` | yes; the version itself is not | µs |
| `probes/examples/login.sps` | whole program and text block | yes (`examples.out`) | 0.49 s; 9.5 s under Valgrind |
| `probes/examples/token.sps` | whole program and text block | yes | 0.10 s; 4.9 s under Valgrind |
| `probes/examples/version.sps` | whole program | prints the version, which differs by library; refused with a missing override: `(refused load-failed "/no/such/libsodium.so.23")` | 0.11 s; 4.9 s under Valgrind |
| The quick start's `app.sps`, without the version | whole program | yes | 0.28 s |
| The reasons table | table against `sodium-library-unavailable-reasons` (`conditions.sls:166-167`) | yes | |
| The discovery table | table against `libsodium-candidates` on `ta6le` and `tarm64le`, and the sources against `libsodium-sources` (`candidates.sps`) | yes | |
| Each `CHEZ_SODIUM_LIBRARY=` line gives an absolute path | text rule, as chez-sqlite3's | | |

Not runnable as tests: the timings, the `ulimit` and cgroup cases, the engine and thread races, the
entropy abort, and `&sodium-failed`, which needs a decoy or a memory cap. Show those as plain
`scheme` fragments.

### 5.3 The example programs and their outputs

Each was run at both releases (`out/examples.out`). The outputs are the same at both, with no
salt or random byte in them.

- **`probes/examples/login.sps`.** Old hashes at `(make-password-limits 2 19456)`, current limits
  `'interactive`.
  - It shows: the rehash on login, a wrong password, a second account, an unknown account checked
    against a real hash, and a password over 1024 characters refused before verify.
  - The rehash is wrapped, so a `&sodium-failed` keeps the old hash and still logs the user in.

  ```
  ("$argon2id$v=19$m=19456,t=2,p=1$" logged-in "$argon2id$v=19$m=65536,t=2,p=1$" refused logged-in refused refused)
  ```

- **`probes/examples/token.sps`.** `random-bytes 32`, stored as its `blake2b` under an id, then
  looked up by id and compared with `constant-time-bytevector=?`. It checks the right token, one
  with a flipped bit, and a wrong id:

  ```
  (32 32 #t #f #f)
  ```

- **`probes/examples/version.sps`.** The `eval` inside the guard. It printed `"1.0.22"` at 1.0.22,
  `"1.0.18"` at the floor, and the refusal with an override that names nothing:

  ```
  "1.0.22"
  (refused load-failed "/no/such/libsodium.so.23")
  (refused invalid-override #f)
  ```

- **The unknown account** is in `login.sps`, as `cal`. Its timing (M3-i) suits prose, not a test.

---

## 6. Disagreements

Between the records, the comments or the "Owed" notes, and the code or its behaviour.

- **D1. README.org is stale.**
  - Its Status says "*One verb is built so far.*" and that the other verbs "come next"
    (`README.org:26-28`). Its opening is in the future tense: "will bind", "there will be nothing to
    compile" (`:10-12`). Every verb is built.
  - It links into `.plans/` (`:30`), which chez-sqlite3's docs rule forbids
    (`tests/test-docs.sps` there, "No link points into .plans/").
- **D2. `password-needs-rehash?`'s meaning is wider than its rules.**
  - ADR-0009, decision 1 (`:36`), brief §4.2 (`:229`), and AGENTS.md and the constraints' first
    Passwords bullet say it answers `#t` for "any hash that is not what `password-hash` would make
    now".
  - An argon2id hash with a 16-byte tag, which `password-hash` never makes, at the given limits,
    verifies `#t` and answers needs-rehash `#f` at both releases (`probes/other-tag.sps`,
    `out/other-tag.out`).
  - Decision 2's rules, and `current-hash-shape?` (`password-text.sls:74-104`), check no salt or tag
    length.
  - The docs should state the rules, not the gloss.
- **D3. A damaged hash can read as current.**
  - Brief §4.2 item 2 (`:236-238`) has libsodium answer -1 for a string "corrupt, truncated, …".
    ADR-0009's batch-job consequence (`:91-94`; brief `:270-272`) has a batch job see `#t` for
    unreadable hashes.
  - Measured: a hash with `x` appended answers `#f` at both releases. One with its last character
    dropped answers `#f` at 1.0.22 and `#t` at 1.0.18 (`out/login-facts.out`).
  - So a batch job cannot find damaged hashes.
  - **Corrected by the caller, 2026-11-25:** the answer does not differ by release. Over 400
    random hashes at `(make-password-limits 1 8)`, the last character dropped answered `#f` 22 to
    26 times, over two runs at each release, `#t` otherwise (`probes/truncated-tag.sps`,
    `out/truncated-tag.out`). A tag of 42 base64 characters decodes only
    when its last character's spare bits are zero, about 1 time in 16, so one run at each release
    can disagree by chance (the M4 plan, §2.2).
- **D4. "About 55 ms at `'interactive`"** (brief `:501`, `:717`; ADR-0001 `:32`; ADR-0009 `:56`;
  progress `:176`). The medians here are 49.0 to 50.5 ms, and moderate and sensitive match the
  brief's 0.3 s and 1.8 s (`out/timing.out`). Machine-dependent, so the docs should say "about
  50 ms here".
- **D5. Where the entropy abort comes.**
  - `byte-verbs.sls:65-66`, `native.sls:782-784` and progress `:161-162` place it in `random-bytes`
    or `randombytes_buf`.
  - With no source at all it comes in `sodium_init`, at the load (`core.c:40` →
    `randombytes_sysrandom.c:281`). See M2-c.
- **D6. `password-verbs.sls:81-82`** says `make-password-limits`' "first call … runs the load". A
  program that names it, even in a procedure never called, loads before its first line, and dies
  there on a bad override (`out/when-load.out`).
- **D7. The fallback's "or with no overcommit"** (progress `:166-167`; ADR-0006's M3 amendment,
  `:208-210`) is measured nowhere. It would need `vm.overcommit_memory=2`, which needs root. The
  container kill, "accepted" by the brief review with no output kept
  (`research/brief-review/review.md:47`, `libsodium/run_probes.sh:14`), is now measured (M3-c).
- **D8. The brief's API sketch writes `Nat`** (brief `:176-185`); the code's signature comments write
  `Natural` (`chez-sodium.sls:20-35`). `test-reference` holds the code's.
- **D9. M4 "delivers `CHANGELOG.md`"** (AGENTS.md; brief §9), but it exists already, with an empty
  `[Unreleased]` (`CHANGELOG.md:1-7`). M4 fills it in. A note, not a conflict.
- **D10. "Printable ASCII (U+0021 to U+007E)"** (brief §4.1 `:218`; ADR-0009, decision 5). Printable
  ASCII includes the space, U+0020, which the pre-check refuses (`password-text.sls:57-64`). The docs
  should say "no spaces".

---

## 7. Rerunning the measurements

From `<repo>`, on the host. Each command writes to stdout; `out/` holds what it printed here.

```sh
R=.plans/research/m4-plan/b/probes
# item 1: refusals, answers, exports
scripts/guix-env sh $R/both.sh $R/refusals.sps          # out/refusals.out
scripts/guix-env sh $R/both.sh $R/answers.sps           # out/answers.out
scripts/guix-env sh -c "CHEZ_SODIUM_LIBRARY=/no/such.so scheme --libdirs src --program $R/exports.sps"
# item 2
scripts/guix-env sh $R/both.sh $R/timing.sps            # out/timing.out, about 80 s
scripts/guix-env sh $R/both.sh $R/login-facts.sps       # out/login-facts.out
scripts/guix-env sh $R/oom.sh                           # out/oom.out
scripts/guix-env sh $R/both.sh $R/init-first.sps        # out/init-first.out
scripts/guix-env sh $R/interrupts.sh                    # out/interrupts.out
scripts/guix-env sh $R/both.sh $R/compare-timing.sps    # out/compare-timing.out
scripts/guix-env sh $R/both.sh $R/tampered-cost.sps     # out/tampered-cost.out
scripts/guix-env sh $R/both.sh $R/wipe-reach.sps        # out/wipe-reach.out
scripts/guix-env sh $R/both.sh $R/threads.sps           # out/threads.out
scripts/guix-env sh $R/both.sh $R/other-tag.sps         # out/other-tag.out
scripts/guix-env sh $R/both.sh $R/owasp-cost.sps        # out/owasp-cost.out
# the cgroup kill: make the two 'sensitive hashes first, as cgroup.sh's header says, then
systemd-run --user --scope -q -p MemoryMax=512M -p MemorySwapMax=0 \
  scripts/guix-env sh $R/cgroup.sh                      # out/cgroup.out
# item 3
scripts/guix-env sh $R/load.sh                          # out/load.out; builds the decoys
scripts/guix-env sh $R/failed.sh                        # out/failed.out; after load.sh
scripts/guix-env sh -c "good=\$CHEZ_SODIUM_LIBRARY; CHEZ_SODIUM_LIBRARY=/no/such.so scheme --libdirs src --program $R/load-once.sps \"\$good\""
scripts/guix-env sh -c "for p in when-limits-named when-predicate-only; do CHEZ_SODIUM_LIBRARY=/no/such.so scheme --libdirs src --program $R/\$p.sps; echo \$?; done"
scripts/guix-env sh -c 'make build; CHEZ_SODIUM_LIBRARY=$PWD/build/slice5/prefix-1.0.18/lib/libsodium.so.23 make build; unset CHEZ_SODIUM_LIBRARY; make build'
# item 4
git clone <repo> build/m4-plan/b/clone                  # on the host; no submodules
scripts/guix-env sh -c 'cd build/m4-plan/b && scheme --libdirs clone/src --program ../../../.plans/research/m4-plan/b/probes/app.sps && make -C clone build'
scripts/guix-env sh -c "scheme --libdirs src --program $R/nothreads-message.sps"
# item 5
scripts/guix-env sh -c "for p in login token version; do scheme --libdirs src --program $R/examples/\$p.sps; CHEZ_SODIUM_LIBRARY=\$PWD/build/slice5/prefix-1.0.18/lib/libsodium.so.23 scheme --libdirs src --program $R/examples/\$p.sps; done"
```

libsodium's sources cited are under `<repo>/build/slice5/libsodium-1.0.18/` and `-1.0.22/`, as
`src/libsodium/…` paths, read with `grep -n` and `sed -n`.
