# Traps: the full accounts

AGENTS.md carries the one-line rule of each trap that binds every task. This file keeps the
incident behind each rule: what happened, how it was found, and what changed. Each account names
the repository it happened in. An account comes with the rule it backs.

The traps the family hit before this repository existed are told elsewhere, and AGENTS.md's
inherited rules cite them:

- chez-sqlite3's `.plans/traps.md`;
- chez-libuv's `AGENTS.md`, under "Traps this repo has already hit". chez-libuv keeps no
  `traps.md`.

## Chez and the FFI

### An abandoned engine leaves a `with-mutex` mutex held

chez-sodium, M0's closing review (R-F4).

- **What happened.** `counters` holds its mutex through `locked`, `(critical-section (with-mutex
  lock (thunk)))`. The review removed the critical section, and every row still passed.
- **Why it matters.** Chez's `with-mutex` takes the mutex in a `dynamic-wind`'s before thunk. An
  engine's expiry runs the after thunks of the winds it escapes, but one between the take and
  the wind escapes none. An engine abandoned there leaves the mutex held, and every other
  thread's count waits for good.
- **Reproduced:** without the section, `count-up!` then `count-down!` in an engine, abandoned at
  each fuel from 1, left the mutex held at fuel 5; another thread's count never answered. With
  it, the engine completed at fuel 6, after 5 expiries, and every count answered.
- **What changed.** `test-counters` gained the critical-section row, which kills the mutant (the
  M0 harness mutation log, C5).
- **The rule:** hold every mutex inside a critical section, as `locked` does.

### A library first reached inside an abandoned engine stays wedged

chez-sodium, M1's plan.

- **What happened.** A library body first referenced through `eval` inside an engine of 50
  ticks, the engine abandoned once the body had started (after 824 expiries), and never resumed.
  Both later references raised "cyclic dependency involving invocation of library". Resumed
  instead, the engine completed.
- **A section narrows the window, and nothing closes it.** An engine spends no ticks inside a
  critical section. With the body's work in one, an engine abandoned in the body's prologue,
  before the section, still wedges the library; one abandoned after the section has run does
  not. The first amendment said a section defers the expiry to its end, inside the body: slice
  0's review measured that false.
- **Where the body runs.** A program that references any of the library's bindings, anywhere in
  its text, runs the body before its first line, outside any engine. A reference through `eval`
  runs it there, which can be inside an engine.
- **Reproduced** with the plan's `engine-invoke3.sps`, and with `engine-section.sps`: at fuel 1,
  the sectioned body abandoned at expiry 45,158, its prologue, wedged; at 45,159, after its
  section, it answered `((body-ran 1) 1)` ([research/m1-plan/](research/m1-plan/README.md),
  `run-engine-section.out`), in every rerun. Slice 0's review's own sweep, a different program
  and not committed, put the edge at slices 44,209 to 44,219, as ADR-0007 has it: the count
  depends on the program, and the edge, the section's start, does not.
- **What changed.** Native's load runs in one section ([ADR-0007], amended after slice 0's
  review).
- **The rule:** every engine row references the library once before its first engine. The
  documents say it, in M4.

### A probe of when a library body runs must not reference that library

chez-sodium, M1's plan.

- **What happened.** The plan's second engine probe, `engine-invoke2.sps`, imported the library
  it meant to reach first inside an engine, and referenced its bindings. The program ran the
  body before its first line, so the engine completed in one step, and the probe measured
  nothing. Importing alone does not run a body; a reference anywhere in the program does (slice
  0's review).
- **Reproduced:** in `import` mode it prints "completed before the flag was seen, after 1
  steps".
- **The rule:** reach the library only through `eval` in a probe of its body's timing, and read
  a flag the body sets to show where it ran.

### A library first reached on two threads at once refuses the second

chez-sodium, M1's closing review (M1-F10).

- **What happened.** A library whose body takes a second, first referenced through `eval` on a
  forked thread and then, 0.1 s later, on the main thread. The thread answered; the main thread
  got Chez's "cyclic dependency involving invocation of library"; a third reference, after both,
  answered.
- **Why.** Chez marks a library as being invoked while its body runs, and a second invocation
  meanwhile reads as a cycle. A critical section defers only its own thread's interrupts, so it
  does not close the window: another thread that reaches the library meanwhile is refused, unless
  it needs a collection first, which waits for the section to end, after which the reference
  answers. So the window is the whole body, and a row that tries to show the race can pass by
  luck.
- **What it means here.** On native, the second thread gets Chez's own condition: not a
  `&sodium-library-unavailable`, and `load-state` never sees it. A program that references the
  library's bindings runs the body before its first line, so only `eval`, the REPL or a lazily
  invoked library can meet it.
- **Reproduced** by the closing review on a toy library and on native itself, with
  `CHEZ_SODIUM_LIBRARY` at Ubuntu's 1.0.18, and again at the fixes, in the container, with the
  committed probes in [research/m1-closing-review/](research/m1-closing-review/README.md):
  - `two-threads.sps`, a body that sleeps: `#(ready (raised "cyclic dependency involving
    invocation of library ~s") (later ready))`;
  - `two-threads-section.sps`, a body in one critical section: a main thread that does not
    allocate is refused, and one that allocates first waits and answers `ready`, two runs each.
- **The rule:** every row that forks a thread which reaches the library references it once
  first ([ADR-0007], amended). The documents say it, in M4.

## libsodium

### `nonnull` is per function

chez-sodium, M1's plan.

- **What happened.** brief §7.2's decoy trap (P-F7): a decoy that tests a `nonnull` parameter
  against NULL fails `-Werror=nonnull-compare`, and GCC may delete the test. The plan's decoy
  compiled the plain ternary on `sodium_memzero`, which `sodium.h` does not mark `nonnull`, and
  failed it on `randombytes_buf`, which it does.
- **Reproduced** on GCC 16.2 against 1.0.22: `decoy-ternary.c` compiles, and
  `decoy-ternary-nonnull.c` fails with "'nonnull' argument 'buf' compared to NULL"; the
  `volatile uintptr_t` form compiles on both.
- **Why it matters.** None of M1's five entry points carries `nonnull`, so a decoy that compiles
  in M1 shows nothing about M2's.
- **The rule:** read every logged pointer through a `volatile uintptr_t`, whether or not that
  entry point is `nonnull` today ([ADR-0011], amended).

## Checks and environment

### A wipe over a freed block passes a plain run

chez-sodium, M1's slice 0 and slice 2 reviews.

- **What happened.** Slice 0's review found that a wipe placed just before
  `free-foreign-block!` would wipe a block PROC had already freed. Slice 2's builder planted that
  wipe: `make test` passed, and only `make test-memory` failed, with Valgrind's "Invalid write of
  size 1" in `__explicit_bzero_chk`.
- **Why.** Writing zeros into a freed glibc chunk usually corrupts nothing a test reads. Only
  Valgrind sees the write.
- **Reproduced** by slice 2's load builder and its reviewer, each under the gate.
- **What changed.** The wipe is fused with the free ([ADR-0008], amended), and `test-wipe`'s
  child, outside Valgrind, catches the mutant in a plain run: a block PROC freed, refilled at
  the same address, must still hold its bytes.
- **The rule:** a mutant of memory safety is run under the gate too, and a row that only the gate
  can fail says so in its suite's header.

### An exit status cannot tell which raise reached the default handler

chez-sodium, M1's slice 3 review.

- **What happened.** Preflight's row for a raise that is no refusal asserted exit 255, an empty
  stdout and no `(reason ` line. Its builder widened preflight's guard from
  `sodium-library-unavailable?` to `error?`, and every row passed, so the mutant was logged as
  equivalent. It is not: the handler's first checked accessor raises in place of the bug, and
  `make build` prints the accessor's complaint, not the bug.
- **Why.** Every uncaught raise ends the same way under Chez's default handler: exit 255, with
  text on stderr. Only that text says which raise it was.
- **Reproduced** by the review and again at the join: on the raising fixture, the clean run's
  stderr names `loaded-libsodium`; the mutant's names `sodium-library-unavailable-candidates`.
- **What changed.** The row requires preflight's stderr to equal that of
  `tests/fixtures/raising/unguarded.sps`, which meets the same raise with no guard. That compares
  two outputs and writes no message (ADR-0006).
- **The rule:** a row about an uncaught raise compares its stderr with the same raise left
  unguarded. An exit status and a missing line can't tell one raise from another.

### In the container, `C_INCLUDE_PATH` set alone loses the kernel headers

chez-sodium, M1's slice 5 measurements.

- **What happened.** A probe compiled against a libsodium built from source, with
  `C_INCLUDE_PATH=PREFIX/include`, failed in the container: `linux/limits.h: No such file or
  directory`, reached from `sodium/export.h` through glibc's `limits.h`.
- **Why.** Guix's gcc has glibc's headers built in, but not the kernel's. `gcc -v` lists the
  profile's `include` first: that is `C_INCLUDE_PATH`, and it alone holds `linux/limits.h`.
  Setting the variable to the build's headers replaces the profile's directory, and the
  kernel's headers with it.
- **Reproduced** at slice 5's measurements, against both builds. The same compile with
  `C_INCLUDE_PATH=PREFIX/include:$C_INCLUDE_PATH` passes, and the probe reads that build's own
  version, `1.0.18` and `1.0.22`.
- **The rule:** in the container, a floor run puts the build's headers first in
  `C_INCLUDE_PATH`, never in its place. On the Ubuntu runner, `PREFIX/include` alone is right,
  as CI's lanes set it: gcc's own system directories still apply.

### Under Valgrind, a suite's `LD_PRELOAD` holds Valgrind's preloads

chez-sodium, M1's plan.

- **What happened.** A program run under Valgrind found `vgpreload_core` and
  `vgpreload_memcheck` in its own `LD_PRELOAD`. A child that appended the wipe row's `free()`
  interposer to it would carry Valgrind's preloads outside Valgrind.
- **Reproduced:** `gate-child.sps` under Valgrind prints both preloads as the parent's
  `LD_PRELOAD`. A child given `LD_PRELOAD=<interposer>` alone maps no `vgpreload_memcheck`, and the
  interposer's verdicts hold there.
- **The rule:** the wipe row's child sets `LD_PRELOAD` to the interposer alone, never appended
  ([ADR-0011], amended).

### A stacked PR conflicts once the one below is squash-merged

chez-sodium, M1's merges of #3 to #7.

- **What happened.** #3 was squash-merged onto `main`. #4, retargeted to `main`, then read
  CONFLICTING, though its parent's tree was exactly `main`'s.
- **Why.** The squash commit is not an ancestor of #4's head, so GitHub merges three ways from
  M0's commit. Slice 1 edits lines next to slice 0's in the same files, so the two sides' hunks
  differ, and they conflict. Identical content alone is not enough.
- **Reproduced:** `git merge-tree --write-tree origin/main <head>` exits 1, as GitHub's check
  does.
- **What worked.** Before each merge, `git commit-tree H^{tree} -p H -p M` made a merge commit
  with the head's own tree, whose parents are the head `H` and `main` `M`. It was pushed as a
  plain fast-forward, with no force-push and no history rewritten. After CI passed on it, the
  squash landed exactly `H`'s tree, and a tree check held that after every merge.
- **The rule:** to merge a stack by squash, bring `main` into each head this way before its merge,
  and check `origin/main^{tree}` against the tested head's tree after it. Budget one CI run a PR.

## Editing the records

None yet.

[ADR-0007]: decisions/0007-one-critical-section-per-verb.md
[ADR-0011]: decisions/0011-the-harness-after-chez-sqlite3.md
[ADR-0008]: decisions/0008-every-block-wiped-before-free.md
