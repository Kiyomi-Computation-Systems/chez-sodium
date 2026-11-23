# M0 closing review

Read-only and adversarial, on Opus, over the M0 plan and everything M0 built, before the first PR. Its
line numbers are those of the tree it read. How each finding was resolved is at the end.

Reviewer: read-only and adversarial. No project file was changed outside `build/review/`, and
that directory was removed at the end. Nothing was committed, pushed or installed.

Counts: **0 blockers, 2 majors, 11 minors.**

How the probes ran:
- **Mutation probes** ran in the container, from a copy at `build/review/tree`. The container
  could see the copy. Each probe made one exact replacement, checked to match once, through a
  scratch script. It ran the suite named and restored the file, and the restore was compared
  byte for byte.
- **Runner-difference probes** ran on the host, in the same copy. Only the host has what the
  runner has and the container lacks: `/bin/sh` is dash 0.5.11, `awk` is mawk 1.3.4 20200120,
  and no `CHEZ_SODIUM_LIBRARY` is set. Its Chez is Guix home's 10.4.0, threaded. This departs
  from AGENTS.md's "run every build and test through `scripts/guix-env`". It was deliberate,
  read-only, and only in the copy.

---

## Findings

### R-F1 (major): ADR-0006 says a hash string over the cap raises, and ADR-0007, ADR-0009 and the brief say it is answered

- **Where:** `.plans/decisions/0006-errors-and-no-secret-shown.md:49-50` (decision 5) and
  `:71-72` (Consequences, row 15); `.plans/global-constraints.md:86-87`.
- **Evidence:** ADR-0006 decision 5 reads: "A caller's mistake is an assertion violation, raised
  before C: a wrong type; a size, key length or limit out of range; an input over the cap
  ([ADR-0007]); an empty key." Its row-15 consequence reads: "each verb's ... inputs over the cap
  ... each raise `&assertion`". `global-constraints.md:86-87` copies the rule with no exception.
- **What contradicts it:**
  - the brief's edited §5: "an input over the cap, except a hash string, which is answered
    (§4.1)";
  - the brief's edited row 15: "other than a hash string (row 9)";
  - ADR-0007 decision 5 and ADR-0009 decision 5;
  - `global-constraints.md:104-106`, in the same file: "A hash string over the cap fails the
    pre-check instead".

  So two records, and two lines of the constraints file, disagree on an owner decision.
- **Fix:**
  - In ADR-0006 decision 5, after "an input over the cap", add "except a hash string, which
    fails the pre-check and is answered ([ADR-0009])".
  - In its row-15 consequence, add "other than a hash string (row 9)".
  - Give `global-constraints.md:87` the same exception.

### R-F2 (major): no record or constraint says the cap counts bytes, with a string counted in UTF-8 bytes

- **Where:**
  - `.plans/decisions/0007-one-critical-section-per-verb.md:38-40` (decision 5);
  - `.plans/global-constraints.md:104-106`;
  - `.plans/decisions/0009-what-needs-rehash-means.md:55` ("within the cap").
- **Evidence:**
  - The brief's edited §4.4 says: "at most 64 KiB (§11.5), counted in bytes: a string counts its
    UTF-8 bytes." This is an owner decision.
  - ADR-0007 settles §4.4 and §11.5's cap, yet says only "Every byte or string input, and
    `random-bytes`' output, is at most 64 KiB."
  - `global-constraints.md:104` says the same.
  - `grep -n 'UTF-8' .plans/decisions/0007* .plans/global-constraints.md` finds no line about
    the cap.
- **Why it matters:** a cap counted in characters would let a 64 Ki-character non-ASCII password,
  up to 256 KiB of UTF-8, into a section sized for 64 KiB. AGENTS.md warns of this mistake in
  its rule on non-ASCII text.
- **A constraint the fix should carry:** the count cannot come from `string->utf8`.
  - That makes the Scheme bytevector copy of the password that ADR-0008 decision 3 forbids:
    "no Scheme bytevector holds it".
  - So the count is summed from each character's UTF-8 length.
- **Fix:**
  - Add "counted in bytes: a string counts its UTF-8 bytes, summed from its characters, with no
    `string->utf8`" to ADR-0007 decision 5 and to `global-constraints.md:104`.
  - Name the non-ASCII row that must hold it, for example a 2-byte character at
    32 Ki + 1 characters.

### R-F3 (minor): `global-constraints.md` widens ADR-0011's child rule, and `test-counters` breaks the wider form

- **Where:**
  - `.plans/global-constraints.md:174-176`;
  - `.plans/decisions/0011-the-harness-after-chez-sqlite3.md:39-42`;
  - `tests/test-counters.sps:202-226`.
- **Evidence:**
  - The constraints file says "A child that runs chez-sodium's code runs under the gate's own
    Valgrind, with its own log."
  - ADR-0011 decision 1 says instead "every suite that starts a child that reaches native code
    starts it through `gated-command`."
  - `test-counters` starts a Chez child that imports `(chez-sodium private counters)`, which is
    chez-sodium's code. It starts the child with `capture-command`, not through
    `gated-command`.
  - After the tree's own gate run, `build/memory/test-counters.children/` is empty. The child ran
    outside Valgrind.
  - The record wins, as the constraints file's header says, and the child reaches no FFI. So
    nothing is uncovered today, but the file that binds every task brief states another rule.
  - chez-sqlite3 has the same gap. Its global constraints say "The rule covers a child that runs
    chez-sqlite3's code", and its `test-counters` child is not gated either.
- **Fix:** do one of these.
  - Reword `global-constraints.md:174` to ADR-0011's "reaches native code: loads libsodium or
    calls a foreign procedure", and name pure-Scheme children as outside it.
  - Or start `test-counters`' child through `gated-command`. It costs about 5 s under the gate.

### R-F4 (minor): the critical section in the counters' `locked` has no row, and its mutation survives

- **Where:** `src/chez-sodium/private/counters.sls:103-105` (the claim) and `:137-138` (the
  code); `tests/test-counters.sps`.
- **Probe:**
  - Guard: every count is read and written inside a critical section, "so no interrupt that
    escapes can leave the mutex held".
  - Mutation: `(critical-section (with-mutex lock (thunk)))` becomes `(with-mutex lock (thunk))`.
  - Result: **SURVIVED.** `test-counters` printed "# of expected passes 13", with no failure.
- **Why it matters:**
  - The harness mutation log's C2 dropped the mutex, not the section.
  - Its "Not mutated" list does not name this rule. AGENTS.md says "Prefer a check to a comment".
  - The failure mode is a mutex left held, which then hangs another thread. That window is
    reachable from an engine. M1's row 18 runs every verb under engines, and the verbs count
    blocks.
- **Fix:** do one of these.
  - Add a row: `count-up!` then `count-down!` under an engine at each fuel from 1 until it
    completes, abandoning the engine at each expiry. After each, another thread's
    `count-up!`/`count-down!` must finish within a bound.
  - Or record the rule under "Not mutated" with the reason.

### R-F5 (minor): `require-threaded`'s header says critical sections need a threaded Chez, and they don't

- **Where:** `src/chez-sodium/private/require-threaded.sls:5-8`.
- **Evidence:** the header reads: "chez-sodium uses Chez's thread system: the counters' mutex
  (ADR-0011), and each verb's critical section (ADR-0007). Chez builds it only into threaded
  builds."
  - Chez 10.4.0's source at
    `/gnu/store/s39m…-chez-scheme-10.4.0-checkout/s/primdata.ss` declares
    `(make-mutex [feature pthreads] …)` at line 1540 and `(with-mutex [feature pthreads] …)` at
    line 1138.
  - It declares `(critical-section [flags])` at line 1063, with no feature. `s/syntax.ss:8123`
    defines it as a `dynamic-wind` around `disable-interrupts`, which every build has.
  - The comment also speaks of verbs, which M0 does not have.
  - Brief §11.6's deciding reasons are `make-mutex` and Techo's worker threads.
- **Fix:** "chez-sodium uses Chez's thread system: the counters' mutex (ADR-0011), and the
  worker threads Techo hashes on (ADR-0004)."

### R-F6 (minor): comments that describe code M0 lacks as if it exists

Each was found by grep:

- **`src/chez-sodium/private/counters.sls:17-18`:** "the exit checks a library that loaded
  libsodium registers". Also `:95-98`: "the library that loads libsodium registers its check
  once the load has succeeded". No library loads libsodium, and `progress.md` says M1 may remove
  the checks.
- **`tests/chez-sodium-testing.sls:58-60`:** "only a library that loaded libsodium registers one".
- **`Makefile:261-262`:** "every one must be refused, the public (chez-sodium) among them". There
  is no `(chez-sodium)`. `tests/check-nothreads.sps:13-14` gets this right: "(chez-sodium) is
  checked ... when it arrives."
- **`manifest.scm:9-12`:** "gcc-toolchain compiles the test-time programs that check constants
  and signatures against that header". M0 has none; `test-constants` is M1's. The comment also
  cites ADR-0003, the floor, for the manifest, which is ADR-0011's decision 2.
- **`packaging/debian-prereqs.txt:25`:** "It also builds the memory gate's C oracle". M0 has no
  oracle. `build-essential` builds case q's C plant in `check-memory-gate.sh`, which is named
  `libsodium-oracle` only so that the gate's child rule can be tested.
- **`packaging/debian-prereqs.txt:38`:** "libsodium23, the library the suites load". No M0 suite
  loads it.
- **`tests/check-memory-gate.sh:506`:** "A C program named as the suites' oracle is".

**Fix:** say what M0 has: "registers, once a library loads libsodium (M1 decides)", "the public
library, when it arrives", "case q's C plant", "report-sodium.sh's program". Comments may not
name milestones, so where a milestone is needed, say "when it arrives" instead.

### R-F7 (minor): leftovers from chez-sqlite3

- **`Makefile:8-9`:** keeps the fallback `$(if $(shell command -v chez …),chez)`. Its reason,
  "the name Homebrew installs it under on macOS", was trimmed from the comment, but the macOS
  code path stayed. ADR-0010 says "no macOS or Windows code paths". Drop the `chez` arm, or give
  it a Linux reason.
- **`tests/test-check-floors.sps:1869-1870`:** "Homebrew's Chez on macOS is .../bin/chez."
- **`tests/fixtures/floors/workflow-other-floor/`:** `floors.sexp` gives `(sodium "3.46.0")`, and
  its `ci.yml:11` echoes `3.46.0 3.45.1`. `workflow-other-version/workflows/ci.yml:11` echoes
  `3.45.1`. Those are SQLite's numbers. They are harmless as data, but `8.1.x`, as the other
  fixtures use, reads as this project's.
- **`Makefile:267-268`:** a sentence was broken in the trim: "CI runs it on a Chez built with
  --nothreads" is followed by a line that starts "#. It imports only". chez-sqlite3's text was
  "(.github/workflows/ci.yml). It imports only". Restore the parenthesis, or end the sentence.

### R-F8 (minor): a test name carries a milestone

- **Where:** `tests/test-check-ci.sps:955`.
- **Evidence:** the row is named "main runs make build, which M0 has none of: it is no step
  check-ci reads".
  - What the row does is replace the make line with `run: make build`. It expects the make line
    to be missing.
  - So the name will be false at M1, and it carries a milestone, which AGENTS.md keeps out of
    `tests/`.
- **Fix:** "main's make line replaced by make build: it is no step check-ci reads".

### R-F9 (minor): the ledger and the pointers are slightly stale

- **`.plans/progress.md:14`:** "`make test` runs six suites". It runs seven: `test-check-ci` came
  with the CI step. The host run printed "test: ran 7, passed 7"; the CI log says "ran 7, passed
  7".
- **`AGENTS.md:10`:** "its §10 lists the questions still open". The edited §10 now reads "Nothing
  is open." Say "its §10 records that nothing is open, and what was settled."
- **`.plans/2026-11-22-m0-plan.md:5`:** still says "Status: draft." Mark it as built, pending CI
  and this review.

### R-F10 (minor): two records credit their decisions to the wrong source

- **`.plans/decisions/0004-a-threaded-chez.md:6-7`:** "The floor, 10.4.0, is the one the M0 plan
  writes into `floors.sexp`". The brief's edited §11.6 now decides "A threaded Chez, 10.4.0 or
  later". Cite §11.6 for the floor.
- **`.plans/decisions/0003-libsodium-floor-1-0-18.md:3-4`:** "Decisions 4 to 6, the versions
  tested, are brief §11.5". Decision 6, the point-release tarball and its `.minisig`, is brief
  §7.2 (P-F16), not §11.5.

### R-F11 (minor): brief rules that no record or constraint carries

- **Brief §4.3**, which no record settles. The M0 plan §4 maps none to it. Its rules are the ones
  C will not enforce:
  - `blake2b`'s size runs from `_bytes_min` to `_bytes_max` (16 to 64), checked before C, since C
    accepts 1 to 15 (P-F9);
  - the default size is `crypto_generichash_bytes()`;
  - a key runs from 16 to 64 bytes;
  - `random-bytes 0` answers `#vu8()` without calling C;
  - `constant-time-bytevector=?` answers `#f` on different lengths without calling C, and passes
    the whole length to `sodium_memcmp`.
- **Brief §7.2's decoy rule:** a decoy logs each pointer through a `volatile uintptr_t` (P-F7).
  AGENTS.md carries it, but no record or constraint does.
- **Fix:** a "Verbs" block in `global-constraints.md` that cites the brief for §4.3's ranges.
  Otherwise, leave M2's plan to restate them, and say so in `progress.md`.

### R-F12 (minor): `global-constraints.md` omits record rules

- **ADR-0002 decision 6:** "`not-found` lists every candidate it checked." This is not at
  `global-constraints.md:78-79`.
- **ADR-0011 decision 1:** "The C oracle is a program named `libsodium-oracle`. The gate's rule
  for child logs names it." It is only in `progress.md`.
- **ADR-0002 Consequences and ADR-0003 decision 5:** "`main` asserts that it loaded the floor."
  No constraint says what `main` must assert.
- **Fix:** one line each, under "Loading libsodium" and "Memory and CI".

### R-F13 (minor): comment lines that edits left unwrapped

- `AGENTS.md:70` (109 columns) and `tests/check-test-fails.sh:46` (119).
- `tests/chez-sodium-testing.sls:161` (104) and `:354` (105).
- `tests/chez-sodium-testing.sls:20`: a bare blank line inside the header comment. chez-sqlite3
  has `;;;` there.
- **Fix:** rewrap to the files' width.

---

## Probes, each as guard, mutation, result

| # | Guard | Mutation | Result |
|---|---|---|---|
| 1 | `counters`' `locked` holds a count inside a critical section | `(critical-section (with-mutex lock (thunk)))` to `(with-mutex lock (thunk))` | **SURVIVED**: `test-counters` 13 passes, 0 failures (R-F4) |
| 2 | every library under `src/` imports `require-threaded` first | `counters` imports `(rnrs)` before `require-threaded` | KILLED: `test-require-threaded` fails "src/chez-sodium/private/counters.sls imports (chez-sodium private require-threaded) first" |
| 3 | a pre-release of the floor is refused | `((or (older? have minimum) pre)` to `((older? have minimum)` | KILLED: 6 pre-release rows fail |
| 4 | `Akku.manifest`'s version is the changelog's latest, or 0.0.0 | `"0.0.0"` to `"0.0.1"` | KILLED: "Akku.manifest's version is CHANGELOG.md's latest release, or 0.0.0 with none" |
| 5 | `check-ci` refuses a top-level key outside its five; a `defaults: run: shell:` would make every run step a no-op | a top-level `defaults:` with `run: shell: true {0}`, run on the host | KILLED: `top-level key "defaults" is not one of name, on, permissions, concurrency, jobs`, plus the flow-mapping rule; exit 1 |
| 6 | the gate's children run under Valgrind | read only: the tree's `build/memory/test-counters.children/` after the gate's run | empty: `test-counters`' Chez child ran outside Valgrind (R-F3) |

### CI's first run

| Probe | Result |
|---|---|
| `sh tests/check-ci.sh .github/workflows`, dash and mawk | passes |
| `make test`, dash, mawk, no `CHEZ_SODIUM_LIBRARY` | `ran 7, passed 7`; `check-suites` 7 checked; `check-floors` and `check-ci` pass |
| `make check-test-fails check-clean` | all 12 cases pass; `check-clean` ok |
| `sh tests/guix-env-launcher.sh` with `CHEZ` set, as `main`'s last step | 82 passed, 0 failed |
| `dash -n` on every shell script | 14 of 14 parse |
| `scripts/ci/report-sodium.sh` under dash, against the host's `libsodium23` 1.0.18 (`.so.23`), with a stand-in 1.0.18 header | exit 0; prints the package and `1.0.18` twice |
| `make test-memory MEMORY_SUITES=tests/test-check-ci.sps` in the container: the slowest suite, 359 rows | `time: 50s under the gate, within 450s`. chez-sqlite3's runner ran its 439-row suite in 84 to 177 s, so `SLOW` is far off |
| `check-ci.sh`'s awk regexes, for runner mawk 1.3.4 20240123, which reads `{n}` as an interval | none holds a `{`; only two `grep -E` lines use intervals |
| `check-nothreads.sps`'s imports, against `[feature pthreads]` in Chez's `primdata.ss` | none is threaded-only, so it runs on the `--nothreads` Chez |

What runs unchanged from chez-sqlite3 v0.1.1, whose CI was green on the same runner, needs no
probe here:
- `test-memory`'s Valgrind `default.supp` question and evidence awk (the Makefile diff shows no
  change);
- the action SHAs, `build-chez.sh`'s pinned sum and the cache keys;
- the checkout of chez-srfi from `https://github.com/arcfide/chez-srfi.git` at `7879b52`.

Two things no probe can settle off GitHub: the Valgrind 3.22 markers in `check-memory-gate`'s
case b, and the build of `--nothreads` Chez. Both are as chez-sqlite3 ran them.

---

## Checked and found sound

**1. The records against the brief.**
- **ADR-0001:** §2, §3.4, §6.1 and §6.4. Every §6.1 row is a decision, and §3.4's "what this
  changes" is carried.
- **ADR-0002:** the override, the worlds, which match chez-sqlite3 ADR-0002's list, the sonames,
  the order of the load and the six reasons.
- **ADR-0003:** the floor from the version string, major and minor reported only, the §8.3
  matrix, and the tarball, minisig and `releases/old/`.
- **ADR-0004, ADR-0005 and ADR-0006:** sound apart from R-F1. The secret list matches the edited
  §5 and AGENTS.md.
- **ADR-0007:** sound apart from R-F2.
- **ADR-0008:** the placement and reach of the wipe, and no Scheme copy.
- **ADR-0009:** all four of §4.2's `#t` cases, and the KiB limits. The pre-check sets no
  `strbytes` limit.
- **ADR-0010.**
- **ADR-0011:** M0's shape, one memory job, `default.supp` alone, the gate's child variable, the
  pin and the manifest.
- **`global-constraints.md`:** every rule cites a record that holds it, apart from R-F1, R-F2,
  R-F3 and R-F12.
- **The brief's uncommitted edits:** §4.4, §5, row 15, the `current` row of §8.3, §9's Later
  row, §10 and §11.6 to §11.8. They agree with each other and with AGENTS.md's edits.

**2. Checks that cannot fail.**
- The three mutation logs were read whole. Probes 2 to 5 were killed.
- The CI log's mutation coverage is thorough: 167 mutant rows across `check-ci.sh`, `floors.sls`,
  `check-floors.sps`, the Makefile and `scripts/ci`, with the survivors closed or shown
  equivalent.
- `check-test-fails`' 12 plants each guard their own plant: a `cmp` shows each changed the file,
  and the floor is read from the file.
- `test-require-threaded` holds the order of imports and the floor of the file, and probe 2
  confirms it.

**3. CI's first run.**
- No blocker was found. The probes are in the table above.
- `report-sodium.sh` and its packages are right for Ubuntu's `libsodium-dev` and `libsodium23`.
- The scripts keep their execute bits: every script that a step runs as `scripts/ci/…` is
  mode 755, and `core.fileMode=true`.
- The submodule URL is public HTTPS.

**4. Leftovers.**
- No `CHEZ_SQLITE3`, `sqlite`, `cmark` or `pages.yml` is left outside deliberate test rows. Those
  rows hold that a shard variable and a second workflow are refused.
- `check-memory-gate`'s mention of shards is a "none".
- The `chez-curl` URLs in `test-manifest` are deliberate rows for another repository.
- No rule guards a file M0 lacks.

**5. The comment rule.** Outside R-F6 to R-F8, no comment holds a milestone, slice, date, research
path or "the maintainer". The `M1` and `M2` labels in the launcher are case names, as the brief
says.

**6. The ledger and the pointers.**
- Everything M0 plan §1 promises is in the tree: the 11 records, the ledger files, two libraries
  under `src/` and 7 suites.
- The `.PHONY` targets equal plan §2's list.
- The three deferrals in `progress.md` match plan §3.

**7. The libraries in `src/`.**
- `counters`:
  - nothing raises inside `locked`;
  - `count-down!` raises after the section;
  - `kind-index` and `register-exit-check!` refuse before the lock;
  - no exported variable is assigned;
  - every export has a Typed Racket style signature;
  - `require-threaded` is imported first.
- `require-threaded` raises at expansion and exports nothing.
- Neither library holds an FFI form.
- The counters' suite against AGENTS.md's testing rules:
  - every refusal is compared by who and irritants, against a `no-raise` sentinel;
  - no expected value is `#f`;
  - its top-level child is under a `guard`;
  - `let*` orders its effects, and the `map`s it uses are pure;
  - its threads make their raises answers, and its wait is bounded by `run-until`;
  - it ends with the shared exit form.

---

## Resolution

Each finding was checked against the tree before it was fixed.

| Finding | Resolution |
|---|---|
| R-F1 | ADR-0006 decision 5, its row-15 consequence and `global-constraints.md` now give the hash-string exception. |
| R-F2 | ADR-0007 decision 5 and `global-constraints.md` count the cap in bytes, with a string counted in UTF-8 bytes summed from its characters, never through `string->utf8`. ADR-0007's consequences name the non-ASCII row. |
| R-F3 | `global-constraints.md` now states ADR-0011's rule: a child that reaches native code starts through `gated-command`, and a Scheme-only child such as `test-counters`' is outside it. |
| R-F4 | Reproduced first: the mutant without the section left the mutex held at fuel 5, and the real code completed at fuel 6 after 5 expiries. `test-counters` gained the critical-section row, which kills the mutant (harness mutation log, C5). |
| R-F5 | Reproduced in `primdata.ss`: only `make-mutex` and `with-mutex` carry `[feature pthreads]`. The header now names the mutex and the callers' worker threads. |
| R-F6 | Each comment now says what M0 has. |
| R-F7 | The Makefile's `chez` arm and the Homebrew comment are gone. The fixtures' SQLite numbers are now libsodium's: `3.45.1` became the real floor `1.0.18` and `3.46.0` became `1.0.19`, 15 replacements as predicted. The broken sentence is restored. |
| R-F8 | The row is renamed. |
| R-F9 | `progress.md` says seven suites. AGENTS.md says §10 records that nothing is open. The plan's status says it is built and reviewed. |
| R-F10 | ADR-0003 credits decision 6 to §7.2, and ADR-0004 credits the floor to §11.6. |
| R-F11 | Owed: M1's plan restates the decoy's pointer rule, and M2's plan restates §4.3's ranges (`progress.md`). |
| R-F12 | `global-constraints.md` gains `not-found`'s candidate list, `main`'s assertion of the floor, and the oracle's name. |
| R-F13 | Rewrapped, and the stray blank line inside the testing library's header is a `;;;` line again. |
