# M3 slice 1 review: the bindings, the writers and the pure core

Reviewer: Opus, read-only and adversarial. Tree: `m3-slice-1` over `main` at `ac5cfaf`,
uncommitted; the 22 changed files and the 5 untracked ones read whole.

Where the probes ran:
- a copy at `build/m3s1-review/base/` (`shutil.copytree(..., symlinks=True)` of `src`, `tests`,
  `packaging`, `scripts` and the Makefile);
- one sibling copy per mutant: `shape-nobound-literal`, `shape-nobound-digits`,
  `shape-noprefix-guard`, `msg-lambda`, `ascii-high-anywhere`, `cstr-shows-value`, `cstr-order`,
  `utf8-snapshot`;
- a C driver in `build/m3s1-review/cc/`;
- two FIFO shell probes in the session scratchpad, since removed.

All through `scripts/guix-env`: Chez threaded, the profile's 1.0.22, and the floor headers at
`build/slice5/prefix-1.0.18/include` put first on `C_INCLUDE_PATH`. No permission check was
denied.

**Counts: 0 blockers, 4 majors, 8 minors.**

**The caller's checks:**
- **F1 reproduced:** `shape-nobound-digits` and `shape-noprefix-guard` each pass all 60 rows.
- **F2 reproduced:** `utf8-snapshot` passes all 109 of `test-native`.
- **F3 read in the code:** hex mode prints one datum, and `compile-and-run` requires one.
- **F4 probed:**
  - with the reader gone, a second write-only open of the FIFO timed out (rc 124);
  - a read-write open returned at once (rc 0).

Each finding is fixed in slice 1, or in the plan and records for slice 2 (F4). The close-out says
where.

The code is sound where it matters most:
- the seventeen forms, the names, the keys, the decoy's lines, values, switches and spelling,
  and the oracle's format all match the plan;
- the writers cannot write past a block, or raise inside a section;
- the C compiles clean at both headers, even at `-O2 -Wextra` and `-fanalyzer`.

The majors are rows that cannot fail, and one trap slice 2 inherits.

---

## Majors

### M3S1-F1 (major): the H rows expect `#f` from `current-hash-shape?`, so a version that raises on short or truncated hashes passes all 60

- **Where:** `tests/test-password-text.sps:111-138`, every `H` row that expects `#f`, and
  `H a #f prefix` at :116-117; `src/chez-sodium/private/password-text.sls:59-75`.
- **Evidence:**
  - AGENTS.md: "SRFI-64 turns an exception in the *actual* expression into `#f`. Never expect
    `#f` from something that can raise."
  - Three mutants, each in its own copy:
    - `shape-nobound-literal`: `(and (<= (+ i m) n) (let loop ((k 0)) …` → `(and #t (let loop
      ((k 0)) …`;
    - `shape-nobound-digits`: `(cond ((and (< j n) (digit? (string-ref hash j))) …` →
      `(cond ((digit? (string-ref hash j)) …`;
    - `shape-noprefix-guard`: `(and prefix (let ((n (string-length hash))) …` → `(and #t …`.
  - `test-password-text` with `CHEZ_SODIUM_LIBRARY=/nonexistent` gives `# of expected passes 60`
    for each, with no FAIL.
  - Direct calls, each wrapped as `(guard (e (#t 'raised)) (list 'answered (current-hash-shape?
    s "$argon2id$")))`:
    ```
    ### shape-nobound-literal
    ("" raised) ("$argon2" raised) ("$argon2id$" raised)
    ("$argon2id$v=19$m=8,t=1,p=1" raised) ("$argon2id$v=19" raised) ("$argon2id$v=19$m=8,t=1" raised)
    ### shape-nobound-digits
    ("$argon2id$v=19" raised) ("$argon2id$v=19$m=8,t=1" raised)
    ```
  - With a `#f` prefix, `shape-noprefix-guard` gives `(raised "~s is not a string")`.
  - So these rows pass by raising: `H the empty hash`, `H a hash shorter than the prefix`, `H
    the prefix only` and `H ,p=1 with no $`. No row's string ends in digits, so the digits bound
    is never reached at all.
  - The log's `shape-*` mutants each remove a part without raising, so none of them could see
    this.
- **Why it matters:**
  - Slice 2's `password-needs-rehash?` calls this on caller data. It must never raise because of
    the hash (ADR-0009, decision 3).
  - A truncated stored hash such as `"$argon2id$v=19"` passes the pre-check, so the shape check
    is the only guard.
  - Slice 2's "garbage" rows will not hit this path: `"garbage"` fails at its first character.
- **Fix:**
  - Make every H row and R row assert `(answered #f)` or `(answered #t)` through a guard with a
    sentinel of its own.
  - Add rows for strings that end in digits: `"$argon2id$v=19"` and `"$argon2id$v=19$m=8,t=1"`.
  - Watch the three mutants above fail.

### M3S1-F2 (major): E13's deny-list misses `make-string` and `string-set!`, so a writer that copies the password into a Scheme string passes every row

- **Where:** `tests/test-native.sps:1580-1592` (E13). `src/chez-sodium/private/native.sls:142`
  now imports `(rnrs mutable-strings)`, from the caller's `foreign-ascii-string` change.
- **Evidence:**
  - Mutant `utf8-snapshot`: `call-with-utf8`'s `(let ((len (string-length string)) …` became
    ```scheme
    (let* ((string (let* ((k (string-length string)) (copy (make-string k)))
                     (let snap ((i 0)) (when (< i k) (string-set! copy i (string-ref string i)) (snap (+ i 1))))
                     copy))
           (len (string-length string)) …
    ```
  - Result: `test-native` 109 of 109, `test-blocks` 34 of 34.
  - E13 forbids only `string->utf8, string->list, list->string, substring, string-copy,
    string-append, utf8->string, bytevector-copy, bytevector->u8-list, make-bytevector`.
  - A snapshot is the natural "fix" a builder reaches for against a string changed mid-write. It
    is exactly the copy that "No Scheme copy of a secret" forbids.
- **Fix:**
  - Hold each writer's definition to an allow-list: the whole set of symbols it may reference,
    written in the suite, as plan §4.1 item 7 does for the verbs' sections.
  - At least add `make-string`, `string-set!`, `string`, `string-fill!` and `string-copy!` to the
    list.
  - Watch `utf8-snapshot` fail.

### M3S1-F3 (major): the oracle's hex mode prints no `(valgrind . …)` line, so its gated children can never show they ran under the gate

- **Where:**
  - `tests/libsodium-oracle.c:154-194`: hex mode prints one datum;
  - `tests/libsodium-oracle.sls` `compile-and-run`, which requires `(= (length data) 1)`;
  - `tests/test-native.sps`' two hex rows, whose 14 oracle children none assert the gate.
- **Evidence:**
  - The plan's every-brief rule says: "a child that reaches native code starts through
    `gated-command`, and asserts `(valgrind . yes)` exactly when the gate asked".
  - The main oracle mode prints `(valgrind . yes)`, and test-native's `(read-by-oracle
    'valgrind)` asserts it. Hex mode does neither: its output is `(hash . "…")` or
    `(verify . N)` alone.
  - The log-based witness (`gate-logs`, `command-of-log`) is internal to `(library-loading)`. Only
    `preflight-in` uses it, and neither helper is exported.
  - In slice 2's table, `libsodium-oracle.{c,sls}` belongs to no agent. So `test-password-oracle`,
    which the plan has run "in gated children", cannot assert the gate without changing a file
    nobody owns.
- **Fix:**
  - Hex mode prints `(valgrind . yes|no)` as a second line, and `compile-and-run` requires it, as
    `libsodium-oracle` does: it returns `(no-oracle valgrind …)` when the line is not
    `valgrind-line`.
  - Or export a log-based witness from `(library-loading)`.
  - Do it in slice 1, before slice 2 starts.

### M3S1-F4 (major, slice 2's footing): the decoy reads the FIFO once, so whichever writer opens it second blocks for ever. Row 19, as planned, hangs in every case

- **Where:** `tests/decoy-libsodium.c` `hold_on_fifo` (opens, reads to EOF, closes); plan §4.1
  item 4; ADR-0011's amendment.
- **Evidence:**
  - The plan has the main thread "open the FIFO for writing, which releases the call", and a
    watchdog shell that "opens the FIFO after 10 s".
  - Probe: a reader `cat f` once, then a second writer.
    ```
    mkfifo f; (cat f >/dev/null; echo "reader done") &  ; echo a > f; wait
    timeout 2 sh -c ': > f'; echo "second writer, no reader: rc=$?"
    → reader done
    → second writer, no reader: rc=124
    ```
  - When the collector releases the call, the watchdog blocks for ever at 10 s. If it holds the
    child's stdout, the suite's capture never sees EOF.
  - When the watchdog releases it (the plain mutant, and the standing control every run), the
    main thread's write-open after the rendezvous blocks for ever. So the control row can never
    pass, and the mutant shows as HUNG, not a named failure.
  - The C driver confirmed the decoy itself is right:
    - it blocks after its marker: `marker after ~100 ms … still blocked after 1 s: yes; output so
      far: []`;
    - it answers as the control once released;
    - its marker persists into the next call. I had to `rm q.entered` before the verify call.
      Without that, a second call's marker already exists, and M3S0-F1's race returns.
- **Fix,** in slice 2's files, with no decoy change:
  - Every writer opens the FIFO read-write, as `sh -c ': 1<>"$FIFO"'`. Probed: it released a
    waiting reader (rc 0), and with no reader it returned at once (rc 0), never blocking.
  - The child kills the watchdog before it exits.
  - One FIFO and marker per call, or remove the marker before each call.
  - Record this in the slice 2 brief.
  - Optional decoy hardening: answer -1 when the marker cannot be created, and retry `open` on
    `EINTR`.

---

## Minors

### M3S1-F5 (minor): the `foreign-ascii-string` row named "holds A5 after its 0" pokes zeros, so a reader that refuses a high byte anywhere within N passes

- **Where:** `tests/test-blocks.sps`, the row "reads a 93-character hash string out of a 128-byte
  block that holds A5 after its 0". It pokes `(make-list-of (- 128 (string-length hash-text))
  0)`.
- **Evidence:**
  - Mutant `ascii-high-anywhere`: `(and end (let high ((j 0)) (or (= j n) (and (< (foreign-ref
    'unsigned-8 address j) #x80) (high (+ j 1))))) …`.
  - Result: `test-blocks` 34 of 34.
  - A direct call on `61 62 63 00 A5 A5 A5 A5` with N 8 answers `#f`, where the real reader
    answers `"abc"`.
  - Only slice 2's decoy rows would catch it, since the decoy writes A5 after its string.
- **Fix:** poke `#xA5` after the 0, as the name says.

### M3S1-F6 (minor, the brief's): the no-copy row in `test-password-text` has a `-message` hole, and its list misses copiers `(rnrs)` provides

- **Where:** `tests/test-password-text.sps:166-193`; plan §4.1 item 7's list, which slice 2's
  `password-verbs.sls` row inherits.
- **Evidence:**
  - Mutant `msg-lambda`: `(define copy-message (lambda (s) (string-append s "")))` added to
    `password-text.sls`. Result: 60 of 60.
  - `message-definition?` checks only that `(cadr f)` is a symbol, so a lambda-valued `-message`
    definition, which does take parameters, passes.
  - The list omits several copiers in `(rnrs)`:
    - `string-normalize-nfc`, `-nfd`, `-nfkc` and `-nfkd`, which copy and also normalise. AGENTS.md
      forbids normalising, and an NFC test string such as `"pässwörd€"` cannot show it;
    - `string-upcase`, `-downcase`, `-foldcase` and `-titlecase`;
    - `string->symbol`;
    - writes to a string port.
- **Fix:**
  - Refuse a `-message` definition whose value is a `lambda` or `case-lambda`.
  - Add those names.
  - In slice 2, add one NFD-input row to row 3 or row 4.

### M3S1-F7 (minor): two writer-refusal rows are weaker than their names

- **Where:** `tests/test-blocks.sps`, the "holds no part of it" and "check in order" rows.
- **Evidence:**
  - Mutant `cstr-shows-value`: `call-with-c-string` refuses with `(shown-value string)`.
    - Only the whole-irritants row fails, with actual `(refused w (not-a-string string (#\a
      #\b)))`.
    - The dedicated secret row passes: `(memv #\t irritants)` searches only the top level, so
      the nested `(#\t #\o #\p)` is never seen.
  - Mutant `cstr-order`: `call-with-c-string` checks CHANGED before PROC. Result: 34 of 34. Only
    `call-with-utf8`'s order is tested.
- **Fix:** search the irritants deeply, as M2's R16 does, and add `call-with-c-string`'s
  PROC-before-CHANGED pair.

### M3S1-F8 (minor): no slice 1 row exercises the six new switches or the password entries' behaviour

- **Where:** a grep for
  `strprefix-null|pwhash-str-fails|pwhash-str-other|pwhash-str-unreadable|verify-other|pwhash-blocks`
  over `tests/*.sps tests/*.sls` finds nothing.
- **Evidence:**
  - M2 held its entries' answers in slice 1, through `-combined`'s `--drive` row. Here the first
    test of the password entries is slice 2, whose agents may not change the decoy.
  - The C driver, `cc/drive.c`, dlopens the control build and shows the decoy right today, under
    every switch. The control:
    ```
    strbytes=128 prefix=$argon2id$ code=0 a5=34 first0=93
    string[93]=$argon2id$v=19$m=8,t=1,p=1$c2FsdHNhbHRzYWx0c2FsdA$dGFn…GE
    log=… crypto_pwhash_str(p,p,3,1,8192) crypto_pwhash_str_verify(p[13],p,0) crypto_pwhash_str_needs_rehash(p[13],1,8192)
    ```
  - The other switches:
    - `pwhash-limits-other`: strbytes 160, prefix `$argon2i$`, first 0 at 140, a5=19;
    - `pwhash-str-fails`: -1;
    - `pwhash-str-other`: 1;
    - `pwhash-str-unreadable`: a5=128, no 0;
    - `verify-other`: verify 1;
    - `strprefix-null`: prefix NULL;
    - `pwhash-blocks`, unset: -1, nothing written, verify -1.
  - Native recording a NULL prefix as `#f` has no row either.
- **Fix:** extend `refusal-probe --drive`, or add `--constants` under `strprefix-null` and expect
  `(pwhash-strprefix . #f)`, so slice 1 holds its own decoy.

### M3S1-F9 (minor): two row-22 details

- **Where:** `tests/test-native-codes.sps`.
- **Evidence:**
  - "the release this suite loaded is one whose byte-0x80 answer was measured: 1.0.18 or
    1.0.22" fails `make test` on any other release at or above the floor, such as 1.0.20. It is a
    deliberate tripwire, but the row says nothing of why.
  - "any string of strbytes characters or more is unreadable" checks only the 136-character
    hash.
- **Fix:** say in the row that it is a tripwire for unmeasured releases, and name the
  136-character case as the case it holds.

### M3S1-F10 (minor): the mutation log's form

- **Where:** `.plans/m3-slice-1-mutation-log.md`.
- **Evidence:**
  - All of the decoy agent's 47 entries have an empty `- Clean rerun:` field.
  - `b-type-prefix` reads "bound to return size_t, read as an address by c-string->string
    anyway: bound as a wrong function instead", so what ran is unclear.
    - Its output shows a negative address, so it was not `size_t`.
    - On LP64, `size_t` for `uptr` is an equivalent mutant that only the convention table sees.
  - Plan §5.2's slice 1 measurement, the gate times, is in `build/m3s1-caller/mem.out`, but in no
    record.
- **Fix:** fill in the clean reruns, rewrite `b-type-prefix`, and record the gate times.

### M3S1-F11 (minor): comments that do not describe the code

- `tests/test-blocks.sps`:
  - the comment `;; written-by : Symbol String Natural -> Any` heads `(define (utf8-written
    string n)`;
  - a header line of about 130 characters.
- `tests/test-password-text.sps`:
  - `;; with-params` heads `id-with`;
  - "the symbol read? when unread" is wrong: it answers `'(unreadable)`;
  - the header says the suite "runs with CHEZ_SODIUM_LIBRARY naming nothing", but `make test`
    does not run it that way. A `foreign-entry? "sodium_version_string"` → not-loaded row would
    hold the claim.
- `native.sls`:
  - `crypto-pwhash-str-needs-rehash`'s comment says "-1 when it cannot read STR". It also answers
    -1 for an opslimit above 2³²−1 (ADR-0009, amended; row 22).
  - `foreign-ascii-string`'s comment breaks a sentence mid-line ("… or more. An / ADDRESS").
- `decoy-libsodium.c` and `test-decoy-source.sps` say the array spelling ends "before libsodium
  1.0.19".
  - Only 1.0.18 (major 10, array) and 1.0.22 (major 26, pointer) exist in the store, so 1.0.19
    is unmeasured.
  - The `< 26` test fails loudly, not silently, if wrong.
- `libsodium-oracle.sls`: `compile-and-run`'s comment is mis-indented.

### M3S1-F12 (minor): the recorded prefix is one mutable string, shared by every importer of native

- **Where:** `native.sls`, `(define pwhash-strprefix (answer 'pwhash-strprefix))`.
- **Evidence:**
  - `c-string->string` answers a fresh mutable string, which is exported as is.
  - M1's E10 held `loaded-libsodium` to fresh strings, so that "what a caller changes in one
    never reaches the next". Here any importer could `string-set!` what "current" means.
  - Nothing does today, and `password-verbs` cannot import `string-set!` under its fixed import
    clause.
- **Fix:** record it with `string->immutable-string`, from `(chezscheme)`, which native already
  imports from.

---

## The eight questions

1. **Plan conformance: it matches.**
   - Checked:
     - the seventeen forms, as data, in item 1's order;
     - the raw names, constant names and keys;
     - E3 (30, `raw-pwhash-str` and `raw-pwhash-str-verify` collect-safe) and E5 (36);
     - the helpers' signatures, refusals and check order;
     - the log lines `crypto_pwhash_str(p,p,N,N,N)`, `…_verify(p[L],p,N)` and
       `…_needs_rehash(p[L],N,N)`;
     - both value sets, the seven switches and the marker path;
     - the two definitions under `#if SODIUM_LIBRARY_VERSION_MAJOR < 26`: the floor compile
       takes `const char str[128U]`, the current one `const char *str`;
     - the oracle's `(pwhash-… F M)` lines, `(hash . "…")` and `(verify . N)`.
   - The divergences are all harmless:
     - under `pwhash-blocks` with the variable unset, `crypto_pwhash_str` writes nothing, which
       follows item 4 ("-1 at once") over item 8 ("A5 under every switch");
     - test-native's two oracle self-test rows are additions;
     - native gains `(rnrs mutable-strings)`, which makes F2 reachable.
   - F3 follows the plan's format to the letter, against the plan's own gate rule.
2. **Rows that cannot fail.**
   - The new rows that cannot fail: F1 (three surviving mutants), F2 (one), F5 (one), F6 (one)
     and F7 (two).
   - Everything else held:
     - row 22's planted expectations;
     - the constants against the oracle's F and M and the numbers;
     - the `pwhash-limits-other` oracle and `--constants` rows;
     - the missing-api rows, conventions, prototypes, and the decoy-source plants.
   - Every item of plan §6 slice 1's "Watched to fail" list is in the log and killed. "Each part
     of the shape check removed" was done only as non-raising removals, which is how F1 slipped
     through.
3. **Secrets and copies: sound, but for the guard in F2.**
   - The writers read in place and refuse by kind. `foreign-ascii-string` builds only the
     returned hash.
   - The decoy logs only `p` and lengths. The oracle is test-only.
   - Nothing stops a future copy inside native (F2), or inside the pure core through a
     lambda-valued `-message` definition or an unlisted copier (F6).
4. **Sections and raises: sound.**
   - No write passes N or N+1:
     - the c-string block is `n+1` for a string whose length cannot change;
     - the UTF-8 writer checks `(> (+ at width) n)` before each character;
     - `n` 0 with a non-empty string answers CHANGED before any write.
   - Every `foreign-set!` value is below 256.
   - Every block goes through `call-with-block` and is wiped and freed, the CHANGED paths
     included.
   - The odd inputs:
     - an N larger than needed, and a shorter string, both answer CHANGED (row ±1);
     - a string of only 4-byte characters is fine for UTF-8, and CHANGED for c-string;
     - the boundary characters are held by the "never writes past N" row.
   - Only a failed `foreign-alloc` raises inside, and `call-in-section` catches it.
5. **C correctness: sound.**
   - The decoy and the oracle compile clean at both headers at `-O0` (as the suites do), at
     `-O2`, `-O2 -Wextra` and `-O2 -fanalyzer`: 16 compiles, all rc 0.
   - `show_string` needs at most 24 bytes of 32. `bytes[length]=0` is within the decoy's own
     strbytes. `_Static_assert`s pin 93 and 140.
   - Every pointer goes through `volatile uintptr_t`.
   - `decode_hex` always allocates at least one byte, and frees on a bad digit. The success paths
     free; the error paths leak only at exit.
   - `hold_on_fifo` does not retry `open` on `EINTR`, and still blocks when it cannot create the
     marker (F4's hardening).
6. **The gate's rules: sound, but F3.**
   - Every child goes through `gated-command`, the oracle's hex children included. Those 14
     children assert nothing about Valgrind (F3).
   - The new suites' top-level calls are guarded: `read-floor-values` always answers a pair.
   - All three new suites end with their exit line.
   - Gate times, from `build/m3s1-caller/mem.out`:
     - the loading suites take 36 to 71 s (missing-passwords 63, missing-limits 49, decoys 71);
     - test-native takes 15 s;
     - the largest is test-check-ci, at 115 s.

     Nothing is near the limit of 450 s.
7. **Slice 2's footing.**
   - Present:
     - every helper, raw binding, constant and `password-text` export;
     - `with-constants`, `other-constants` and `constants-keys` from `(library-loading)`;
     - the decoy's `name_block` lengths, which match the writers' blocks (strlen+1 = N+1, and
       `max(1,len)`);
     - room in the log: about 3,370 bytes after the load, or about 40 hash and verify calls.
   - Gaps it will hit:
     - F3: `test-password-oracle` cannot assert the gate;
     - F4: the FIFO's second writer, and the marker persisting;
     - F1: needs-rehash on truncated hashes is unguarded;
     - F8: untested decoy switches that slice 2 may not change.
   - Change in slice 1, before slice 2: F1, F2, F3 and F8, all in slice 1's files.
8. **Comments and records.**
   - The comment rule holds: a grep of every added line for milestones, slices, finding ids,
     research paths, dates, "maintainer", §, plan, agent and owner finds none.
   - F11 lists the comments that misdescribe the code.
   - The records agree with the code:
     - ADR-0009's shape text matches `current-hash-shape?`;
     - ADR-0011's switches, marker and spelling match the decoy;
     - the constraints match, but for the harmless A5 point in answer 1;
     - `raise-sodium-failed`'s new message matches ADR-0006's amendment.
