# M1's closing review

Read-only and adversarial, on Opus, over chez-sodium's M1 as merged on `main` at `49e7e3b`
(`git diff 0b800ed 49e7e3b`, PRs #3 to #8). Line numbers are `main`'s.

- **No project file was changed.** Nothing was committed, pushed or installed, and nothing was
  written under the checkout's `build/`.
- **Every probe ran in a copy** under the scratchpad's `review-m1/`, which is now removed. Probes
  ran in the container (`scripts/guix-env`) unless named. "Host" is the development
  workstation: its Guix-home Chez 10.4.0 and Ubuntu's `libsodium.so.23` (1.0.18).
- **`gh` was used read-only:** `run list`, `run view`, `pr view`, and one `gh api` GET of a job's
  log.
- **No command was denied.** No subagent was used.

**Counts: 0 blockers, 4 majors, 10 minors.**

**Verdict: M1 is done once its four majors land: M1-F1, M1-F2, M1-F3 and M1-F9.** M1-F3 and
M1-F9 need the owner, since they amend ADR-0003, ADR-0001 and ADR-0012. Each minor can be fixed
in the same PR or recorded as owed. The code holds every record, and no check I sampled passes
when its target is broken, apart from the unheld CI lines of M1-F4 and the hand-written list of
M1-F6. What fails is the paperwork:

- the ledger and AGENTS.md still describe M1 as under way;
- the CI measurements plan §5.2 owes are recorded nowhere;
- the record of what a floor raise moves is incomplete, and leaves out two things only the
  owner can settle;
- two records were changed in place, with no dated amendment and no acceptance noted.

---

## Findings

### M1-F1 (major): the ledger and AGENTS.md misstate where the project stands

- **Where:**
  - `.plans/progress.md:21-27`: "M1 is under way", and "Their close-outs follow M1's closing review";
  - `.plans/progress.md:70`: "Slice 5 is on `m1-slice-5`", though it merged as #8, `49e7e3b`;
  - `.plans/progress.md:89`: "Next: slice 5's PR";
  - `AGENTS.md:5-8`: "No verb exists yet", and "M1 ... is under way".
- **Evidence:**
  - Plan §7's last item: "`progress.md` has each slice's close-out, and AGENTS.md's 'Where the
    project stands' names M1 done and M2 next." Neither holds.
  - Plan §1 says "M1 delivers `sodium-version`", and calls it "the only verb". So "No verb exists
    yet" is false, as slice 5's review noted (S5-F6). README was fixed then; AGENTS.md was left
    for M1's close.
  - The ledger has no close-out for any of slices 0 to 5.
- **Fix:** the drafts under "Drafts" below: the new "Now", the owed lists, six close-outs newest
  first, and AGENTS.md's paragraph. Commit this review as
  `.plans/research/m1-closing-review/README.md`, as the slice reviews are committed.
- **Kind:** mechanical.

### M1-F2 (major): the CI measurements plan §5.2 owes are recorded nowhere

- **Where:**
  - `.plans/2026-11-22-m1-plan.md:415-416`, slice 2: "the first time Valgrind 3.22 sees Chez load
    Ubuntu's 1.0.18 ... Record it";
  - `:418-420`, slice 3: "each `test-library-loading-*` suite's time under the gate, in the
    container and on CI's runner";
  - `.plans/progress.md:56`: "CI's first measured times, which plan §5.2 owes";
  - slice 2's review S2-F5: "record CI's first `main` and `memory` runs in the slice's
    close-out".
- **Evidence:** a grep of `.plans/` for `3.22` finds only the plan's own promise and the slice 2
  review's request. The numbers exist on CI:

  | What | Run | Measured |
  |---|---|---|
  | Valgrind 3.22 meets Ubuntu's 1.0.18, the first time | 45176193659 (slice 2, `35a26d8`) | `memory` 17 of 17; `test-native` 12 s under the gate (8 s in the container); slowest `test-check-ci`, 68 s |
  | The runner | 45242596732, `main` | GCC 13.3.0 (Ubuntu 13.3.0-6ubuntu2~24.04.1), valgrind-3.22.0, `libsodium23` and `-dev` 1.0.18-1ubuntu0.24.04.1, image `ubuntu24 20261116.133.1` |
  | The library-loading suites under the gate, on the runner | 45242596732, `memory`, attempts 1 and 2 alike | decoys 55 s, missing 51, preflight 51, real 51, combined 46, discovery 19 |
  | The heaviest suite | the same | `test-check-ci`, 113 s of the 450 s SLOW line (116 s in the container) |
  | The whole gate | the same | `check-memory-gate` 269 to 270 s; all 26 suites 596 to 600 s; the job 15m27s cold, 17m42s warm, of 120 min |
  | The lanes' serial builds | 45242596732, attempt 1 | `floor` 66 s, falling back to `releases/old/` (its log: "could not download …/releases/libsodium-1.0.18.tar.gz, trying …/releases/old/…"); `current` 50 s |
  | The lanes' `make test` | the same | `floor` 65 s, `current` 61 s, each 26 of 26 |

  The 14-child budget per suite (3.85 s a child in the container) holds on the runner: about
  3.6 to 3.9 s a child.
- **Fix:** put these numbers in slice 2's, 3's and 5's close-outs; the drafts below do.
- **Kind:** mechanical.

### M1-F3 (major): the record of what a floor raise moves is incomplete, and leaves out two consequences only the owner can settle

- **Where:**
  - `.plans/decisions/0003-libsodium-floor-1-0-18.md:72-73`: "Raising the floor is a new record,
    and the edits chez-sqlite3 ADR-0008 lists";
  - `.plans/decisions/0011-the-harness-after-chez-sqlite3.md:101-103`: "Changing a floor edits
    the file, README.org's Requirements, the code's check and the literal rows that name the old
    floor";
  - against them, `scripts/ci/build-sodium.sh:40-51` and `scripts/ci/check-sodium.sh:46-55`, whose
    comments list the rest.
- **Evidence:**
  - **The lists.** The scripts name what the records don't:
    - `floor_archive`, a new SHA-256 checked once against its `.minisig`;
    - the floor's soname in both scripts;
    - `--discovery`'s path (`check-sodium.sh:175`);
    - `ci.yml:383,390,397`;
    - `check-ci.sh`'s `sodso["floor"]`;
    - `test-check-ci`'s `sod-so`;
    - `test-ci-sodium`'s reviewed copies.
  - **Probe A**, in a copy, on the host: `packaging/floors.sexp` and README's line set to 1.0.22,
    the current release. `check-floors` fails, naming
    `scripts/ci/build-sodium.sh: line 84 contains the libsodium floor 1.0.22` and the same at
    `check-sodium.sh: line 101`. So a floor raised to `current_version` cannot land until
    `current` moves past it (carried).
  - **Probe B**, in the container: the floors file and README raised to 1.0.19, nothing else.
    `make test` ran 26: 20 passed, 6 failed by name:
    - `test-check-floors`;
    - `-combined`, `-decoys`, `-missing` and `-preflight`, whose decoys read the file while
      `verify` still holds `(1 0 18)`;
    - `test-verify`.

    So ADR-0011's "each place left behind fails by name" holds in the container. The CI-only
    places fail in CI:
    - the floor lane's pin;
    - the soname, since 1.0.19 is `.so.26`;
    - `main`.
  - **What no record says:**
    - CI's `main` asserts that the runner's own package is the floor (ADR-0002, ADR-0003), and
      Ubuntu 24.04 ships only 1.0.18 (ADR-0003's table). Raise the floor past 1.0.18 and `main`'s
      `make build` refuses `below-floor`. `main` must then move to an image whose package is the
      new floor, or its assertion must change. ADR-0003 rejected a higher floor for exactly that
      reason, but its "Raising the floor" doesn't say it.
    - A raise to 1.0.19, 1.0.20 or 1.0.21 also moves the floor's soname to `.so.26`. The
      `floor` and `current` lanes would then test two libraries under one soname.
- **Fix:** amend ADR-0003's "Raising the floor" consequence, and point ADR-0011's bullet at it:
  - the full list above, with README and `verify`'s `sodium-floor`;
  - `main`'s runner must ship the new floor, or `main`'s floor assertion changes, decided in the
    raise's own record;
  - `current` moves past the new floor first, since `current_version` in `scripts/ci/` must not
    equal it;
  - the soname follows the release (`.so.23` for 1.0.17 and 1.0.18, `.so.26` from 1.0.19).
- **Kind:** an owner's decision (ADR amendment).

### M1-F4 (minor): `check-ci` holds neither the "Identify the runner image" step nor any job's `timeout-minutes`

- **Where:**
  - `ci.yml:109-113`, `:209-213`, `:269-273`, `:326-330`, `:425-429`;
  - the claim at `ci.yml:68-79` ("keyed by … the runner's OS release and architecture");
  - `Makefile`'s test-memory comment ("600 s is far below the memory job's 120-minute limit in
    CI").
- **Evidence:** on the host, `sh tests/check-ci.sh` on a copy of `ci.yml`:

  | Mutation | check-ci |
  |---|---|
  | the step deleted from `floor` | passes |
  | the step deleted from all five jobs (7 `steps.image` keys left reading an empty id) | passes |
  | its run made `echo "id=fixed"` | passes |
  | control: the `cc` step's run made `echo "id=fixed"` | fails, both lanes, by name |
  | `floor`'s `timeout-minutes: 600`, `memory`'s `timeout-minutes: 5` | each passes |
  | control: `floor`'s `runs-on: ubuntu-22.04` | fails by name |

  chez-sqlite3 v0.1.1's `check-ci.sh` holds no image step either, so the gap is inherited.
- **Impact:** low.
  - **The image step.** `runs-on` is held, so the id only changes when a held line does.
    `check-chez.sh` and `check-sodium.sh` still check what a restored cache holds.
  - **The timeouts.** A wrong one fails loudly, or waits 6 h on a hang.

  Still, a comment claims what nothing checks (AGENTS.md: "Prefer a check to a comment").
- **Fix:**
  - **The image step.** `check-ci` holds it in every job: its name, `id: image` and its two run
    lines, before the first restore.
  - **The timeouts.** It holds each job's `timeout-minutes`: 60, and 120 for `memory`.
  - **Rows in `test-check-ci`.** The step deleted, its id renamed, its run changed, and it moved
    after a restore; a timeout changed. Watch each fail.
- **Kind:** a rule change (new `check-ci` rules).

### M1-F5 (minor): `build-chez.sh` follows a redirect to plain HTTP, keeps a macOS fallback, and five M0 scripts trap `EXIT` alone

- **Where:**
  - `scripts/ci/build-chez.sh:72`: `curl -fsSL --retry 3`, with no `--proto '=https'`;
  - `:59-66`: `shasum -a 256` "elsewhere";
  - `:69`: `trap 'rm -rf "$work"' EXIT`, alone. So do `check-chez.sh:44`, `report-sodium.sh:32`,
    `check-action-pins.sh:75` and `scripts/guix-env-selftest:18`.
- **Evidence:**
  - Slice 5's review probed the redirect (S5-F3) and the signal case (S5-F12): curl follows a
    302 to HTTP, and a SIGTERM to dash leaves the `mktemp -d` directory.
  - The new scripts carry the fix: `build-sodium.sh:126,129,132`, `check-sodium.sh:119`.
  - `build-chez.sh` is M0's, unchanged since `0b800ed`.
  - ADR-0010: "no abstraction kept only so another platform could come later". `shasum` is the
    macOS spelling. Ubuntu has `sha256sum` in coreutils, an Essential package
    (`debian-prereqs.txt`).
- **Impact:** the SHA-256 is checked before anything is unpacked, so a downgraded fetch fails
  closed. A Ctrl-C on a host leaves a directory in `/tmp`, and `check-action-pins.sh` is run on
  the host.
- **Verdict on the carried item:** real, low impact.
- **Fix:**
  - `--proto '=https'` on `build-chez.sh`'s curl;
  - `trap 'exit 1' HUP INT TERM` after each of the five `EXIT` traps;
  - `sha256sum` alone in `sha256_of`.

  No row holds `build-chez.sh`, so record it in the PR, as S5-F12 was.
- **Kind:** mechanical.

### M1-F6 (minor): `test-never-loads` says "every condition export", but its child's list is written by hand

- **Where:** `tests/test-never-loads.sps:328-357`, the program; `:410`, the row.
- **Evidence (probe P3):**
  - Mutation: `(chez-sodium)` also exports `sodium-failed?`, imported from conditions.
  - Result: `test-never-loads` passes, 7 of 7. `test-public` fails its export row.
  - So the claim that each condition export loads no libsodium covers only the names written
    in the child.
  - M3 adds three such names (ADR-0012, decision 2), and nothing ties them to this child.
- **Fix:** build the child's names from `(library-exports '(chez-sodium))`, which the suite
  already imports, less the verbs, which load libsodium. Or add a row that holds the child's list
  to those exports. Either way, M3's owed list names it (draft below).
- **Kind:** mechanical.

### M1-F7 (minor): the FHS discovery rows take their expected path from the code under test

- **Where:** `tests/test-library-loading-discovery.sps:192-202` (`first-standard`) and
  `:279-288`.
- **Evidence:**
  - `first-standard` is `(find file-exists? (map car (libsodium-candidates 'fhs …)))`:
    discovery's own list.
  - The row "the first standard candidate that exists loads" therefore passes whatever order
    that list has. This is AGENTS.md's "an assertion passes whenever another rule can produce
    its expected value", with the same rule producing both sides.
  - The Guix not-found row writes its ten candidates by hand. The FHS rows run only on CI's
    `main`.
- **Impact:** small. The order is held elsewhere:
  - `test-discovery`'s literal FHS lists (slice 1's mutants; probe S1a below);
  - `check-sodium.sh --discovery`'s literal path on CI.
- **Fix:** a hand-written FHS list in the suite, `/usr/local/lib`, `/usr/lib/<triple>`,
  `/usr/lib64`, `/usr/lib`, each `.so.26` then `.so.23`, as the Guix row has.
- **Kind:** mechanical.

### M1-F8 (minor): the constraints' rule-symbol line is wider than its record, and the load's refusals don't meet it

- **Where:**
  - `.plans/global-constraints.md:104-105`: "A refusal raised through the public surface leads
    its irritants with the rule's symbol";
  - `.plans/decisions/0006-errors-and-no-secret-shown.md:53-62`, where that rule is a sub-bullet
    of decision 5, "A caller's mistake is an assertion violation";
  - plan §4.1, item 3: "A refusal of a caller's mistake leads its irritants with a symbol".
- **Evidence:**
  - The load's refusals reach a caller through `sodium-version`, the public surface.
  - Their irritants are a path or the override, not a rule symbol: `native.sls:183,386`,
    `discovery.sls:66-68,79-81`, `verify.sls:55,73`. Their contract is the `reason` field.
  - The code follows the record. The constraints line, read alone, says the code is wrong.
  - M2's verbs are the first to raise a caller's mistake through the public surface, so M2's
    briefs are the first this line binds.
- **Fix:** "A caller's mistake refused through the public surface leads its irritants with the
  rule's symbol; a load refusal carries its reason in its `reason` field."
- **Kind:** mechanical (the constraints follow the record).

### M1-F9 (major): two records were changed in place, and ADR-0001's new sentence is not the rule the suite holds

- **Where:**
  - `.plans/decisions/0001-bind-libsodium-directly.md:3-4`, the status, and `:54-59`, decision 10;
  - `.plans/decisions/0012-the-public-library-and-the-seam.md:60-65`, a consequence;
  - `global-constraints.md:46-47` and `:71`;
  - `tests/foreign-conventions.sls:106`, `(int uptr size_t)` for arguments, and
    `tests/test-conventions.sps:238`.
- **Evidence:**
  - **ADR-0001.** `git diff 0b800ed 49e7e3b` shows decision 10 rewritten in place by slice 0.
    It used to say "`size_t` joins both allow-lists, for arguments and for results"; it now says
    "The allow-lists are exactly the types the rows use … (…; amended after slice 0's review)".
    - The status line still reads "Accepted (the owner, 2026-11-22), approved with the brief".
    - There is no amendment section.
    - Every other amended record (ADR-0002, 0003, 0006, 0007, 0008 and 0011) keeps its first
      text and adds a dated section that says the owner accepted it.
    - So nothing in the record shows what the owner accepted on 2026-11-22, or that the owner
      accepted the change.
  - **ADR-0012.** Slice 2 (`64dc8cf`) edited its consequence in place to add a rule: "Decision
    7's rows also hold that native imports memory once, under memory's own names" (S2-F1, held
    by `test-native`'s E11).
    - The rule is in no decision, and not in the constraints: `global-constraints.md:46-47` names
      decision 7's names alone.
    - The status line doesn't mention the change.
  - **The wording.** No row uses `int` as an argument. The suite's rule for the argument list is
    "every type an argument or a non-void result", as plan §2.2 and v0.1.1 have it. Read
    literally, ADR-0001's sentence says `int` should not be in that list.
    - M2 adds `size_t` as a result and `unsigned-64` as an argument, so the sentence decides
      what the next builder writes.
- **Fix:**
  - **ADR-0001.** Restore decision 10's first sentence, and add "Amendment, 2026-11-23: slice
    0's review", accepted by the owner, with the suite's rule: "the argument allow-list is
    every type a row uses as an argument or a non-void result; the result allow-list is every
    result type, and `void`". Note it in the status line.
  - **ADR-0012.** Make the import-once rule part of decision 7 by a dated amendment, and add it
    to the constraints' line.
- **Kind:** an owner's decision (two ADR amendments).

### M1-F10 (minor): a library first reached on two threads at once refuses the second with Chez's "cyclic dependency", and nothing records it

- **Where:**
  - nothing in `traps.md`, ADR-0007 or AGENTS.md;
  - native's header (`native.sls:36-39`) discusses engines alone.
- **Evidence:**
  - **Probe T1, host.** A toy library whose body sleeps 1 s, with or without its work in one
    `critical-section`. Thread 0 references it through `eval`; 0.1 s later, thread 1 does.
    Results: `#(ready (raised "cyclic dependency involving invocation of library ~s") (later ready))`.
  - **Probe T2, host,** on native itself: a copy whose body sleeps 1 s before its load section,
    `CHEZ_SODIUM_LIBRARY` at Ubuntu's 1.0.18, and two threads each evaluating `(sodium-version)`.
    Results: `#("1.0.18" (raised "cyclic dependency involving invocation of library ~s" #f) (later "1.0.18"))`.
  - So the second thread gets Chez's own condition. It is not a `&sodium-library-unavailable`
    (the `#f`), and `load-state` never sees it.
  - It is transient: later references answer. A critical section blocks only its own thread,
    so the window is the whole body, not just its prologue.
  - A program that references the library's bindings runs the body before its first line, so
    only `eval`, the REPL or a lazily invoked library can meet it. Techo hashes on worker
    threads, and M3's row 19 forks threads.
- **Fix:**
  - a `traps.md` entry with these probes;
  - an M4 documents note;
  - a rule beside the engine rule, in AGENTS.md and the constraints: "a row that forks a thread
    which reaches the library references it once first".
- **Kind:** a rule change.

### M1-F11 (minor): slice 1 had no review of its own, and the ledger doesn't say so

- **Where:** plan §6, "Each ends with a read-only adversarial review on Opus"; `progress.md:35-37`.
- **Evidence:**
  - The brief for this review says so. No `m1-slice-1-review/` exists.
  - Slice 2's review read its own diff against `m1-slice-1`.
  - This review covered the gap. It read `conditions`, `load-state`, `discovery` and `verify`
    whole, and their suites' top-level definitions. Every one that can raise is guarded.
  - It ran ten mutants slice 1's log does not have. Every one was killed (probes S1a to S1l,
    below).
- **Fix:** slice 1's close-out says that slice 1 had no review of its own, and that the
  closing review read it (draft below).
- **Kind:** mechanical.

### M1-F12 (minor): the ledger cites trim tables that are not in the repository

- **Where:**
  - `.plans/progress.md:119`: "(slice 2's tables)";
  - `:36`, and each slice log's opening, "trim tables the caller checked".
- **Evidence:**
  - `git ls-files | grep -i trim` finds nothing.
  - The tables are in the session's scratchpad, as `slice1-core-trim.md`, `slice2-*-trim.md`,
    `slice3-*-trim.md`, `slice4-public-trim.md` and `slice5-*-trim.md`. A cleanup can clear it.
  - They are plan §2's record of what each dropped piece of v0.1.1 protected, and M3 copies more
    of v0.1.1 (`call-with-c-string`).
- **Fix:** commit them as `.plans/research/m1-trim-tables/`, with a README and local paths
  scrubbed, and cite that. Or drop the citation and state the point it supports.
- **Kind:** mechanical.

### M1-F13 (minor): stale or wrong comments and wording

- **`Makefile:286-288`.** check-ci "holds … its three jobs" and "no if: but the Chez cache's
  own". There are five jobs, and the libsodium caches carry ifs too (`ci.yml:42-46` says it
  right).
- **`packaging/floors.sexp:1-2`.** "test-require-threaded holds the code". `test-verify` holds
  the libsodium floor's code (`verify.sls:26`).
- **`tests/check-test-fails.sh:20-23`.** The `seam` row's text columns sit two left of the other
  rows'.
- **`AGENTS.md:194`.** "Each verb's whole extent is one `critical-section`" doesn't name ADR-0007
  decision 8's exception, `sodium-version`, which holds none.
- **ADR-0007 `:110-113` against `traps.md:49-51`.** They tell one probe with two sets of numbers:
  slices 44,209 to 44,219 (slice 0's review's run), and expiries 45,158 and 45,159 (the committed
  `run-engine-section.out`). Say which run each is.
- **`src/chez-sodium/private/conditions.sls:148-174, 212-217`.** The exported accessors and
  predicates carry no Typed Racket signature in their own library (AGENTS.md: "Exported
  functions should have a comment with a Typed Racket style type signature").
  `(chez-sodium)`'s re-exports have them.
- **Fix:** reword each. The ADR-0007 line is the owner's.
- **Kind:** mechanical, but for ADR-0007's line.

### M1-F14 (minor): the owed lists leave out plan §1's "Waits" column and several things M2 and M3 inherit

- **Where:** `progress.md:105-151`, against plan §1's table (`:48-61`).
- **Evidence:** the owed lists never name these:
  - **From plan §1's "Waits" column:**
    - row 11's password half;
    - rows 15, 16 and 18 for each verb;
    - row 17's `&sodium-failed`;
    - row 22's M2 and M3 codes;
    - row 24 for each verb's blocks (named only as "how row 24 reaches a verb's blocks").
  - `size_t` joining the result allow-list with M2's first size function (ADR-0001, decision 10);
  - each verb refusing its own secret parameters, by their own names, before its section. Inside
    the section, `call-with-bytes`' refusal names its own parameter, `bytes`, and is only a net;
  - M1-F6's child list, and M1-F10's thread rule.
- **Fix:** the drafted owed lists below.
- **Kind:** mechanical.

---

## The carried list

| Item | Verdict | Finding |
|---|---|---|
| The places a floor raise moves | Real. The scripts' comments list them, and the records don't. A raise to `current_version` fails `check-floors` (probe A). Every place left behind fails by name (probe B, and CI for the rest). The records also miss `main`'s runner and the soname change. | M1-F3, major, the owner's |
| "Identify the runner image", held by no job | Real, inherited from v0.1.1. Deleting it, or making it constant, passes `check-ci`. Low impact while `runs-on` is held. `timeout-minutes` is unheld too. | M1-F4, minor, a rule change |
| `build-chez.sh`'s redirect and `EXIT` trap | Real, fails closed. Four more M0 scripts trap `EXIT` alone, and `build-chez.sh` keeps a macOS `shasum` branch. | M1-F5, minor, mechanical |
| CI's measured times against `MEMORY_TIMEOUT` | Sound. `test-check-ci` takes 113 s on CI, 116 s in the container, of the 450 s SLOW line, about 25%. The library-loading suites take 46 to 55 s. Split `test-check-ci` by job once it passes about 300 s. The record of these times is missing. | M1-F2, major, mechanical |

---

## Item 1: is M1 done?

### Plan §1

| Promised | On `main` | Held by |
|---|---|---|
| Conditions: the tree, the raise helpers, `shown-value`, `refuse-secret` | `conditions.sls` | `test-conditions` (51 rows) |
| The load in ADR-0002's order | `native.sls:374-424` | `test-native` E1 to E6; the decoys' call logs |
| `sodium-version`, from `(chez-sodium)` | `chez-sodium.sls` | `test-public` (8 rows) |
| The block helper, the wipe, `call-in-section` | `memory.sls`, `native.sls:140-275` | `test-blocks`, `test-native`, `test-wipe` |
| The decoy, the oracle, `test-constants`, the convention table, `check-seam` | `tests/` | their suites; the `seam` plant |
| CI's `floor` and `current`; `main`'s `make build`, its floor assertion and `check-dev` | `ci.yml` | `check-ci`; run 45242596732 |
| `make build`, `make dev`, `check-dev` | `Makefile:145-179` | `check-dev`'s two cases; CI's `main` |
| `(chez-sodium)`'s eight names, with signature comments | `chez-sodium.sls:14-35` | `test-public`'s export row |

Nothing promised is missing from the code.

### Plan §6, the done lines

| Slice | Done line | Holds |
|---|---|---|
| 0 | every record accepted, as each status line says; the review's blockers and majors fixed | yes for §4.3's six: each status names the owner's acceptance. ADR-0001's slice-0 change is in no status line (M1-F9). The review's resolution table fixes all 20 findings. |
| 1 | the four container checks; `nothreads` refuses each new library by name; CI in all three jobs | yes; this review's 10 mutants confirm it, though there was no review (M1-F11) |
| 2 | slice 1's checks; `make build` both ways; CI green with `test-native` under Valgrind 3.22 | yes: run 45176193659 (M1-F2) |
| 3 | `check-dev`; CI's `main` runs `make build` naming `/usr/lib/x86_64-linux-gnu/libsodium.so.23 (system)` | yes: `main`'s log reads exactly that, `1.0.18 (library 10.3)`, `((block . 0))` |
| 4 | `(chez-sodium)` among the libraries `nothreads` refuses by name | yes: its log names nine, `(chez-sodium)` first |
| 5 | CI green in all five jobs, cold and warm | yes, with a nuance for the close-out: attempt 1's libsodium caches were cold, but Chez's were warm from earlier PRs. Chez's cold builds were proven at M0. The push run on `main`, 45249131058, is green too. |

### Plan §7

| Item | Holds |
|---|---|
| Slices 0 to 5 merged, CI in all five jobs | yes |
| Container checks | yes (the caller's runs; this review reran `make test` in a copy: 26 of 26) |
| `make check-guix` on the host | **yes, now:** run by this review in a copy. "check-guix: ALL CHECKS PASSED": 82 launcher checks, then 26 of 26 in the container. No earlier record shows it run in M1. |
| Every record of §4.3 accepted, the constraints carrying its rules | yes, but for M1-F8's wording, and E11's rule, which the constraints lack (M1-F9) |
| The closing review run, its blockers and majors fixed or owed | this review: M1-F1, M1-F2, M1-F3 and M1-F9 |
| Close-outs; AGENTS.md names M1 done and M2 next | **no** (M1-F1) |

### Built but not in the plan

Each is recorded:

- `tests/fixtures/raising/unguarded.sps` (S3-F1, `traps.md`);
- `version-bom`, `--init-after` and `--wipe` (plan §2.2);
- `build-sodium.sh`'s pthreads check (plan §2.3);
- native's 13 exports (`progress.md`);
- four traps beyond the plan's list (`traps.md`).

---

## Items 2 and 3: the records, the seams and the rows

### The records against the code

| Record | Holds in the code | Unheld or contradicted |
|---|---|---|
| ADR-0001 | decisions 1, 3 to 9, 10's table and prototype check | decision 2 (constants), owed to M2; decision 10 changed in place, and its wording (M1-F9) |
| ADR-0002, amended | all six; the five entry points; init 0 and 1 | none |
| ADR-0003, amended | decisions 1 to 6; major and minor reported, never compared | "Raising the floor" (M1-F3) |
| ADR-0004 | `require-threaded` first in all nine; `nothreads` refuses nine | none |
| ADR-0005 | the subset: five entry points, each with a use | none (no verb holds state) |
| ADR-0006, amended | the tree; `&who` on every raise; `refuse-secret`'s shape; `checked-accessor`'s rule symbol | the constraints' wording (M1-F8) |
| ADR-0007, amended | `call-in-section`; `sodium-version` with no section (E10); the load in one section (E1) | the numbers' wording (M1-F13); the thread case (M1-F10) |
| ADR-0008, amended | the wipe fused, a dead block never wiped, no `bytevector-copy` (E9) | none |
| ADR-0009 | nothing yet (M3) | none |
| ADR-0010 | Linux only in `src/` | `build-chez.sh`'s `shasum` (M1-F5) |
| ADR-0011, amended | one gate job; the plants; `default.supp`; `gated-command`; no exit checks; the decoy's rule; the wipe child's `LD_PRELOAD` | the floor list (M1-F3) |
| ADR-0012 | defines nothing; eight exports; rules (c) to (i), (k), (m); E7, E8, E11 | E11's import-once rule is carried only by a consequence edited in place (M1-F9) |

**Hard rules with no check,** each known or by design:

- ADR-0001 decision 2 and the decoy's pointer rule, owed to M2;
- the engine-row rule, held by review;
- "every block is made under `call-in-section`" (`call-with-block`'s "Latent" comment), held
  per verb by row 18 from M2 (slice 2's S1 mutant shows it fails there);
- `timeout-minutes` and the image step (M1-F4).

**Records two slices read differently:** the rule symbol (M1-F8); the allow-lists (M1-F9).

### The seams

- **The public library.**
  - `check-seam` reads 9 libraries; `nothreads` on CI refuses the same 9; `test-public`'s export
    row is whole; `test-never-loads`' loaders row is asserted whole: native and `(chez-sodium)`.
  - Its condition child covers only the names it writes (M1-F6).
  - `(chez-sodium)` importing memory fails rule (m).
- **The CI scripts.**
  - `check-floors` reads both new scripts (CI's log lists them).
  - The cache keys' hash lists are each role's reads: `floor.sh`, `floors.sexp` and both scripts
    for the floor; both scripts for current.
  - `test-ci-sodium` holds `--discovery`'s preflight call to `make build`'s recipe.
  - Probe A shows `check-floors` and `current_version` colliding (M1-F3).
- **The load.**
  - Four lists agree: `every-entry` equals the table's names, whole and in order (`-missing` and
    `test-conventions`); the decoy's `lacks-` builds are generated from `every-entry`;
    `test-constants` reads its prototypes from the table; native's five forms are held to the
    table and to E2 and E3.
  - A sixth entry needs all four lists and E3 and E5 to move, and each fails by name until they
    do.
- **The coverage of new checks.**
  - `check-seam`, the one new prerequisite of `make test`, has the `seam` plant.
  - `check-dev` carries its own refused case.
  - Every suite is under the gate: CI's `memory` ran 26 of 26, no override of `MEMORY_SUITES`
    (`check-ci` refuses one).
  - No row is skipped in `main` or `floor`: their logs show no UNAVAILABLE, so `test-wipe`'s
    dead-block row ran. Under the gate, `test-native`'s B5 is skipped by design, and memcheck
    holds its byte (S2-F4). The gate's log prints verdicts only, so it can't show a skip.

### The rows of brief §8.1 that plan §1 says M1 holds

| Row | M1's part | Held by |
|---|---|---|
| 11 | an empty bytevector gets a non-NULL block of one byte | `test-native.sps:495` ("none is one byte, 0") and `:526`, `:559` |
| 15 | the helpers' refusals before any block | `test-native.sps:626-643` ("nothing allocated at the raise"), D1 `:912` |
| 16 | a secret's refusal by kind | `test-conditions.sps:420`; `test-native.sps:633` |
| 17 | `call-in-section` raises after its section, handler at depth 1 | `test-native.sps:785` |
| 18 | `sodium-version` and `call-with-block` in `call-in-section` at every fuel | `test-public.sps:209`; `test-native.sps:864` (C5), `:874` (C6) |
| 20 | all | `-decoys` (eight switches plus the control), `-missing` (each entry, and `not-sodium`), `-real` (bare name, empty, text file, missing path), `-discovery` (not-found, ten candidates), `test-discovery` |
| 21 | all | `test-library-loading-real.sps:278`, `:287` |
| 22 | `sodium_init` 0 then 1; versions before it | `test-native.sps:334`, `:370` and the oracle field rows at `:363` |
| 23 | every suite under the gate; the two plants | CI's `memory`: 26 of 26; `check-memory-gate` 59 cases |
| 24 | every block `call-with-block` frees reads zeros | `test-wipe.sps:227`, `:231` |

---

## Item 4: the probes

Guard, mutation, result. All in copies.

| # | Guard | Mutation | Result |
|---|---|---|---|
| P1 | the wipe's length is the block's | `memory` records `(+ size 1)` for each block: the wipe overruns by one byte | **killed** in a plain run: `test-blocks` W1, W2 and W8; `-combined`'s two `sodium_memzero(p,N)` rows; `test-native` aborts (134). `test-wipe` passes, as it reads only the named bytes. |
| P3 | `test-never-loads`' "every condition export" | `(chez-sodium)` also exports `sodium-failed?` | **survives** in `test-never-loads` (7 of 7); `test-public`'s export row fails (M1-F6) |
| S1a | the FHS list | `/usr/lib64` dropped | killed, 13 rows of `test-discovery` |
| S1b | the Guix list | `/run/current-system/profile` dropped | killed, 14 rows |
| S1c | `kind-of` | a char reads `other` | killed, 3 rows of `test-conditions` |
| S1d | the strict parse | `split-dots` drops a trailing empty part, so `"1.0.18."` reads | killed, `test-verify`'s malformed row |
| S1f | `as-serious`' `&who` | `native` for `chez-sodium` | killed, 4 rows of `test-load-state` |
| S1h | an accessor's `&who` | the refusal from `checked-accessor`, not the accessor | killed, 4 rows |
| S1i | a relative `HOME` | `HOME` taken unchecked | killed, 1 row |
| S1j | the aarch64 triple | its arm of `linux-triple` dropped | killed, 3 rows |
| S1k | `kind-of` | `()` reads `other` | killed, 3 rows |
| S1l | the world, from any line of the maps | the first line alone read | killed, 12 rows |
| C1 | the image step | deleted from `floor`; from every job; its run made constant | **all pass `check-ci`** (M1-F4) |
| C2 | the `cc` step (control) | its run made constant | killed, both lanes |
| C3 | the lanes' shape | `--current` dropped from the build or check; `floor`'s restore path `sodium-current`; `MEMORY_SUITES` on `make test-memory`; `floor`'s checkout without submodules; `main`'s discovery step deleted; `make build` made `make dev`; `current`'s library `.so.23`; `main`'s report step deleted; `concurrency`'s cancel made `true`; `runs-on` 22.04 | each killed, by name |
| C4 | timeouts | `floor` 600 min, `memory` 5 min | **pass** (M1-F4) |
| A | `check-floors` and `current_version` | the floor and README at 1.0.22 | fails, naming `build-sodium.sh:84` and `check-sodium.sh:101` (M1-F3) |
| B | "each place left behind fails by name" | the floor and README at 1.0.19, nothing else | 6 of 26 suites fail, each by name (M1-F3) |
| T1, T2 | the first reference | two threads reach a library body, then native's, at once | the second raises Chez's "cyclic dependency", not a refusal; later references answer (M1-F10) |
| G | plan §7's host check | `make check-guix` in a copy | passes: 82 launcher checks, then 26 of 26 |

Probes P1, S1a to S1l, C1 to C4, A, B, T1 and T2 are not in the slice logs. Slice 1's own ten
were picked because it had no review.

---

## Drafts (item 5)

### `progress.md`: "Now"

```markdown
## Now

- **M0 is done and merged** (PR #2; [the M0 plan](2026-11-22-m0-plan.md); its close-out is
  below).
- **M1 is done and merged** (PRs #3 to #8, squashed onto `main` on 2026-11-23; [the M1
  plan](2026-11-22-m1-plan.md); the close-outs below). Its closing review
  ([research/m1-closing-review/](research/m1-closing-review/README.md)) found no blocker, 4 majors
  and 10 minors; the majors are fixed in the fixes' own PR, two of them by the owner's amendments of
  ADR-0001, ADR-0003 and ADR-0012, and each minor is fixed there or owed below.
  - **One verb, `sodium-version`,** exported by `(chez-sodium)` with the predicates and
    accessors of `&sodium-library-unavailable` (ADR-0012).
  - **The load:** discovery, one load in one critical section, the floor read from
    `sodium_version_string`, then `sodium_init`, in ADR-0002's order; five entry points bound.
  - **The block helper:** counted blocks, `call-with-block` with the wipe fused with the free
    (ADR-0008), and `call-in-section` (ADR-0007).
  - **The checks of the FFI:** the decoy, the C oracle, the convention table, `test-constants`'
    prototypes against `sodium.h`, and `check-seam` with rule (m).
  - **The harness:** `make test` runs 26 suites, and `check-test-fails` plants 13 cases;
    `make build`, `make dev` and `check-dev`.
  - **CI:** five jobs. `main` finds Ubuntu 24.04's 1.0.18 by discovery and asserts it is the
    floor; `memory`; `nothreads`; `floor` and `current` build their pinned tarballs and run the
    suites against them.
- **Next: M2,** `random-bytes`, `blake2b` and `constant-time-bytevector=?`, built on M1's helper
  (brief §9). Its plan starts from "Owed to M2" below.
```

### `progress.md`: the owed lists

Keep "Answered for M1" as it is. Replace the three owed lists with these.

```markdown
## Owed to M2

- **Brief §4.3's ranges are in the brief alone,** with no record: `blake2b`'s size and key
  lengths, checked before C; `random-bytes 0` answering `#vu8()` without C; and
  `constant-time-bytevector=?` answering `#f` on unequal lengths without C. M2's plan restates
  them.
- **The bindings:** `randombytes_buf`, `crypto_generichash` with its six sizes, and
  `sodium_memcmp`, each with its convention row, its decoy entry, its `missing-api` row and its
  return codes (row 22), at the floor and the current release.
  - `unsigned-64` joins the argument allow-list with `crypto_generichash`'s `inlen`, and `size_t`
    joins the result allow-list with the first size function (ADR-0001, decision 10).
    `test-conventions`' row that only an argument uses `size_t` changes then, and the rows that
    count five entry points (`test-native` E3 and E5, `test-conventions`) grow.
  - The missing-entry rows split again, four ways as in v0.1.1: one suite holds M1's five
    within its 14 children (slice 3's mutation log).
- **Each verb's rows from plan §1's "Waits" column:**
  - 15: its refusals, each before any block, the decoy's log showing no call;
  - 16: its secret parameters refused by kind;
  - 18: under an engine, at every fuel;
  - 24: its blocks, which `test-wipe`'s child names from inside PROC today, so row 24 needs a way
    to reach a verb's.
- **The input cap and its check** (ADR-0007, decision 5), before the section.
- **The refusals' shape.**
  - Each verb refuses its own parameters by their own names, before its section, each leading
    with a rule symbol (ADR-0006, decision 5). `call-with-bytes`' `(not-a-bytevector bytes ...)`
    names its own parameter, and is a net.
  - Scope `global-constraints.md`'s rule-symbol line to a caller's mistake first (M1's closing
    review, M1-F8).
- **Where the verbs live.** In native, or in a library beside it. If beside it:
  - `check-seam`'s rule (f) keeps `foreign-ref` and `foreign-set!` in native, and rule (m) keeps
    every block in `call-with-block`;
  - `test-never-loads`' loaders row, asserted whole, gains the new library.
- **How a verb reads a size,** at the load or at each call, so that ADR-0001 decision 2 (every
  constant read through libsodium's own function) gets the check it lacks.
- **Whether `test-constants` gains a constants half,** each size function against its header's
  macro.
- **A check of the decoy's `volatile uintptr_t` rule,** which nothing holds in M1, since no M1
  entry is `nonnull`.
  - A `-Werror` compile holds it only for a `nonnull` parameter, and `nonnull` is per function.
    In 1.0.22 only `randombytes_buf`'s `buf` and `crypto_generichash`'s `out` are marked.
  - So the check reads the decoy's source: each pointer parameter's only use is its
    `volatile uintptr_t` read ([slice 3's review](research/m1-slice-3-review/README.md),
    S3-F3).

## Owed to M3

- The password verbs and their bindings, two of them collect-safe, and `test-conventions`' rows
  for them, the first to use `collect-safe`.
- `call-with-c-string` for the hash string, and the password's UTF-8 writer.
  - v0.1.1's makes two Scheme copies of its string, which ADR-0008 forbids for a secret.
  - So M3's writers bound every write by the block's size, and answer a string changed
    mid-write as data.
- `&sodium-failed`'s first raise, row 17's M3 half, and its export.
  - `sodium-failed?`, `-function` and `-code` join `(chez-sodium)` (ADR-0012, decision 2).
  - `test-never-loads`' condition child must call them: today its names are written by hand
    (M1's closing review, M1-F6).
- The oracle's hex mode (row 4); the FIFO decoy (row 19).
  - Row 19's threads reference the library once before the first fork: a library first
    reached on two threads at once refuses the second (M1-F10).
- Rows 11 (the password half), 15, 16, 18, 22 and 24 for the password verbs (plan §1).

## Owed to M4

- **The documents' notes from M1:**
  - the first reference under an engine (ADR-0007, amended);
  - the first reference on two threads at once (M1-F10);
  - `sodium_init`'s 1;
  - what wiping cannot reach.
- **The docs rule of `check-floors`** waits for `docs/`.
- **The install-line checks of `test-manifest`** wait for the first release, which writes the
  install lines.
```

Add a short "Owed from M1's closing review" list for any minor not fixed in its PR. M1-F4,
M1-F7, M1-F12 and M1-F13 are the likeliest to wait.

### `progress.md`: the close-outs, newest first

Insert these above M0's close-out.

```markdown
### 2026-11-23 — M1 slice 5: the `floor` and `current` lanes (PR #8)

- **Measured first,** on the host: 1.0.18's tarball is under `releases/old/`, and 1.0.22's
  under `releases/`; three tools agree on each SHA-256; each verifies against its `.minisig`
  with libsodium's published key. In the container, each built with `--prefix` alone and passed
  `make test`, 25 of 25 ([research/m1-slice-5-measurements/](research/m1-slice-5-measurements/README.md)).
- **Built** on `m1-slice-5` by two Sonnet builders, on disjoint files in one tree, from trim
  tables the caller checked first:
  - `build-sodium.sh`, `check-sodium.sh` (with `--discovery`) and `test-ci-sodium`;
  - the lanes in `ci.yml`, `check-ci` and `test-check-ci`.

  158 mutants are logged (101 on the scripts, 57 on `check-ci`)
  ([its mutation log](m1-slice-5-mutation-log.md)). The caller ran `check-sodium.sh` by hand
  against real builds of both releases.
- **Reviewed:** one Opus review found no blocker, 2 majors and 10 minors
  ([research/m1-slice-5-review/](research/m1-slice-5-review/README.md)).
  - The majors were an unguarded top-level read of the floors file, and two build rows that
    ended before the calls that would show the check's env. Both are fixed and watched to fail.
  - Four items went to M1's closing review: the floor-raise list, the image step,
    `build-chez.sh`, and CI's times.
- **CI's run** 45242596732 passed all five jobs twice.
  - **Attempt 1,** with the libsodium caches cold and Chez's warm from earlier PRs, built each
    release serially: the floor in 66 s, falling back to `releases/old/`, and the current one in
    50 s. Each lane's `make test` ran 26 of 26.
  - **Attempt 2** restored both.
  - **`memory`:** the gate's 59 cases, then 26 of 26 suites in about 600 s, the slowest
    `test-check-ci` at 113 s of 450.
  - **`main`:** `check-sodium.sh --discovery` passed on
    `/usr/lib/x86_64-linux-gnu/libsodium.so.23 (system)`, 1.0.18 (library 10.3).
  - **The push run on `main`,** 45249131058, passed too.

### 2026-11-23 — M1 slice 4: the public library (PR #7)

- **Built** on `m1-slice-4` by one Sonnet builder, beside slice 3's, on disjoint files in one
  tree, from a trim table the caller checked first:
  - `(chez-sodium)`, which defines nothing and re-exports ADR-0012's eight M1 names, each `eq?`
    to its definition;
  - `test-public`, and `test-never-loads`, whose children reference the condition exports with no
    libsodium to load.

  38 mutants are logged, with no survivor ([its mutation log](m1-slice-4-mutation-log.md)).
- **Reviewed** with slice 3, in one Opus review
  ([research/m1-slice-3-review/](research/m1-slice-3-review/README.md)): 2 majors and 2 minors on
  slice 4, each fixed. The majors were an unguarded top-level definition, and an engine row that
  read the counts in no fixed order.
- **CI's run** 45233248425 passed all three jobs. `nothreads` refuses nine libraries by name,
  `(chez-sodium)` among them. In the container, the slowest suite under the gate took 69 s of
  450.

### 2026-11-23 — M1 slice 3: refusals end to end (PR #6)

- **Built** on `m1-slice-3` by two Sonnet builders, beside slice 4's, on disjoint files in one
  tree, from trim tables the caller checked first:
  - the decoy, the refusal probe, `library-loading.sls` and six `test-library-loading-*` suites;
  - `make dev` and `check-dev`;
  - CI's `main` running `make build` by discovery;
  - the row tying `every-entry` to the convention table, owed from slice 2.

  53 mutants are logged, and `check-dev`'s eight ([its mutation log](m1-slice-3-mutation-log.md)).
- **Added beyond the plan:** the decoy's `version-bom`, and the probe's `--init-after` and
  `--wipe` (plan §2.2).
- **Measured:**
  - **A child under the gate** takes 3.85 s in the container, not the plan's 2.6 s, so each
    suite runs at most 14 children. On CI's runner the six suites take 46 to 55 s each under the
    gate, about 3.6 to 3.9 s a child (run 45242596732).
  - **The not-found world** is three empty directories, so it lists all ten candidates.
- **Reviewed:** one Opus review over slices 3 and 4 found no blocker, 5 majors and 9 minors,
  3 majors and 7 minors of them on slice 3, each fixed.
  - The majors: a mutant logged as equivalent that was not; eight rows that depended on argument
    order; and an M2 item that misstated what a `-Werror` compile checks.
  - `traps.md` gained "An exit status cannot tell which raise reached the default handler".
- **CI's first run by discovery,** 45211022814, passed.
  - The container always exports `CHEZ_SODIUM_LIBRARY`, so this was the first run of
    discovery's FHS arm, `make build` and `check-dev` by discovery.
  - `make build` named `/usr/lib/x86_64-linux-gnu/libsodium.so.23 (system)`.

### 2026-11-23 — M1 slice 2: the load and the checks of the FFI (PR #5)

- **Built** on `m1-slice-2` by three Sonnet builders, from trim tables the caller checked first:
  - the load and the block helper;
  - `check-seam` with rule (m);
  - the convention table and `test-constants`.

  They shared one tree, on disjoint files, by the owner's choice: the harness's worktrees came
  from `main`, and fast-forwarding one was denied. About 190 mutants are logged
  ([its mutation log](m1-slice-2-mutation-log.md)).
- **Native exports 13 names,** among them `call-with-block`, `call-in-section` and the five raw
  bindings; never `foreign-block` or `free-foreign-block!`.
- **Reviewed:** one Opus review found no blocker, 2 majors and 6 minors, each fixed
  ([research/m1-slice-2-review/](research/m1-slice-2-review/README.md)).
  - The majors: a renamed second import of `memory` got past every check (now E11), and nothing
    held `call-with-block`'s critical before thunk (now D4 and E12).
  - The reviewer ran the load against Ubuntu's 1.0.18 and Guix's 1.0.18 headers, and it passed.
  - `traps.md` gained "A wipe over a freed block passes a plain run".
- **CI's first run,** 45176193659, was the first on the runner's toolchain, GCC 13.3 and
  Valgrind 3.22, against Ubuntu's `1.0.18-1ubuntu0.24.04.1`. It passed all three jobs.
  - `memory` ran 17 of 17, with `test-native` at 12 s under the gate (8 s in the container).
  - The slowest suite was `test-check-ci`, at 68 s.

### 2026-11-23 — M1 slice 1: the pure core (PR #4)

- **Built** on `m1-slice-1` by two Sonnet builders, on disjoint files: `conditions`, `load-state`,
  `discovery` and `verify`, from trim tables of eight v0.1.1 files that the caller checked before
  any code; and the exit checks removed from `counters` and the testing library (ADR-0011,
  amended). Every suite ran red against a stub first. 67 mutants were killed
  ([its mutation log](m1-slice-1-mutation-log.md)).
- **Not reviewed on its own,** against plan §6. M1's closing review read the four libraries and
  their suites, and killed ten further mutants.
- **CI's run** 45226809762 passed all three jobs. `nothreads` refused each new library by name.

### 2026-11-23 — M1 slice 0: the plan and the records (PR #3)

- **Written** on `m1-plan`, from `0b800ed`, by the caller:
  - the M1 plan;
  - ADR-0002, ADR-0003, ADR-0006, ADR-0007 and ADR-0011 amended, and ADR-0012 new;
  - the constraints, the brief, `traps.md` and AGENTS.md to match;
  - the plan's probes, in [research/m1-plan/](research/m1-plan/README.md).
- **Reviewed:** one Opus review found a blocker, six majors and thirteen minors, each fixed
  ([research/m1-slice-0-review/](research/m1-slice-0-review/README.md)).
  - The blocker: v0.1.1's free-failure path would have wiped freed memory. The owner chose the
    wipe fused with the free (ADR-0008, amended).
  - The owner also chose native's load in one section (ADR-0007, amended), which narrows the
    engine wedge to the load's prologue.
  - ADR-0001 is amended for the allow-lists.
- **Accepted:** every record, by the owner, on 2026-11-23, as each status line says. CI's run
  45160419954 passed.
```

### AGENTS.md: "Where the project stands", first bullet

```markdown
* **M1 is done: one verb, `sodium-version`.** M0 built the records, the container, the test
  harness, the memory gate and CI. M1 built the load, the block helper and CI's `floor` and
  `current` lanes ([its plan](.plans/2026-11-22-m1-plan.md)). M2 comes next: `random-bytes`,
  `blake2b` and `constant-time-bytevector=?`, built on M1's helper. `.plans/progress.md` says
  where the project stands and what comes next.
```

The other bullets stand. Optionally, add to the bullet at `AGENTS.md:194`:
"`sodium-version`, which makes no block and calls no C, holds none (ADR-0007, decision 8)".

### README.org: Status

It is right as it stands. If the next step should be named:

```org
*One verb is built so far.* chez-sodium finds libsodium, checks that it is
new enough, and loads it, and =sodium-version= names the version it loaded.
Random bytes, BLAKE2b and the constant-time compare come next, then the
password verbs.
```

Rewrap `README.org:29`, the brief's link line, if `check-floors` permits.

### CHANGELOG.md

No change. AGENTS.md asks for an entry at each release, and the plan gives `CHANGELOG.md`'s
0.1.0 to M4 (plan §3). If the owner prefers Keep a Changelog's running "Unreleased" list, the
entry is:

```markdown
## [Unreleased]

### Added

- `(chez-sodium)`, with `sodium-version` and the predicate and accessors of
  `&sodium-library-unavailable`.
- libsodium found at runtime, by `CHEZ_SODIUM_LIBRARY` or discovery, and refused below 1.0.18.
```

---

## Item 7: ahead to M2

What M1 leaves that M2's plan must know. "Written" means it is in the ledger today.

| Item | Written? |
|---|---|
| The nine new entry points; `unsigned-64` with `inlen` | yes |
| `size_t` joining the result allow-list; the rows that count five | no (M1-F14) |
| The input cap and its check | yes |
| Brief §4.3's ranges, in no record | yes |
| Each verb's own named refusals before the section; `call-with-bytes`' `bytes` refusal only a net | no (M1-F14) |
| The rule symbols M2's refusals lead with; the constraints line scoped first | no (M1-F8) |
| Where the verbs live, and the seam rules that follow | no |
| ADR-0001 decision 2's missing check; whether a size is read at the load or at each call | half: the check yes, the timing no |
| The decoy's pointer rule, held by reading its source | yes |
| The missing-entry rows split four ways | yes |
| Rows 15, 16, 18, 22 and 24 per verb (plan §1's "Waits") | only row 24 |
| Every block made under `call-in-section` (the "Latent" comment), held per verb by row 18 alone | no |
| The gate's budget: `test-check-ci` at 113 s of 450, the library-loading suites at about 55 s and 14 children | no (M1-F2) |
| A first reference on two threads | no (M1-F10) |
| The floor: M2 changes nothing there, but any raise is M1-F3's list | no (M1-F3) |

---

## What was checked and found sound

1. **The code against every record.** It holds them all, but for wording (item 2's table).
   - `native`: the load in ADR-0002's order, in one section, refusals through `load-step`.
   - `memory`: liveness, wipe and free as one step, the table entry deleted before the wipe.
   - `conditions` and `verify`: secrets shown by kind; the strict parse.
   - `discovery`: pure, by world, `.so.26` first, never the bare `.so`.
2. **Slice 1, which had no review.** Read whole, and ten new mutants killed. Its suites' top-level
   definitions that can raise are guarded.
3. **The wipe's length,** mutated one byte long (P1). Killed in a plain run by `test-blocks` and
   the decoy's log, and `test-native` aborts.
4. **`check-ci`'s lane rules.** Eleven mutations of `ci.yml` beyond the slice logs, each killed by
   name (C3), all but the image step and the timeouts.
5. **CI.**
   - Run 45242596732: every job green on both attempts. `main`'s report and discovery check name
     the floor exactly. `nothreads` names nine libraries. The floor lane fell back to
     `releases/old/` and passed its check.
   - The push run on `main`, 45249131058, passed.
   - The action pins equal chez-sqlite3 v0.1.1's.
6. **`make check-guix` on the host,** in a copy: 82 launcher checks, then 26 of 26 in the
   container. Plan §7 asks for it, and no earlier M1 record shows it run.
7. **`make test` in the container,** in a copy: 26 of 26.
8. **AGENTS.md's rules across the 226 files M1 changed** under `src/`, `tests/`, `scripts/`,
   `packaging/`, the Makefile and `.github/`:
   - no milestone, slice, date, "maintainer" or research path in a comment;
   - no checkout, home or scratch path; `/home/ana` is a test's made-up home, and the research
     outputs read `<repo>`;
   - no SQLite leftover but the deliberate refusals: `--no-load`, `CHEZ_SQLITE3_LIBRARY`,
     `not-threadsafe`, `bind-optional`, `__varargs_after`;
   - no secret in a test name: the fixture secret appears only as data;
   - Typed Racket signatures on all eight of `(chez-sodium)`'s exports, and on every export of
     native, memory, counters, load-state, discovery and verify. conditions' accessors are the
     exception (M1-F13).
9. **The rows of brief §8.1 M1 holds.** Each is present (item 3's table).
10. **The ledger's existing owed items.** Each is real and placed right: `unsigned-64` in M2,
    collect-safe in M3, the docs and the install lines in M4.

---

## How each finding was resolved

Fixed in PR #9 by two Sonnet builders and the caller. The owner decided M1-F3, M1-F9, M1-F4 with
M1-F10, and R2-F3 on 2026-11-23. The fixes had a second review on Opus,
[second-review.md](second-review.md), because they change rules. Its findings, R2-F1 to R2-F12,
are resolved below too. Every new assertion was watched to fail ([the closing fixes'
log](../../m1-closing-mutation-log.md)).

### This review

- **M1-F1:** `progress.md`'s Now, owed lists and close-outs for slices 0 to 5 and for #9, from
  this review's drafts, and AGENTS.md's "Where the project stands".
- **M1-F2:** CI's measured times are in slices 2, 3 and 5's close-outs.
- **M1-F3:** ADR-0003's amendment, "raising the floor". ADR-0011's consequence and status point
  at it.
- **M1-F4:** `check-ci` holds each job's image step, line for line, before the first restore;
  each job's `timeout-minutes`; and, after R2-F1, each Chez restore key whole, the image id
  included. `test-check-ci` has 91 new rows, and 26 mutants were killed.
  - The builder's edit of `ci.yml`'s header comment was denied by the permission classifier, and
    was not made. The comment's claim, that each cache is keyed by the runner's release and
    architecture, is now held.
- **M1-F5:** `build-chez.sh` has `--proto '=https'` and `sha256sum` alone, and five scripts trap
  `HUP`, `INT` and `TERM`. No row holds them.
- **M1-F6:** `test-never-loads` takes its condition names from `(chez-sodium)`'s exports, less
  `verb-names`, reached inside a guard after R2-F6. A further export fails a row by name.
- **M1-F7:** the discovery suite writes the FHS list by hand, and a row that runs in every world
  holds it to discovery's own. Two candidates swapped in `discovery.sls` fail it.
- **M1-F8:** the constraints scope the rule symbol to a caller's mistake.
- **M1-F9:** ADR-0001's decision 10 and ADR-0012's consequence are back to their first texts,
  with dated amendments for the allow-lists and for memory imported once. The constraints and
  `foreign-conventions.sls`' comments state each rule.
- **M1-F10:** `traps.md`'s two-thread entry and ADR-0007's amendment, "the first reference on
  two threads", which the constraints and AGENTS.md cite. The probes are committed here.
- **M1-F11:** slice 1's close-out says it had no review of its own, and that this one read it.
- **M1-F12:** the trim tables are in [research/m1-trim-tables/](../m1-trim-tables/README.md).
- **M1-F13:** the comments in the Makefile, `floors.sexp`, `check-test-fails.sh` and AGENTS.md;
  ADR-0007's probe note, corrected after R2-F2; and `conditions.sls`' signatures.
- **M1-F14:** the owed lists, from this review's drafts.

### The second review

- **R2-F1:** above, under M1-F4.
- **R2-F2:** ADR-0007 and `traps.md` say the two counts come from two programs: slice 0's
  review's sweep, which is not committed, and the committed `engine-section.sps`. The caller
  reran the committed one, and it gave 45,158 and 45,159 again.
- **R2-F3:** the owner chose an ADR-0007 amendment for the thread rule.
- **R2-F4:** the ledger names #9, with a close-out for it. The fixes' mutation log is committed,
  and so are these probes.
- **R2-F5:** the thread rule's cause is corrected in ADR-0007, the constraints, AGENTS.md and
  `traps.md`. The caller reproduced it: a main thread that allocates first waits for the
  section, then answers.
- **R2-F6:** `test-never-loads` reaches `(chez-sodium)` through `environment` inside its guard.
  A `(chez-sodium)` that fails to expand now fails three rows by name, not the suite.
- **R2-F7:** `foreign-conventions.sls`' comments, the constraints' line, and ADR-0001's
  amendment's first bullet.
- **R2-F8:** the owed lists are brought up to date.
- **R2-F9:** ADR-0003's list names all of `test-ci-sodium`'s reviewed copies, and the
  constraints' line on `main`.
- **R2-F10:** ADR-0012's "row" is restored and its pointer re-indented. ADR-0007's and
  ADR-0011's status lines note their changes.
- **R2-F11:** slice 0's close-out names its cancelled first attempt.
- **R2-F12:** the wraps the review named, except README.org's link line, which stays long.

## The probes committed here

- `two-threads.sps`, with `lib/toy/slow.sls`, a body that sleeps 1 s: a forked thread and the
  main thread reach it 0.1 s apart. `run-two-threads.out`:
  `#(ready (raised "cyclic dependency involving invocation of library ~s") (later ready))`.
- `two-threads-section.sps`, with `lib-section/toy/slow.sls`, a body in one critical section:
  - `plain` refuses the main thread;
  - `alloc`, which allocates first, waits for the section and answers `ready`.

  `run-two-threads-section.out` holds two runs of each.
- Run each from this directory, in the container:
  `"$CHEZ" --libdirs lib --program two-threads.sps`, and
  `"$CHEZ" --libdirs lib-section --program two-threads-section.sps plain|alloc`.
