# M1's closing fixes: the second review

Read-only and adversarial, on Opus, over the uncommitted fixes on `m1-closing`, over `main` at
`49e7e3b` (`git diff`, `git status --short`). Line numbers are the working tree's.

- **No project file was changed.** Nothing was committed, pushed or installed, and nothing was
  written under the checkout's `build/`. `git status` at the end matches the one at the start.
- **Every probe ran in a copy,** `<scratch>/review-m1fix/tree` (rsync without `.git`, `build`,
  `.claude`), or in the scratchpad. Container probes ran through the copy's `scripts/guix-env`;
  `check-ci.sh` and the trap probe ran on the host, with mawk 1.3.4 and dash.
- **`gh` was used read-only:** `run list`, `run view` (jobs and steps, attempts 1 and 2),
  `pr list`, `pr view --json body`.
- **No command was denied.** No subagent was used.
- **Not redone,** as the brief says: the builders' suite runs, the `if:` rule on the image step,
  and the full join.

**Counts: 0 blockers, 5 majors, 7 minors.**

**Verdict:** the code changes are sound but for one unheld line (R2-F1). The records need work
before merge:

- two false statements went into rules and records (R2-F2, R2-F5);
- a constraint was added with no decision record behind it (R2-F3);
- the ledger records nothing of the closing PR itself (R2-F4).

R2-F2 and R2-F3 touch the owner's records.

---

## Findings

### R2-F1 (major): `check-ci` now holds the image step, but not its use in the five Chez cache keys

- **Where:**
  - `tests/check-ci.sh:281-285`, `keyok`: a Chez restore key is the prefix and the `hashFiles`
    list, then "nothing or a `-` and more";
  - the rule's own header, `tests/check-ci.sh:64-69`: the step "names the runner's OS release
    and architecture in the caches' keys";
  - the claim M1-F4 set out to hold, `.github/workflows/ci.yml:68-71`: "Every Chez cache is keyed
    by … the runner's OS release and architecture".
- **Evidence** (host, mawk, copies of `ci.yml`):

  | Mutation | check-ci |
  |---|---|
  | control, the real file | passes |
  | `-${{ steps.image.outputs.id }}` deleted from all five Chez restore keys (2 references left, both lanes' libsodium keys) | **passes** |
  | `main`'s Chez key tail made `-ubuntu` | **passes** |

  - Builder A's 17 mutants all turn off the step's rules. None touches a key.
  - The libsodium keys are held whole (`sodkey`), so only the Chez keys are open.
  - With the tail deleted, every job still runs a well-formed image step that feeds no Chez key.
    That is M1-F4's C1 result ("keys left reading an empty id") by another route.
- **Impact:** low, as M1-F4's was. The id is `ubuntu-24.04-X64` while `runs-on` is held, and
  `check-chez.sh` checks whatever is restored. Still, a comment claims what nothing checks.
- **Fix:**
  - Hold the Chez restore key whole, as `sodkey` is:
    `prefix[job] "${{ hashFiles(" HASHLIST ") }}-${{ steps.image.outputs.id }}"`. Its message
    becomes "is not exactly …".
  - Add rows per job: the tail deleted, and the tail naming another step's id. Watch them fail.
  - The existing key rows' messages change with it.

### R2-F2 (major): ADR-0007 and `traps.md` now say "the count moves between runs", which measures false

- **Where:**
  - `.plans/decisions/0007-one-critical-section-per-verb.md:110-114`: "the count moves between
    runs, and the edge, the section's start, does not";
  - `.plans/traps.md:51-53`: "the count moves between runs, and the edge does not".
- **Evidence:**
  - **Three reruns, in the container, of the committed probe:**
    `engine-section.sps engsect pre|post`, from `research/m1-plan/` in the copy.
    - Each answered "abandoned at expiry 45158" (wedged) and "45159" (`((body-ran 1) 1)`).
    - That is identical to `run-engine-section.out`, three runs of three.
  - **The slice-0 figure comes from another program.** Slice 0's review measured
    44,209 to 44,219 with its own `sweep.sps LIB FUEL N`, over `lib/rv/sect.sls`
    (`research/m1-slice-0-review/README.md:113-114`).
    - That program is not committed.
    - The two drivers differ: N slices against a flag, and a different library and reference.
    - So the count moves between the programs, not between runs.
  - **The committed run cannot show the "11 ticks".** Its pre-flag is set just before the
    section, so one expiry, 45,158, falls between the pre-flag and the flag.
- **Fix:** the owner's wording. For example: "… (slices 44,209 to 44,219 at fuel 1, in slice 0's
  review's own sweep). The committed run, a different program, puts the same edge at expiries
  45,158 and 45,159, in every run: the count depends on the program; the edge, the section's
  start, does not." Make the same change in `traps.md`.

### R2-F3 (major): the thread rule sits in the constraints with no decision record behind it

- **Where:** `.plans/global-constraints.md:141-144`, citing `.plans/traps.md`. Also
  `AGENTS.md:224-228`.
- **Evidence:**
  - **The constraints' preamble** (`:3-4`): "The hard rules from the decision records … Each
    rule cites the record it comes from, and where a rule and its record disagree, the record
    wins."
    - Every other bullet cites an ADR, or a chez-sqlite3 record.
    - This one cites a trap, so it has no record to win.
  - **The repository's own pattern.** A trap's rule with no ADR lives in AGENTS.md and
    `traps.md` alone. "Hold every mutex inside a critical section" is one such rule; it is not in
    the constraints.
  - **The owner's decision is recorded nowhere.** On 2026-11-23 the owner decided "M1-F4 and
    M1-F10: build both rule changes in this PR". No record names that decision. The engine rule
    beside this one comes from ADR-0007, amended, with its acceptance.
- **Fix:** either of these (the owner's choice):
  - an ADR-0007 amendment, "2026-11-23: the first reference on two threads", accepted by the
    owner, with the constraint cited as `[ADR-0007], amended`. Use R2-F5's wording in it;
  - or drop the bullet from the constraints, and keep AGENTS.md's and `traps.md`'s, as the mutex
    rule is kept.

### R2-F4 (major): the ledger calls M1 done through #8, and records nothing of the closing PR

- **Where:** `.plans/progress.md:11-17`, and no close-out above slice 5's.
- **Evidence:**
  - **"M1 is done and merged (PRs #3 to #8 …)".** Plan §7 makes M1 done only when the closing
    review's majors land, which is this PR, still unopened (`gh pr list`: #8 is the newest). Once
    it merges, the sentence names the wrong range.
  - **"Each is fixed in the closing fixes' own PR".** That is not yet true:
    - M1-F4 is half held (R2-F1);
    - M1-F5's "record it in the PR" waits for the PR's body.
  - **No close-out records the closing PR.** That leaves out:
    - the owner's three decisions of 2026-11-23;
    - who built what, and on which model;
    - the 70 new `test-check-ci` rows, the 2 new rows of F6 and F7, and the red-first runs;
    - this review.
  - **The fixes' mutation evidence is only in the scratchpad:**
    - `m1fix-ci-log.md`, with 17 mutants of the two new `check-ci` rules;
    - `m1fix-tests-log.md`, with f6a, f6b and f7a.

    Every slice's log is committed as `.plans/m1-slice-N-mutation-log.md`. A cleanup can clear
    the scratchpad: that is M1-F12's trap, repeated in the PR that fixes it.
  - **A reproduction no file holds.** `.plans/traps.md:88-91` cites one "again at the fixes, on
    a toy library in the container", and no committed file holds it.
- **Fix:**
  - **A close-out,** "2026-11-23 — M1's closing review and its fixes (PR #9)", newest first,
    with the items above.
  - **The two logs,** committed as `.plans/m1-closing-mutation-log.md`.
  - **This review,** committed beside the first, as the slice reviews are.
  - **The Now,** naming the closing PR.
  - **The trap,** citing the committed probe (or this review's, below).

### R2-F5 (major): "A critical section blocks only its own thread" is false, and contradicts AGENTS.md's own rule

- **Where:**
  - `AGENTS.md:226`;
  - `.plans/global-constraints.md:143-144`;
  - `.plans/traps.md:82-83`.

  Against `AGENTS.md:229-231`: "a handler of the raise runs with interrupts disabled, and another
  thread's collection waits".
- **Evidence** (container, toy library `(toy slow)`):
  - **The setup.** The library's whole body is one `critical-section` that spins about 360 ms
    with no allocation. A forked thread `eval`s a reference at 0 ms, and the main thread at
    100 ms.
  - **The main thread, not allocating:** `(raised "cyclic dependency involving invocation of
    library ~s")` at 100 ms, then later `ready`. The window is not narrowed, so the rule's
    conclusion holds.
  - **The main thread, allocating first:** 3 million small vectors, which take 23 ms and 35
    collections alone. It stalled from 100 ms to 381–386 ms, until the other thread's section
    ended, and then answered `ready`, not the error. Three runs of three.
  - **So a section stalls every thread that needs a collection, and the stall can hide the
    race.** A row that tries to show the trap can pass by luck.
- **Fix:** "A critical section defers only its own thread's interrupts. Another thread that
  reaches the library meanwhile is refused, unless it needs a collection first: that waits for
  the section to end, and then the reference answers. So the window is the whole body." Write it
  in all three places, and in R2-F3's record if one is made.

### R2-F6 (minor): `test-never-loads`' new import kills the whole suite, naming no test, if `(chez-sodium)` fails to expand

- **Where:** `tests/test-never-loads.sps:58-62`, the import `(only (chez-sodium))`.
- **Evidence:**
  - **The import itself is sound.** It runs no body: a probe with that import listed 8 exports
    and mapped no libsodium.
  - **The mutant.** A copy whose `(chez-sodium)` exports an unbound name.
    - The new suite exits 255 at import: "missing definition for export …". No row runs.
    - `main`'s suite runs its 5 data rows, and fails the two children by name.
  - **The rule it breaks.** AGENTS.md: a raise outside a guard "the suite dies and no test is
    named. Compute anything that can raise under a guard".
  - **The alternative works.** `(guard … (environment '(chez-sodium)) (library-exports
    '(chez-sodium)))` lists the 8 exports (probed). Without it, the guard catches "library ~s is
    not loaded".
  - **A smaller point.** The child's `(define referenced (map pub '(…)))` is `map` used for its
    effects. No assertion depends on the order, but AGENTS.md says `for-each` for effects.
- **Fix:**
  - Drop the import, and load the library inside `condition-names`' guard with `environment`.
  - Write the child's references with `for-each`.

### R2-F7 (minor): the allow-lists are still described the old way next to ADR-0001's amendment

- **Where:**
  - `tests/foreign-conventions.sls:12-15`: "exactly the types the table uses as arguments, and as
    results with void";
  - `:102-105`: "Each is exactly the types the table writes there";
  - `.plans/global-constraints.md:71-73`: "The allow-lists are exactly the types the rows use
    ([ADR-0001])", not marked amended;
  - ADR-0001 `:90-92`, the amendment's first bullet.
- **Evidence:**
  - **The code comments.** Read literally, `int`, which no row takes as an argument, does not
    belong in `(int uptr size_t)`. That is the reading M1-F9 fixed in the ADR. The M2 builder
    edits this file.
  - **The amendment's first bullet.** "… so a type no row uses would be refused there, and the
    lists would pass with a type allowed that nothing binds" runs two cases together.
- **Fix:**
  - **The comments:** the amendment's rule. The argument list is every type a row uses as an
    argument or a non-void result; the result list is every result type, and `void`.
  - **The constraint:** cite `[ADR-0001], amended`, and state the same rule.
  - **The bullet:** "Kept, v0.1.1's rows refuse a list that allows a type no row uses, so
    `size_t` among the results fails them; dropped, the lists could allow a type nothing binds."

### R2-F8 (minor): `progress.md`'s owed lists are already stale against the fixes

- **Where and fix:**
  - **`:77-78`, M2:** "Scope `global-constraints.md`'s rule-symbol line … (M1-F8)". It is done
    in this PR (`global-constraints.md:106-107`). Delete it.
  - **`:105-106`, M3:** "today its names are written by hand (M1-F6)". F6 is fixed. Say instead
    that M3's names join `checked-names` and the child's lines, and that the export row fails
    until they do.
  - **Add to M2:** M2's three verbs join `verb-names` (`test-never-loads.sps:330`). The same row
    fails by name until they do.
  - **`:108-109`, M3:** "Row 19's threads reference the library once before the first fork".
    Threads can't act before they exist. It should read "Row 19 references the library once
    before its first fork".
  - **`:44-45`, "Answered for M1":** "a refusal's irritants lead with the rule's symbol". That is
    the wide reading M1-F8 just narrowed. It should read "a caller's mistake's refusal".

### R2-F9 (minor): ADR-0003's list words the test-ci-sodium copies too narrowly

- **Where:** `.plans/decisions/0003-libsodium-floor-1-0-18.md:107`, "`tests/test-ci-sodium.sps`'s
  reviewed copies of the pins".
- **Evidence:**
  - **The copies are wider than the pins.** Its "reviewed copies" block
    (`test-ci-sodium.sps:226-237`) also holds `floor-so` (`libsodium.so.23`), and `:796` holds
    `system-path` (`--discovery`'s path). A raise past 1.0.18 moves both.
  - **The scripts' comments say it right.** `build-sodium.sh:46-50` and `check-sodium.sh:50-55`
    say "the reviewed copies", whole.
  - **One more place.** `global-constraints.md:95` names Ubuntu 24.04's 1.0.18 for `main`. The
    raise's record moves it with `main`'s assertion.
  - Otherwise a grep of the tree for `1.0.18`, `so.23` and the floor's SHA-256 finds nothing the
    list leaves out.
- **Fix:** "`tests/test-ci-sodium.sps`'s reviewed copies: the pins, the floor's soname and
  `--discovery`'s path". Add the constraint to the `main` bullet.

### R2-F10 (minor): the restorations and pointers aren't quite in the form M1-F9 asked for

- **ADR-0012 is not back to its first text.**
  - `:63` keeps slice 2's "decision 7's **rows**". `c1d1be7` has "decision 7's row", and `:67`
    still says "Rule (m) and the row".
  - Either restore "row", or say in the amendment that the plural came with E11.
- **ADR-0012's pointer is mis-indented.** `:52-53`: the "Amended:" pointer's continuation is
  indented 2, where the list item's is 3. It renders as a lazy continuation, but the wrap is off.
- **Two records were edited in place, with no status-line note:**
  - ADR-0011 `:101-104`, its new pointer;
  - ADR-0007 `:110-114`, its run note.

  Both are owner-directed and editorial, but this is the pattern M1-F9 named. A status clause
  would close it, such as "Consequence points at ADR-0003's amendment, 2026-11-23".

### R2-F11 (minor): slice 0's close-out says its run passed, and leaves out a 31-minute hang

- **Where:** `.plans/progress.md:249-250`: "CI's run 45160419954 passed".
- **Evidence** (`gh run view 45160419954 --attempt 1`):
  - **Attempt 1 was cancelled.** `memory`'s "Install the packages" ran from 10:55:27 to
    11:26:25, and the job was cancelled. Attempt 2 passed, with `memory` at 8m48s.
  - **It matters now.** A hung `apt-get` waits out the job's `timeout-minutes`, which M1-F4 now
    holds at 120 for `memory`.
- **Fix:** "… passed on its second attempt: the first's `memory` hung 31 minutes in `apt-get
  install` and was cancelled".

### R2-F12 (minor): wraps

- **Over-long lines:**
  - ADR-0007 `:114`, 124 characters;
  - `progress.md:130`, 106;
  - `AGENTS.md:196`, 87, where the section keeps to 82;
  - `tests/check-ci.sh:66` and `tests/test-check-ci.sps:442`, 81, where their neighbours keep
    to 80.
- **A ragged wrap:** `packaging/floors.sexp:1-3`, at 85, 86 and 38.
- **README.org:29,** the brief's link line, is still unwrapped. The closing review left that
  optional.

---

## Checked and found sound

1. **M1-F4's rules hold what they say, but for R2-F1.**
   - **Mutants past the log's 17, each failing closed or killed:**
     - a quoted name, or a trailing space;
     - `run: | # x`;
     - a re-indented block line, and a comment line inside the block, which counts;
     - a blank line inside the block: skipped, and harmless to the shell;
     - `env: ID`, `VERSION_ID` or `RUNNER_ARCH` on the step: refused, "not CHEZ";
     - a step-level `timeout-minutes`: refused;
     - `fr` taken as the last restore: killed by the lanes' "moved after the first restore";
     - `060` and `0120`: compared as text, and killed.
   - **The 70 rows.** Each plants what its name says, and asserts the whole output. All 70 ran
     red against `main`'s script.
2. **The move of the older rows holds as much as before.**
   - **The count is 45, not 23.** 44 of them plant in a block, and 1 adds a key below it.
   - **Unmoved, the 44 would fail.** Probe: `main`'s `test-check-ci` against the new script
     passes 631 rows and fails 44, each a moved row. The 45th, the dedented `shell: bash`,
     plants no run line.
   - **Nothing else changes.** Each now plants in the same job's "Install the packages" block,
     at the same indent. That block is held to no line, and each row still asserts its whole
     stdout and stderr.
3. **M1-F10's operative rule is right.**
   - The trap matches T1 and T2, and this review's reproduction.
   - No existing row breaks the rule. `test-counters` and `test-chez-sodium-testing` fork
     threads, but reference their libraries at top level first.
4. **ADR-0001's amendment matches the suite.**
   - It equals `foreign-conventions.sls:106-107` and `test-conventions.sps:234-244`, the rule
     and the M1 lists.
   - Decision 10's first sentence is restored exactly as at `0b800ed`.
   - S0-F7 is the right finding.
5. **ADR-0012's amendment matches E11** (`test-native.sps:1244-1253`): one plain spec, and no
   other spec mentioning `memory`. So does the constraint at `:46-49`. S2-F1 is the right
   finding.
6. **ADR-0003's amendment.**
   - Every place in `src/`, `tests/`, `scripts/ci/` and `ci.yml` is listed, but for R2-F9's
     wording.
   - The soname history, `main`'s runner and "current first" (the closing review's probe A) are
     right.
   - ADR-0011's pointer agrees.
7. **The amendments' form.**
   - Each heading, first line ("Accepted (the owner, 2026-11-23), from …") and status clause is
     in the form of ADR-0002, 0006, 0007, 0008 and 0011.
   - All four anchors resolve to GitHub's slugs.
8. **M1-F6.**
   - The empty import runs no body (probed). The children start fresh, so what they prove is
     unchanged.
   - The `before` scan now follows a reference of every export, which is stronger.
   - `condition-names` is guarded, and `checked-names` is a literal. No top-level raise, and no
     order dependence.
9. **M1-F7.**
   - `fhs-triple` equals `discovery.sls:99-103` arm for arm.
   - The hand list is ADR-0002's order (`:39`), and the new row runs in every world.
   - `first-standard` no longer reads discovery, and the expected value is a top-level literal
     computation that cannot raise.
10. **M1-F5.**
    - **The traps** (dash, on the host). Without the signal trap, TERM, HUP and INT each leave
      the `mktemp` directory. With it, all three remove it; INT waits for the child to finish.
    - **`--proto '=https'`** also covers redirects (S5-F3's probe).
    - **`sha256sum`** is coreutils, an Essential package. A missing tool gives an empty sum,
      which fails the comparison closed.
    - **Checks:** `dash -n` passes on all five scripts, and `check-action-pins.sh` passes.
11. **The cache keys.**
    - **What changes.** Every Chez key hashes `build-chez.sh` and `check-chez.sh`, and both
      changed, so all five Chez caches miss. The libsodium keys don't change.
    - **What a cold build costs.** 3m24s to 4m01s a job (M0's cold run, 45093705139).
    - **It happens twice.** The PR's first run builds Chez in all five jobs. A PR's caches are
      scoped to its ref, so `main`'s push run after the merge builds cold again.
    - **That fits the timeouts.** `memory` goes from about 17 minutes to about 21, of 120, and
      the lanes from about 3 to about 7, of 60. Acceptable: say so in the PR.
12. **The close-outs against their sources.**
    - **Every cited run exists and is green:** 45160419954 (attempt 2), 45226809762,
      45176193659, 45211022814, 45233248425, 45242596732 (both attempts) and 45249131058.
    - **The mutant counts** match the logs and PR bodies: slice 1's 67 are 65 core and 2 exit
      checks, plus one control that must survive; slice 5's 158 are 101 and 57.
    - **The review counts** match: 1/6/13, 0/2/6, 0/5/9 (3/7 on slice 3 and 2/2 on slice 4), and
      0/2/10.
    - **Slice 2's 1.0.18 run** matches its log: Ubuntu's library, with Guix's headers.
13. **AGENTS.md's "Where the project stands", and README's status.** Both are right once the PR
    merges.
14. **The research copies.**
    - No local path or personal detail.
    - `m1-closing-review/README.md` is identical to its scratchpad original, which had none.
    - The trim tables are scrubbed: one differs from its original by 2 lines, and the rest were
      clean already.
15. **AGENTS.md's rules across the diff.**
    - No milestone, slice, date, research path or "maintainer" in an added comment under
      `src/`, `tests/`, `scripts/`, `packaging/` or the Makefile.
    - No personal detail anywhere in the diff.
    - `conditions.sls`' exports now all carry signatures, matching `(chez-sodium)`'s.
16. **M1-F8, M1-F13 and AGENTS.md's ADR-0007 decision 8 sentence** read right against their
    sources.

## Probes

| # | What | Where | Result |
|---|---|---|---|
| K1 | Chez keys without the image id, all five | host, mawk | passes (R2-F1) |
| K2 | `main`'s Chez key tail `-ubuntu` | host, mawk | passes (R2-F1) |
| M1 | `main`'s `test-check-ci` against the new `check-ci.sh` | container | 631 pass, 44 fail, each a moved row |
| E1 | committed `engine-section.sps`, three times | container | 45,158 and 45,159 every time (R2-F2) |
| T1 | toy library, whole body in one section; main references at 100 ms | container | raised "cyclic dependency" at 100 ms; later `ready` |
| T2 | the same, main allocating first | container | stalled until the section ended (about 383 ms), then `ready`, 3 of 3 (R2-F5) |
| N1 | `(only (chez-sodium))` import | container | 8 exports, no libsodium mapped |
| N2 | `(environment '(chez-sodium))` in a guard | container | 8 exports; an absent library is caught |
| N3 | `(chez-sodium)` exporting an unbound name | container | new suite exits 255 at import, no row; `main`'s runs 5 rows, fails 2 by name (R2-F6) |
| S1 | EXIT-only trap against EXIT and signal traps, under TERM, HUP and INT | host, dash | left, left, left; removed, removed, removed |
