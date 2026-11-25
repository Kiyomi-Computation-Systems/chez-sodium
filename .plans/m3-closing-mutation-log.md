# M3 closing mutation log

The mutants behind M3's closing fixes ([research/m3-closing-review/](research/m3-closing-review/README.md)).
Each ran in a whole copy of `src/`, `tests/` and `packaging/`, made with
`shutil.copytree(..., symlinks=True)`, never in place, and each real file passes after it. Three
Sonnet fix agents wrote the parts below, each over its own files; the caller reran the review's
survivors against the fixed suites. The form is Guards, Mutation, Result, Clean rerun.

## The rounding rows

### round-max-ceil
- Guards: new suite rows "verbs on control under pwhash-limits-odd" (1024 refused), "the refusal ... states the range, 17 to 1023"
- Mutation: password-verbs.sls `(div pwhash-memlimit-max 1024)` -> `(div (+ pwhash-memlimit-max 1023) 1024)`, in build/m3c-fix-limits/round-max-ceil
- Result: fails 3 rows: the verbs row, the 17-to-1023 row, the counts/Valgrind row (the accepted 1024 call prints no datum)
- Clean rerun: real tree passes, 8 passes, 0 failures

### round-min-keep-plus
- Guards: same rows (16 refused, message "17 to 1023")
- Mutation: `(+ pwhash-memlimit-min 1023)` -> `(+ pwhash-memlimit-min 0)`, in build/m3c-fix-limits/round-min-keep-plus
- Result: fails the same 3 rows
- Clean rerun: real tree passes, 8 passes, 0 failures

### limits-record-fallback (M3C-F6)
- Guards: "a Password-limits is made, and is no pair, no vector and no list of its numbers"
- Mutation: CHEZ_SODIUM_LIBRARY=/nonexistent/libsodium.so (constructor cannot run); old row in build/m3c-fix-limits/nolib-old passes (16 passes), new row in the tree fails (15 passes, 157 failures)
- Result: new row fails by name
- Clean rerun: real library, 172 passes, 0 failures

## The watchdog

Guards: the child's `kill -0` check after `stop-watchdog!` (`watchdog-gone`), asserted gone in all three rows of tests/test-collect-safe.sps.
Mutation: no-stop-watchdog: both `(stop-watchdog!)` calls in tests/collect-probe.sps replaced by `(if #f #f)` (copy at build/m3c-fix-safe/no-stop-watchdog/).
Result: killed. password-hash and password-verify rows FAIL (watchdog-gone #f, expected #t); control passes (its watchdog had already fired and exited). 6 pass, 2 fail.
Clean rerun: 1.0.22 8/8 (rendezvous 2, 2, 10001 ms); floor 1.0.18 8/8 (2, 2, 9999 ms); gate (make test-memory, MEMORY_SUITES=tests/test-collect-safe.sps) pass in 36 s. No probe/watchdog processes or FIFO dirs left.

## The no-memory row

| Guards | Mutation | Result | Clean rerun |
|---|---|---|---|
| the 'sensitive hash row and the capped verify row: the cap is the cause | `no-limit/`: the capped children (hash-sensitive, capped verify) run with no `ulimit` | FAIL x2: hash answers `(hash ok ...)` not code -1; verify answers `#t` not `#f`; 3 pass, 2 fail, exit 1 | clean copy: 5 pass, exit 0 (1.0.22 and 1.0.18, and under the gate) |
| the code -1 row: password-hash raises with the code libsodium answered | `hash-any-code/`: password-verbs.sls `(if (eqv? code 0)` replaced by `(if #t`, so any code takes the hash path | FAIL x1: raised code 0 not -1; 4 pass, 1 fail, exit 1 | same |
| the verify row: short memory is #f, not a raise | `verify-raises/`: password-verify raises `&sodium-failed` when the code is -1 | FAIL x1: `(verify raised)` not `(verify #f)`; 4 pass, 1 fail, exit 1 | same |

## The caller, against the review's survivors

### round-max-ceil and round-min-keep-plus

- Guards: `test-library-loading-password-limits`
- Mutation: the review's two rounding mutants, with the fixed suite, decoy and probe copied in
- Result: each fails 3 rows, among them `verbs on control under "pwhash-limits-odd"` and the `17 to 1023` row; 5 pass
- Clean rerun: the real files pass, 8 of 8

### no-stop-watchdog

- Guards: `test-collect-safe`'s three rows
- Mutation: both call sites of `stop-watchdog!` replaced by `(if #f #f)`, its definition kept
- Result: the two verb rows fail, `watchdog-gone` being `#f`; the control passes, its watchdog having fired and exited; 6 pass
- Clean rerun: the real files pass, 8 of 8

### no-limit

- Guards: `test-no-memory`
- Mutation: the capped children run with no `ulimit`
- Result: the `'sensitive` hash row and the capped verify row fail; 3 pass
- Clean rerun: the real files pass, 5 of 5, at 1.0.22 and at the floor
