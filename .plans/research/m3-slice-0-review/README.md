# M3 slice 0 review: the M3 plan and its records

Reviewer: Opus, read-only and adversarial. Tree: `m3-plan` over `main` at `cd64dc6`, with the work
uncommitted. Probes ran in a copy, `build/m3-s0-review/tree/` (made with
`shutil.copytree(..., symlinks=True)`, without `build/` and `.git`), and in
`build/m3-s0-review/probe/`, through `scripts/guix-env`: Chez 10.4.0 threaded, GCC 16.2, the
profile's 1.0.22, and the floor headers at `build/slice5/prefix-1.0.18/`. The copy will be removed,
so each probe's text and output is quoted below. No permission check was denied.

**Counts: 0 blockers, 7 majors, 10 minors.**

**The caller's checks.**
- **F1, reproduced:** `race.sh` rerun, 8 plain runs of 8 and 8 collect-safe runs of 8, all
  released by the collector. The probe is kept here: `race.sh`, `race.sps`, and set B's
  `blocker.c`. Run it as `scripts/guix-env sh .plans/research/m3-slice-0-review/race.sh`.
- **F2, read in the code:** `tests/test-never-loads.sps:181-192, 230-234`.
- **F7, read in the measurements:** `research/m3-plan/a/run-3.out`, lines 5 and 7.
- **The fixes:** each finding is fixed in the plan and the records. [The plan](../../2026-11-24-m3-plan.md)'s
  §4.5 lists where.

---

## Majors

### M3S0-F1 (major): row 19 as written passes with a plain binding, because nothing waits for the call to reach C

- **Where:**
  - plan `:223-227` (§4.1, item 4: "references the library once, then forks a thread that
    calls the verb … The main thread then runs `collect-rendezvous`");
  - ADR-0011's amendment ("forks a thread that calls the verb. It then runs
    `collect-rendezvous` and releases the FIFO");
  - brief §8.1 row 19.
- **Evidence:**
  - The plan names no step between the fork and the rendezvous.
  - Both measured patterns have one:
    - set B's `blocker.sps` waits on a flag set just before the call, then pauses 300 ms;
    - chez-sqlite3 (`test-native.sps` ~2560-2580) sets `opener-calling` inside PROC, just
      before the C call, then sleeps 1 s.
  - A verb gives the probe no such hook. Only the decoy knows it has been entered.
  - **Probe** (`race.sps`, using set B's `blocker.c`):
    - it references both bindings first;
    - then `(fork-thread (lambda () (verb) (set! done #t)))`, where `verb` is a 200-step
      Scheme loop then `(critical-section (binding b))`;
    - then at once `(collect-rendezvous)` and `(release!)`, a shell `exec 3<>FIFO`;
    - a 5 s watchdog shell leaves a marker; the verdict is "released-by".
  - Output, 8 runs each:
    ```
    run=1 plain released-by=collector   … run=8 plain released-by=collector
    run=1 safe released-by=collector    … run=8 safe released-by=collector
    ```
    A plain binding passed 8 of 8, so the X-M3 mutant the plan lists (`:733`) survives.
  - **A second risk, under the gate:** the watchdog is 10 s, and the plan does not say who
    starts it. Set B's plain cases under Valgrind were released at 6.8-7.0 s, because Valgrind
    starts after the watchdog's clock. A gated child takes 3.6-3.9 s on CI's runner
    (progress.md, M2 slice 0). If the parent starts the watchdog, a slow runner can let it fire
    before a correct collect-safe call is reached. chez-sqlite3 used 30 s.
- **Fix:**
  - Under `pwhash-blocks`, have the decoy signal entry before it opens the FIFO: its log entry,
    or a marker file.
  - Have `collect-probe` poll for that signal, pause (1 s, as chez-sqlite3 does), then
    rendezvous.
  - Start the watchdog inside the child once the call is in C, or make it 30 s.
  - Name the standing control: a test-side plain binding of the decoy's entry, released by the
    watchdog.
  - Record all of this in ADR-0011's amendment and brief row 19.

### M3S0-F2 (major): the plan has `test-never-loads`' loaders row expect `password-text`, the pure library, to be a loader

- **Where:**
  - plan `:114` ("the loaders row gains `password-verbs` and `password-text`");
  - `tests/test-never-loads.sps:181-192, 230-234`.
- **Evidence:**
  - The row computes loaders from src/'s imports: native, and every library that imports a
    loader.
  - `password-text` imports `require-threaded`, `(rnrs)` and `cap` alone (plan `:90`;
    ADR-0012, amended), so it is not a loader.
  - **Probe:** in the copy I added these two stubs, then added the two names to the row's
    expected list as the plan says:
    ```scheme
    (library (chez-sodium private password-text) (export utf8-length)
      (import (chez-sodium private require-threaded) (rnrs) (chez-sodium private cap)) …)
    (library (chez-sodium private password-verbs) (export password-hash)
      (import … (chez-sodium private native) … (chez-sodium private password-text)) …)
    ```
    Output:
    ```
    FAIL the libraries under src/ that load libsodium, found from their imports: native, and each that imports a loader
      expected: (… (chez-sodium private password-text) (chez-sodium private password-verbs) (chez-sodium))
      actual:   (… (chez-sodium private password-verbs) (chez-sodium))
    ```
  - The expected value inverts the decision. A builder can make the row pass only by making
    `password-text` import native.
  - This row is also the only check that `password-text` loads nothing. The plan says
    `test-password-text` "runs with no libsodium" (`:107`, `:359`) but names no row that
    proves it.
- **Fix:**
  - The loaders row gains `password-verbs` alone.
  - Say that it is the row holding `password-text` pure. A mutant where `password-text` imports
    native must fail it.

### M3S0-F3 (major): R16 for `length-out-of-range` cannot be built where the plan puts it

- **Where:** plan `:108` (`test-password-verbs`, "Against the real library, in process: … row
  16 and R16"), `:330-338` (§4.1, item 10), `:324-326`.
- **Evidence:**
  - On all four libraries, `passwd_min` is 0 and `passwd_max` is 4294967295 (set A,
    `run-3.out`).
  - A password that passes the 65536-byte cap is always inside that range. So
    `length-out-of-range` is unreachable in process, at every release.
  - It is reachable only under the decoy's `pwhash-limits-other` (1 to 100 bytes), in a child
    through `verb-probe`.
  - `verb-probe` prints `(refused WHO IRRITANTS)`, "never its message"
    (`tests/verb-probe.sps:22-24`).
  - R16 compares the whole printed condition, the message included (`describe`,
    `test-byte-verbs.sps:665-700`).
  - The plan gives `verb-probe` no print mode for this. Two further errors in the same item:
    - `:332` says "for `password` in each of the three verbs", but `password-needs-rehash?`
      takes no password;
    - item 10 answers "Owed to M3"'s R16 bullet in name only, for this rule.
- **Fix:**
  - Put `length-out-of-range`'s R16 in `test-library-loading-passwords`, under
    `pwhash-limits-other`, with a `verb-probe` option that prints `describe` of a refusal.
  - Use 101- and 102-byte passwords, one of them non-ASCII.
  - Say "the two verbs that take a password".

### M3S0-F4 (major): `&sodium-failed` with code 0 is planned and recorded, but nothing can reach it

- **Where:**
  - plan `:202-204` (§4.1, item 3: "also raised when the answer is 0 and the out block holds no
    readable string, with code 0");
  - ADR-0006's amendment `:180-187` ("its two cases are one rule … answers anything but 0",
    then "also raised, with code 0");
  - `global-constraints.md:115-118`;
  - brief §5.
- **Evidence:**
  - Under every switch, the decoy writes "A5 over all of `out`, then a fixed hash string that
    passes the pre-check and the shape check, and a 0" (plan `:657-659`).
  - Real libsodium writes the string, then zeros, on every 0 (set A, 5a).
  - So no row can see `foreign-ascii-string` answer `#f`. A build that answers `#f` as the hash
    passes every row. So does one that calls a string operation on `#f` inside the section (a
    raise inside, caught by `call-in-section`'s guard as a net).
  - The records disagree with each other:
    - ADR-0006 calls the case "one rule: anything but 0", then adds code 0;
    - the constraints and brief §5 do not mention code 0;
    - `raise-sodium-failed`'s fixed message, "libsodium answered a failure", is false for
      code 0.
- **Fix:**
  - Add a decoy switch in slice 1, such as `pwhash-str-unreadable`: answer 0 and leave `out`
    all A5, with no 0 within `strbytes`.
  - Or, under `pwhash-limits-other`, write a well-shaped string of 129 to 159 characters, so
    that a reader bounded by a Scheme 128 finds no 0. This also covers F9.
  - Add a row expecting `(failed password-hash "crypto_pwhash_str" 0)`.
  - Put the case in the constraints and brief §5, and drop "one rule".

### M3S0-F5 (major): `changed-during-call` makes `password-needs-rehash?` raise because of the hash, against a standing decision

- **Where:**
  - plan `:317` (refusal table: "any verb … `password` or `hash`") and `:437-446`;
  - `global-constraints.md:130-131` ("by every verb"), against `:199-202` ("never raises
    because of the hash");
  - ADR-0006's amendment `:211, 216`;
  - ADR-0009, decision 3 (`:46`), which its amendment leaves untouched;
  - brief §4.2 `:247`;
  - AGENTS.md `:69` against `:79`.
- **Evidence:**
  - Under `call-with-c-string`, another thread's `string-set!` of a hash character to U+0000 or
    above U+007F makes the verb raise.
  - The constraints file now contradicts itself across its own lines 130 and 202.
  - The plan's status line names §4.2 items 1 to 5 as the owner's. Item 6 is "This plan's",
    and its effect on ADR-0009 is recorded nowhere.
- **Fix (the owner's choice):**
  - either needs-rehash answers `#t` for a changed hash, which keeps decision 3;
  - or amend ADR-0009 decision 3, brief §4.2 and §5's list of mistakes, AGENTS.md and the
    constraints, and record the owner's assent.

### M3S0-F6 (major): no row holds "no Scheme copy" outside the writers

- **Where:**
  - plan `:345-348` ("never through `string->utf8`"), `:683-686` (password-text's mutants),
    `:272-283` (the shape rows read "inside each section");
  - `global-constraints.md:152-154, 189-191`;
  - ADR-0008, decision 3.
- **Evidence:**
  - `(bytevector-length (string->utf8 s))` equals the sum of widths on every string: set B 2b
    found `string->utf8` equal to the `char->integer` writer byte for byte on 13 strings up to
    U+10FFFF.
  - So a `utf8-length` built that way passes every value row, while making a Scheme bytevector
    of the password. ADR-0008 decision 3 forbids exactly that.
  - Nothing reads `password-text`'s body. The shape rows read only inside each section, and the
    count runs before it.
  - "`string->utf8` used" is listed for the writers alone.
  - The same holds for:
    - `string->list` or `string-copy` of the password;
    - `substring` of the hash string in `current-hash-shape?` or `readable-hash-string?`. The
      ledger treats a Scheme copy of the hash string as forbidden too (v0.1.1's
      `call-with-c-string`).
- **Fix:**
  - Add an E9-style row over `password-text.sls`, and over `password-verbs.sls`' pre-section
    code, refusing `string->utf8`, `utf8->string`, `string->list`, `list->string`, `substring`,
    `string-copy`, `string-append`, `string->bytevector` and `bytevector-copy`.
  - List "`utf8-length` through `string->utf8`" and "a `substring` in the shape check" among the
    mutants watched to fail.

### M3S0-F7 (major): the twins `opslimit_max` and `passwd_max` defeat the listed mutants, which M2-F1 warned of

- **Where:** plan `:670` ("reading one from another"), `:673` ("the oracle's constants swapped,
  and one read from the wrong macro"), `:98, 101, 268-270`.
- **Evidence:**
  - On all four libraries, `crypto_pwhash_opslimit_max` and `crypto_pwhash_passwd_max` both
    answer 4294967295 (set A, `run-3.out`).
  - Their macros, `OPSLIMIT_MAX` and `PASSWD_MAX`, are both `4294967295U` (set A, item 1).
  - In slice 1, against a real library:
    - native reading `passwd_max` into `pwhash-opslimit-max` passes `test-native`;
    - so does the oracle printing one function's line under the other's key.
  - Only slice 2's `pwhash-limits-other` rows (ops max 9 against passwords max 100) kill
    native's twin.
  - Nothing ever runs the oracle against the decoy, so its twin swap survives every row. A macro
    swap of the pair cannot be told apart by any value.
  - M2-F1 was this exact major: "M3 adds oracle lines for its constants, and some of those also
    have equal-valued twins" (`research/m2-closing-review/README.md:63-64`). M2 fixed it with a
    gated oracle child under `sizes-other` (`test-library-loading-verbs.sps:319-340`), and
    native's twins through `refusal-probe --sizes`.
  - `refusal-probe.sps` is in no agent's list.
- **Fix:**
  - In slice 1, add a gated oracle child, and a `refusal-probe --constants` line, under
    `pwhash-limits-other`, each asserted whole.
  - Give `refusal-probe` an owner.
  - Record that the macro pair cannot be held by value.

---

## Minors

### M3S0-F8 (minor): the decoy's version-dependent `str` is unspelled, and `test-decoy-source` reads each natural spelling differently

- **Where:** plan `:652-655`; ADR-0011's amendment; `tests/test-decoy-source.sps:31-36,
  300-322, 979-988`.
- **Evidence:** probe `probe-scan.sps`, the suite's scanner run on four spellings:
  ```
  param-if: ((("crypto_pwhash_str_verify" ("str" "str" "passwd"))) ())
  head-if: ((("crypto_pwhash_str_verify" ("str" "passwd"))) (("crypto_pwhash_str_verify" unreadable head)))
  macro-param: ((("crypto_pwhash_str_verify" ("passwd"))) ())
  two-definitions: ((("crypto_pwhash_str_verify" ("str" "passwd")) ("crypto_pwhash_str_verify" ("str" "passwd"))) ())
  ```
  - **Alternative heads** are refused by name.
  - **A parameter macro** (`#define DECOY_STR const char str[…]`) is silently read as a scalar.
    The `str` pointer drops out of the rule, and the planted body's plain `str[0]` is not
    flagged. This is a scanner gap: a parameter of one identifier with no type words is
    classified `none`.
  - **An `#if` inside the parameter list** lists `str` twice.
  - **Two whole definitions** list the function twice.
  - The plan's claim itself is confirmed. Probe `arr.c` compiled with `-Wall -Werror` and
    `-DAS_ARRAY` or `-DAS_POINTER`:
    ```
    1.0.18 AS_ARRAY: exit 0
    1.0.18 AS_POINTER: exit 1   argument 1 of type 'const char *' declared as a pointer [-Werror=array-parameter=]
    1.0.22 AS_ARRAY: exit 1     argument 1 of type 'const char[128]' with mismatched bound [-Werror=array-parameter=]
    1.0.22 AS_POINTER: exit 0
    ```
  - `SODIUM_LIBRARY_VERSION_MAJOR` is 10 at 1.0.18 and 26 at 1.0.22.
- **Fix:**
  - Fix the spelling in the plan: two whole definitions, or a parameter-level `#if`, with the
    whole-list row's expected value.
  - Make the scanner refuse a one-identifier parameter as unreadable.

### M3S0-F9 (minor): `strbytes`' check names a witness that cannot see it

- **Where:** plan `:262` ("named to `watch_set`"), `:657`; ADR-0001's amendment.
- **Evidence:**
  - `watch_set` resolves only with `free-watch.c` preloaded, in `test-wipe`'s children, and
    those run the control build, whose `strbytes` is 128 = the real value.
  - The witness that does work is the decoy's `sodium_memzero(p,160)` in the growth that
    `test-library-loading-passwords` asserts whole.
  - The plan does not say whether the decoy writes A5 over its own 160 or the header's 128.
    Writing 160 into a block made 128 by a Scheme constant corrupts the heap, a crash rather
    than a named failure.
  - `foreign-ascii-string`'s N from a Scheme 128 is held by nothing.
- **Fix:**
  - Name the memzero line as the witness.
  - Have the decoy write over its own `strbytes`.
  - Use F4's longer string under `pwhash-limits-other`.

### M3S0-F10 (minor): the order of refusals against the pre-check's answer is unfixed

- **Where:** plan `:297-323`; ADR-0009's amendment ("run first").
- **Evidence:**
  - Take `(password-verify "\x0;bad" 'not-a-string)`. Either `#f` (pre-check first) or a
    `not-a-string` refusal fits the text. The same holds for needs-rehash with a bad hash and
    bad limits.
  - Row 15 uses a good hash, so either order passes.
  - Likewise, `over-the-cap` against `length-out-of-range` can be ordered only under
    `pwhash-limits-other`, with a 65537-byte password. The plan's "checks out of order" mutant
    does not say so.
- **Fix:**
  - Say that every refusal precedes the pre-check, and add a row with both mistakes.
  - Name the decoy row for cap against range.

### M3S0-F11 (minor): the prototype column's "sodium.h's own spelling" cannot hold array parameters, and the convention column already exists

- **Where:** plan `:163` ("gains the convention as a column"), `:102-103`;
  `tests/foreign-conventions.sls:58-71`; `tests/test-constants.sps:195-205`.
- **Evidence:**
  - The table already has `CONVENTION`, `convention-forms`, and the fixtures `collect-safe-ok`
    and `plain-collect-safe-row`.
  - `chez-type` maps a pointer only when its last word is `*`. So `char[crypto_pwhash_STRBYTES]`
    maps to `#f` and fails the map row.
  - `str` is spelled differently at the two releases.
  - Set A's `prototypes.c` used `char *` and `const char *`, which `_Generic` matches at both
    releases.
- **Fix:** write the adjusted pointer types in the rows, say so, and drop "gains a column".

### M3S0-F12 (minor): the writers' "missing terminating 0" mutant survives plain runs

- **Where:** plan `:679`, against `:726`, where only row 10 says "under the gate".
- **Evidence:** probe `reuse.sps`: a block filled `#xFF`, zeroed, freed, then a same-size
  block's last byte:
  ```
  (94 same-chunk #t last-byte 0) (95 …0) (129 …0) (161 …0) (65537 …0)
  (77 fresh last-byte 0) (1001 fresh last-byte 49) (3333 fresh last-byte 21)
  ```
  Every block the library frees is wiped, so a reused chunk's byte N already reads 0.
- **Fix:**
  - State that `test-blocks`' row sees this mutant under the gate.
  - Or pre-dirty a chunk of that size without a wipe, as `test-wipe`'s dead-block row relies on
    reuse.

### M3S0-F13 (minor): inputs and behaviour the builders would have to invent

- **The long hash:** the 136-character hash for rows 8 and 22 needs `crypto_pwhash`, which is
  unbound. Set A built it in C. The plan does not say whether to use a literal or a test-side
  binding.
- **The no-memory codes:** §3.4's no-memory -1 needs `ulimit -v`, which Valgrind cannot run
  under. The plan does not say that row 22 leaves these to research.
- **Row 4's empty password** has no "last byte" to change (`:217`).
- **`pwhash-blocks`** with `CHEZ_SODIUM_DECOY_FIFO` unset is unspecified.
- **The decoy's fixed hash string** under `pwhash-limits-other` must begin `$argon2i$` to pass
  the shape check.
- **The helpers' own refusals:**
  - a non-string's irritants and parameter name for `call-with-c-string` and `call-with-utf8`
    are unspecified;
  - N and CHANGED are unchecked.
  - `call-with-c-string` accepts U+0001 to U+007F where the pre-check accepts U+0021 to U+007E;
    aligning them is simpler.
- **The memory range's rounding:** `memlimit_min` / 1024 must round up, and `memlimit_max` /
  1024 down. Every release and the decoy use multiples of 1024, so no row holds the rounding.

### M3S0-F14 (minor): slice 1's seams between agents are not named

- **Native's new exports:** written before the helpers exist, they break native for every
  agent. Probe: `(library (demo n) (export a call-with-utf8) … (define a 1))` gives `Exception:
  missing definition for export call-with-utf8`.
- **The decoy suites** stay red (missing-api) until the decoy agent lands its 17 entries.
- **Rows that join two agents' files:**
  - `test-conventions:201` (conventions agent) holds the table to `library-loading`'s
    `every-entry` (decoy agent);
  - `test-library-loading-verbs:335-340` (decoy agent) asserts the oracle's output whole, and
    the load agent adds 14 lines to it.
- **Files with no owner:**
  - `refusal-probe.sps`;
  - in slice 2, `test-library-loading-verbs`, while `verb-probe` changes;
  - `test-wipe`, which also reads `library-loading` (not only "the third agent").
- **Fix:**
  - The caller writes stub helpers, present and wrong.
  - List these rows as red until the join.
  - Assign the unowned files.

### M3S0-F15 (minor): the records miss M3's new paths and lists, and leave stale text

- **The no-section paths:** ADR-0007 (`:176-178`: "are the others"), the constraints `:165-167`
  and AGENTS.md `:209-211` list them exhaustively. They omit the password verbs' C-less
  answers: the pre-check, the shape check and a NULL prefix.
- **The caller's mistakes:** brief §4.2 `:247-248` ("limits out of range") and §5's list of
  mistakes are not updated for `make-password-limits` or `changed-during-call`.
- **Stale comments:**
  - `src/chez-sodium.sls` ("never a & name or a constructor");
  - native's header ("none is `__collect_safe`").
- **AGENTS.md `:68-69`** says "a string another thread changed mid-write is answered as data".
  Only a width change, or a hash character leaving U+0001 to U+007F, is detected.

### M3S0-F16 (minor): the documented fallback for Techo contradicts brief §5, and plan §3 omits it

- **Where:** ADR-0006's amendment `:203-204` ("A `&sodium-failed` there means memory is
  short"); progress `:151-153`; plan §3 `:128`.
- **Evidence:**
  - Brief §5 says that in a container with a memory limit "libsodium never sees a failure": the
    process is killed. So the fallback's failure path covers `ulimit` or no-overcommit only.
  - Techo's own brief adds that it "only fits hashes made at Techo's current limits".
  - Plan §3's list of M4 notes leaves the fallback out.
- **Fix:** carry both caveats, and make the three lists agree.

### M3S0-F17 (minor): numbers and wording that do not match

- **Reruns (`:498-500`):**
  - "items 2 to 6 of set A reproduce": A's README says items 2 to 5. Item 6, short memory, was
    not rerun; only its source lines were read again.
  - "set B's items 2 to 4 reproduce exactly": item 3 reproduced at 17 ms against 12.
- **"0.36 ms"** (`:467, 531`; brief §8.2) is the plain binding's cost. The collect-safe binding
  the verbs use costs 0.39-0.41 ms (B, `run-1.out`).
- **"E3 and E5 count thirty bindings"** (`:98`): E5 lists answers, 36 after M3, not bindings.
- **"Rows 2 and 21's later parts wait for M5"** (`:81`): row 21 is M1's, and nothing of it
  waits.
- **"The print holds no character of the first secret"** (`:337`) is impossible for an ASCII
  secret against an English message. M2's R16 searches runs of text.

---

## The eight questions

1. **Do the claims match the measurements and the code?** Mostly they do.
   - Checked and confirmed:
     - `argon2.c` lines 258 (1.0.18) and 272 (1.0.22);
     - `SODIUM_LIBRARY_VERSION_MAJOR` 10 and 26;
     - `-Werror=array-parameter` in both directions (probe);
     - every constant, code, cost and collect-safe result in §5.1, against sets A and B;
     - "thirty bindings" against E3's 13 + 17.
   - Mismatches: F17, F11 (the convention column exists) and F9 (the `watch_set` witness).
2. **Can each row kill its mutant?** These can, as described: rows 3, 5, 6, 7, 8 (with §5.1's
   strings), 11, 12, 16, 17, 18 and 24, and the shape rows. These cannot:
   - row 19 (F1);
   - the loaders row (F2);
   - the code-0 branch (F4);
   - copies outside the writers (F6);
   - the twins (F7);
   - the plain-run terminating 0 (F12).
3. **Are the interfaces complete and consistent?** Gaps are F3, F8, F9, F10, F13 and F14. No two
   agents of one slice edit one file, but rows join two agents' files and some files have no
   owner (F14).
4. **Can a secret reach a condition, a log or a Scheme copy?** One path: F6. Otherwise sound:
   - refusals show a secret by its kind;
   - bounds go through `refuse-secret` as numbers;
   - `limits` goes through `shown-value`, as the rules allow;
   - only the test decoy logs lengths.
5. **Can anything raise inside a section?** Sound.
   - The writers answer CHANGED as data, and `foreign-ascii-string` answers `#f`.
   - `c-string->string` cannot raise on a `uptr`.
   - The NULL prefix, the record check and `make-password-limits`' load all run outside any
     verb's section.
   - The engine and thread rules are restated.
   - The exception is F4: the code-0 branch has no row, so a build that raises inside the
     section there passes.
6. **Do the documents contradict each other or the owner?** F5, which silently changes ADR-0009
   decision 3; F4's "one rule"; F15; and F16.
7. **Is anything owed to M3 dropped?** All ten items are carried. R16's `length-out-of-range`
   half is answered in name only (F3). M2-F1's warning about M3's oracle twins is dropped (F7).
8. **Is anything the rules require missing from slices 1 and 2?**
   - Missing: `test-never-loads` (F2), the oracle and probe children under
     `pwhash-limits-other` (F7), and the seams (F14).
   - Present and sound:
     - `check-seam`: neither new library imports from `(chezscheme)`;
     - `check-nothreads` and `test-check-nothreads`: glob src/;
     - `check-floors`: reads no `tests/` file;
     - the `missing-api` split, the 14-children limit, gate times, `check-test-fails` and
       `check-suites`.
