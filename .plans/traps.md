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
  section, it answered `((body-ran 1) 1)` ([research/m1-plan/](research/m1-plan/README.md)).
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

## Editing the records

None yet.

[ADR-0007]: decisions/0007-one-critical-section-per-verb.md
[ADR-0011]: decisions/0011-the-harness-after-chez-sqlite3.md
