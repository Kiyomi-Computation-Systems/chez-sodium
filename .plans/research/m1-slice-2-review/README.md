# M1 slice 2's review

Read-only and adversarial, on Opus, over the load, the seam and the convention table. Its line
numbers are those of the tree it read. How each finding was resolved is at the end.


Read-only and adversarial, on Opus. It covers the uncommitted slice 2 on `m1-slice-2`, read
against `m1-slice-1` (`9161e6e`), the records and chez-sqlite3 v0.1.1 (`960d9f0`). No project
file was changed. The probes ran in the container, from a copy at `build/review-s2/tree/`, which
was removed at the end. Nothing was committed, pushed or installed. Line numbers are the working
tree's at review time.

**Counts: 0 blockers, 2 majors, 6 minors.**

---

## Findings

### S2-F1 (major): a renamed import of memory gets past both rule (m) and E7

- **Where:**
  - `tests/test-native.sps:1177-1200` (E7) and `:1202` (E8);
  - `tests/check-seam.sps:75-86` (rule (m));
  - `src/chez-sodium/private/native.sls:83-84`;
  - `.plans/decisions/0012-the-public-library-and-the-seam.md:60-64` (the consequence: "these
    hold that no other path makes or frees one");
  - `.plans/global-constraints.md:46-47`.
- **Evidence:**
  - E7 and E8 look for the literal symbols `foreign-block` and `free-foreign-block!` in native's
    body, `(cddddr form)`. They never read the import clause.
  - Rule (m) works out the local names memory binds, through `prefix` and `rename`, but uses
    them only to refuse an export. Native is the listed importer, so it may bind memory's
    procedures under any name, and as often as it likes.
  - **Probe P1.** Native gained a second import of memory,
    `(rename (only (chez-sodium private memory) foreign-block free-foreign-block!) (foreign-block raw-block) (free-foreign-block! raw-free))`,
    and a helper `scratch-block`. The helper makes a block with `raw-block` and frees it with
    `(raw-free b (lambda (a n) #f))`, which skips the wipe. Results:
    - `make check-seam`: "the seam holds (8 libraries in 8 files checked)";
    - `test-native`: 63 of 63, E7 and E8 included;
    - `test-conventions`: 51 of 51;
    - `test-check-seam`: 91 of 91.
  - So a block made and freed outside `call-with-block`, never wiped, passes every check.
    `(prefix (chez-sodium private memory) m:)` would pass the same way. ADR-0012 decision 7
    holds in letter, since the two names occur only in `call-with-block`, but not in purpose:
    "every block is made and freed by `call-with-block`".
- **Fix:** close it in one place and record which.
  - Either a `test-native` E-row: native's import clause holds memory exactly once, as the bare
    `(chez-sodium private memory)` or as `(only (chez-sodium private memory) foreign-block free-foreign-block!)`,
    with no `prefix` or `rename`.
  - Or rule (m) gains a third part: a library in `memory-importers` imports memory once, under
    memory's own names. `import-bound` already computes those names.
  - Watch each fail on P1's mutant and on a `prefix` variant. Reword ADR-0012's consequence and
    native's header comment to name the import rule.

### S2-F2 (major): nothing holds `call-with-block`'s critical before thunk; two mutants survive every suite

- **Where:**
  - `src/chez-sodium/private/native.sls:252-257`;
  - `.plans/decisions/0007-one-critical-section-per-verb.md:39-40` (decision 4: "A failure to
    make a block is caught inside and answered as data, as `call-with-block` already does");
  - `AGENTS.md:220` (nothing raises inside a critical `dynamic-wind` thunk).
- **Evidence:**
  - **Probe P2.** The guard in the before thunk was removed:
    `(set! make-failure (guard (c (#t (list c))) (set! block (foreign-block size)) #f))` became
    `(set! block (foreign-block size))`.
    - `test-native` still passed 63 of 63, and `test-wipe` 1 of 1.
    - A direct probe, `(call-with-block 'w (greatest-fixnum) …)` under a
      `with-exception-handler`, showed `foreign-alloc`'s refusal reaching the handler at depth 2:
      interrupts disabled, the condition ADR-0007 forbids.
    - On the real code the same probe answers depth 1, with counts `((block . 0))`.
  - **Probe P3.** `(dynamic-wind #t` became a plain `(dynamic-wind`, so the block's making and
    freeing were no longer critical. `test-native` passed 63 of 63, and `test-wipe` 1 of 1.
  - Neither mutant is in the plan's watch list or the mutation log. v0.1.1 has the same gap,
    but there `call-with-block` was not exported. Here native exports it, which makes a direct
    row cheap: `test-native` has no alias for it today.
- **Fix:**
  - A D-row: `call-with-block` asked for `(greatest-fixnum)` bytes under `handler-depth`. Its
    handler runs at depth 1, its who is `"foreign-alloc"`, neither FILL! nor PROC runs, and the
    counts are zero. P2 must turn it red.
  - An E-row: the first argument of `call-with-block`'s inner `dynamic-wind` is `#t`. P3 must
    turn it red.
  - Add both mutants to the log.

### S2-F3 (minor): the gate-only mutant of S0-F1 is recorded only in the suite's header, and a plain-run kill exists

- **Where:**
  - `tests/test-native.sps:44-53` and `:919-926`;
  - `.plans/m1-slice-2-mutation-log.md` W5g and W6;
  - nothing in `.plans/traps.md`, `AGENTS.md` or `progress.md`.
- **Evidence:**
  - The W6 mutant wipes a dead block before the free, keeping the free's own wipe. A plain run
    passes it, and only `make test-memory` kills it. CI's `memory` job runs `test-native` under
    the gate, so CI holds it.
  - An M2 or M3 builder who changes `call-with-block` and runs `make test` alone sees nothing.
    The only place that warns them is a comment in `test-native`'s header.
  - **Probe P5.** A plain run can see it:
    - with W6 applied, a PROC frees its own 64-byte block of `#x41`;
    - the next `(foreign-block 64)` is the same chunk (glibc's tcache);
    - its bytes 16 to 63, past tcache's two words, read all `#x41` on the real code and all 0
      under the mutant.
- **Fix:**
  - Put that witness in `test-wipe`'s child, which runs outside Valgrind in every run, so it is
    never skipped. Give it a same-chunk control and a named UNAVAILABLE skip, as B5 has.
  - Add a `traps.md` entry: "a write to freed memory exits 0 in a plain run".
  - Name the gate-only mutant in the slice's close-out.

### S2-F4 (minor): B5's comment says the row is skipped under the gate, but not that the gate holds the byte

- **Where:** `tests/test-native.sps:512-521`; the mutation log, Y2.
- **Evidence:**
  - **Probe P4.** With Y2 applied (the empty bytevector's one byte left unwritten),
    `make test-memory MEMORY_SUITES=tests/test-native.sps` gave:
    - B5 printed UNAVAILABLE and was skipped (62 passed, 1 skipped);
    - Valgrind reported "Conditional jump or move depends on uninitialised value(s)" twice;
    - `test-memory: ran 1, passed 0, failed 1`.
  - So under the gate, memcheck's definedness check holds the write, reading B1's comparison.
    In a plain run, B5 holds it. The row is worth keeping.
  - The wipe of a one-byte block is held in every run, the gate's included, by `test-wipe`'s
    `empty-bytes-dirtied` and `return-1` rows. Their child always runs outside Valgrind.
- **Fix:** say both in B5's comment, and add the gated run to the log as Y2g.

### S2-F5 (minor): slice 2's 1.0.18 checks are still open in the records

- **Where:** `.plans/2026-11-22-m1-plan.md` §6, slice 2's watch list ("`test-constants`: each
  kind of wrong row, planted, … on CI's 1.0.18"), and §5.2 ("Record it": Valgrind 3.22 and
  Ubuntu's 1.0.18). The mutation log records 1.0.22 only.
- **Evidence (probe P6, in the container):** the host's `libsodium.so.23` (1.0.18, sha256
  `f1e78ef8…518f96`), and Guix's built 1.0.18 headers
  (`/gnu/store/7rr6w0hwsal5abp7l1gb4lacw24c6qar-libsodium-1.0.18/include`, first on
  `C_INCLUDE_PATH`). Results:
  - `test-constants`: 20 of 20, with every plant answering 0 and every control 1;
  - `test-native`: 63 of 63, with the oracle compiled `-Wall -Werror` against 1.0.18's header;
  - `test-wipe`: 1 of 1, and `test-blocks`: 18 of 18;
  - `make build`'s program: "1.0.18 (library 10.3)";
  - under the gate (Valgrind 3.27): `test-native` 8 s, `test-wipe` 6 s, `test-blocks` 9 s, all
    passing.
  - Still unverified: GCC 13 and Valgrind 3.22, which are CI's.
- **Fix:** cite P6 as interim evidence, and record CI's first `main` and `memory` runs in the
  slice's close-out.

### S2-F6 (minor): a WIPE that re-enters `free-foreign-block!` double-frees

- **Where:** `src/chez-sodium/private/memory.sls:96-106` and `:89-90` ("WIPE must not call back
  into this library").
- **Evidence:**
  - Chez's mutexes are recursive. The entry is deleted only after WIPE returns, so a WIPE that
    frees the same address finds it live, and frees it. The outer call then frees it again.
  - **Probe P7:** "free(): double free detected in tcache 2", exit 134.
  - Only test code can do this, since `src/` hands in `sodium-memzero` alone. The contract is
    written in a comment, not held by the code.
- **Fix:** call `hashtable-delete!` before WIPE, still under the lock and before `foreign-free`.
  The block is still allocated, so the wipe stays valid, and a re-entrant free is then refused as
  not live. Add a W-row that a WIPE which frees its own address is refused unwiped.

### S2-F7 (minor): `progress.md` places `unsigned-64`'s first row in M3; it is M2's

- **Where:** `.plans/progress.md:77-78`: "the first rows that use `collect-safe` and
  `unsigned-64`", under "Owed to M3".
- **Evidence:** `crypto_generichash`'s `inlen` is `unsigned long long`, and it is M2's binding.
  ADR-0001's amendment (S0-F7's fix) says `unsigned-64` joins the arguments with "M2's `inlen`".
- **Fix:** move `unsigned-64` to "Owed to M2", or say "collect-safe" alone there. The same diff
  leaves a list item ending "macro." (`:63`) and another ending "(row 19)." (`:76`) mid-list. Use
  semicolons.

### S2-F8 (minor): two departures from the plan are recorded nowhere but the scratch files

- **Where:** the mutation log, `:4` ("worked in one tree on disjoint files"), against the plan
  at `:505` and `:523` ("each in a worktree of its own"); native's export list,
  `src/chez-sodium/private/native.sls:105-109`.
- **Evidence:**
  - The builders shared one tree, with the stubs under `build/`.
  - Native exports 13 names: the five raw bindings, `call-in-section`, `call-with-block` (which
    v0.1.1 kept private) and the helpers. The plan fixes neither choice. The load trim's flag F2
    records the export list only in the scratchpad.
- **Fix:** state both in the slice's close-out.

---

## Probes

Each ran in the copy, inside the container; each mutant was restored and compared with `cmp`.

| # | Guard | Mutation | Result |
|---|---|---|---|
| P0 | baseline | none | `test-native` 63, `test-wipe` 1, `test-blocks` 18, `test-conventions` 51, `test-constants` 20, `check-seam` passes; all 17 suites ≤ 10 s each; `check-nothreads` names the 8 libraries on the threaded Chez |
| P1 | E7, E8, A3, rule (m) | native imports memory again under `rename`, and `scratch-block` frees with a no-op wipe | survives: check-seam, `test-native` 63, `test-conventions` 51, `test-check-seam` 91 |
| P2 | none found | `call-with-block`'s make guard removed | survives: `test-native` 63, `test-wipe` 1; depth 2 by direct probe (control: depth 1) |
| P3 | none found | the inner `dynamic-wind #t` made plain | survives: `test-native` 63, `test-wipe` 1 |
| P4 | B5; the gate | Y2 under `make test-memory` | B5 skipped; memcheck "Conditional jump … uninitialised" ×2; the gate fails |
| P5 | a proposed plain-run witness | W6, PROC frees its 64-byte block | the next 64-byte block, the same chunk: tail all `#x41` on the real code, all 0 under the mutant |
| P6 | the suites, on 1.0.18 | none | `test-constants` 20, `test-native` 63, `test-wipe` 1, `test-blocks` 18; gated, all pass |
| P7 | none | a WIPE that frees its own address | glibc double-free abort, exit 134 |

---

## Checked and found sound

**1. The load against the records.**
- **ADR-0002's order** is the `let*`: choose, load, bind the three version entries and call each
  once, check the floor from the string alone, bind and call `sodium_init` and check its answer
  (0 or 1), then bind `sodium_memzero`.
  - Every entry point is required, through `bind-required` and `foreign-entry?`.
  - A NULL version is `#f`, and so `below-floor`.
  - E2 holds every step's name, the head of its init and the load's names it uses. A12 holds that
    `sodium_init` was called, and A8 holds the recorded 0 to the oracle's.
- **ADR-0007 decision 9:** everything from discovery to the last bind runs inside
  `call-in-section`. That covers `maps-text`'s file read, `file-exists?`, `dlopen`, the binds,
  the C calls and `sodium_init`.
  - Every refusal inside is our own pure code. Its handler is `call-in-section`'s catch-all
    guard, which only escapes, so the guard never re-enters and no caller's handler runs inside.
  - `load-step` is a macro, so its guard wraps the call and runs after the section. It makes the
    raise serious and records it, and step 0 raises it again. E1 and E4 hold the shape.
- **ADR-0008:**
  - `free-foreign-block!` checks liveness, wipes once over the recorded size, then frees and
    counts down, under the lock in one section. A dead block is refused before the wipe (W3, W7).
  - `call-with-block` hands `sodium-memzero` (E8) and clears `block` first. The wipe never
    follows the free: `test-wipe` would read 2, and W8 under the gate.
  - The one route around this is S2-F1.
- **ADR-0006:**
  - Every refusal carries who and irritants.
  - `call-with-bytes` refuses through `refuse-secret`. B4 holds six kinds, and that no secret
    text appears in the whole condition.
  - Sizes and addresses are shown by `shown-value`. The load's refusals name `chez-sodium` and
    carry the path.
- **The FFI rules:**
  - Every binding is plain, its pointers `uptr` and its length `size_t`.
  - The empty bytevector gets a one-byte block written 0 (B1, B5).
  - Nothing raises in a critical thunk, except as S2-F2 shows is unheld.
  - The re-entry refusal is latent under `call-in-section` (C4), and the "Latent" comment says so.

**2. Checks that cannot fail.**
- Every other new row I read can fail, and the log shows a mutant for each.
- The witness has standing controls: verdict 2 for a block freed unwiped, 0 for one never freed.
- C5 and C6 complete at fuel 4, since all their work is in the section, yet they kill the
  sectionless mutant at fuel 1.
- The rule (m) rows were mutated 23 ways. The conventions' sweeps and complement are exhaustive
  for M1's types.

**3. Trims.**
- `memory`: v0.1.1's `hashtable-contains?` became `hashtable-ref … #f`, which is sound because a
  recorded size is never `#f`.
- `test-blocks` keeps all 11 of v0.1.1's rows and adds W1 to W8.
- Each drop in the three trim tables matches v0.1.1 and keeps its protection, or has none to keep:
  - native's SQLite pieces;
  - the seam's (l), `get-thread-id` and `foreign-sizeof`, each now refused everywhere;
  - the conventions' variadic convention, with a `varargs-refused` fixture;
  - `library-loading`'s tie, owed to slice 3 in the plan.
- The U+FEFF residual became a row that refuses a version string beginning with a byte order
  mark.

**4. Rule (m):**
- It reads `for`, `only`, `except`, `prefix`, `rename`, `library` and a version reference.
- `memory-x`, and `memory extra`, are other libraries.
- `(chez-sodium)` is refused as an importer, and an unreadable import set of memory is named.
- Rule (k) refuses any macro native exports, since native imports names only it may.

**5. The conventions:**
- Form to row: no-row, no-form, the mismatches, bound twice, and strays.
- Row to header: `_Generic` on each of the five, the map from C type to Chez type, and the
  written-out list of the five.
- Together they hold each binding both ways. On 1.0.18's header every prototype answers 1 (P6),
  and its five prototypes are spelled as 1.0.22's.

**6. CI:**
- `main`:
  - `check-seam` reads `src` only;
  - `check-test-fails`' copy holds two libraries, which pass;
  - discovery finds `/usr/lib/x86_64-linux-gnu/libsodium.so.23` in the FHS world, as
    `test-native`'s own choice does;
  - `CHEZ` is exported to the suites;
  - `cc` and `sodium.h` come from `build-essential` and `libsodium-dev`;
  - every suite takes at most 10 s, against a timeout of 300.
- `memory`:
  - the gate passes no `--trace-children`, so the wipe child runs natively on any Valgrind;
  - the slowest suite in the container took 50 s, against a limit of 450.
- `nothreads`:
  - `check-nothreads` finds the libraries itself, and names 8;
  - memory and native import `require-threaded` first, the pattern slice 1's green run proved.
- Unverified: GCC 13 and Valgrind 3.22 (S2-F5).

**7. Comments and records:**
- No milestone, slice, date or research path appears in `src/`, `tests/`, the fixtures, the
  Makefile or `check-test-fails.sh`.
- Every ADR cited in a copied comment points to our record on that subject, and the one sibling
  citation names chez-sqlite3.
- No local path appears in the log.
- Every export of native and memory has a signature comment.

---

## Resolution

| Finding | Resolution |
|---|---|
| S2-F1 | `test-native`'s E11: native imports `(chez-sodium private memory)` exactly once, as the plain set. The caller planted the reviewer's renamed import: E11 fails, and `check-seam` alone still passes. ADR-0012's consequence names the row. |
| S2-F2 | `test-native`'s D4 (a `(greatest-fixnum)` block refused at depth 1, every count zero) and E12 (the inner wind's first argument is `#t`). Each killed its mutant. |
| S2-F3 | `test-wipe`'s child gains the dead-block row, which catches S0-F1's mutant in a plain run; `test-native` also aborts on it. `traps.md` records the trap. |
| S2-F4 | B5's comment and the log say what holds the one-byte block in each run. |
| S2-F5 | The reviewer's 1.0.18 runs are in the mutation log, "Against 1.0.18". |
| S2-F6 | `memory` deletes the table entry before the wipe; `test-blocks`' W9 holds a re-entrant free refused, with no abort. |
| S2-F7 | `progress.md`: `unsigned-64`'s first row is M2's; the list's punctuation fixed. |
| S2-F8 | `progress.md` records the shared tree and native's 13 exports. |
