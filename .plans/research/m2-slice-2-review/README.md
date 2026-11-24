# M2 slice 2 review: the verbs

Read-only adversarial review of the uncommitted work on `m2-slice-2` (over PR #11 and PR #10).
Every probe ran in copies under `build/m2s2-review/` (a base tree, plus one whole copy for each
mutant, with `make deps` run in each, each run from inside the copy through its own
`scripts/guix-env`). Chez 10.4.0 threaded, libsodium 1.0.22 (the container's), and the floor,
1.0.18, from `build/slice5/prefix-1.0.18`, where named.

**Counts: 0 blockers, 2 majors, 10 minors.**

- **M2S2-F1 (major):** a check moved inside a verb's section through a let-bound lambda passes
  every row of `test-byte-verbs` and `test-library-loading-verbs`. The shape rows read only the
  verb's own text, and only five raiser names.
- **M2S2-F2 (major):** the plan's mutant for row 17, "a verb with no `call-in-section`", does not
  test row 17. The log shows row 17 passes it. The mutant row 17 exists for (X-M2, a raise from
  inside the extent) was never run. It does fail row 17 (probe P2).

---

## Findings

### M2S2-F1 (major): the shape rows can be fooled by a helper that raises inside the section

- **Where:** `tests/test-byte-verbs.sps:805-845` (S1, S2, S3; `around-section` :813,
  `inside-section` :837). The design comes from plan §4.1, item 10, which the verbs brief
  restates.
- **What the rows hold:**
  - S1 counts the `call-in-section` symbol in the verb's definition.
  - S2 counts `assertion-violation`, `refuse-secret` and `raise-sodium-failed` before and after
    the first `call-in-section` token, in reading order.
  - S3 lists those names (and `raise`, `error`) among the tokens of the section's argument.
  - So "before the section" means "written before it", not "run before it". A name the verb calls
    inside its section is not read through.
- **Probe P1 (`lambda-cap`).** In a whole copy, `random-bytes`' cap check is moved into a
  let-bound lambda, written before the section and called first thing inside it:

  ```scheme
      (let ((check-cap
             (lambda ()
               (unless (<= n input-cap)
                 (assertion-violation 'random-bytes "n is over the cap"
                                      'over-the-cap 'n (shown-value n))))))
        (if (= n 0)
            (make-bytevector 0)
            (call-in-section
             (lambda ()
               (check-cap)
               (call-with-block 'random-bytes n leave-unwritten ...)))))
  ```

  Result:

  ```
  edited src/chez-sodium/private/byte-verbs.sls
  test-byte-verbs exit=0
  test-library-loading-verbs exit=0
  # of expected passes      11
  ```

  - S1 still sees one section.
  - S2 still counts `(assertion-violation 2 0)`, because the lambda is written before the
    `call-in-section` token.
  - S3 sees only `check-cap` inside.
  - The behaviour rows cannot tell. `call-in-section` raises the refusal again after the
    section, and the decoy's log is empty because the refusal comes before `call-with-block`.
    That is exactly why plan §4.1, item 10 put the rows on the text.
- **The same holds for a top-level helper:** it fails S2 only because S2's counts change, so
  whoever updates the counts makes the row pass again. It also holds for a second section
  reached through a helper (S1).
- **Why major:**
  - A check inside the section is the failure the shape rows exist for (plan §4.1, item 10, and
    the "check after it" and "raise moved inside" mutants of §6).
  - This variant passes every row.
  - The brief's design is the cause, so M3's password verbs would inherit it.
- **Suggested fix:**
  - S3 asserts, for each verb, the whole list of symbols inside its `call-in-section` argument,
    against an expected list. That list is today's names: `lambda`, `call-with-block`,
    `call-with-bytes`, `leave-unwritten`, the raw bindings, `foreign-bytes`,
    `bytevector-length`, `let`, `if`, `eqv?`, `cons`, `quote` and the verb's own variables.
    Any helper, local or top-level, called inside then shows by name. This follows AGENTS.md's
    "assert whole outputs".
  - Optionally, S2 also requires that no `lambda` occurs in a verb's definition outside its
    section's argument.

### M2S2-F2 (major): row 17's watched mutant is the wrong one, and its own mutant was never run

- **Where:**
  - plan §6, slice 2, "Watched to fail", row 17 (`.plans/2026-11-23-m2-plan.md:532`);
  - the verbs brief, item 6, which restates it;
  - `.plans/m2-slice-2-mutation-log.md:86`:
    `R17 blake2b no call-in-section: B FAIL x4 [R18 … | R18 …] ;; L pass`.
- **The problem:**
  - Brief §8.1 row 17 says it catches "a raise from inside the extent (X-M2)".
  - Removing `call-in-section` alone leaves `blake2b`'s raise after the block extents. So row 17,
    in `test-library-loading-verbs` ("L"), passes the plan's mutant, as the log records.
  - It is killed only by R18 and S1/S2 in `test-byte-verbs` ("B").
  - The log lists it under R17 as if row 17 had been watched failing.
- **Probe P2 (`raise-in-extent`):** no section, and `raise-sodium-failed` inside the innermost
  `call-with-block` in place of `(cons 'failed code)`:

  ```
  test-library-loading-verbs exit=1
  FAIL verbs on control under "generichash-fails": crypto_generichash answering -1 is a &sodium-failed …
  FAIL verbs on control under "generichash-other": crypto_generichash answering 1 is a &sodium-failed too …
    actual:   (0 (((refused blake2b ()) "crypto_generichash(p,32,p,3,p,0) sodium_memzero(p,32) sodium_memzero(p,1) sodium_memzero(p,3)") ((refused blake2b ()) "crypto_generichash(p,32,p,3,p,16) …") …
  test-byte-verbs exit=1   (R18 ×2, S1, S2)
  ```

  The inner guard for something else re-enters the extent, and `call-with-block`'s
  "re-entered after its block was freed" replaces the `&sodium-failed`. Row 17 does what brief
  §8.1 says.
- **Probe P2b (`no-section-raise-after`), the plan's literal mutant:**

  ```
  test-library-loading-verbs exit=0
  # of expected passes      11
  test-byte-verbs exit=1   (R18 ×2, S1, S2)
  ```

- **Why major:**
  - The record misleads: row 17's claim had never been watched failing.
  - M3's half of row 17 (`crypto_pwhash_str`) will copy the plan's wording.
- **Suggested fix:**
  - Log P2 as row 17's watched failure.
  - Reword plan §6's row 17 item as "a raise from inside the extent, with no `call-in-section`".
  - Keep "a verb with no `call-in-section`" under row 18 and S1, where it is killed.

### M2S2-F3 (minor): `test-byte-verbs` has no `test-begin`/`test-end`, so it prints nothing

- **Where:** `tests/test-byte-verbs.sps`, whole file.
- **Evidence:**
  - It is the only `tests/test-*.sps` with neither form (a grep over all 31 suites: every other
    suite has 1 and 1).
  - Plain, a passing run writes a 0-byte output (`build/plain-test-byte-verbs.out: 0 lines`).
  - With a count printed before its exit line it reports `(pass 115 fail 0)` at 1.0.22 and at
    the floor.
  - So `make test` and the gate show only "pass", with no count. The verbs builder's
    "110 fail, 5 pass" against the stub was counted from FAIL lines.
- **Fix:** `(test-begin "byte-verbs")` after the runner, and `(test-end "byte-verbs")` before
  the exit line.

### M2S2-F4 (minor): two expected expressions raise at top level when native cannot be reached

- **Where:** `tests/test-byte-verbs.sps:459` `(- bytes-min 1)` and `:463` `(+ bytes-max 1)`.
  `library-value` answers a procedure when the library cannot be reached, and SRFI-64 does not
  guard an expected expression.
- **Probe P3:** the suite with `CHEZ_SODIUM_LIBRARY=/nonexistent/libsodium.so.26`:

  ```
  exit=255
  54   (FAIL lines)
  Exception in -: #<procedure at count-byte-verbs.sps:3690> is not a number
  ```

  The suite dies after 54 named failures.
  - The ~60 rows after it never run, unnamed.
  - Among them are S1 to S5, the export rows and the final count, which need no libsodium at all.
  - The header (:34-36) says every computation that can raise runs under a guard.
- **Fix:** compute the two bounds under a guard, e.g. `(define (bound x) (if (number? x) x
  'unreached))` and `(refusal … (bound-1 bytes-min))`, or build the expected value inside the
  row's thunk.

### M2S2-F5 (minor): "the cap is written once" is held only for the literal 65536

- **Where:** `tests/test-byte-verbs.sps:885-889` (S5).
- **Probe P4 (`second-cap`):** all four `input-cap` uses in `byte-verbs.sls` replaced by
  `(* 64 1024)`. Afterwards `grep -c input-cap` gives 0. Result:

  ```
  test-byte-verbs exit=0
  test-library-loading-verbs exit=0
  # of expected passes      11
  ```

- **Fix:** count `input-cap` in each verb's definition, as S2 counts the raisers:
  `random-bytes` 1, `blake2b` 1, the compare 2, asserted whole.

### M2S2-F6 (minor): the verbs half of the mutation log is not in the log's form, and cannot be read

- **Where:** `.plans/m2-slice-2-mutation-log.md:30-104`.
- **The form:** plan §6 asks for "Guards, Mutation, Result, Clean rerun". Each mutant here is
  one line, `B FAIL xN [two names cut at ~70 characters] ;; L …`. For example:
  - `S check moved after the section: B FAIL x4 [R15 blake2b with a key one byte under the
    least is refused, key-length | R15 …]` does not show whether S2, the row it is for,
    failed;
  - names are cut mid-word ("concatenated and h", "the others call it with t | v").
- **Also:**
  - No line names the guard row a mutant targets. F2 is the case where that matters.
  - The public half's weak-symbol measurement (:121) is "a plain Chez". Plan §4.1, item 3 and
    §5.2 ask for "a library-loading child". L passing under the gate covers it in practice;
    say so.
- **Fix:** rewrite the verbs half in slice 1's form, with each mutant's guard row and every
  failing row by its whole name. Add F1's and F2's probes.

### M2S2-F7 (minor): stale counts and headers

- **Counts:**
  - `tests/library-loading.sls:2` and `:5` say "the seven suites", over a list of eight
    (`-verbs` added at :21). `test-wipe` now imports it too.
  - Each of the seven older `tests/test-library-loading-*.sps:2` says "One of the seven suites".
    `-verbs:2` says eight.
- **`test-wipe`:**
  - Its header (`tests/test-wipe.sps:1-37`) describes one child, and the decoy child is
    described only at :166-180.
  - `:96`, in the child's program, says "loading it by path reaches its two functions". The
    interposer now has five, and that child binds three.
  - The suite does not say that a block a verb makes and never hands to C is invisible to the
    decoy rows. Rule (m) and E7 hold that (plan §4.1, item 3).
- **Fix:** "eight" throughout. A header paragraph for the second child, with what it cannot
  witness. ":96" changed to "its functions".

### M2S2-F8 (minor): comments that disagree with the code, and wraps

- **`tests/test-byte-verbs.sps`:**
  - :69 says `library-procedure :` for `library-value`.
  - :322 says `position-values :` for `distinct-per-position`.
  - :18-19 says "no two calls alike in any position". The row asserts each position takes at
    least two values across 8 calls.
  - :39 says "never map". R16 calls the verbs through `map` (:607). There is no order
    dependence, but the header says otherwise.
  - :22 says "the plan's table". Name ADR-0006's rule symbols: a comment should point to the
    record, not the plan.
- **`tests/test-library-loading-verbs.sps:167`:** says `table :` over `table-calls` and
  `table-lines`.
- **`src/chez-sodium/private/byte-verbs.sls`:**
  - :42-44, `leave-unwritten : Natural -> Void`, answers `#f`.
  - :8 cites "ADR-0007, decisions 7 and 8" for the verbs' shape. The shape is decisions 1 to 4
    and 7; decision 8 is `sodium-version`'s.
- **Wraps:** B has 7 and L has 5 section separators over 100 columns, up to 124. The other
  suites keep theirs under 100. `test-native` has 2 comment lines over 100, and
  `-decoys`, `-codes` and native have none.

### M2S2-F9 (minor): the records name `sodium-version` as the one path with no section

- **Where:**
  - `AGENTS.md:199`;
  - `.plans/global-constraints.md:150`;
  - ADR-0007, decision 8 (`0007-…md:58`).
- **The gap:**
  - `random-bytes 0` and the compare of operands of different lengths also hold no section.
    Like `sodium-version`, they make no block and call no C.
  - ADR-0007's M2 amendment says each "calls no C", not that it holds no section. AGENTS.md
    reads "Each verb's whole extent is one `critical-section`", and its only named exception is
    `sodium-version`.
  - Also, the constraints (:237) and ADR-0011 (:57, :163) say "the wipe row's child". There are
    two now.
- **Fix:**
  - "A path that makes no block and calls no C holds no section: `sodium-version`,
    `random-bytes 0`, and the compare of different lengths", in ADR-0007's amendment, the
    constraints and AGENTS.md.
  - "children" in the wipe texts.

### M2S2-F10 (minor): what a user meets: a secret's refusal message names no mistake

- **Where:** `src/chez-sodium/private/conditions.sls:98` (`refuse-secret`'s fixed message),
  reached by every secret refusal.
- **Probe P14:**

  ```
  (blake2b "hello")       => "Exception in blake2b: a secret parameter is refused by its kind alone with irritants (not-a-bytevector input (kind string))"
  (blake2b bv 32.5)       => "Exception in blake2b: size is not an exact natural with irritants (not-a-natural size 32.5)"
  ```

  `n` and `size` say what is wrong. Every refusal of `input`, `key`, `a` and `b`, an empty key
  included, says only that a secret was refused, and the rule symbol carries the meaning. Arity
  errors show no argument, which is good: `incorrect number of arguments 4 to #<procedure
  blake2b …>`.
- **Fix:** let `refuse-secret` take a message, as the `n` and `size` refusals have one ("input is
  not a bytevector", "the key is empty"). Tests still assert no message. Or owe it to M4's
  documents. It is M1's helper, so its change is the owner's call.

### M2S2-F11 (minor): the key's cap rests on libsodium's own bound, unchecked and unrecorded

- **Where:**
  - `src/chez-sodium/private/byte-verbs.sls:104-107`;
  - plan §4.1, item 5 (`:198-199`, "An over-cap key is refused by the key's range").
- **The gap:**
  - The key is never compared with `input-cap`. It is capped only while
    `generichash-keybytes-max` ≤ 65536. The same goes for the output block and
    `generichash-bytes-max`.
  - Every release answers 64, and `sizes-other` 81. So nothing is wrong today. But ADR-0007,
    decision 5 ("every byte input … at most 64 KiB") holds by an assumption that no record or
    row states.
- **Fix:** say it in ADR-0007's amendment. Or check the key against `input-cap` too, before its
  range, which changes no irritant today.

### M2S2-F12 (minor): the fixture's SHA-256 is a comment, not a check

- **Where:** `tests/fixtures/blake2b/README.md:7`.
- **The gap:** the SHA-256 matches (`82fcb3ca…2e364f`, equal to `build/m2-plan/vectors/`). But
  no row or check holds the file to it, so an edited fixture is held only by the 256-match row.
  A fixture regenerated from libsodium itself would pass that row.
- **Fix:** optional. Either a host check beside `check-pins` (`sha256sum -c`), or a row holding
  the fixture's byte length (135681) and its first and last hash literally. AGENTS.md: "Prefer a
  check to a comment."

---

## Probes and their outputs (not given above)

- **P5, R16's needles each see a leak.** Conditions built as `shown-value` would build them:

  ```
  (hunter2 "… with irritants (not-a-bytevector input hunter2)" (#t))
  (4242424242 "… with irritants (not-a-bytevector input 4242424242)" (#t))
  ((#\q #\z #\w) "… with irritants (not-a-bytevector input (#\\q #\\z #\\w))" (#t #f))
  ```

- **P6, a short copy at C** (`(randombytes-buf out (- n 1))`):
  - B fails "R13 8 calls of random-bytes 64: every one of the 64 positions takes at least two
    values". In-process, that relies on the allocator handing back a wiped chunk.
  - L's `randombytes_buf(p,5)` line holds it regardless.
  - "0 reaching C" with a one-byte block (`(if #f …)`, `(max 1 n)`): B exit 0, and L fails the
    control row. As designed.
- **P7, the wipe's length is held** (`(free-foreign-block! made (lambda (a n) (sodium-memzero a
  1)))`). L fails 5 of 11, e.g. `"randombytes_buf(p,5) sodium_memzero(p,1)"` for
  `"… sodium_memzero(p,5)"`.
- **P8, a decoy entry that names no key** (`name_block(k, keylen);` removed):
  - `test-wipe` fails its verbs row: `(blake2b-keyed ran ((32 1) (3 1)))`, and the control's
    `((32 2) (3 2))`;
  - `test-decoy-source` still passes 37.
- **P9, a KAT parse that reads none** (tag `"hsh:"`): `expected: (no-raise (256 256))`,
  `actual: (no-raise (0 0))`.
- **P10, `cap.sls` without `require-threaded`:** `test-require-threaded` fails "src/chez-sodium/
  private/cap.sls imports (chez-sodium private require-threaded) first".
- **P11:**
  - `make check-nothreads` on the threaded Chez names both "(chez-sodium private byte-verbs)
    loaded …" and "(chez-sodium private cap) loaded …", 11 problems in all;
  - `make check-seam` says "the seam holds (11 libraries in 11 files checked)".
- **P12, the gate** (`make test-memory` on the five suites, in the copy, with the main tree's
  gate running at the same time):

  | Suite | Time | Gated children |
  |---|---|---|
  | `test-byte-verbs` | 9 s | 0 |
  | `test-library-loading-verbs` | 34 s | 6 |
  | `test-wipe` | 8 s | 0 (its 2 run outside, as ADR-0011 says) |
  | `test-public` | 7 s | 0 |
  | `test-never-loads` | 16 s | 2 |

  Each is "within 450s, three quarters of MEMORY_TIMEOUT's 600s"; ran 5, passed 5. Each child
  count is at most 14.
- **P13, R18's sweeps complete** at fuel 5 (`random-bytes 32`), 2 (`0`), 6 (`blake2b` unkeyed),
  37 (keyed), and 133, 133 and 129 (the compares, whose operands are built inside the job). Every
  fuel below those expired, and each answered right.
- **P14, a bignum `n`:** `(random-bytes (expt 2 70))` gives `(over-the-cap n
  1180591620717411303424)`. `(eq? (random-bytes 0) #vu8())` gives `#t`.
- **Plain, in the base copy:**
  - B passes 115, at 1.0.22 and at the floor;
  - L 11, `test-wipe` 3, `test-public` 8, `test-never-loads` 8;
  - `test-decoy-source` 37, `-decoys` 20, `-combined` 18, `test-native` 77,
    `test-require-threaded` 59, `test-check-seam` 91.

---

## Checked and found sound

### The verbs (`byte-verbs.sls`, `cap.sls`)

- **Refusals:**
  - Each verb checks left to right, type before range, before any section, with plan §4.1,
    item 5's table exactly: rule symbols, parameters, `(kind K)` for secrets, and `shown-value`
    for `n` and `size` only.
  - The who is the verb.
  - Each is an assertion violation with a `&message`.
- **Nothing raises inside a section** on any reachable path. `call-with-bytes`' own checks are
  the unreachable net plan §4.1, item 5 keeps. `blake2b` answers `(hash . BYTES)` or
  `(failed . CODE)`, and raises `&sodium-failed` after, its who `blake2b`, its function
  `"crypto_generichash"` and its code the answer. Only 0 is a hash.
- **No Scheme copy of a secret:** input, key and operands go to `call-with-bytes` in place. The
  only new bytevectors are the answers and `(make-bytevector 0)` for no key.
- **Blocks:**
  - Every block comes from `call-with-block` or `call-with-bytes`. Output blocks use a FILL!
    that writes nothing, and a failure's block is never read.
  - The unkeyed key is the one-byte block, passed with length 0, never NULL. An empty input is
    the same.
- **Values and C types:**
  - Every value fits its C type before the section. Lengths are ≤ 65536 for `unsigned-64` and
    `size_t`, and sizes are within libsodium's own bounds.
  - An inexact size, `#f` as a key, an empty key and a bignum are each refused before C.
- **The default size and the sentinel:**
  - The default path re-enters the checked three-argument clause with `generichash-bytes`, read
    at call time: 33 under `sizes-other`.
  - The `no-key` sentinel is a fresh, unexported list compared by `eq?`, so `#f` and every
    caller's value are refused as keys.
- **The compare:**
  - It checks `a`'s type, `a`'s cap, `b`'s type, then `b`'s cap, before the lengths.
  - Operands of different lengths answer `#f` with no C. Equal lengths, 0 included, call
    `sodium_memcmp` over the whole length, and only 0 is `#t`.
- **Imports:** `byte-verbs` imports exactly `require-threaded`, `(rnrs)`, native, conditions
  and cap, and nothing from `(chezscheme)`. `cap` imports `require-threaded` and `(rnrs)`, and
  exports `input-cap` alone.
- **Signature comments:** each matches what the code answers.
- **Arity errors show no argument.**

### The rows

- **R1:**
  - The Scheme `selftest-seq`, sizes, input lengths and plain-then-keyed order equal
    `research/m2-plan/selftest.c` and RFC 7693 Appendix E, at 48 outputs and 1968 bytes. It
    cannot pass with the hash wrong: the grand hash goes through `blake2b` itself, and the
    count and length are asserted.
  - The KAT parser reads all 256 (P9). The fixture's SHA-256 matches.
  - The `hashlib` literals equal `run-4b-python.out` and `run-7-python.out`, and the three
    keys are as plan §5.1 says.
- **R13, R14, R15 and R16:**
  - Their boundaries and order rows cover every adjacent pair of checks.
  - Each secret parameter is shown only as `(kind K)` for a symbol, a number, a character list,
    a string and `#f`.
  - R16's text search can fail for each value (P5).
- **R18:** it references the libraries at the top of the suite. Each sweep asserts the outcome
  and the counts at every fuel, never an expiry.
- **L, `test-library-loading-verbs`:**
  - Each line is asserted whole, wipes included (P7), with `p` at length 0.
  - The refusal table is complete, with empty growth.
  - `sizes-other` has bounds on each side ("in place" and "beside" are both killed).
  - Row 17 catches X-M2 (P2), and `generichash-other` holds the code.
  - `memcmp-other` holds that only 0 is a match.
- **`verb-probe`:**
  - It starts through `gated-command` (via `spawn`) and prints `(valgrind . yes|no)`.
  - Its baseline follows the first reference.
  - Its inner guard is for something else, inside a catch-all.
  - A full log is loud.
- **Row 24, `test-wipe`:**
  - The interposer keeps every name in order. M1's child keeps each row's meaning through
    `watch_reset` and `watch_verdict 0`.
  - The decoy child's lists are asserted whole. Its standing controls read 2 through the raw
    bindings, and a missing name shortens the list (P8).
  - Every input, key and operand holds a non-zero byte, and `LD_PRELOAD` is the interposer
    alone.
  - The suite states the length-0 and `random-bytes 0` blind spots.
- **The decoy:**
  - The weak `watch_set` and the static `name_block` helper take the volatile copy's value.
  - `test-decoy-source`'s rule (functions `sodium.h` declares) leaves the helper out, and the
    rule passes 37. ADR-0011's amendment is met.
  - Nothing else in the decoy changed: `-decoys` 20 and `-combined` 18.

### The public library and the suites

- **The public library:** `(chez-sodium)` exports exactly ADR-0012's amended set, each `eq?`
  to its definition, and its body stays empty. `sodium-failed-function` answers a String and
  `sodium-failed-code` an Integer, as their comments say.
- **`test-never-loads`:**
  - `verb-names` holds the three verbs.
  - The loaders row holds `byte-verbs`, and not `cap`.
  - The condition children make `(make-sodium-failed "crypto_generichash" 13)` with field
    values distinct from the other condition's. They call each name on it, on a
    `&sodium-library-unavailable` and on 42, and their expected lines gain the three. M1-F6 is
    discharged.
- **SRFI-64 and Chez traps,** in every new or changed suite:
  - no `#f` is expected from anything that can raise. The compare's `#f` is `(no-raise #f)`,
    and L's is a printed line;
  - no `guard` returns the body's value where 0 could pass;
  - no assertion depends on evaluation order;
  - outputs are asserted whole;
  - the engines are referenced first;
  - every suite ends with its exit form;
  - every other top-level definition that can raise is guarded. The exceptions are F4's two.
- **Tooling:** `check-nothreads`, `check-seam` and `test-require-threaded` read both new
  libraries without a change (P10, P11).
- **The gate:** every new suite's time is far under three quarters of `MEMORY_TIMEOUT`, and
  every child count is at most 14 (P12).
- **The comment rule:** no milestone, slice, research path or date appears in any comment under
  `src/` or `tests/` in the touched files. The one pointer is to "the plan's table" (F8).

### Owed, not findings

- CI's gate times for the new suites (plan §5.2, slice 2's "Done").
- The slice's close-out in `progress.md`.
- AGENTS.md's "Where the project stands", at M2's close.
