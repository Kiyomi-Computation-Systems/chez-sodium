# M0 memory gate mutation log

Evidence that each rule of `make test-memory` that the sabotage cases of `make check-memory-gate` did
not already hold fails through the property it names. Format of `m0-harness-mutation-log.md`: Guards,
Mutation, Result, then a clean rerun.

The gate's own sabotage groups (a, b, e to m, p, q, r: Valgrind's options, suppressions, evidence,
logs, awk, children, SLOW) are the sabotage this log leaves alone: each is a mutation of the gate
already, and `make check-memory-gate` runs all of them (54 cases before the cases below, 58 after). What this log adds is the rules that had no case, so the first three rows are gaps the
mutations found, closed by new cases, and the later rows are rules that already had a check.

Every run was in the Guix container (`scripts/guix-env`): Chez 10.4.0 (threaded), libsodium 1.0.22,
gcc 16.2.0, Valgrind 3.27.0, x86_64. Each mutant changed one file in place, by one exact replacement
that matched once, and the file was restored from a copy taken before; the clean rerun below shows
nothing stayed changed. The cases that a mutation targets were run alone, by running the script's
prelude and those cases (`build/partial.sh`, not kept), so each row says which cases ran.

## Rules of `test-memory` that had no case

The first run of these two mutations showed the gate green: no case read the limit's quarters, nor
test-memory's question of Valgrind's `default.supp`. The cases `g quarters` and `g default.supp` were
added to `tests/check-memory-gate.sh`, and the rows below are the mutations run against them.

| Mutation | Guards | Result |
|---|---|---|
| Q1: Makefile, `test-memory`, the `case $((limit4 % 4))` that adds `.25`, `.5` and `.75` to the limit replaced by a case that never matches | the limit is three quarters of `MEMORY_TIMEOUT`, to the quarter second | `g quarters` fails for 5, 6, 7 and 9: the time line says `within 3s`, not `3.75s`, and so on. 8 and 12 give whole numbers and stay green, as they must |
| D1: Makefile, the `wc -l` test of the `default.supp` answer from `-ne 1` to `-lt 1` | test-memory takes one `default.supp` and no more | `g default.supp (twosupp)` fails: wanted the refusal line, got the suite's own FAIL line, and "a suite ran" |
| D2: Makefile, the pattern `/*/default.supp)` to `*default.supp)` | the `default.supp` it names is an absolute path | `g default.supp (relsupp)` fails the same way |

## Rules that already had a check

| Mutation | Guards | Result |
|---|---|---|
| P1: Makefile, `test-memory: deps` to `test-memory:`, run as `make test-memory SRFI_LIBS=build/nolinks MEMORY_SUITES=tests/test-counters.sps` | test-memory links chez-srfi itself, and a fresh tree needs it | `FAIL tests/test-counters.sps (exit 255)`, `Exception: library (srfi :64) not found`. The clean Makefile, same command: `pass tests/test-counters.sps` |
| P2: Makefile, `.PHONY` without `test-memory` | every target `make help` lists is `.PHONY` | `make check-help` fails: `make help lists 'test-memory', which is not in .PHONY` |
| L1: Makefile, the `echo "  Valgrind's log: ..."` line of a FAIL replaced by `:` | a FAIL names Valgrind's log, so a CI log says where to look | no case read the line before (the gate compared only the `test-memory: ` lines and Valgrind's markers). Case `b` now reads it and the suite's log line; with the mutation it fails: `no "  Valgrind's log: build/memory/memory-plant-leak.valgrind" in .../out` |
| X1: `tests/memory-plant-overrun.sps`, the write at `size` moved to `(- size 1)` | the overrun plant writes one byte past its block | `b memory-plant-overrun` fails: `make test-memory exited 0`, the plant passes, and its log has no `Invalid write of size 1` |
| X2: `tests/memory-plant-leak.sps`, `(foreign-alloc 777)` to `(foreign-free (foreign-alloc 777))` | the leak plant drops a block nothing frees | `b memory-plant-leak` fails: `make test-memory exited 0`, the plant passes |

## Not mutated

- `check-memory-gate`'s passing of `LIBDIRS` to the script: the script's default is the Makefile's
  value, so dropping it is an equivalent mutant.
- The boundary of SLOW (`-gt` against `-ge` on `4 * took` and `limit4`): case `r` plants a suite
  10 s old against a limit of 9 s and one at 7.5 s, and no case runs a suite at exactly the limit.
  A time-based case cannot hit a whole second on purpose.
- The skipped read of children's logs after a HUNG suite (`[ $rc -ne 124 ]`): a suite killed at
  its timeout has no log of a child to read, so removing the test changes no output.

## Clean rerun

After the last restore: `cmp` shows the Makefile, both plants and the script equal to their copies,
and in the container `make test-memory` (`ran 6, passed 6, failed 0, hung 0, slow 0`),
`make check-memory-gate` (`in all 58 cases`, no case FAILED), `make test` (`ran 6, passed 6`),
`make check-test-fails` (`in all 10 cases`), `make check-clean` and `make check-help` pass. On the
host, `make check-guix` prints `ALL CHECKS PASSED`.
