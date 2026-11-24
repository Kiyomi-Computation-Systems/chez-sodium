# M3 plan's probes, set A

Measurements for the password verbs: declarations, prototypes, decoys, constants, return codes
through Chez's FFI, and out-of-memory against a wrong password. Taken by a Sonnet agent; the caller
reran items 2 to 5, which reproduce once the random salts are masked. They ran from `build/m3-plan/a/`, which the container can see.

Run in the container (`scripts/guix-env`): Chez 10.4.0 threaded, GCC, no Python. Four libsodium
builds: `build/slice5/prefix-1.0.18/` (`.so.23`, the floor), `build/slice5/prefix-1.0.22/`
(`.so.26`), the container profile's `libsodium.so.26` (1.0.22), and the workstation package's 1.0.18
(`build/m1-plan/host-1.0.18/libsodium.so.23`). A floor run puts `prefix-1.0.18/include` first on
`C_INCLUDE_PATH`, in front of the old value; every compile is `-I` its own version's `include/` as
well. Source trees: `build/slice5/libsodium-1.0.18/` and `-1.0.22/`. Compiled programs stay in the
directory but are not kept as results. Timings are not measured (set B does that).

Chez bindings: `uptr` for every pointer, `unsigned-64` for `unsigned long long`, `size_t` for
`size_t`. Blocks are `foreign-alloc`'d, hold the C string's bytes then a 0, and are freed after.
Hashes use libsodium's minimum limits (ops 1, memory 8192 bytes) unless stated.

| What | Ran | Got |
|---|---|---|
| 1. The declarations and macros of both releases, and what differs | `run-1.sh` -> `headers-decls.txt` | The three hash functions and the 15 limit/size/prefix functions carry the same attributes at both: `crypto_pwhash_str`, `_str_verify`, `_str_needs_rehash` are each `__attribute__ ((warn_unused_result)) __attribute__ ((nonnull))` (every pointer; no `nonnull(1)` form). The limit functions, `strbytes` and `strprefix` have none. Differences, only these: `_str_verify` and `_str_needs_rehash` spell `str` as `const char str[crypto_pwhash_STRBYTES]` at 1.0.18 and `const char *str` at 1.0.22 (same for `crypto_pwhash_argon2id_*`); `crypto_pwhash_PRIMITIVE` is `"argon2i"` then `"argon2id,argon2i"`. `crypto_pwhash_str`'s `out` is `char out[crypto_pwhash_STRBYTES]` at both. Macros (in `crypto_pwhash_argon2id.h`) are identical: STRBYTES 128U, STRPREFIX `"$argon2id$"`, OPSLIMIT 1U / 4294967295U / 2U / 3U / 4U, MEMLIMIT 8192U / `SIZE_MAX`-conditional 4398046510080U / 67108864U / 268435456U / 1073741824U, PASSWD 0U / 4294967295U. |
| 2. `_Generic` on each function's address against brief 3.4's types, plus two planted wrong rows | `prototypes.c`, `run-2.sh` | `run-2.out`: all 17 rows 1 at both versions. Planted `int` for `unsigned long long` (opslimit of `_str_needs_rehash`) answers 0; planted `size_t` for `unsigned long long` (opslimit of `_str`) answers 0. |
| 3a. Decoy per pointer parameter, tested by ternary, `-Wall -Werror -shared -fPIC` | `decoys/*-ternary.c`, `run-2.sh` | `run-2.out`, same at both versions: all five fail on `-Werror=nonnull-compare`: `_str`'s `out` and `passwd`, `_str_verify`'s `str` and `passwd`, `_str_needs_rehash`'s `str`. |
| 3b. The same through `volatile uintptr_t` | `decoys/*-volatile.c`, `run-2.sh` | `run-2.out`: all five compile (exit 0) at both versions. |
| 3c. A decoy must spell the header's array | `decoys/*.c`; a first draft with plain pointers, not kept | A decoy that defines `str` as `const char *str` against 1.0.18's header fails `-Werror=array-parameter` (all ten files, both kinds, and `out` as `char *out` at 1.0.22 too). The kept decoys spell `out` as `char out[crypto_pwhash_STRBYTES]` and `str` as the array under `-DSTR_ARRAY` (1.0.18) or the pointer (1.0.22). |
| 4a. The 14 size and limit functions `() size_t`, `strprefix` `() uptr`, on four libraries | `consts.sps`, `run-3.sh` | `run-3.out`, identical on all four: strbytes 128; passwd 0 and 4294967295; ops min 1, max 4294967295, interactive 2, moderate 3, sensitive 4; memory min 8192, max 4398046510080, interactive 67108864, moderate 268435456, sensitive 1073741824; prefix `"$argon2id$"`. |
| 4b. Header macros against the functions | `macros.c`, `run-3.sh` | `run-3.out`: every macro agrees with its function at 1.0.18 and 1.0.22, `STRPREFIX` included. |
| 4c. KiB multiples, 32-bit fit | `consts.sps` | Each of `memlimit_min`, `_max`, `_interactive`, `_moderate`, `_sensitive` is a multiple of 1024: /1024 = 8, 4294967295, 65536, 262144, 1048576. `opslimit_max` (4294967295) and `memlimit_max / 1024` (4294967295) both fit an unsigned 32-bit number, with no room: each is exactly 2^32-1. |
| 5a. `crypto_pwhash_str` in range | `codes.sps`, `run-4.sh` | `run-4.out`, same on all four (but the salt and tag). Answer 0; string length 93 at ops 1, memory 8192; the 34 bytes after the NUL up to strbytes are all 0, none still 0x5a (the whole 128-byte out is written). |
| 5a. Each -1 | `codes.sps` | -1 with all 128 bytes of `out` zeroed (none left 0x5a) for: ops 0; ops 2^32; ops 2^64-1; memory 0; memory 8191; memory `memlimit_max`+1; memory 2^64-1. Memory above its maximum **can** be passed as `size_t` (max+1 is far below 2^64); it answers -1. |
| 5a. Empty password | `codes.sps` | Length 0 on a 1-byte block: 0, and a valid string. |
| 5a. Memory 16*1024+1 at ops 2 | `codes.sps` | Parameter field `m=16,t=2,p=1`: floored to whole KiB. |
| 5a. Ops 2, memory 16 KiB: the shape | `codes.sps` | Field `m=16,t=2,p=1`; fields `$argon2id$`, `v=19`, params, salt 22 chars, tag 43 chars; total length 94. |
| 5b. `crypto_pwhash_str_verify` | `codes.sps` | `run-4.out`, identical on all four. right password 0; wrong -1; `"garbage"` -1; `""` -1; hash + `"\0junk"` (bytes held in the block) **0**; hash + `"junk"` -1; hash + `"\n"` -1; space + hash -1; `"a\0b"` against its own hash 0; `"a"` against it -1; empty against its own 0 and `"x"` -1. |
| 5b. Long valid hash | `codes.sps` | Built as `probe_pwhash.c` does (`crypto_pwhash` with a 64-byte tag, `sodium_bin2base64` variant 3), 136 characters (strbytes 128): right password 0, wrong -1. |
| 5b. Non-ASCII | `codes.sps` | `"pässwörd€"`, 13 UTF-8 bytes: against its own hash 0; last character changed to `$` -1; Latin-1 bytes (with the euro as Windows-1252 0x80, since Latin-1 has none) -1; Latin-1 bytes without the euro -1; `"pässwörd"` UTF-8 -1. |
| 5c. `_str_needs_rehash`, limits | `codes.sps` | Identical on all four. Same limits 0; ops+1 1; memory x2 1; memory +1023 bytes **0**; +1024 bytes 1; -1 byte 1; hash made at ops 3 against ops 1 1; hash made at 4x memory against the minimum 1; `"garbage"` -1; long valid hash -1 (also against ops+1). |
| 5c. argon2i string (made in C by `mk-argon2i.c`, ops 3, memory 8192; `argon2i-string.txt`) | `codes.sps`, `run-4.sh` | verify right password 0; at ops 3, min memory: **0** (the prefix selects argon2i's own `_needs_rehash`; algorithm is ignored); at ops 4: 1. |
| 5c. Hand-edited strings | `codes.sps` | At memory 8 KiB: `p=4` -1, `p=0` -1 (p=4 needs m >= 32 KiB, so those are decode refusals). On a m=64 KiB hash made at ops 1: unedited 0, **`p=4` 0, `p=2` 0** at the same t and m; verify of the `p=4` string -1. `$argon2d$` prefix -1; `$argon2i$` prefix on an argon2id hash 0; no `$v=` -1; `$v=16` -1; `"$argon2id"` alone -1. |
| 5c. A byte >= 0x80 in the salt | `codes.sps` | **Differs by release.** 1.0.18 (both the tarball and the workstation package): `needs_rehash` 0. 1.0.22 (tarball and profile): -1. Verify is -1 at both. |
| 5c. Hash then `"\0junk"` | `codes.sps` | 0 (C reads to the first NUL). |
| 5c. Limits out of range | `codes.sps` | ops 0 1; memory 0 1; ops 0 and memory 0 1; **ops 2^32: -1**; ops 2^32-1 with `memlimit_max` 1; ops 2^64-1 with memory 2^64-1 -1. |
| 5d. Hand-written preset strings, 3x3 | `codes.sps` | Identical on all four. Rows interactive / moderate / sensitive strings, columns the three presets' limits: `(0 1 1)`, `(1 0 1)`, `(1 1 0)`: each is 0 at its own preset and 1 at the others. Salt 22 chars, tag 43 chars, valid. Salt of 21 chars: -1. Tag of 42 chars: -1. The intact string at its limits: 0. |
| 6a. Under `ulimit -v 49152` (48 MiB), `crypto_pwhash_str` at 64 MiB | `oom.c`, `run-5.sh` | `run-5.out`. 1.0.18: -1, errno 12 (ENOMEM). 1.0.22: -1, errno 12. 8 KiB controls: 0. |
| 6b. Verify, right password, 64 MiB hash made beforehand without the limit (`hash64-*.txt`) | `oom.c` | Without the limit: 0, errno 0, and wrong password -1 errno 22. Under the limit, **1.0.18: -1, errno 22 (EINVAL)**; **1.0.22: -1, errno 12 (ENOMEM)**. |
| 6c. Verify, wrong password, 8 KiB hash, under the limit | `oom.c` | -1, errno 22, at both. |
| 6d. Verify, wrong password, 64 MiB hash, under the limit | `oom.c` | 1.0.18: -1, errno 22. 1.0.22: -1, errno 12. |
| 6e. Other verifies under the limit | `oom.c` | `"garbage"`: -1, errno 22, both. A `$argon2id$` string with its tag missing (decode fails): -1, errno **0**, both, with or without the limit. A string with `m=4294967295` KiB: 1.0.18 -1 errno 22; 1.0.22 -1 errno 12. |
| 6f. The source: where errno is set on `crypto_pwhash_argon2id_str_verify` | `pwhash_argon2id.c`, `argon2.c`, `argon2-core.c`, `crypto_pwhash.c` | Quoted below. |

Rerun, from the repository root (each writes its `.out` beside it; filter the container's locale
warning with `grep -v guile`):

```
scripts/guix-env sh -c 'export C_INCLUDE_PATH=$PWD/build/slice5/prefix-1.0.18/include:$C_INCLUDE_PATH; sh build/m3-plan/a/run-2.sh'
```

and likewise `run-3.sh`, `run-4.sh`, `run-5.sh` (`LIMIT_KB=49152` is its default). `run-1.sh` needs only `sh`
(`sh build/m3-plan/a/run-1.sh > build/m3-plan/a/headers-decls.txt`).

## Item 6: the source, and the answer

Errno on each path of `crypto_pwhash_argon2id_str_verify` (`src/libsodium/crypto_pwhash/argon2/pwhash_argon2id.c`):

- 1.0.18 line 216 and 1.0.22 line 220: `passwdlen > PASSWD_MAX` sets `EFBIG` (unreachable for the binding).
- 1.0.18 line 221 and 1.0.22 line 225: `passwdlen < PASSWD_MIN` sets `EINVAL` (unreachable: min is 0).
- 1.0.18 lines 230-231 and 1.0.22 lines 234-235: `if (verify_ret == ARGON2_VERIFY_MISMATCH) { errno = EINVAL; }`.
  Nothing else sets errno there; every other nonzero `verify_ret` returns -1 with errno as the
  callee left it.
- The dispatcher `crypto_pwhash_str_verify` in `crypto_pwhash.c` (line 187 at both) sets `EINVAL` for a
  string with neither prefix.

What puts MISMATCH in `verify_ret`, in `argon2.c` `argon2_verify`:

- **1.0.18, line 258-259:** `if (ret != ARGON2_OK || sodium_memcmp(out, ctx.out, ctx.outlen) != 0) { ret = ARGON2_VERIFY_MISMATCH; }`.
  A failure of `argon2_hash` (an `ARGON2_MEMORY_ALLOCATION_ERROR` included) is turned into
  MISMATCH, so `errno = EINVAL`, exactly as for a wrong password. This is why the run reads 22 under
  the limit.
- **1.0.22, line 272-273:** `if (ret == ARGON2_OK && sodium_memcmp(...) != 0) { ret = ARGON2_VERIFY_MISMATCH; }`.
  The allocation error stays `ARGON2_MEMORY_ALLOCATION_ERROR`, so `errno` is not set to `EINVAL`.
  It keeps what `argon2-core.c` left: line 102 `mmap(...)` (with `HAVE_MMAP=1` in
  `libsodium-1.0.22/builds/Makefile`'s `DEFS`) fails with `ENOMEM`, which is the 12 in the run. The
  `posix_memalign` path (line 109, `errno = posix_memalign(...)`) and `errno = ENOMEM` (line 117, in
  the no-`posix_memalign` branch) are not the path taken here. At 1.0.18 the same code is at
  `argon2-core.c` lines 93, 100, 108.
- The two small `malloc`s in `argon2_verify` (1.0.18 lines 233, 240; 1.0.22 lines 244, 253) return
  `ARGON2_MEMORY_ALLOCATION_ERROR` before any hashing, with `malloc`'s own errno.

What the runs and source show:

- **1.0.18:** nothing tells "no memory" from "wrong password". Both are -1 with `errno` 22 (run:
  6b, 6c, 6d), and the source folds the failure into MISMATCH. No other return value exists
  (`crypto_pwhash_str_verify` only returns 0 or -1).
- **1.0.22:** the return value is the same -1 in both cases, but `errno` differs in the runs:
  12 (ENOMEM) for the out-of-memory verify (6b, 6d) and 22 (EINVAL) for a wrong password with
  enough memory (the no-limit control, and 6c). This holds only if the caller sets `errno` to 0
  before the call and the allocation failure is `mmap`'s: the ENOMEM is a leftover of `mmap`, not a
  value libsodium sets on purpose, and a string that fails to decode leaves `errno` at 0 (6e), so
  "errno is EINVAL" is not a general "mismatch" signal either. A binding that wants it must read
  `errno` immediately after the call, by a means that does not run Scheme between (a Chez foreign
  call that reads `__errno_location`, or `(foreign-procedure "__errno_location" ...)`); that was not
  tested here.
- At either release, `errno` is not meaningful for a verify that succeeded (it is 0 here, not reset by
  libsodium).

## Where the brief is false or incomplete

1. **Brief 3.4, `crypto_pwhash_str_verify`: "-1 for ... no memory: at 1.0.18 errno reads `EINVAL`
   either way (L-F2)" is true at 1.0.18 and incomplete.** At 1.0.22 an out-of-memory verify leaves
   `errno` 12 (ENOMEM) while a wrong password leaves 22, with the same -1 (`run-5.out`; the source
   change is `argon2.c` line 258 at 1.0.18 against line 272 at 1.0.22, quoted above). The floor
   cannot tell them apart, so a binding that supports both cannot rely on it.
2. **Brief 3.4, `crypto_pwhash_str`: "nonnull on every pointer" is true; the decoy rule is
   stricter than "volatile for some".** Every one of the five pointers (`out`, `passwd`, verify's
   `str` and `passwd`, rehash's `str`) is a `-Werror=nonnull-compare` failure by ternary and
   compiles through `volatile uintptr_t` (`run-2.out`). Unlike M2, no pointer is exempt
   (`headers-decls.txt`: bare `nonnull`, not `nonnull(1)`).
3. **Brief 3.4 (L-F7), array sizes: the header's spelling changed between the releases.** 1.0.18 declares
   `str` of verify and rehash as `const char str[crypto_pwhash_STRBYTES]`, 1.0.22 as `const char *`
   (`headers-decls.txt`). A decoy that is correct for one is an `-Werror=array-parameter` failure at the other
   (seen in a first draft that spelled both as pointers: all ten files failed at 1.0.18, and the two `out` decoys at 1.0.22; that output is not kept). Also, at 1.0.18 gcc's
   `-Werror=stringop-overread` rejects `crypto_pwhash_str_verify("garbage", ...)` from a C literal (reading 128
   bytes from a region of 8), though the library reads only to the NUL (`oom.c` had to copy it into a 512-byte
   buffer).
4. **Brief 3.4, constants: "memory 8192 to 4398046510080 bytes" and "every value fits both" are right, and
   incomplete.** `memlimit_min`, `_max` and the three memory presets are multiples of 1024 (/1024: 8,
   4294967295, 65536, 262144, 1048576); `opslimit_max` and `memlimit_max/1024` are each exactly 2^32-1
   (`run-3.out`, `consts.sps`). So `crypto_pwhash_str_needs_rehash`'s checks `opslimit > UINT32_MAX` and
   `memlimit/1024 > UINT32_MAX` (source: `_needs_rehash` in `pwhash_argon2i.c`, the same test at both releases) accept every in-range value and
   refuse nothing of them.
5. **Brief 3.4, `crypto_pwhash_str_needs_rehash`: "0 when t and m/1024 match; 1 when either differs;
   -1 when it cannot parse" omits that it also answers -1 for ops above 2^32-1 or memory/1024 above 2^32-1.**
   Ops 2^32 -> -1, and ops 2^64-1 with memory 2^64-1 -> -1 (`run-4.out`, 5c). Per the source, `errno = EINVAL`. The
   brief's "never raises because of the hash" is untouched; the -1 here comes from the limits. A binding
   range-checking opslimit before the call never meets it.
6. **Brief 3.4 (L-F6): "ignores p ... and the salt and tag lengths" is true for p but the p ignored is
   only the p that the decoder accepts.** `p=4` at m=64 KiB answers 0 and `p=2` 0, but `p=4` at m=8 KiB answers -1: the
   decoder refuses p when m < 8p KiB (`run-4.out`, 5c). The tag and salt lengths are not ignored in
   general: a 21-character salt and a 42-character tag each answer -1 (5d). The long valid hash (136 chars) is -1
   for rehash because `fodder_len >= crypto_pwhash_STRBYTES` (source), and 0 for verify.
7. **Brief 3.4, `crypto_pwhash_str_needs_rehash`: the algorithm is not "ignored" so much as
   chosen by the prefix.** An argon2i hash at ops 3 answers 0 against ops 3, an argon2id-shaped string with the
   prefix replaced by `$argon2i$` answers 0, and a `$argon2d$` prefix answers -1 (`crypto_pwhash.c` line 193:
   dispatch by prefix, `EINVAL` otherwise). The brief's `password-needs-rehash?` rule, "#t for any hash that is not
   what `password-hash` would make now", must therefore test the prefix itself: C answers 0 for an argon2i hash at
   matching t and m.
8. **A byte >= 0x80 in the salt differs by release (not in the brief).** `needs_rehash` answers 0 at 1.0.18 and -1 at 1.0.22 for the
   same string; verify is -1 at both (`run-4.out`, 5c). A rule or test that depends on rehash's answer for such
   a string cannot be the same on both floors.
9. **Brief 3.4, `crypto_pwhash_str`: "-1 ... with `out` zeroed" is exact.** All 128 bytes of `out` are 0 at every
   -1 (7 cases), and on success the whole 128 bytes are written: string, NUL, then zeros (none left as the old fill).
   So the 128-byte out block holds nothing from before, and a block of strbytes wipes cleanly.
10. **Brief 3.4: "Memory is floored to whole KiB" is exact**: 16*1024+1 gives `m=16`. Memory +1023 bytes against a
    hash of m=8 answers 0 (not different), +1024 bytes answers 1, and -1 byte answers 1.
11. **Brief 3.4 "reads `str` to its first NUL, and refuses any byte after the hash"** (L-F1): confirmed, with the case
    spelled out: "hash + `\0junk`" answers 0 (verify and rehash, since C stops at the NUL), and "hash + `junk`",
    "hash + `\n`" and " " + hash answer -1. A hash string that holds a NUL is judged as its prefix, so the binding's own
    check (printable ASCII, no U+0000) is the only guard (`run-4.out`, 5b).
