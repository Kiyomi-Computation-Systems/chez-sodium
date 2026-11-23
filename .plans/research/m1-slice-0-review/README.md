# M1 slice 0's review

Read-only and adversarial, on Opus, over the M1 plan and the records slice 0 wrote. Its line
numbers are those of the tree it read. How each finding was resolved is at the end.


Read-only, on Opus, over the M1 plan and the record changes on `m1-plan` (uncommitted), against
`main` (`0b800ed`) and chez-sqlite3 v0.1.1 (`960d9f0`). No project file was changed. Probes ran
in the container from a copy at `build/review-m1/`, which was removed at the end. Nothing was
committed, pushed or installed.

Line numbers are those of the working tree at review time.

**Counts: 1 blocker, 6 majors, 13 minors.**

---

## Findings

### S0-F1 (blocker): the new wipe writes freed memory on a path v0.1.1's kept rows exercise

- **Where:** `.plans/2026-11-22-m1-plan.md:80` (native: keep `call-with-block` and
  `call-with-bytes`, add the wipe "just before `free-foreign-block!`") and `:93` (`test-native`:
  "the helpers" kept); `.plans/decisions/0008-every-block-wiped-before-free.md:27-30`.
- **Evidence:**
  - v0.1.1's `call-with-block` has a free-failure path, "a free that failed, as when PROC freed
    the block itself" (`../chez-sqlite3` `src/chez-sqlite3/private/native.sls:319-320`,
    `:356-359`).
  - v0.1.1's `test-native` exercises that path for each helper: "call-with-bytes raises a failed
    free outside its critical after thunk: a PROC that freed its block itself makes
    free-foreign-block! refuse it" (`tests/test-native.sps:2216-2238`, and the header's "the free
    of a block PROC freed itself", `:87`).
  - With the wipe placed just before `free-foreign-block!` in the after thunk, that row wipes a
    block PROC has already freed. That is X-B1, the heap corruption ADR-0008 was written to rule
    out.
  - **Reproduced** (`wipe-after-free.sps`: `foreign-alloc` 32, `foreign-free`, then
    `sodium_memzero` over it, the after thunk's order). Run plainly, it prints `returned` and
    exits 0. Under Valgrind it reports `Invalid write of size 8` twice. So a builder who keeps the
    row and adds the wipe passes `make test`, and fails only under `make test-memory`, with no
    pointer to why.
- **Fix:** decide in the plan, and record it in ADR-0008 or ADR-0012. Either:
  - drop the "PROC freed its block itself" rows and the free-failure branch, since rule (m)
    leaves no `src/` PROC able to reach `free-foreign-block!`. Name what they protected in the
    copy table; or
  - make the liveness check, the wipe and the free one step. For example,
    `free-foreign-block!` takes the wipe as a procedure and calls it after the live-table check,
    under memory's lock and section, before `foreign-free`. `sodium_memzero` then stays native's.
  - Either way, add a row that holds it under the gate.

### S0-F2 (major): AGENTS.md says to let a re-entry through; the plan, v0.1.1 and the records refuse it

- **Where:** `AGENTS.md:220-224`; `.plans/2026-11-22-m1-plan.md:493` (mutant "a re-entry let
  through") and `:498`; brief `:397-400`; `.plans/decisions/0007-one-critical-section-per-verb.md:14-16`.
- **Evidence:**
  - AGENTS.md: "a `dynamic-wind` before thunk that refuses a re-entry replaces the caller's
    condition with its own. **Let a re-entry through.**" chez-sqlite3's AGENTS.md scopes the
    same rule: "as `call-with-database`'s before thunks do".
  - v0.1.1's `call-with-block` refuses the re-entry from its outer before thunk
    (`native.sls:337-339`). It marks this "Latent", safe only because "every block is made under
    a catch-all guard", and lists chez-sqlite3's guards (`:327-336`). Its `test-native` has "a row
    each for re-entry".
  - The plan copies that `call-with-block`, and lists letting the re-entry through as a mutant to
    kill. Brief §6.2 and ADR-0007 also say `call-with-block` refuses it.
  - **Probed** (`cis.sps`, the plan's `call-in-section` over a v0.1.1-style refusal):
    - bare `call-with-block` under a guard that doesn't match: the outer guard caught
      `"re-entered after its block was freed"`;
    - the same inside `call-in-section`: the outer guard caught the caller's own `mine`.

    So `call-in-section` is the catch-all guard that keeps the refusal latent. No record or plan
    line says so.
  - A builder who follows AGENTS.md lets the re-entry through. An engine resume outside a section
    then runs PROC on a freed block.
- **Fix:**
  - Plan §2.1: `call-with-block` keeps v0.1.1's refusal. Its "Latent" comment names
    `call-in-section` as the guard every verb's block is made under. Test rows that call it
    directly use catch-all guards.
  - AGENTS.md:222: restore chez-sqlite3's scope, "as a wind with nothing to refuse", and add
    "`call-with-block` refuses, under `call-in-section`'s catch-all guard (ADR-0007)".

### S0-F3 (major): rule (m) does not hold "every block is made by `call-with-block`"

- **Where:** `.plans/decisions/0012-the-public-library-and-the-seam.md:44-45`, `:55-56`;
  `.plans/global-constraints.md:43-44`; `.plans/2026-11-22-m1-plan.md:288-290`.
- **Evidence:** rule (m) says only that no library but `native` imports `memory`. Two paths stay
  open:
  - **Inside native.** Any procedure in native can call `foreign-block` and
    `free-foreign-block!` (memory's two exports, v0.1.1 `memory.sls:31`) outside
    `call-with-block`. M2 and M3 add helpers to native (output blocks, `call-with-c-string`), so
    one written that way frees unwiped. `test-wipe` reads only the blocks `call-with-block` frees.
  - **Through a re-export.** Native can re-export memory's names. v0.1.1's rule (g) refuses
    re-exports of `(chezscheme)` names only (`tests/check-seam.sps`, rule (g)). A library that
    imports native would then make blocks with no wipe, and no rule names it. `test-public`
    would catch only a public leak.

  So "rule (m) holds that no other path makes one" (ADR-0012:56) overstates it.
- **Fix:**
  - A `test-native` row that reads native's body as data: `foreign-block` and
    `free-foreign-block!` occur only inside `call-with-block`'s definition, and native's export
    list holds neither.
  - Either a check-seam rule that no library exports a name it imports from `memory`, or the
    same row.
  - Reword ADR-0012 decision 6 and its consequence to name all three parts.

### S0-F4 (major): the records give the engine wedge a mechanism that measures false

- **Where:**
  - `.plans/decisions/0007-one-critical-section-per-verb.md:70-75`, `:87-91`;
  - `.plans/2026-11-22-m1-plan.md:269-270`;
  - `.plans/traps.md:41-42`;
  - `AGENTS.md:214-216`;
  - `.plans/global-constraints.md:127-129`.
- **What they say:** "No section can prevent it: a section defers the expiry to its end, still
  inside the library's body."
- **Probed** (`lib/rv/sect.sls`; `sweep.sps LIB FUEL N`, which abandons the engine after N
  slices, then makes two plain references):
  - **The body:** the same as the plan's `engbody2`, but its work (counter, flag, the
    200,000-step loop) sits in one `critical-section`.
  - **At fuel 1**, abandoning at slices 44,209 to 44,219 wedged the library: "cyclic
    dependency". That is about 11 ticks between the body's invocation and the section's start.
  - **Abandoning at 44,220 or later**, with the section run, never wedged. The next reference
    answered `((body-ran 1) 1)`. Fuels 1, 2, 3, 5, 10 and 20, abandoned at the first expiry after
    the section, all answered the same. Fuels 50, 100 and 1000 completed.
  - **Without the section** (`plain`), every abandon from the body's start to past slice 50,000
    wedged.
- **What this shows:**
  - The expiry is not deferred to the section's end, since an engine spends no ticks inside a
    section (chez-sqlite3 `traps.md`, M1's closing review).
  - The expiry after the section fell after the library was marked invoked.
  - **What stays true:** no code closes the window completely.
  - **What is wrong:** one section over a body's work narrows the window from the whole body
    (for native: dlopen, the binds and `sodium_init`) to the invocation's prologue. The owner
    accepted the amendment on the stated reason, without seeing that option.
- **Fix:**
  - Correct the five places: "a section narrows the window to the ticks before it starts
    (measured: about 11 at fuel 1); it cannot close it".
  - Record whether native's load should run in one section that answers data and raises after.
    That would rework `load-step`, since nothing may raise inside the section. Adopt it, or
    record it as rejected, with the reason.
  - Keep the engine-row rule either way.

### S0-F5 (major): the kept `call-with-bytes` shows a secret by `shown-value`

- **Where:** `.plans/2026-11-22-m1-plan.md:80` (native: keeps `call-with-bytes`; only the copy is
  dropped); `.plans/decisions/0006-errors-and-no-secret-shown.md:56-63`.
- **Evidence:**
  - v0.1.1 refuses a non-bytevector with `(assertion-violation who "not a bytevector"
    (shown-value bytes))` (`native.sls:470-471`). `shown-value` shows a symbol, a number or a
    character list as it is (`conditions.sls:103-114`).
  - In chez-sodium, `call-with-bytes`' BYTES is always a secret parameter: "every string and
    bytevector parameter is secret". So `(blake2b 'hunter2)` would carry `hunter2` as an
    irritant if the verb's own check were missing. That is the very case row 16 names.
  - The plan's §1 row 15 holds "the helpers' own refusals" in M1. A builder copying v0.1.1 writes
    those rows to the leaking shape.
- **Fix:** plan §2.1: `call-with-bytes` refuses through `refuse-secret`, irritants `(RULE
  bytes (kind K))`. Row 16's M1 half covers it with a symbol, a number and a character list.

### S0-F6 (major): ADR-0006's new universal rules contradict pieces the plan keeps unchanged

- **Where:** `.plans/decisions/0006-errors-and-no-secret-shown.md:53-55`;
  `.plans/global-constraints.md:98-99`; `.plans/2026-11-22-m1-plan.md:75` (keeps
  `checked-accessor`, `refuse-field`) and `:79` (memory: "Renames").
- **The rules:** "Every other raise names the public verb", and "A refusal of a caller's mistake
  leads its irritants with a symbol naming the rule".
- **What the kept pieces do:**
  - **`checked-accessor`,** which guards M1's exported accessors, refuses with `(shown-value x)`
    and no rule symbol (`conditions.sls:121-125`). So does `check-who` (`native.sls:290-292`).
  - **Memory's refusals** name `foreign-block` and `free-foreign-block!`. M0's own counters name
    `count-up!` and `count-down!` (main `counters.sls:56-57`, `:85-87`). So the constraint is
    already false on `main`.
  - **A failed `foreign-alloc`** is re-raised as Chez raised it, then again by `call-in-section`.
  - **Chez-sqlite3's rule was scoped:** "Native's earlier refusals don't", in ADR-0013's slice-4
    amendment, the amendment ADR-0006 cites.
- **Fix:** scope the rule:
  - every refusal raised through the public surface leads with a rule symbol, and
    `checked-accessor` gains one, for example `not-a-sodium-library-unavailable`;
  - a helper raises with the WHO it is given;
  - internal invariants (memory, counters, `load-state`) name themselves;
  - a condition Chez raises is passed on as raised.

  Then list in plan §2.1 which kept refusals change.

### S0-F7 (major): the convention allow-lists the plan asks for fail a row it keeps

- **Where:** `.plans/2026-11-22-m1-plan.md:95` ("`size_t` joins both allow-lists; `unsigned-64`
  stays"); `.plans/decisions/0001-bind-libsodium-directly.md:54-58`.
- **Evidence:** v0.1.1's `test-conventions` holds:
  - "the types its rows use are exactly the allowlists' ... no type is allowed that no row uses"
    (`tests/test-conventions.sps:297-304`);
  - an argument-only row: "which the result allowlist refuses" (`:306-310`);
  - `foreign-conventions.sls:262-266`: "Each is exactly the types the table writes there".

  M1's five rows use uptr and `size_t` as arguments, and uptr, int and void as results. So the
  exact lists are `(int uptr size_t)` and `(int uptr void)`:
  - `size_t` is argument-only in M1;
  - no M1 row uses `unsigned-64`.

  A builder following the plan fails both kept rows, or deletes them, losing v0.1.1's guard
  against a table loosened with its binding.
- **Fix:** plan §2.2: M1's allow-lists are exactly its rows' types. `size_t` joins the results,
  and `unsigned-64` the arguments, with the first row that uses each (M2's sizes, M2's `inlen`).
  Read ADR-0001 decision 10 as the end state, or amend it to say "as the rows need them".

### S0-F8 (minor): slices 3 and 4 both edit the Makefile, and the plan says they are disjoint

- **Where:** `.plans/2026-11-22-m1-plan.md:518` (refusals: "the `Makefile` (`dev`,
  `check-dev`)"), `:543-544` ("their files are disjoint"), `:549` (public library: "the comments
  in ... the `Makefile`").
- **Fix:** move the Makefile comment edit to slice 3's refusals agent, or to the caller at the
  join. Or say the two slices share the Makefile, and merge slice 4 after slice 3.

### S0-F9 (minor): "a program that imports the library runs the body at its start" is imprecise

- **Where:** `.plans/decisions/0007-one-critical-section-per-verb.md:73`;
  `.plans/traps.md:42`, `:48-58`; `.plans/2026-11-22-m1-plan.md:265-266`, `:350-351`.
- **Probed:**
  - `import-only.sps` imports `(rv quiet)`, whose body sets a flag, and references nothing. It
    prints `flag at the program's first line: #f`.
  - `import-ref.sps` also references `quiet-value` inside a procedure it never calls, and prints
    `#t`.
  - The plan's `engine-invoke2` both imported and referenced the library.

  AGENTS.md:204 already says it right: a body runs when a binding is referenced. Chez-sqlite3's
  AGENTS.md says "a top-level program runs every body it references before its first line".
- **Fix:** "a program that references any of the library's bindings, anywhere in its text, runs
  its body before its first line". Retitle the trap "must not reference that library".

### S0-F10 (minor): ADR-0003 cites `[ADR-0006]` with no link definition

- **Where:** `.plans/decisions/0003-libsodium-floor-1-0-18.md:84`. The file defines only
  `[ADR-0002]` and `[ADR-0011]`, so GitHub prints the bracket text.
- **Fix:** add `[ADR-0006]: 0006-errors-and-no-secret-shown.md`.

### S0-F11 (minor): stale pointers and one stale sentence

- **`.plans/2026-11-22-m1-plan.md:9`:** "whose 'Owed to M1'". progress.md's heading is now
  "Answered for M1".
- **`.plans/2026-11-22-m1-plan.md:16-17`:** the probes "are in `build/m1-plan/` (ignored)". They
  are now in `.plans/research/m1-plan/`.
- **Brief `:335-337`:** "It carries the verb and libsodium's answer". The amended fields are
  `function` and `code`, with the verb as `&who`.
- **Fix:** update each.

### S0-F12 (minor): §5.1 claims the research files don't carry, and an overclaiming README

- **`.plans/2026-11-22-m1-plan.md:369`:** "1.0.18's file needs only `libc.so.6` and `ld-linux`;
  its soname is `libsodium.so.23`".
  - True: the host's `readelf -d` shows `NEEDED libc.so.6`, `NEEDED ld-linux-x86-64.so.2` and
    `SONAME libsodium.so.23`.
  - But no file in `research/m1-plan/` records it. Add the output.
- **`:368`:** "0, then 1, then 1, on both versions". The third call was made only by
  `version.c`, against 1.0.22. On 1.0.18, `ffi.sps` and the oracle each called twice.
- **`:377`:** "under the gate's options". The `vg-ffi.*.log` files hold no "Valgrind options:"
  list, which the gate's `-v` would print. So say "under Valgrind with `--leak-check=full`",
  which is what the logs show, or rerun with the gate's own flags.
- **`.plans/research/m1-plan/README.md:24-25`:** "`run.sh` and `run2.sh` rerun most of them".
  - They rerun 6 of the README's 13 rows.
  - Not rerun: `engine-invoke3`, which backs ADR-0007's amendment, the oracle sketch,
    freewatch, `gate-child`, the host 1.0.18 run, and the two shell loops, which are not kept.
  - Add a `run3.sh`, or each command line.

### S0-F13 (minor): chez-sqlite3 lessons missing from "Every brief restates these"

- **Where:** `.plans/2026-11-22-m1-plan.md:410-423`.
- **Missing.** Each applies to an M1 slice:
  - **An engine spends no ticks inside a section, so assert the outcome at every fuel, not an
    expiry** (chez-sqlite3 traps, M1's closing review). Relevant to row 18 and `call-in-section`'s
    mutants.
  - **A red run against a check that refuses the whole input proves no row; turn each rule off
    instead** (M1 slice 5). Relevant to rule (m), and to the `check-ci` and `check-sodium.sh`
    rules in slices 3 and 5.
  - **A scanner of forms reads elements, never tails** (M1 slice 2). Relevant to `test-native`'s
    body-as-data rows, `test-conventions` and rule (m).
  - **GNU `env` reads `-u` only before its first assignment** (M1 slice 3). Relevant to
    `test-wipe`'s child, `--discovery`'s "override unset" and `test-never-loads`.
  - **Anchor a row on a line's content, not an occurrence count** (M1 slice 3). Relevant to
    `test-check-ci` as `ci.yml` grows twice.
  - **A program naming an unbound identifier dies before its first line; watch new-export rows
    fail against stubs that are present and wrong** (M4 slice 1). Relevant to slice 4 and to
    slice 1's "red against a stub".
  - **Valgrind logs carry the checkout's path; scrub them before committing** (M2 slice 0).
  - **A positive control for a witness** (chez-sqlite3's M1 plan §3.6). Row 24 should keep a
    standing row in the same child: a block freed unwiped reads verdict 2, and one never freed
    reads 0. Today only the mutants show the interposer can say 2.
- **Fix:** add these lines.

### S0-F14 (minor): the container has no `tar`, `gzip` or `curl` for slice 5's measurement

- **Where:** `.plans/2026-11-22-m1-plan.md:119` ("`build-sodium.sh` needs `curl`, `tar`, `make`,
  `cc` and `sha256sum`, all present"); `:400-402` ("Then in the container, from those files: each
  build's `configure` flags ... `make test` against each").
- **Evidence:**
  - In the container, `tar`, `gzip`, `xz` and `curl` are missing, and so is `cc` (`$CC` is
    `gcc`). ADR-0011 decision 2 leaves `tar` and `xz` out of the manifest until M4.
  - "All present" holds on the runner. `test-ci-sodium` is unaffected: v0.1.1's
    `test-ci-sqlite` shims `curl`, `openssl`, `tar` and `cc`.
- **Fix:** the host unpacks each tarball, and the container builds the unpacked tree. Or the
  manifest gains `tar` and `gzip`, an ADR-0011 amendment. Say "on the runner" at `:119`.

### S0-F15 (minor): two citations to chez-sqlite3 point at the wrong record or rule letters

- **Where:** `.plans/decisions/0012-the-public-library-and-the-seam.md:8`, `:16-17`;
  `.plans/2026-11-22-m1-plan.md:340`.
- **Wrong record:** "re-exports and defines nothing" is cited to chez-sqlite3 ADR-0009, amended.
  That amendment holds the public name and what `check-seam` reads. The empty-bodied re-export
  is chez-sqlite3 ADR-0012's slice-4 note: "`(chez-sqlite3)` re-exports, with an empty body"
  (`0012-explicit-close-and-the-handle.md:164-166`).
- **Rule letters:** "(c) to (k)" (`:18`, `:38`; constraints `:43`) implies a rule (j). v0.1.1 has
  none: "there is no (a), (b) or (j)".
- **Fix:** cite chez-sqlite3 ADR-0012 for the empty body, and write "(c) to (i) and (k)".

### S0-F16 (minor): pieces v0.1.1 has that the copy tables neither keep nor drop

- **`test-native`'s "collect-safe" section,** the FIFO row
  (`../chez-sqlite3` `tests/test-native.sps` header): absent from the row at `:93`. M1 binds
  nothing collect-safe.
- **Native's `answered-null`,** v0.1.1's refusal of a NULL version as `load-failed`: it is
  replaced by `#f` → `below-floor`. Not listed at `:80`.
- **`exact-natural?` and `linux-machine?`:** helpers, kept implicitly.
- **Fix:** list each in its table, with what it protected (plan §2's own rule).

### S0-F17 (minor): the constraints drop part of ADR-0002's amendment, and lines are unwrapped

- **`.plans/global-constraints.md:85-86`:** "each with its convention row, its decoy entry and
  its `missing-api` row". ADR-0002's amendment (`:93-95`) also names row 22.
- **Unwrapped lines,** the kind M0's R-F13 fixed:
  - `.plans/global-constraints.md:106` runs past the file's width;
  - so do the five amended status lines (ADR-0002:3, 0003:4, 0006:3, 0007:3, 0011:3),
    ADR-0007:87 and `AGENTS.md:7`.

### S0-F18 (minor): ADR-0007's decision 7 reads as a license to raise inside the section

- **Where:** `.plans/decisions/0007-one-critical-section-per-verb.md:45-47` beside `:36-37`
  ("Nothing inside may raise").
- **Evidence:**
  - The plan carries the sentence that settles it: "THUNK answers data, and a verb raises what
    that data says after the call" (`:257-258`). The record does not.
  - Probed: a caller's handler runs at depth 0 through `call-in-section`, and at depth 1 for a
    bare raise in a section. So the net works, but a builder could lean on it.
- **Fix:** add the plan's sentence to decision 7. Call the guard a net for a bug, not a channel.

### S0-F19 (minor): the mutex trap is outside §4.3's list, and AGENTS.md drops "abandoned"

- **Where:** `AGENTS.md:211-213`; `.plans/traps.md:16-31`; `.plans/2026-11-22-m1-plan.md:346-352`.
- **Evidence:**
  - Slice 0 added M0 review R-F4's trap and an AGENTS.md line for it. Plan §4.3 lists four traps
    and "the engine rule's one line", and progress says "to match".
  - AGENTS.md's "leaves it held for good" holds only for an engine that is abandoned, as the
    trap says. A resumed one releases the mutex.
- **Fix:** add both to §4.3, and write "an engine abandoned after `with-mutex` takes the mutex,
  and before it winds, leaves it held".

### S0-F20 (minor): two of slice 2's agents can't run their own suites green before the join

- **Where:** `.plans/2026-11-22-m1-plan.md:466-487`.
- **Evidence:**
  - `test-check-seam` requires `allowed-chez-names` to equal what `src/` imports.
    `test-conventions` reads native's forms.
  - Both read `native.sls` and `memory.sls`, which the load agent writes in another worktree.
    Main's `src/` holds only `counters.sls` and `require-threaded.sls`.
  - The plan says the caller joins and reruns, but not which rows each agent should expect red
    until then.
- **Fix:** name those rows in the two briefs. Or give both agents stub headers holding the fixed
  import lists and the five forms.

---

## Checked and found sound

**1. Consistency.**
- **Every accepted decision reads the same** in the plan, ADR-0002, 0003, 0006, 0007 and 0011,
  ADR-0012, the constraints, the brief's §5, AGENTS.md and progress, except as above:
  - `init-failed`: anything but 0 or 1, detail the answer;
  - NULL or malformed is `below-floor`, detail the string or `#f`;
  - `function` and `code`, with the verb as `&who`;
  - the rule symbol first, and `(RULE PARAMETER (kind K))`;
  - no exit checks; the volatile pointer; `LD_PRELOAD` set alone;
  - `call-in-section`, and `sodium-version` without a section;
  - the five bindings; the M1 exports.
- **No stale "only -1" or "the verb, and what libsodium answered"** is left in the records. The
  record count reads ADR-0001 to ADR-0012 in AGENTS.md, and progress says "M1 adds ADR-0012".
- **Links:** every relative link resolves (a script over the slice's files). Every
  `#amendment-2026-11-23-m1s-plan` matches its heading's GitHub slug; the headings use ASCII
  apostrophes. The one gap is S0-F10.

**2. The plan against v0.1.1.**
- Every named source file exists at `960d9f0`, the brief review's `ffi/freewatch.c` and
  `p05-freewatch.sps` among them.
- **Native's fixed imports are exactly what its kept pieces use:**
  - `foreign-sizeof` is dropped with its three users, `sqlite-transient`,
    `call-with-out-pointer` and `c-int?`;
  - `critical-section` is added for `call-in-section`;
  - `dynamic-wind` is Chez's, with `(except (rnrs) dynamic-wind)` as in v0.1.1.
- **Memory's five names** equal v0.1.1's. `library-only-chez-names`, `foreign-entry` included,
  matches v0.1.1's. The "44 SQLite bindings" are 15 + 21 + 5 + 3.
- **The M0 testing library's exports** equal v0.1.1's, so nothing needs restoring there.
- **`test-constants`** already uses `_Generic` at v0.1.1.

**3. The slices.**
- **Slice 1's split is disjoint.** Main's `counters` imports no `conditions`, and no file
  outside the exit-check agent's names `exit-check` (`git grep`).
- **Slice 2's three owners are disjoint.** Slice 5's two are disjoint, and its `ci.yml` and
  `check-ci` edits follow slice 3's.
- **Every item of brief §9's M1 row lands in a slice:**
  - conditions, discovery, the load, the floor, `sodium_init` and `sodium-version`;
  - the block helper, its wipe and one section;
  - the decoy, the oracle and the prototype check;
  - `floor` and `current`, `make build` and `check-dev`.
- **`check-memory-gate`** has cases p and q, and the "unwrapped" case records the gap the wipe
  child relies on.

**4. chez-sqlite3's lessons already carried:**
- message text, raises in sections, `let*`, sentinels;
- the `LD_LIBRARY_PATH` override mutant;
- an allowlist against its complement;
- the keyword alias of `foreign-procedure`;
- tools handed over by path;
- sweeping until the call completes, not to a fixed bound;
- `test-never-loads` referencing every export through `eval`.

**5. The measurements, rerun in the container from the copy, all reproduced:**
- **The C probes:** `version.c` gives 1.0.22, 26.4, minimal 0, then 0 1 1. `prototypes.c` gives
  16 ones and the planted 0.
- **The decoys:** the ternary compiles on `sodium_memzero`, and fails on `randombytes_buf` with
  `-Werror=nonnull-compare`; the volatile form compiles on both. The header confirms it: no
  `nonnull` on `sodium_memzero`, `nonnull` on `randombytes_buf`.
- **Through Chez's FFI:** `ffi.sps` on 1.0.22, on the host's 1.0.18 (10.3, then 0 1) and on the
  decoy. All 36 entries are present.
- **The oracle sketch** reads all three libraries.
- **The engine probes:** `engine-invoke` resumed after 4,809 expiries; `engine-invoke2` in both
  modes; `engine-invoke3` wedged after 824.
- **The interposer:** freewatch gives verdicts 2 and 1. `gate-child` under Valgrind shows both
  preloads in the parent, and a child with no `vgpreload_memcheck` whose verdicts hold.
- **The cost and versions:** Valgrind costs about 2.85 s against 48 ms. The container's world
  matches. GCC 16.2.0, Valgrind 3.27.0, Chez 10.4.0.
- **The host library:** the package `1.0.18-1ubuntu0.22.04.1`, sha256 `f1e78ef8…518f96`.
- **Not found:** no `/home` path in the committed outputs.

**6. The records' substance.**
- **`below-floor` with detail `#f` fits ADR-0006.** v0.1.1's constructor checks only the reason
  and the report, and the detail is already heterogeneous: a string, an entry point's name, an
  integer code.
- **`call-in-section` is sound when THUNK answers data:**
  - its guard's handler runs in the section but only escapes;
  - the catch-all guard always matches, so it never re-enters;
  - the caller's handler runs at depth 0 (probed).
- **The `init-failed` change** has evidence: libsodium documents 0, 1 and -1, and chez-sqlite3
  had two decoy codes for `sqlite3_initialize`.
- **The decoy's pointer rule** holds on GCC 16.2.

## Probe sources (removed with `build/review-m1/`)

- **`lib/rv/sect.sls`:** `engbody2` with
  `(define value (critical-section (set! counter …) (flag-set!) (loop 200000) (list 'body-ran counter)))`.
- **`sweep.sps LIB FUEL N`:** reaches `(rv LIB)` by `eval` in an engine of FUEL ticks a slice,
  abandons after N slices, then references it plainly.
  - Run: `for n in $(seq 44180 44225); do $CHEZ --libdirs lib --program sweep.sps sect 1 $n; done`.
- **`import-only.sps` and `import-ref.sps`:** described in S0-F9.
- **`cis.sps`:** the plan's `call-in-section` over a v0.1.1-style `call-with-block`, under a
  non-matching guard, plus the handler depth read through `(disable-interrupts)`.
- **`wipe-after-free.sps`:** `foreign-alloc`, `foreign-free`, then `sodium_memzero`, run plainly
  and under Valgrind.

---

## Resolution

Each finding was checked against the tree before it was fixed. The owner chose between the two
fixes for S0-F1 and for S0-F4.

| Finding | Resolution |
|---|---|
| S0-F1 | Confirmed in v0.1.1's `call-with-block` and `test-native`. The wipe is fused with the free: `free-foreign-block!` checks liveness, wipes, then frees, as one step (ADR-0008, amended; the owner's choice). |
| S0-F2 | AGENTS.md scopes "let a re-entry through", and names `call-with-block`'s refusal, safe under `call-in-section`'s guard. The plan's native row says the same. |
| S0-F3 | Rule (m) widened to re-exports, and a body-as-data row holds `foreign-block` and `free-foreign-block!` to `call-with-block` (ADR-0012). |
| S0-F4 | Reproduced (`engine-section.sps`, research/m1-plan). The mechanism is corrected in ADR-0007, the plan, `traps.md`, AGENTS.md and the constraints. Native's load runs in one section (the owner's choice); its refusals are taken as data by `call-in-section`'s guard and raised after. |
| S0-F5 | `call-with-bytes` refuses through `refuse-secret` (the plan; ADR-0006, amended). |
| S0-F6 | ADR-0006's rules scoped to the public surface. `checked-accessor` now leads with a rule symbol, in slice 1, watched to fail. |
| S0-F7 | The allow-lists are exactly the rows' types (ADR-0001, amended; the plan). |
| S0-F8 | The Makefile's comment moves to the caller at slice 4's join. |
| S0-F9 | "References any binding", in ADR-0007, the plan and `traps.md`, whose trap is retitled. |
| S0-F10 | ADR-0003 gains the link. |
| S0-F11 | The stale pointers and the brief's sentence are fixed. |
| S0-F12 | §5.1's wording fixed; `readelf-host-1.0.18.out` added; the README says what `run.sh` reruns. |
| S0-F13 | Every lesson joins "Every brief restates these". |
| S0-F14 | Slice 5 unpacks on the host; "on the runner" at the package row. |
| S0-F15 | ADR-0012 cites chez-sqlite3 ADR-0012's slice-4 note, and "(c) to (i) and (k)". |
| S0-F16 | The collect-safe section and `answered-null` are listed as dropped. |
| S0-F17 | Row 22 added; the long prose lines rewrapped. |
| S0-F18 | ADR-0007 decision 7 gains "THUNK answers data", and names the load as its one exception. |
| S0-F19 | Plan §4.4 and AGENTS.md: "an engine abandoned after `with-mutex` takes the mutex". |
| S0-F20 | Slice 2's seam and conventions agents work against stub headers, and name the rows red until the join. |
