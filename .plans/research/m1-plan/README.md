# M1 plan's probes

Run in the container (`scripts/guix-env`) on 2026-11-22: Chez 10.4.0 threaded, GCC 16.2.0,
Valgrind 3.27.0, libsodium 1.0.22. `host-1.0.18/libsodium.so.23` is a byte-for-byte copy of the
host's Ubuntu 22.04 `libsodium.so.23.3.0` (`1.0.18-1ubuntu0.22.04.1`, sha256 `f1e78ef8…518f96`).
The M1 plan's §5.1 states the results.

| File | What it asks | Output |
|---|---|---|
| `version.c` | the version functions before `sodium_init`, its answers, `sodium_memzero` | `run.out` |
| `prototypes.c` | `_Generic` on each function's address against the table's C types | `run.out` |
| `decoy-ternary.c`, `decoy-volatile.c` | P-F7 on `sodium_memzero` (no `nonnull`): both compile | `run.out` |
| `decoy-ternary-nonnull.c`, `decoy-volatile-nonnull.c` | P-F7 on `randombytes_buf` (`nonnull`): the ternary fails | `run2.out` |
| `ffi.sps` | the five through Chez's FFI, `foreign-entry?` on 36 names, type sizes | `run.out`, `run-host-1.0.18.out` |
| `oracle-sketch.c` | `dlopen` by path, pointers typed by `__typeof__` | `run-oracle.out` |
| `engine-invoke.sps` | a library body under an engine; abandoned (expired in `eval`'s compile, so inconclusive) and resumed | `run.out` |
| `engine-invoke2.sps` | the same, the program importing the library: its body ran at the program's start, so the eval case is flawed | `run2.out` |
| `engine-invoke3.sps` | the same through `eval` alone, abandoned after the body started: wedged | `run3.out` |
| `engine-section.sps`, `lib/probe/engsect.sls` | slice 0's review: the body's work in one critical section, abandoned before it starts and after it has run (fuel 1) | `run-engine-section.out` |
| `freewatch.c`, `p05-freewatch.sps` | the brief review's `free()` interposer, rerun | `run-freewatch.out` |
| `gate-child.sps` | a child of a Valgrind-run parent, given `LD_PRELOAD` | `run-gate-child.out` |
| (shell loop) | a Chez child loading libsodium under the gate's Valgrind options | `run-vg-cost.out` |
| (shell loop) | the libsodium candidates the container's world holds | `run-world.out` |

`run.sh` and `run2.sh` rerun the version, prototype, decoy and FFI rows, from a copy of this
directory at `build/m1-plan/`: `scripts/guix-env sh build/m1-plan/run.sh`. Each other probe's
header gives its command line. `readelf-host-1.0.18.out` holds the host library's `NEEDED` and
`SONAME`.

Kept here: the sources, the scripts and their outputs. Not kept: the compiled programs, the `.so`
files and `host-1.0.18/`'s copy of the host's library, which the scripts rebuild or copy. Local
paths in the outputs read `<repo>` and `<home>`.
