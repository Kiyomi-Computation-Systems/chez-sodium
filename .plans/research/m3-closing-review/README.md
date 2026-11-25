# M3 closing review: the password verbs, whole

**Reviewer:** Opus, read-only and adversarial.

**Tree:** `m3-slice-2` at `394cb8c`, clean. The reviewer read:
- `git diff cd64dc6..394cb8c` across `src/` and the M3 suites;
- the plan, the seven ADR amendments, the brief's §3.4, §4, §5, §6 and §8, the constraints, AGENTS.md
  and progress.md;
- all three slice reviews and both mutation logs;
- Techo's two briefs, in `../techo/.plans/briefs/`.

**Where the probes ran:**
- copies under `build/m3c-review/`: `base` and one beside it per mutant, each made with
  `shutil.copytree(..., symlinks=True)` of `src`, `tests`, `packaging` and `.plans/decisions`,
  with `build/scheme-libs` linked in for `test-never-loads`' child;
- through `scripts/guix-env`, with `--libdirs src:tests:../../scheme-libs`;
- the scripts `mutate.py`, `mutants.py`, `run-suites.sh` and `run-many.sh`, and the probes
  `base/probes/forge.sps`, `login.sps` and `oom.sps`;
- the profile's 1.0.22, and the floor at `build/slice5/prefix-1.0.18`, its headers first on
  `C_INCLUDE_PATH`;
- `make check-guix` on the host, which wrote only to `mktemp` directories, and read-only `gh run`
  calls.

No permission check was denied. No FIFO, marker or process was left behind.

**Counts: 0 blockers, 0 majors, 6 minors.**

**The caller's checks:**
- **F1:** reproduced. `round-max-ceil` passes `test-library-loading-passwords`, 23 of 23.
- **F5:** reproduced, with only the two call sites of `stop-watchdog!` replaced: the fixed suite's two
  verb rows fail, as the fix agent's did.

Each minor is fixed in the closing PR; its close-out says where. The owner chose F2's fix: a row
outside the gate.

**Where M3 is sound:**
- Of 22 mutants planted, 19 failed at least one row by behaviour. The survivors are F1's two
  rounding mutants and F5's.
- 18 M3-relevant suites pass at 1.0.22, and 11 at the floor.
- The M3S2-F2 fix's probe names all 172 rows, and exits 1.
- Forging a Password-limits with Chez internals raises only after the section, with no block left
  live.
- No secret reaches a condition or a Scheme copy.
- The login pattern works against the real library.

---

## Minors

### M3C-F1 (minor): no row holds the memory range's rounding, and the records do not state which way it rounds

- **Where:**
  - `src/chez-sodium/private/password-verbs.sls:71-72`: `least-kib` and `greatest-kib`;
  - plan §4.2 item 2: "no row holds the rounding";
  - ADR-0007's M3 amendment: "`_memlimit_min` / 1024 to `_memlimit_max` / 1024";
  - ADR-0009 decision 4, and brief §4.1: "divided by 1024".
- **Evidence:**
  - Mutant `round-max-ceil`, `(div pwhash-memlimit-max 1024)` → `(div (+ pwhash-memlimit-max 1023)
    1024)`, passed every row it ran:
    - test-password-verbs 172/172;
    - -passwords 23/23;
    - -verbs 15/15;
    - -password-entries 14/14;
    - test-native 110/110;
    - test-password-text 68/68.
  - Mutant `round-min-keep-plus`, `(+ pwhash-memlimit-min 1023)` → `(+ pwhash-memlimit-min 0)`,
    passed test-password-verbs, -passwords, test-native, test-conventions and test-collect-safe.
  - The floor mutant, `(div pwhash-memlimit-min 1024)`, failed only S6, by its source read.
  - `test-password-verbs.sps:111` computes `kib-min` with the code's own formula.
  - On a release whose minimum is not a whole KiB, a floored least would accept limits libsodium
    refuses. That would surface at the first login as `&sodium-failed`, not where the
    configuration is read.
- **Fix:**
  - a decoy switch with memlimit 16385 to 1048575 bytes, whose rows refuse 16 and 1024 KiB and
    accept 17 and 1023;
  - write "rounded up" and "rounded down" in ADR-0007's and ADR-0009's amendments, and in brief
    §4.1.

### M3C-F2 (minor): no row holds the no-memory codes brief §3.4 states, and the gap is recorded only in plan §6

- **Where:**
  - brief §3.4: "-1 … no memory";
  - brief §8.1 row 22: "every return code §3.4 states";
  - AGENTS.md: "Every return code the brief states is confirmed by a row…";
  - plan §1, and plan §6's slice 2: "row 22 leaves the no-memory codes to research";
  - "Owed to M4", where it is absent.
- **Evidence:**
  - None of `test-native-codes`' 31 rows runs under a memory limit, and no `ulimit` appears under
    `tests/`.
  - M4's fallback note for Techo rests on this code.
  - `probes/oom.sps` under `ulimit -v 524288` printed the same at 1.0.22 and at 1.0.18:

    ```
    (hash-interactive-ok answered)
    (hash-sensitive (failed password-hash "crypto_pwhash_str" -1))
    (verify-sensitive (answered #f))
    ```
- **Fix:** a child outside the gate, as the wipe children are, with two rows; or record the gap,
  and owe it to M4.

### M3C-F3 (minor): the records still describe shapes the slice reviews' fixes replaced, and miss rules the code now holds

- **The watchdog.** ADR-0011's amendment and plan §4.1 item 4 have the watchdog start "once the
  marker appears". Since M3S2-F3, `collect-probe` starts it before the fork, and the suite bounds
  each child with `timeout 180`. Only the close-out records this.
- **The no-copy row.** ADR-0012's amendment and plan §4.1 item 7 describe a deny-list. Since
  M3S1-F2 the rows are allow-lists.
- **ADR-0009 decision 3** still reads "limits out of range". `password-needs-rehash?` now raises
  `not-password-limits`, and `make-password-limits` checks the ranges.
- **The constraints omit ADR-0011's FIFO rules:** the read-write open, a FIFO and marker per call,
  a watchdog outside the process, and a bounded child.
- **The limits rule** allows "one cheap pair … and one hash at the default". Row 22 also hashes at
  (3, 8 KiB), (1, 32 KiB), (1, 64 KiB), (2, 16 KiB) and (2, 16 KiB + 1), each cheap and each
  needed for a code.
- **The tripwire.** `test-native-codes.sps:560` fails on any release but 1.0.18 and 1.0.22, for
  example `current` once its pin is bumped. Its comment says why; no record does.
- **Plan §2.2's row for `test-library-loading-passwords`** omits `pwhash-str-empty` and the
  rehash-change sweep.
- **Fix:** amend each of these.

### M3C-F4 (minor): M4's list misses hazards Techo's login will meet

- **Where:**
  - "Owed to M4", the notes from M3;
  - plan §3;
  - the login pattern, in ADR-0009 decision 6 and brief §4.2.
- **Evidence:** `probes/login.sps`, against 1.0.22:

  ```
  (login (logged-in 52))  (rehashed "$argon2id$v=19$m=65536,t=2,p=1$")
  (dummy-empty (#f 0))    (dummy-real (#f 49))
  (custom-limits-default-rehash? #t with-L #f)
  (nfc-vs-nfd #f)
  ```

  - **An unknown account:** a dummy hash that fails the pre-check answers in 0 ms, against 49 ms for
    a real one, so the time tells accounts apart. The dummy must be a real hash at the current
    limits.
  - **Custom limits** must go to both `password-hash` and `password-needs-rehash?`, or every login
    rehashes.
  - **No normalisation:** NFC and NFD forms of a password do not verify against each other.
  - **The rehash step** calls `password-hash`, which can raise `&sodium-failed` after a `#t`
    verify. A failed rehash need not fail the login.
- **Fix:** add all four to "Owed to M4" and to plan §3.

### M3C-F5 (minor): no row holds that the child kills the watchdog; `collect-probe`'s header overstates; it holds a mutex outside a critical section

- **Where:**
  - plan §4.1 item 4, and ADR-0011;
  - `tests/collect-probe.sps:22`: "it never outlives this process";
  - `:226, 240, 248`: `with-mutex`.
- **Evidence:**
  - Mutant `no-stop-watchdog` removes both `(stop-watchdog!)` calls. `test-collect-safe` still
    passed 8/8.
  - A child killed from outside leaves its watchdog polling for up to 90 s.
  - AGENTS.md: "Hold every mutex inside a critical section". It is harmless here: no engine runs in
    this child.
- **Fix:**
  - the child prints whether its watchdog's pid is gone, and the rows assert it;
  - correct the comment;
  - wrap the mutex uses.

### M3C-F6 (minor): comments that misdescribe the code

- **`conditions.sls:8-9`:** "&sodium-failed: libsodium answered a failure". Code 0 is also raised
  for no readable string.
- **`password-verbs.sls:27-28`:** "Every number a verb checks against is native's … None is written
  here". `input-cap` is cap's, and 1023, 1024 and `refuse-secret`'s 0 are written here.
- **`test-password-verbs.sps:9`:** "a library that cannot load fails every row that needs it by
  name". With no library, 16 rows pass. One of them, the no-pair row, passes on the fallback
  symbol `limits-failed`.
- **`test-password-verbs.sps:31-33`:** "each verb that holds a string … changed-during-call", where
  `password-needs-rehash?` answers `#t`.
- **Fix:** correct each, and have the no-pair row fail on `limits-failed`.

---

## The eight questions

1. **Done (plan §7).** Not yet, by process.
   - #16 is not merged, and the closing fixes are still to come. AGENTS.md says "M3 is under
     way", and Techo is not yet told the commit.
   - The caller's container checks hold.
   - `make check-guix` on the host printed "check-guix: ALL CHECKS PASSED", with 39 of 39 suites
     inside.
   - Row 22 falls short on the no-memory codes (F2).
   - M4's list lacks F2's codes, F1's row and F4's notes.
2. **Rows across slices.** Held by no row: F1's rounding, F2's codes, and F5's kill of the
   watchdog. The leads:
   - **code 0:** held by `pwhash-str-unreadable` and `pwhash-str-empty`, by behaviour;
   - **the twins:** held by `--constants` and the ranges rows;
   - **the prefix read at the load:** held by the presets, prefix and strprefix-null rows;
   - **row 22:** all 31 rows pass at both releases; the tripwire is unrecorded (F3);
   - **forging:** raises only after the section, with no block left live.
3. **Mutants.** 19 of 22 failed rows. The survivors are `round-max-ceil`, `round-min-keep-plus` and
   `no-stop-watchdog`.
4. **Secrets.** Sound.
5. **Sections, threads, engines and the gate.**
   - Nothing a caller can make raises inside a section.
   - No block is left live.
   - Every child is gated and asserts it, but for the recorded exceptions.
   - The hygiene gap is F5.
6. **Techo's login.** The pattern works, and fails safe. F4's four notes are missing.
7. **Records against code.** F1's rounding direction, and F3. The rest agrees.
8. **Comments.**
   - No milestone, slice, finding id, research path, date or "the maintainer".
   - Every export has its signature.
   - F6, and collect-probe's header (F5).
