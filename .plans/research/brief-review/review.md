# Adversarial review of the brief, 2026-11-22

Reviewed: `.plans/2026-11-22-chez-sodium-project-brief.md` as it stood before its
revision of the same day, which answers every finding below. Read-only reviewers, each
on Opus, each given the brief and the sources but not the maintainer's opinions:

| Reviewer | Lens | Tokens | Tool calls | Time |
|---|---|---|---|---|
| L | libsodium's behaviour, security, the API contract | 238,131 | 68 | 18m 26s |
| X | Chez FFI mechanics, the reuse of chez-sqlite3 | 319,050 | 80 | 21m 41s |
| P | Tests, CI, milestones, the plan's coherence | 290,657 | 74 | 23m 20s |

IDs are the reviewers' own, prefixed by reviewer: `L-F1`, `X-B1`, `P-F1`. Severity:
**blocker** (would build something wrong or unworkable), **major** (a milestone's rework,
or a real bug through), **minor** (accuracy or wording).

"Verified" says what the maintainer's session did with a hand-back:

- **reproduced**: rerun independently, by a probe in `verify/` or a reviewer's probe;
- **read**: confirmed in the cited source;
- **accepted**: taken on the reviewer's evidence, which was read but not rerun.

## The owner's decisions

The review left four questions open. The owner settled them on 2026-11-22, and the
brief's §11 records each one.

1. `password-needs-rehash?` answers `#t` for a hash it cannot read. This is documented
   in detail. The reviewers split here: L said `#t`, P said raise, X said either, so
   long as it is raised after the section.
2. Every block is wiped, not only the password's.
3. Each verb's whole extent runs as one critical section, with inputs capped.
4. Streaming SHA-256 is out; `hmac-sha256` is one call; `bytes=?` stays as a general
   verb. Techo was asked to look keys up by their hash. It recorded that as a proposed
   amendment to its ADR-0006.

Later the same day, the owner renamed two verbs (brief §11.7). The findings below keep
the names the reviewed brief used:
- `generic-hash` is now `blake2b`;
- `bytes=?` is now `constant-time-bytevector=?`.

## L: libsodium and security

| ID | Sev. | Finding | Verified | Brief |
|---|---|---|---|---|
| L-F1 | major | A hash string's block must end in 0. libsodium reads to the first NUL and refuses any byte after the hash. `call-with-bytes` adds no 0. | reproduced (`verify/v1.c`: hash plus junk gives -1); read `native.sls:470-490` | §4.1, §7.2 |
| L-F2 | major | `&sodium-failed` covers less than §5 claimed. Verify answers -1 when it has no memory. A cgroup memory limit gets the process OOM-killed. Misuse, or no entropy source, aborts. | reproduced the verify case (`verify/v3.c`: right password under `ulimit -v` gives -1, errno 22); cgroup kill accepted | §5 |
| L-F3 | major | `(ops . bytes)` invites a KiB-for-bytes mistake: a hash about 1000 times weaker, which needs-rehash then calls current | reproduced (`v1.c`: memlimit 19456 gives `m=19`, needs-rehash 0) | §4.1 |
| L-F4 | major | The wipe policy is inconsistent: other secret blocks are freed unwiped, and the binding's own Scheme copies stay. "A Scheme string cannot be wiped" is inaccurate. | read `native.sls:476` | §6.3 |
| L-F5 | major | RFC 7693 gives one BLAKE2b-512 vector, which cannot catch a dropped key or a wrong size | reproduced (`v1.c`: BLAKE2b-256 is not a truncated BLAKE2b-512) | §8.1 row 1 |
| L-F6 | minor | needs-rehash compares only t and m/1024. It ignores the algorithm and p. Lowered limits also answer 1. | reproduced (`v1.c`) | §4.2 |
| L-F7 | minor | "Shorter than `strbytes`" rejects hashes libsodium verifies: a 136-character hash does | accepted (`libsodium/probe_pwhash.c` §10, method read) | §4.1 |
| L-F8 | minor | generic-hash: C accepts sizes and keys of 1–15 bytes; an empty key means no key; a NULL key with a length aborts | reproduced (`v1.c`) | §4.3 |
| L-F9 | minor | `shown-value` shows a secret passed as a symbol, number or list as it is | read `conditions.sls:105-117` | §5 |
| L-F10 | minor | A stored hash's own t and m decide what verify costs | accepted | §4.1 |
| L-F11 | minor | `bytes=?` has no named use if Techo looks keys up by their hash | Techo's records read | §3.1, §11.4 |
| L-F12 | minor | Timings: interactive is about 55 ms, not "100 ms or more"; large plain calls are not "microseconds" | reproduced (`verify/v2.c`: 0.055 s) | §6.4 |
| L-F13 | minor | Tier 2: streaming SHA-256 has no use; an abandoned HMAC state holds key material; `_init`'s key is `nonnull` at 1.0.18 | accepted | §3.2, §3.3 |
| L-F14 | minor | `_major`/`_minor` are libtool numbers: 10.3 at 1.0.18, 26.x after | reproduced (`v1.c`: 10.3) | §3.4, §7.2 |
| L-F15 | minor | `random-bytes` has no bound but a macro, and `nonnull` holds even at size 0 | accepted | §4.3 |

## X: Chez FFI and reuse

| ID | Sev. | Finding | Verified | Brief |
|---|---|---|---|---|
| X-B1 | blocker | `call-with-secret-bytes` as written wipes after the free: wiping freed memory aborted glibc. A wipe inside PROC misses an engine's expiry. | reproduced (`ffi/p06-secret-wipe-model.sps`: outer 51/51 after free, inner 24/52 unwiped, fused 28/28 clean); read `native.sls:321-364` | §6.3 |
| X-M1 | major | An engine resumed inside a verb raises "re-entered" against a correct caller; §7.3 dropped the engine rule | read `native.sls:141-147` | §6.2 |
| X-M2 | major | A raise inside PROC, under a guard that doesn't match, is replaced by the re-entry refusal | reproduced (`ffi/p07-guard-reentry.sps`) | §5, §6.2 |
| X-M3 | major | The collect-safe row's order judge is fragile, likely fails under Valgrind, and covers one call | accepted | §8.1 row 19 |
| X-M4 | major | Plain calls run long on large inputs; the byte-wise copy costs about 30 ms per MiB | accepted | §4.4, §6.4 |
| X-M5 | major | The floor cannot be held to `floors.sexp` through `_major`/`_minor` | reproduced (with L-F14) | §7.2 |
| X-M6 | major | The header prototype check (`test-constants`) is missing from the reuse plan | read `test-constants.sps:35-56` | §6.1, §7.2 |
| X-M7 | major | Tier 2's streaming state is a handle | read | §3.2, §3.3 |
| X-M8 | major | Secrets other than the password go unwiped (folded into X-B1) | read | §6.3 |
| X-m1 | minor | The range rule names only `int` and `uptr`; a NULL pointer with a nonzero length aborts | accepted | §6.1 |
| X-m2 | minor | chez-libuv's rule is looser than chez-sqlite3's; the brief took the stricter one silently | accepted | §6.1 |
| X-m3 | minor | `native.sls`'s keep-list is incomplete | accepted | §7.2 |
| X-m4 | minor | The load order omits binding the version entries before the floor | accepted | §3.1, §7.2 |
| X-m5 | minor | "Copy nearly as it is" understates the cost: counters, the gate, the seam suites | accepted | §7.1, §7.2 |
| X-m6 | minor | The wipe test needs a named mechanism: a preloaded `free()` interposer in a child | accepted (`ffi/p05-freewatch.sps`) | §8.1 row 24 |
| X-m7 | minor | Discovery's candidate order is unstated | accepted | §7.2 |

## P: tests, CI, milestones

| ID | Sev. | Finding | Verified | Brief |
|---|---|---|---|---|
| P-F1 | blocker | The copied harness cannot pass "CI green on an empty suite" | read `Makefile:351-353`, `tests/check-nothreads.sps:191` | §9 |
| P-F2 | major | The floor's numbering is undecided: the check, the floors file and the decoy cannot agree | reproduced (with L-F14) | §7.2 |
| P-F3 | major | The floor job is defined two ways, and `main` asserts nothing | accepted | §8.3 |
| P-F4 | major | No row shows `password-hash` uses its limits; presets and the default are untested | accepted (`plan/precheck-observable.c`) | §8.1 rows 5–7 |
| P-F5 | major | A binding that passes the character count as the length passes every row | accepted (`plan/mutant-char-length.ss`) | §8.1 rows 3–4 |
| P-F6 | major | The empty-password row cannot tell NULL from a block | accepted (`plan/null-empty-password.ss`) | §8.1 row 11 |
| P-F7 | major | chez-sqlite3's decoy pattern fails `-Werror` against `sodium.h` (`nonnull-compare`) | reproduced (`verify/decoy.c`) | §7.2 |
| P-F8 | major | `shown-value` would put a password of the wrong type in a condition (with L-F9) | read | §5, §8.1 row 16 |
| P-F9 | major | §5's "raised before C" has no rows | accepted | §8.1 row 15 |
| P-F10 | major | Two pre-check rows pass with the pre-check deleted | accepted | §8.1 row 9 |
| P-F11 | major | The vectors test neither the default size nor the key (with L-F5) | reproduced | §8.1 row 1 |
| P-F12 | minor | Decoys reach three refusal reasons, not all six | read `test-library-loading-real.sps:217` | §5, §8.1 row 20 |
| P-F13 | minor | `sodium_init`'s 1 is confirmed only by a decoy | accepted | §8.1 row 21 |
| P-F14 | minor | The random-bytes and `bytes=?` rows pass weak mutants | accepted | §8.1 rows 13–14 |
| P-F15 | minor | The memory gate needs adapting, but one job suffices; libsodium is clean under Valgrind | accepted (`plan/vg-*.log`) | §7.2 |
| P-F16 | minor | Tarball pinning: no published checksums, `-stable` rebuilt, old releases move | accepted | §7.2 |
| P-F17 | minor | needs-rehash ignores the algorithm; there is no policy for a new default (with L-F6) | reproduced | §4.2 |
| P-F18 | minor | Unowned items: ADRs, reference test, CHANGELOG, oracle, decoys, scripts; no versions policy | accepted | §9, §10 |
| P-F19 | minor | Techo waits on M3, the brief said M4 | read Techo's `progress.md:29` | §9 |
| P-F20 | minor | Citations: chez-libuv's tag commit, a stray "(`S/`)", the result allow-list, §5 against §10.8 | reproduced (`git rev-parse v0.11.0` is `afe79a5`) | header, §7, §10 |

## Settled by the review

- **Sonames**, from libtool versions in `configure.ac`: `libsodium.so.23` for 1.0.17
  and 1.0.18, and `libsodium.so.26` for 1.0.19 through 1.0.22.
- **Ubuntu** ships 1.0.18 in 22.04, 24.04 and 26.04. noble's is
  `1.0.18-1ubuntu0.24.04.1`.
- **Guix**: the pinned channel `b532aa7` has 1.0.22.
- **Return codes and threads**: `sodium_init` answers 0 and then 1, and is thread-safe.
  Every Tier 1 call is thread-safe after it.
- **Valgrind**: libsodium runs clean at every limit, with no suppression.
- **Chez types**: `size_t` exists and is unsigned; `unsigned-64` matches
  `unsigned long long`.
- **AWS Signature Version 4**: the key lengths, 44 bytes and then 32, are as the brief
  says. AWS's example was reproduced.
- **Tier 2 states**: their alignment is met by a `malloc`'d block.

## The probes

Every probe's header gives its usage.

| Folder | What it holds |
|---|---|
| `libsodium/` | L's probes. `run_probes.sh` rebuilds them against Guix's 1.0.18; its last cgroup probe starts a transient systemd scope. |
| `ffi/` | X's Chez probes and C helpers. |
| `plan/` | P's probes and its Valgrind logs. |
| `verify/` | The maintainer's independent reproductions. |

Binaries were not kept, nor were the libsodium source trees the reviewers read. Fetch
tags `1.0.18-RELEASE` and `1.0.22-RELEASE` from `https://github.com/jedisct1/libsodium`
to read them again.
