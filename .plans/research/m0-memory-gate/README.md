# Valgrind on the container's Chez, loading libsodium

Question: does Valgrind, with the gate's options and its own `default.supp` alone, report anything
when the container's Chez loads libsodium and calls it through a bare `foreign-procedure`? If it
did, the gate would need a suppression file (brief §7.2 says libsodium ran clean with none).

Answer: no. 0 errors, 0 bytes definitely lost, 0 suppressed.

## The program

`bare-sodium.sps`, beside this file: `load-shared-object`s `$CHEZ_SODIUM_LIBRARY`, binds
`sodium_init` and `sodium_version_string` with `foreign-procedure`, calls both, and prints what
they return. No suite, no library of ours.

## The run

In the container (Chez 10.4.0 threaded, libsodium 1.0.22, Valgrind 3.27.0, x86_64), with exactly
the options `make test-memory` hands Valgrind and no suppression:

```
scripts/guix-env sh -c 'valgrind -v --command-line-only=yes \
  --log-file=build/mm/bare.valgrind --error-exitcode=9 --leak-check=full \
  --show-leak-kinds=definite --errors-for-leak-kinds=definite \
  --child-silent-after-fork=yes \
  scheme --program .plans/research/m0-memory-gate/bare-sodium.sps'
```

Program output, exit status 0:

```
sodium_init: 0
sodium_version_string: 1.0.22
```

Valgrind's log:

```
--4-- Reading suppressions file: /gnu/store/gsixr2n0a6aacsiy6lky6d1fjh7svqyd-valgrind-3.27.0/libexec/valgrind/default.supp
==4==    definitely lost: 0 bytes in 0 blocks
==4==    indirectly lost: 0 bytes in 0 blocks
==4==      possibly lost: 0 bytes in 0 blocks
==4==    still reachable: 1,728 bytes in 5 blocks
==4==         suppressed: 0 bytes in 0 blocks
==4== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
```

`default.supp` was the only suppressions file read. `sodium_init` returned 0 (it returns 1 on a
second call, -1 on failure). Time: 3.4 s wall, container start included. The 1,728 reachable
bytes are not in the gate's `--show-leak-kinds=definite`.

## Each suite under the gate

`scripts/guix-env make test-memory`, six suites, 54 s wall for the target (`deps` and
`require-tools` included). The time is the gate's own line, whole seconds, against the limit of
450 s (three quarters of `MEMORY_TIMEOUT`'s 600 s):

| Suite | Under the gate |
|---|---|
| tests/test-check-floors.sps | 9 s |
| tests/test-check-nothreads.sps | 8 s |
| tests/test-chez-sodium-testing.sps | 13 s |
| tests/test-counters.sps | 7 s |
| tests/test-manifest.sps | 7 s |
| tests/test-require-threaded.sps | 9 s |

All six passed, none SLOW. None of these suites loads libsodium: they run the harness, not a verb.
