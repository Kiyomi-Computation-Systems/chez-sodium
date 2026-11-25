# M3 closing fixes, re-reviewed: the third exception, the rows and the records

**Reviewer:** Opus, read-only and adversarial.

**Tree:** `m3-closing` at `89a891e`, clean afterwards. The reviewer read:
- `git diff 394cb8c..89a891e`, and the closing review;
- the M3 amendments of ADR-0006, 0007, 0009, 0011 and 0012;
- the constraints, AGENTS.md, brief §4.1 and §8, the plan, progress.md and the mutation log;
- the new suites and probes, `password-verbs.sls`, `library-loading.sls`, the Makefile's
  `test-memory` rule, and `ci.yml`.

**The plan's rule for a re-review:** fixes that change a rule are reviewed again on Opus. One fix
added a third exception to the memory gate's child rule, so this review exists.

**Where the probes ran:**
- in copies under `build/m3c-rereview/`, each made with `shutil.copytree(..., symlinks=True)` of
  `src`, `tests`, `packaging` and `.plans/decisions`, with `build/scheme-libs` linked in;
- with `mutate.py`, `gate-one.sh` (one suite under Valgrind with the gate's eight options),
  `caps.sh`, `vg-caps.sh`, `vg-verify.sh`, `watch-watchdogs.sh`, and `wd/run.sh` and
  `wd/watchdog.sh`;
- through `scripts/guix-env`, at the profile's 1.0.22 and at the floor;
- `wd/run.sh` alone on the host, under dash, which is CI's `/bin/sh`.

No permission check was denied, and nothing outside the copies was left.

**Counts: 0 blockers, 1 major, 3 minors.**

**The caller's checks.** F1's measurement, reproduced in the container:
`sh -c "ulimit -v 524288; exec valgrind <the gate's options> $CHEZ … no-memory-probe.sps
hash-sensitive"` gave `(hash raised "crypto_pwhash_str" -1) (valgrind . yes)`, exit 0. At
1572864 KiB it gave `(hash ok "$argon2id$v=19$m=1048576,t=4,p=1$")`.

**The owner chose on 2026-11-24:**
- to gate every child, which drops the third exception;
- to stop the review loop after this round. The caller verified the fixes by hand.

**Where the fixes are sound:**
- **Mutants:** of 13 planted, 9 failed the new rows. A tenth, a least rounded by 1000, fails other
  suites. The survivors are F2's two and F4's `LD_PRELOAD` mutant.
- **`test-no-memory`:** no row passes for the wrong reason.
  - A cap that kills Chez at boot fails three rows.
  - A 64 MiB cap fails only the `'interactive` control.
- **The rounding rows:** they hold both bounds, the bytes conversion, and the message.
- **The watchdog:** the header's claim is true, in bash and in dash.
- **The comment rule:** clean.
- **CI:** run 45526362780 on `89a891e` passed all five jobs, on Valgrind 3.22.0.

---

## M3C2-F1 (major): the third exception rests on a claim the gate's own Valgrind refutes, and two of its four children are not under a cap at all

- **Where:**
  - ADR-0011's M3 amendment, which said "Valgrind cannot run under `ulimit -v`";
  - `global-constraints.md:274-276`;
  - `tests/test-no-memory.sps:7-10` and `tests/no-memory-probe.sps:10-11`;
  - `test-no-memory.sps:74` and `:95`: `make-run` and `free-verify-run` are `(run-child #f ...)`,
    with no cap.
- **Evidence:**
  - `vg-caps.sh`, under the gate's eight options, at 1.0.22, on Valgrind 3.27.0:
    ```
    524288 KiB hash-interactive: [(hash ok "$argon2id$v=19$m=65536,t=2,p=1$") (valgrind . yes) ] 5s | ERROR SUMMARY: 0 errors
    524288 KiB hash-sensitive: [(hash raised "crypto_pwhash_str" -1) (valgrind . yes) ] 4s | ERROR SUMMARY: 0 errors
    1572864 KiB hash-sensitive: [(hash ok "$argon2id$v=19$m=1048576,t=4,p=1$") (valgrind . yes) ] 26s | ERROR SUMMARY: 0 errors
    ```
  - `vg-verify.sh`, on a real `'sensitive` hash:
    ```
    verify, cap 524288: [(verify #f) (valgrind . yes) ] 5s | ERROR SUMMARY: 0 errors
    verify, cap none: [(verify #t) (valgrind . yes) ] 26s | ERROR SUMMARY: 0 errors
    ```
  - The same at the floor.
  - Headroom under Valgrind for `'interactive`:
    - 131072 KiB is out of memory;
    - 196608 KiB gives -1;
    - 262144 KiB and above succeed.
  - Mutant `nm-free-gated`, with the uncapped children gated: the suite took 58 s, with both child
    logs at 0 errors.
  - No fault in the binding can hide only there. Every path is gated elsewhere: R3, R9, and
    `pwhash-str-fails` with its counts. Unseen were libsodium's own out-of-memory path, which ran
    clean under Valgrind, and the children's counts.
- **Why major:** the rule change is unneeded, and its records state a false reason. The two
  uncapped children fall outside even the exception as written.
- **Fix, the owner's choice:** gate every child, inside the cap; print the counts and the Valgrind
  line; drop the exception; record the measurement. Or keep the exception, with true reasons.

## M3C2-F2 (minor): two watchdog properties the records state are held by no row

- **Mutant `wd-no-parent-check`:** with `kill -0 "$parent" ... || exit 0` removed, the suite
  passes 8 of 8.
- **Mutant `wd-pid-outer`:** with `echo $! >` → `echo $$ >`, the suite passes 8 of 8. A trace
  through `/proc` shows password-hash's watchdog outliving its child by about 9.5 s, while the
  child printed `watchdog-gone #t`.
- **The header's claim is true:**
  ```
  sh marker=yes killed-at=1208ms watchdog-exit=11011ms behind=9802ms fired=no
  dash marker=yes killed-at=1208ms watchdog-exit=11009ms behind=9800ms fired=no
  ```
- **Fix:**
  - `watchdog-gone?` looks in `/proc` for this call's `watchdog.sh`, not in the pid file;
  - either add a row that kills a child from outside, or record the parent check as held by no
    row.

## M3C2-F3 (minor): records the limits rule and the exception left out of step

- **Brief §8.2** still reads "The exceptions are row 5's cheap pair and row 7's one default
  hash", and "No row needs a high limit."
- **ADR-0011 has no amendment for row 22's cheap limits,** though the constraints cite one.
- **The constraints miscount:** they say "two exceptions", then "The third exception".
- **The tripwire.** ADR-0011 says "the byte of 0x80", but the row uses 0xC3, "a byte of 0x80 or
  more". A `channels.scm` bump that moves Guix's libsodium also trips it.

## M3C2-F4 (minor): new comments that misdescribe the code

- `test-no-memory.sps` and `no-memory-probe.sps`: "Valgrind cannot run under a cap" (F1).
- `test-no-memory.sps:12-13`: the `LD_PRELOAD` sentence. Mutant `nm-keep-preload` passes 5 of 5,
  since Valgrind strips its preloads when it execs a child it does not trace.
- `test-no-memory.sps:61`: the comment `output-of` sits over `stdout-of`.
- `no-memory-probe.sps:5-7`: three modes are listed, but there are four.
- `password-verbs.sls:27-32`: it lists the numbers written there, and omits 0, which is
  libsodium's success code, the code of an unreadable string, and `natural?`'s bound.
- "This suite's own process hashes nothing" is a comment with no row.
