# M2 slice 1 review: the bindings

Read-only, adversarial, over the uncommitted work on `m2-slice-1`, against the M2 plan, ADR-0001,
ADR-0002, ADR-0011 and ADR-0012 as amended, `global-constraints.md` and AGENTS.md. Every probe ran
in a copy, `build/m2s1-review/tree/` (and mutant copies under `build/m2s1-review/mut/`), through
the copy's own `scripts/guix-env`, after `make deps` in each copy. Nothing in the checkout was
changed.

**Counts:** 0 blockers, 2 majors, 8 minors.

## Findings

### M2S1-F1 (major): two sizes stored under their twins' keys pass every slice-1 suite

- **Where:** `src/chez-sodium/private/native.sls:476-480`, the answers' `(cons 'KEY VAR)` list.
  `tests/test-native.sps:1151` (E2) and `:1246` (E5) are the rows that ought to see it.
- **What:** E2 holds the let*'s inits, and E5 holds `(define NAME (answer 'KEY))`. No row holds
  the answers list itself. Only the oracle rows check by behaviour, and at both releases they
  cannot tell `_bytes_min` from `_keybytes_min` (16 and 16), nor `_bytes_max` from
  `_keybytes_max` (64 and 64). So a size recorded under its twin's key is caught by nothing. That
  is the plan's own listed mutant, "reading one size from another's function", in another
  spelling. The load builder's log has "answers pair for bytes-min holding bytes (3 rows)"
  killed, but that pair's values differ (32 and 16). The twin pairs were never tried.
- **Probe** (mutant copy `answers-twin`, two exact replacements in native.sls):

  ```
  (cons 'generichash-keybytes-min keybytes-min)  ->  (cons 'generichash-keybytes-min bytes-min)
  (cons 'generichash-keybytes-max keybytes-max)  ->  (cons 'generichash-keybytes-max bytes-max)
  ```

  ```
  == test-native                        # of expected passes      77
  == test-native-codes                  # of expected passes      13
  == test-conventions                   # of expected passes      54
  == test-library-loading-decoys        # of expected passes      20
  == test-library-loading-combined      # of expected passes      14
  == test-library-loading-missing-verbs # of expected passes      17
  ```

  All of them pass. Slice 2's `sizes-other` rows would catch it (an 8-byte key accepted where 9
  is the minimum). But the verbs builder does not own native, and would be chasing a fault in
  code it cannot touch.
- **Suggested fix:** an E row that holds the let* body's `list` whole, every `(cons 'KEY VAR)`, as
  E5 holds the defines. A second option kills every twin and swap by behaviour: one slice-1 row
  that loads native against the decoy under `sizes-other` and asserts the five sizes whole. My
  probe below shows native records `(33 8 80 9 81)` there. The probe program, refusal-probe or
  a new child, would print them.

  ```
  CHEZ_SODIUM_DECOY=sizes-other CHEZ_SODIUM_LIBRARY=.../decoy.so $CHEZ ... build/probes/sizes.sps
  ("1.0.18" 33 8 80 9 81)
  decoy(sizes-other) sodium_version_string() ... sodium_init() crypto_generichash_bytes() ... crypto_generichash_keybytes_max()
  ```

### M2S1-F2 (major): the overflow row's C driver runs native code outside the gate

- **Where:** `tests/test-library-loading-combined.sps:214-273`, `overflow-run` at `:250`. The
  driver runs at `:260` through `capture-command`, never `gated-command`.
- **What:** Three records say every child that reaches native code goes through `gated-command`:
  `global-constraints.md` ("A child that reaches native code starts through `gated-command` …
  The wipe row's child is the exception"), ADR-0011 decision ("every suite that starts a child
  that reaches native code starts it through `gated-command`"), and plan §6's list every brief
  restates ("the wipe children alone run outside").
  - The driver is a C program running the decoy's `called`, the very code whose offsets the row
    is about. Under `make test-memory` it runs unseen. It also prints no valgrind line, so
    nothing asserts where it ran.
  - It cannot simply be wrapped. The gate accepts a child log only if its `Command:` begins with
    CHEZ or names `libsodium-oracle` (Makefile:393-400), and plan §2.3 says the Makefile does not
    change.
  - The decoy brief prescribed "a small C driver", so this is a flaw in the brief as well as the
    code.
  - test-constants' `_Generic` program (`tests/test-constants.sps:139`) is an older C child
    outside the gate, and the records do not name it either.
- **Probe:** with `CHEZ_SODIUM_GATE_CHILD` set to a wrapper that logs every gated child
  (`build/probes/count.sh`), `-combined` logged 8 gated children. The driver was not among them.
- **Suggested fix:** either of these.
  - Drive the overflow from a Chez child started through `gated-command`. It would bind the
    decoy's `sodium_init` and `decoy_calls` with its own `foreign-procedure`, as `-real`'s
    direct-call child does, and print the same five lines plus its valgrind line. `-combined` has
    6 children of room.
  - Record the exception in ADR-0011 and the constraints: C programs that link no libsodium, this
    driver and test-constants' program, run outside the gate, and say why.

### M2S1-F3 (minor): test-decoy-source misses a pointer tested through a macro, and some definition heads

- **Where:** `tests/test-decoy-source.sps:140-148` (`code-text` drops every preprocessor line,
  macro bodies included), `:225-235` (`pointer-parameter`) and `:239-244` and `:284-299` (only
  `__attribute__` may sit between `)` and `{`).
- **What:**
  - **Multi-line parameter lists are read right.** So is `#ifndef`: both arms are read, and with
    alternative heads under `#if`/`#else` the head that owns the body is read and its breach found.
  - **A macro whose replacement text names a pointer parameter passes.** On the real decoy it
    compiles at `-Wall -Werror` and passes test-decoy-source. Only `-Werror=nonnull-compare`
    would catch it, and only for `buf` and `out`.
  - **Some heads make a definition or a parameter vanish silently:**
    - a macro between `)` and `{`;
    - an attribute on a parameter;
    - a parenthesised name;
    - a definition made by a macro;
    - `extern "C" {` braces;
    - a typedef'd pointer type.

    The whole-list row (`:346`) backstops these for the decoy only.
- **Probe 1**, extra plants appended to a copy of the suite (`build/probes/decoy-source-plants.sps`):

  ```
  P1 macro between ) and {: (() ())
  P2 macro body names the parameter: ((("crypto_generichash" ("out" "in" "key"))) ())
  P3 attribute on a pointer parameter: ((("randombytes_buf" ())) ())
  P4 #if/#else alternative heads: ((("randombytes_buf" ("buf"))) (("randombytes_buf" "buf" (uses 2))))
  P5 parenthesised name: (() ())
  P6 definition made by a macro: (() ())
  P7 extern C braces around a definition: (() ())
  P8 typedef pointer parameter: ((("crypto_x_thing" ())) ())
  ```

  Every one of P1-P3 and P5-P8 contains a plain `if (buf)` or `key ? …`.
- **Probe 2**, on the real decoy (mutant copy `src-macro`), in `crypto_generichash`:

  ```c
  #define IN_GIVEN (in != NULL)
    (void) i;
    called("crypto_generichash(%s,%zu,%s,%llu,%s,%zu)",
           o ? "p" : "NULL", outlen, IN_GIVEN ? "p" : "NULL", inlen, k ? "p" : "NULL", keylen);
  ```

  ```
  compiled-1.0.22-headers
  # of expected passes      23
  ```

  Without the `(void) i;`, `-Wunused-variable` happened to catch it.
- **Suggested fix:** count a parameter's name found free in any `#define` replacement list of the
  file as a breach, outside that macro's own parameters. And treat a family name followed by `(`
  at depth 0, whose `)` is followed by anything but `{`, `;`, `,` or `__attribute__`, as
  unreadable, by name. Failing that, say in the suite's header what it does not parse.

### M2S1-F4 (minor): the decoy's `sodium_memcmp` calls a NULL operand equal

- **Where:** `tests/decoy-libsodium.c:331-349`. The comment says "Two NULL addresses compare no
  byte", but `if (p1 && p2)` skips the compare when either one is NULL.
- **What:** `(p, NULL, 8)` answers 0, equal, in the control, and 1 under `memcmp-other`. The
  common brief's "compares honestly, byte by byte" did not say what to do here. The log still
  shows `NULL`, so slice 2 can see the pointer. The answer, though, is that of a match.
- **Probe:** `build/probes/switches.c`, linked against the decoy:

  ```
  == []             memcmp equal=0 differ=-1 len0=0 onenull=0
  == [memcmp-other] memcmp equal=1 differ=-1 len0=1 onenull=1
  ```

- **Suggested fix:** when exactly one address is NULL and `len > 0`, answer -1, the same under
  every switch, and make the comment say so.

### M2S1-F5 (minor): the oracle has more equivalent mutants than the log says

- **Where:** `.plans/m2-slice-1-mutation-log.md`, "Oracle: KILLED except two equivalent mutants";
  `tests/libsodium-oracle.c:102-132`.
- **What:** At both releases every size line has a twin of equal value. `crypto_generichash_BYTES`
  and `_KEYBYTES` are both 32U, `_MIN` and `_KEYBYTES_MIN` both 16U, `_MAX` and `_KEYBYTES_MAX`
  both 64U, and the functions answer the same. So for every line, both F and M have a wrong twin
  no row can see. One of them, `bytes`' F, can be read from `crypto_generichash_keybytes`, which
  the project deliberately does not bind.
- **Probe** (mutant copy `oracle-twins`, four replacements at once):

  ```
  FIND(bytes, crypto_generichash_keybytes)
  FIND(keybytes_min, crypto_generichash_bytes_min)
  (size_t) crypto_generichash_KEYBYTES   for generichash-bytes' M
  (size_t) crypto_generichash_BYTES_MAX  for generichash-keybytes-max' M
  test-native: # of expected passes 77
  ```

  The macro values were read from `build/slice5/prefix-{1.0.18,1.0.22}/include`: identical at both.
- **Suggested fix:** correct the log. Every line's F and M has an equal-valued twin, so the oracle
  holds the numbers, not which function or macro gave them. To kill the F twins, run the oracle
  once against the decoy under `sizes-other`, where the five answers differ. The M twins cannot
  be killed by value.

### M2S1-F6 (minor): row 22 leaves out keylen 128

- **Where:** `tests/test-native-codes.sps:181-183`.
- **What:** Plan §2.2 asks for "each code of §5.1's table", and §5.1's table measured "keylen 65
  and 128: -1". The load brief listed 65 alone, so the brief dropped it.
- **Suggested fix:** add keylen 128, answering -1 with `out` untouched, to the keylen-65 row.

### M2S1-F7 (minor): the convention table cites ADR-0001 decision 4 for a type rule

- **Where:** `tests/foreign-conventions.sls:105, 110, 115, 120, 125, 130`.
- **What:** `"ADR-0001 decision 4: a size is size_t"` (five rows) and `"ADR-0001 decision 4: inlen
  is unsigned long long, bound unsigned-64"`. ADR-0001's decision 3 is the type rule. Decision 4
  is "No Scheme object crosses into C". M1's rows cite "decisions 3 and 4" for address and
  length together.
- **Suggested fix:** decision 3 in all six strings.

### M2S1-F8 (minor): the mutation log leaves out what plan §5.2 asks it to record

- **Where:** `.plans/m2-slice-1-mutation-log.md`, the decoy builder's "Gate: see the report; every
  suite 7 s to 66 s", and the load builder's test-native-codes section.
- **What:** Plan §5.2 says slice 1 measures "each `test-library-loading-*` suite's time under the
  gate". The log names no suite's time and points to a report that is not in the repository.
  The log also does not say where test-native-codes' expected hashes came from. The suite says
  hashlib, and they do match it (below).
- **Probe 1**, the gate in the copy, while the main tree's gate also ran:

  ```
  decoys 67s, missing 47s, missing-verbs 51s, combined 42s, real 48s, preflight 56s, discovery 35s,
  decoy-source 6s, native-codes 7s; ran 9, passed 9; each "within 450s"
  ```

- **Probe 2**, gated children per suite:

  ```
  decoys 14, missing 9, missing-verbs 10, combined 8 (+1 ungated, F2), real 10, preflight 12, discovery 9
  ```

- **Probe 3**, `python3 -I` with `hashlib.blake2b` on the host: all ten expected hashes match.
  - abc at sizes 1, 15, 16, 32 and 64;
  - keys `01..N` for N = 1, 15, 16 and 64, at size 32;
  - the empty input at 32.
- **Suggested fix:** write each suite's gate time and child count into the log, and the hashlib
  call that made the hashes.

### M2S1-F9 (minor): wording and wraps

- `src/chez-sodium/private/native.sls:37`: 89 characters, where the paragraph wraps at 80. It was
  not reflowed after "and the size calls" went in.
- `native.sls:26-30`: "with one pair each in the answers" is wrong for the five size
  functions, whose raw bindings have no pair; their values do.
- `tests/test-library-loading-decoys.sps:182-186`: an orphan `;;.` line, and "What each switch
  then answers is the verbs' rows". Removing a slice word left these behind.
- `tests/decoy-libsodium.c`:
  - `:24` "no sodium_* function at all" and `:55` "every sodium_* function appends one entry":
    `randombytes_*` and `crypto_*` now do too;
  - `:71` "holds every function here to that": the helpers are outside the rule.
- `tests/test-native.sps:22-25`: says the five size functions are test-native-codes'. They are
  held by test-native's own "the sizes" rows, just below.
- `tests/test-native.sps:147-151`: the five sizes are fetched with `native-procedure`, but they
  are numbers.
- Over 80 characters:
  - `tests/libsodium-oracle.c:21-27`: the field table is misaligned, and `:25` is 84;
  - `tests/test-native-codes.sps:2` and `tests/test-decoy-source.sps:8`: 84 each.

### M2S1-F10 (minor): no slice-1 row holds the switches' effects or the A5 pattern

- **Where:** `tests/test-library-loading-decoys.sps:187-193`. Each switch row shows only
  `decoy(SWITCH)` in the log.
- **What:** No slice-1 row holds the decoy's switch answers or its A5 writes. That is as the
  decoy brief allowed ("slice 2's, through the verbs"). The first rows to see them will be
  slice 2's, through verbs whose builder does not own the decoy's behaviour. A decoy that read
  `sizes-other` and answered 32, or wrote A5 over the first byte only, passes slice 1.
- **Probe** (`build/probes/switches.c`): every answer is as plan §6 fixes it.

  ```
  []                sizes 32 16 64 16 64  generichash=0   out a5=33 of outlen 33  rb a5=50 of 50
  sizes-other       sizes 33 8 80 9 81
  generichash-fails generichash=-1 (A5 still written)
  generichash-other generichash=1
  memcmp-other      equal=1 differ=-1
  log ... crypto_generichash(p,64,p,0,NULL,0) ... randombytes_buf(NULL,0) crypto_generichash(NULL,0,NULL,0,NULL,0)
  ```

- **Suggested fix:** F1's sizes-other row covers the sizes. One small row in `-combined` could
  hold the others: a child calling each M2 entry through its own binding, under each switch,
  asserting the answer and the block whole.

## Checked and found sound

- **Native's new code:**
  - The eight forms are plan §4.1, item 2's, token for token, in its order, after
    `sodium_memzero`, each the whole second argument of `bind-required` and the whole init of
    its let* binding.
  - Step 7 calls each size function once, in order, after `raw-memcmp`, inside `load-answers`'
    let*, which is inside `call-in-section`.
  - The exports are as plan §6 fixes them, and the answers' keys are the same names.
  - The signature comments are right: three `Positive-Integer … -> Void/Integer`, five `Natural`.
  - The comments carry no milestone, slice or date.
- **A size read cannot raise in the section.** A `() size_t` call has no argument to convert, and
  its result always converts. Probe: a decoy answering `(size_t) -1` loads and records
  `18446744073709551615`; `sizes-other` loads and records `(33 8 80 9 81)`.
- **test-native-codes' rows can fail.**
  - Each hash is a whole 80-byte block, so a size, a truncation, a key ignored or a key-length
    mistake shows.
  - The -1 rows show `out` untouched, whole.
  - The memcmp rows hold both orders, the length 0 and a short length.
  - randombytes holds its tail and refuses a constant fill.
  - The hashes match CPython's own BLAKE2 (F8).
- **Every gated child's suite has at most 14 children** (F8's counts), and every gate time is far
  under 450 s.
- **The decoy:**
  - Every pointer is read once, as `(uintptr_t) NAME` in a `volatile uintptr_t`, and only the
    copy is tested, logged or written through.
  - A5 covers exactly `outlen` and `size` bytes under every switch.
  - The log lines are the plan's, with `p` and `NULL` apart.
  - Each switch is read once and logged.
  - `DECOY_LACKS_<entry>` exists for all eight.
- **The overflow logic** cannot overrun `calls`. The overflow row kills a truncating decoy. Probe
  (mutant `ov-trunc`, `snprintf` into the room left, with no marker):

  ```
  FAIL a full call log ends in one overflow entry and takes nothing more
    actual: (0 "head=decoy(control)\ntail=m_init() sodium_init() sodium_init()\nunmoved=yes\noverflows=0\nfits=yes\n" "")
  ```

- **`library-loading`:**
  - `every-entry`, `first-entries` and `verb-entries`;
  - `init-calls` and `loaded-calls`, with step 7 last;
  - `missing-api-rows`, where the eight refuse after `sodium_init()` with no size call;
  - the four switch rows, and the order rows in `-missing-verbs`.
- **Conventions:**
  - the eight rows match 1.0.22's `sodium.h`;
  - the allow-lists are `(int uptr size_t unsigned-64)` and `(int uptr size_t void)`;
  - argument-only is `unsigned-64`;
  - the complement count is 120, from 59 types × 2 + 1 + 1;
  - the fixtures gain `p_allowed`'s `unsigned-64`, `p_size_result`, and `fx_result_only_0`;
  - test-constants' plants and map rows are each a real mistake against the header, with `(void)`
    for none.
- **SRFI-64 and Chez traps.** I grepped every new and changed top-level definition in the nine
  touched suites.
  - Each value that can raise is guarded (`native-procedure`, `native-load`, `scratch`,
    `compile-decoys`) or behind an `(exit 1)` check.
  - Expected expressions are pure on constants.
  - No `#f` is expected from anything that can raise.
  - Ordered effects use let* or named lets.
  - The sentinels are distinct from 0.
  - Each suite ends in `(exit (suite-exit-status runner))`.
- **Records.**
  - ADR-0001 and ADR-0002 as amended, the constraints' load order and step 6/7, ADR-0011's
    pointer-rule and overflow texts, and plan §2.2's rows all match the code, but for F2.
  - The only comment words caught by the grep for milestone, slice, date or research were
    `slice` as a helper's name.
- **Mutation-log claims spot-checked and borne out:**
  - the children counts (14, 9, 10);
  - "seven suites";
  - test-native 77 and test-native-codes 13;
  - the scanner's rows killed by their plants;
  - the two logged oracle equivalents, which are real (F5 adds four).

The copy, `build/m2s1-review/`, was removed after this report.
