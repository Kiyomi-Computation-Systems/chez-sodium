# M3 slice 2 review: the password verbs

**Reviewer:** Opus, read-only and adversarial.

**Tree:** `m3-slice-2` over `main` at `9fee8ff`, uncommitted. The six changed files, the seven
untracked ones, and the plan, records and constraints named in the brief, all read whole.

**Where the probes ran:**
- in copies under `build/m3s2-review/`, each a `shutil.copytree(..., symlinks=True)` of `src`,
  `tests`, `packaging` and `.plans/decisions`: `base`, `rehash-changed-false`, `r18-count`,
  `c-string-no-nul`, `hang`, `not-opaque` and `rehash-no-section`;
- through `scripts/guix-env`: Chez 10.4.0 threaded and the profile's 1.0.22, with `--libdirs
  src:tests:../../scheme-libs`;
- one decoy compiled by hand in `hang/` with `-DDECOY_VERSION="1.0.18"`.

No permission check was denied. No process, FIFO or marker was left behind.

**Counts: 0 blockers, 2 majors, 7 minors.**

**The caller's checks:**
- **F1:** reproduced. `rehash-changed-false` passes all 171 rows of `test-password-verbs`.
- **F2:** reproduced. `CHEZ_SODIUM_LIBRARY=/nonexistent/libsodium.so` makes `test-password-verbs`
  exit 255, its last line `Exception in string-append: (unhashed "Exception in password-hash: library
  could not be reached …") is not a string`.

Each finding is fixed in slice 2's fixes, or in the plan's list for M4. The close-out says where.

**The verbs match plan §4.1 items 3, 9 and 11 and §4.2 items 1 to 6 on every point checked:**
- each refusal's rule, parameter, irritants and order;
- the limits and the memory range's rounding;
- code 0 with no string;
- any answer but 0;
- the NULL prefix;
- the defaults;
- `changed-during-call` for hash and verify.

Nothing raises inside a section for any value a caller can make through the public API. No
block is left live. No secret reaches a condition or a Scheme copy. Row 19 works, and well within
its bound: 15–16 ms under the gate against 5 s, and 10,086 ms for the control.

The majors are a row that cannot fail and a suite that dies at top level.

---

## Majors

### M3S2-F1 (major): no row holds that `password-needs-rehash?` answers `#t` for a hash changed during its call; a version that answers `#f` passes all 192 rows

- **Where:** `src/chez-sodium/private/password-verbs.sls:220-227`; `tests/test-password-verbs.sps:1017-1021`,
  the R18 sweep "password-needs-rehash? with a hash that gains a character out of U+0021 to
  U+007E…".
- **Evidence:**
  - Plan §4.2, item 6, and the constraints say a changed hash answers `#t`. Plan §6's list watches
    only "raised by password-needs-rehash?", not "`#f` answered".
  - The sweep's `right?` accepts `#t` or `#f`, and its expected kinds are `(answered-false
    answered-true)`. A run's answer depends on where its expiry falls:
    - before the pre-check reaches the changed character: `#t`, from the pre-check;
    - between the shape check and the section: the changed path;
    - after the section: `#f`.

    So `#t` from the pre-check stands in for `#t` from the changed path. The log's
    `changed-rehash-raises` shows the sweep does reach the changed path.
  - Mutant `rehash-changed-false/`: `(not (and (eq? (car outcome) 'code) (eqv? (cdr outcome) 0)))`
    → `(and (eq? (car outcome) 'code) (not (eqv? (cdr outcome) 0)))`, which makes a changed hash
    answer `#f`.
    - `test-password-verbs` printed `# of expected passes 171`;
    - `test-library-loading-passwords` printed `# of expected passes 21`.
- **Fix:** hold the changed path where it can be seen, in either of two ways:
  - a child under the decoy runs the same engine sweep and prints each run's `(answer growth)`.
    The row asserts that every run whose growth is `sodium_memzero(p,94)`, with no
    `crypto_pwhash_str_needs_rehash` line, answered `#t`, and that at least one such run exists;
  - or move the after-section mapping into a pure procedure in `password-text`, and give
    `(changed . hash)` → `#t` a row of its own.

  Either way, add "`#f` for a changed hash" to the watched list.

### M3S2-F2 (major): `test-password-verbs` dies at top level when libsodium cannot load or `password-hash` fails, naming no test

- **Where:** `tests/test-password-verbs.sps:444-457` (R8's `for-each` list) and `:478-486` (R9's).
  Both are top-level expressions that call `replace-first`, `string-append` and `with-char-at` on
  `hash-pw-min`, outside any guard.
- **Evidence:**
  - AGENTS.md: "SRFI-64 does not catch an exception … in a suite's top-level definitions: the
    suite dies and no test is named". The plan's "Every brief restates these" repeats it: grep
    every top-level definition.
  - The suite's header claims the opposite (:7-10): "a library that cannot load fails every row
    that needs it by name".
  - Probe: `CHEZ_SODIUM_LIBRARY=/nonexistent/libsodium.so scheme … --program
    tests/test-password-verbs.sps` gave `exit=255`. The last line was `Exception in string-append:
    (unhashed "Exception in password-hash: library could not be reached …") is not a string`.
  - The builders' own log shows the same:
    - `r5-kib-as-bytes`: "exit 255, 0 pass, 21 fail";
    - `r15-order-pw-first-verify`: "exit 255, 0 pass, 37 fail";
    - `s-missing-export`: "exit 255, 0 pass, 25 fail".

    Under each of those mutants, R9, R15, R16, R18 and S never ran.
  - The same probe on `test-password-oracle` gives exit 1, with 8 failures named, as it should.
    `test-collect-safe` and `-passwords` override the library per child.
- **Fix:** build each R8 and R9 row's string inside its thunk, for example `(list name (lambda ()
  (replace-first hash-pw-min …)))`, or guard the lists. Then the `/nonexistent` probe names every
  row and exits 1.

---

## Minors

### M3S2-F3 (minor): `collect-probe` can hang for ever, leaving the process and its FIFO behind, if a collection fires between the marker and the watchdog's start

- **Where:** `tests/collect-probe.sps:203-208` (the marker poll, the 1 s pause, then
  `start-watchdog!`); `tests/test-collect-safe.sps:98-101`, where the child is spawned with no
  bound.
- **Evidence:**
  - After the marker, the control's thread is active in a plain C call, blocked on the FIFO.
  - If the main thread's allocation trips a collect request before the watchdog starts, the
    request's rendezvous waits for that thread. Nothing can open the FIFO, since the watchdog is
    not running yet.
  - A diagnostic copy, `hang/`, printed `(trip 8388608 poll 272 pause 80 watchdog 2192)`: about
    2.5 KB is allocated in the window, against an 8 MiB trip, so about 3·10⁻⁴ per control run.
    The same window opens under a plain-binding mutant.
  - Forcing a trip in the window (`FORCE_TRIP=1`, which allocates twice the trip before the
    pause) gave `control: rc=124 after 30s` under `timeout 30`. It left `blocking.fifo` and
    `blocking.fifo.entered`. `password-verify` under the same trip answered at once, released by
    the collector.
  - `capture-command` has no bound. `make test` and `test-memory` use `timeout --foreground`,
    which does not kill the suite's children: the suite is named HUNG, and the child stays blocked
    for ever.
- **Fix:**
  - start the watchdog before the fork, as a shell that waits for the marker, then 1 s, then
    10 s;
  - bound the child;
  - remove the directory on every exit path.

### M3S2-F4 (minor): the login path can raise on what the user types, and M4's list does not say so

- **Where:** `password-verbs.sls:120-129, 183`.
- **Evidence:**
  - `(password-verify h (make-string 65537 #\a))` is `(refused password-verify over-the-cap
    password (kind string))`: an assertion violation from a login form, not `#f`.
  - If a release ever raises `passwd_min`, an empty password at login becomes
    `length-out-of-range`.
  - Two more things a caller needs:
    - a stored hash with a trailing newline or space answers `#f` for ever, and
      `password-needs-rehash?` is never reached, so the user is locked out silently;
    - the calling thread's interrupts wait for the whole hash, about 55 ms at `'interactive` and
      seconds at `'sensitive` (ADR-0007, Consequences).
- **Fix:** three notes on the M4 list:
  - bound or catch the password before `password-verify`;
  - store the hash string exactly;
  - interrupts wait while a hash runs.

### M3S2-F5 (minor): more hashes at the default, and more non-minimum pairs, than the rule allows

- **Where:**
  - `test-password-verbs.sps:295-301`: R7 hashes twice at the default;
  - `:920-924`: R18's default sweep;
  - `:283-293` and `:337-344`: the pairs (2,16), (3,24) and (1,16).
- **Evidence:**
  - The rule: "one cheap pair that is neither the minimum nor a preset, and one hash at the
    default".
  - `r18-count/` printed `(fuels 7)` for the default sweep: 9 default hashes in all.
- **Fix:**
  - keep one default hash;
  - sweep `(password-hash "")` at the minimum instead;
  - use one non-minimum pair.

### M3S2-F6 (minor): three rows cannot fail against a wrong verb

- **Where:** `test-password-verbs.sps:827-830` ("a Password-limits is opaque"), `:534-536` ("the
  length range is libsodium's") and `:807-810`.
- **Evidence:**
  - Mutant `not-opaque/`: `(sealed #t)` → `(sealed #f)` and `(opaque #t)` → `(opaque #f)`.
    - The suite printed `# of expected passes 171`.
    - Its `forge.sps` printed `(record? #t)`, then `(raised password-hash ())`: standard
      `record-rtd` plus `record-constructor` built a `(1 1)` limits that skipped the ranges.
  - The real code is opaque: `(record? #f)`, and `record-rtd` is refused. Only Chez's internal
    `$record-type-descriptor` forges one. A `2^64` ops then raises from the foreign call inside
    the section, and the net raises it again after.
  - The row at `:534` reads only native's constants.
  - The row at `:807` checks a fixture's character count.
- **Fix:**
  - assert that `(record? limits)` is `#f`, and that `record-rtd` is refused;
  - delete or rename the other two rows as fixture checks.

### M3S2-F7 (minor): `password-hash` returns any ASCII string C left, even `""` or one the pre-check refuses

- **Where:** `password-verbs.sls:157-161`, with `foreign-ascii-string` answering `""` when `out[0]`
  is 0.
- **Evidence:**
  - Read from the code; no release or decoy switch reaches it.
  - Such a hash would be stored, then verify `#f` for ever.
- **Fix:**
  - treat an answer that fails `readable-hash-string?` as `(failed … 0)`;
  - optionally, a decoy switch that writes `""`.

### M3S2-F8 (minor): gaps in the mutation log

- **No entry:** plan §6's "row 10: the terminating 0 dropped, under the gate". Planted in
  `c-string-no-nul/`:
  - plain `-passwords` gave 9 failures, from the decoy's `p[L]`;
  - plain `test-password-verbs` gave 1, R3, by chance;
  - `valgrind -q --error-exitcode=9 … test-password-verbs` gave `rc=9`, with 18 errors such as
    `Conditional jump or move depends on uninitialised value(s) at … strlen`.

  So it is held; only the entry is missing.
- **F1's mutant** is missing.
- **The exit-255 results** above are recorded without saying that the suite died at top level.

### M3S2-F9 (minor): comments that do not match the code

- **`test-library-loading-passwords.sps:49`** says "runs 11 children". There are 13: eleven
  `verb-row`s and two `printed-lines`.
- **`password-verbs.sls:14-16`, item 2,** says a hash that "is not what password-hash would make
  now, is answered without … C". Stale limits do reach C; only a shape-check failure does not.
- **`test-password-verbs.sps:7-10`:** see F2.
- **`test-collect-safe.sps:109-111`:** `within?` is defined and never used.

---

## The eight questions

1. **The verbs against the plan and records.** They match, but for F7.
   - **The check order:**
     - `password-hash`: password type, cap and range, then limits;
     - `password-verify`: hash type, then the password's three checks, then the pre-check;
     - `password-needs-rehash?`: hash type, then limits.
   - **The irritants** are item 9's table exactly.
   - **The limits:**
     - a preset is native's pair, and a Password-limits is `(ops . (* 1024 kib))`;
     - the range is `ceil(min/1024)` to `floor(max/1024)`, which no row can tell, as the plan says.
   - **The answers:**
     - code 0 with no string is `(failed … 0)`;
     - any code but 0 is `&sodium-failed` from hash, `#f` from verify, and `#t` from needs-rehash;
     - a NULL prefix is `#t` without C;
     - the defaults are `'interactive`;
     - a changed string is `changed-during-call` from hash and verify, and `#t` from needs-rehash.
2. **Rows that cannot fail.**
   - F1 and F6.
   - Sound:
     - the other R18 sweeps, needs-rehash's included: `rehash-no-section/` gives 8 failures, three
       of them R18;
     - R16's differentials, in process and through `--describe`;
     - S1–S7 and the whole-body allow-list;
     - the `pwhash-limits-other` and `strprefix-null` rows;
     - row 19 and its control;
     - row 4 both ways;
     - the wipe child's whole lists.
3. **Secrets.**
   - Every refusal of a password or hash goes through `refuse-secret`. Limits are shown by
     `shown-value`, which shows a string by its kind.
   - The verbs make no Scheme copy, which the allow-list and S7 hold.
   - The probes print only fixtures, the decoy's hash, or a hash's 27-character prefix and its
     length.
4. **Sections, threads and engines.**
   - Nothing raises inside a section for any value a caller can make. Only limits forged with Chez
     internals can, and the net raises it again after the section.
   - No block is left live.
   - Row 19 is well within its bound; F3 is its one hazard.
   - The engine rows reference the library before their first engine, and `collect-probe` imports
     it before its fork.
5. **Techo.**
   - The login path raises on input over 64 KiB (F4).
   - No stored string makes needs-rehash raise.
   - Every limit libsodium accepts can be expressed, in whole KiB and at p=1.
   - A Password-limits cannot be forged with standard R6RS. It can be with Chez internals, at the
     cost only of a refusal of another shape.
6. **The gate and harness.**
   - Every Chez child goes through `gated-command` and asserts `valgrind-line`. The wipe children
     run outside the gate, by design.
   - The suite dies at top level in F2.
   - Every suite ends with its exit line, and each has at most 14 children: 13, 3 and 9.
   - Gate times: about 15, 70, 35 and 11 s.
   - `check-seam` passes.
7. **Comments and records.**
   - No milestone, slice, finding id or date appears under `src/` or `tests/`.
   - The signatures match.
   - The records agree with the code.
   - The stale comments are F9.
8. **For M3's closing review.**
   - F1's row.
   - The memory rounding, which no row holds: a decoy with `memlimit_min` 16385 would.
   - F7.
   - F3's window.
   - CI's gate times for the new suites, owed and not yet recorded.
   - The no-memory codes, still left to research.
   - The note on forging with Chez internals.
   - F4's notes.
