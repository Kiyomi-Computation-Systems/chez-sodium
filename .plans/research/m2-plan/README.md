# M2 plan's probes

The measurements behind [the M2 plan](../../2026-11-23-m2-plan.md)'s §5.1, taken by a Sonnet
agent and rerun by the caller (items 3 and 4 reproduce, but for the random bytes). They ran
from `build/m2-plan/`, which the container can see; to rerun one, copy this directory there.

The two fetched files are not kept here. Fetch them into `vectors/` first:

- `rfc7693.txt`, from `https://www.rfc-editor.org/rfc/rfc7693.txt`, SHA-256
  `c943754888364fe29bbd0bb3c71c6658ef392371497eaa4a9d9dde015b0721e5`;
- `blake2b-kat.txt`, from
  `https://raw.githubusercontent.com/BLAKE2/BLAKE2/ed1974ea83433eba7b2d95c5dcd9ac33cb847913/testvectors/blake2b-kat.txt`,
  SHA-256 `82fcb3cabe8ff6e1452849e3b2a26a3631f1e2b51beb62ffb537892d2b3e364f`. M2's slice 2 keeps
  it as a fixture of the suites.

Run in the container (`scripts/guix-env`): Chez 10.4.0 threaded, GCC 16.2.0, Valgrind 3.27.0. Two
libsodium builds from `build/slice5/`: `prefix-1.0.18/` (`.so.23`, the floor) and `prefix-1.0.22/`
(`.so.26`). The container profile's `libsodium.so.26` (1.0.22) and the workstation package's 1.0.18
(`build/m1-plan/host-1.0.18/libsodium.so.23`, a byte-for-byte copy) are run where noted. A floor run
puts `prefix-1.0.18/include` first on `C_INCLUDE_PATH`, in front of the old value. Every compile is
`-I` its own version's `include/` as well. Python 3.10.12 on the host. Paths in the outputs read
`<repo>` and `<home>`. Compiled programs are not kept.

| What | Ran | Got |
|---|---|---|
| The nine declarations, quoted from both versions' headers | `headers-decls.txt` | Identical at 1.0.18 and 1.0.22, but for `sodium_memcmp`'s spacing (`void * const`, then `void *const`). `randombytes_buf`: `__attribute__ ((nonnull))` (every pointer). `crypto_generichash`: `__attribute__ ((nonnull(1)))`, so only `out`. The six size functions and `sodium_memcmp`: no `nonnull` (`sodium_memcmp` is `warn_unused_result`). |
| `_Generic` on each address against brief 3.4's C types, plus two planted wrong rows | `prototypes.c`, `run-1.sh` | `run-1.out`: all nine match (1) at both versions. Planted `int` for `size_t` answers 0, and `size_t` for `unsigned long long` answers 0. |
| Decoy per pointer parameter, tested by ternary, `-Wall -Werror -shared -fPIC` | `decoys/*-ternary.c`, `run-1.sh` | `run-1.out`, same at both versions: `-Werror=nonnull-compare` fails `randombytes_buf`'s `buf` and `crypto_generichash`'s `out`; `in`, `key`, and `sodium_memcmp`'s `b1` and `b2` compile. |
| The same through `volatile uintptr_t` | `decoys/*-volatile.c`, `run-1.sh` | `run-1.out`: all six compile at both versions. |
| The six size functions, each bound `() size_t`, against the header macros | `sizes.sps`, `macros.c`, `run-2.sh` | `run-2.out`: 32, 16, 64; 32, 16, 64 at both versions and on the profile library and the workstation package; the macros agree. |
| `randombytes_BYTES_MAX` | `macros.c`, `sizes.sps`, `run-2.sh` | 4294967295 (2^32-1) at both versions. No function answers it: `foreign-entry?` is `#f` for five guessed names, and none of the `randombytes*` exports of either library (listed in `run-2.out`) is a bound. |
| `crypto_generichash` return codes through the FFI | `codes.sps`, `run-3.sh` | `run-3.out`, identical on all four libraries (only the random bytes differ). outlen 0 -> -1; 1, 15, 16, 32, 64 -> 0; 65 -> -1. keylen 0, 1, 15, 16, 64 -> 0; 65 and 128 -> -1. inlen 0 on a one-byte block -> 0. Every -1 left `out` untouched (128 bytes of 0x5a read back). On 0, nothing past outlen was written. |
| keylen 0 against the unkeyed hash | `codes.sps` | Key blocks of 0x00, 0xff, 0xa5 and an 80-byte 0x11 block with keylen 0 all give `bddd813c...d52319`, the unkeyed BLAKE2b-256 of "abc". keylen 16 differs. |
| `sodium_memcmp` | `codes.sps` | Equal -> 0; first byte only, last byte only, all bytes, in both orders -> -1; length 0 on different blocks -> 0. All 65536 single-byte pairs: only (equal, 0) and (different, -1) occur. A difference is always -1. |
| `randombytes_buf` size 0 on a one-byte block | `codes.sps` | The byte is 165 before and after. Size 16 writes 16 bytes. |
| NULL pointers (not asked; checks brief 3.4's abort claim) | `nullptr.sps`, `run-6.sh` | `run-6.out`, both versions: key NULL with keylen 0 and in NULL with inlen 0 answer 0. key NULL with keylen 16, or in NULL with inlen 3, exit 134 (abort). `sodium_memcmp` NULL, NULL at length 0 answers 0; at length 4 it is an invalid memory reference. |
| BLAKE2b-256 and -512 of "abc" and the empty input against Python | `run-4b-python.out` (hashlib, 3.10.12), `kat.sps`, `run-4c.sh` | `run-4c.out`: libsodium agrees with hashlib at 1.0.18, 1.0.22 and the workstation package, all four. 256 of "abc" is `bddd813c...d52319`. |
| RFC 7693 text | `vectors/rfc7693.txt` | 1683 lines, SHA-256 `c943754888364fe29bbd0bb3c71c6658ef392371497eaa4a9d9dde015b0721e5`. |
| Appendix E's self-test: outputs 20, 32, 48, 64; inputs 0, 3, 128, 129, 255, 1024; input = `selftest_seq(in, inlen, seed=inlen)`; key = `selftest_seq(key, outlen, seed=outlen)`, keylen = outlen; for each (outlen, inlen) an unkeyed then a keyed hash; every result is fed to a 32-byte unkeyed streaming hash; published result `c23a7800...ccd475` | `selftest.c`, `run-4a.sh` | `run-4a.out`: `ok` reaches `c23a7800d98123bd10f506c61e29da5603d763b8bbad2e737f5e765a7bccd475` at 1.0.18 and 1.0.22. `oneshot` (the 1968 bytes of results concatenated, then one `crypto_generichash`) reaches the same. Changing one size (33 for 32), one input length (127 for 128), the key length (outlen-1) or dropping the key each FAILs, with the same wrong answer at both versions. |
| The reference's keyed KAT | `vectors/blake2b-kat.txt`, `kat.sps`, `run-4c.sh` | Commit `ed1974ea83433eba7b2d95c5dcd9ac33cb847913` (`git ls-remote ... HEAD`), SHA-256 `82fcb3cabe8ff6e1452849e3b2a26a3631f1e2b51beb62ffb537892d2b3e364f`. 256 entries, one key (64 bytes, 00..3f), input lengths 0 to 255, output 64 bytes. `run-4c.out`: 256 of 256 match at 1.0.18, 1.0.22 and the workstation package. A first run matched 0 (upper-case hex): the check can fail. |
| Costs, medians of 7 runs, microseconds per call, container's 1.0.22, Valgrind with the gate's flags | `cost.sps`, `run-5.sh`, `medians.py`, `run-5-raw.out` | `run-5.out`. 64 KiB, plain / Valgrind: `crypto_generichash` 49 / 1223; `randombytes_buf` 96 / 325; `foreign-set!` loop in 1784 / 47627; `foreign-ref` loop out 1735 / 45407. 32 bytes: 0.12 / 5.9; 0.07 / 0.85; 0.93 / 22.9; 0.88 / 22.1. |

Rerun, from `build/m2-plan/`:

```
scripts/guix-env sh -c 'export C_INCLUDE_PATH=$PWD/build/slice5/prefix-1.0.18/include:$C_INCLUDE_PATH; sh build/m2-plan/run-1.sh'
```

and likewise `run-2.sh` and `run-4a.sh`. `run-3.sh`, `run-4c.sh`, `run-5.sh`, `run-6.sh` and
`run-7.sh` need only `scripts/guix-env sh`. `medians.py` runs on the host. The vectors were fetched
once, on the host.

## Where the brief is false or incomplete

1. **Brief 3.4, `crypto_generichash`: "A NULL key or input with a nonzero length aborts (L-F8)" is
   true but the header does not say so.** `__attribute__ ((nonnull(1)))` covers `out` alone at both
   versions (`headers-decls.txt`). The abort is real (exit 134, `run-6.out`), and NULL with length 0
   is accepted for both `in` and `key`. A decoy that tests `in` or `key` by ternary compiles; only
   `out` needs the `volatile uintptr_t` form (`run-1.out`).
2. **Brief 3.4, `sodium_memcmp`: incomplete.** It has no `nonnull`, so its decoy needs no
   `volatile`. NULL with a nonzero length is a crash (invalid memory reference), and NULL at length
   0 answers 0 (`run-6.out`). Its "-1 different" is exact: the answer is never another negative or
   positive number.
3. **Brief 3.4, `randombytes_buf`: "Its bound, `randombytes_BYTES_MAX`, is a macro only" gives no
   value.** It is 4294967295 at both versions and no function answers it (`run-2.out`), so the
   binding's own 64 KiB cap is the only bound C-side callers can read.
4. **Brief 3.4, `crypto_generichash`: the -1 case leaves `out` untouched.** The brief does not say
   so. At every -1 (outlen 0, outlen above 64, keylen above 64) all 128 bytes of the sentinel stayed
   (`run-3.out`), so `blake2b` has nothing to wipe on that path beyond its own block.
5. **Brief 8.1 row 1: Appendix E cannot go "through `blake2b`" alone.** Its grand hash is a
   streaming hash over 1968 bytes of results. One `crypto_generichash` over those bytes concatenated
   reaches the same published result (`run-4a.out`, `oneshot`), so the test can build the
   concatenation in Scheme and call `blake2b` once. The row's six input lengths are 0, 3, 128, 129,
   255 and 1024, seeded by their length, and the key is seeded by the output size and has that
   length.
6. **Brief 8.1 row 1: the reference KAT is narrower than the row implies.** Every entry has the same
   64-byte key and a 64-byte output, with input lengths 0 to 255. It cannot catch "BLAKE2b-512
   truncated to 256", a wrong or ignored size, or a key of another length; only Appendix E (sizes 20
   to 64, keys 20 to 64) and the "abc" vector do (`vectors/blake2b-kat.txt`). It does catch a
   dropped key.
7. **Brief 4.3, `blake2b` "`_bytes_min` to `_bytes_max` (16 to 64) ... since C accepts 1 to 15":
   confirmed** for outlen and for keylen (`run-3.out`). Also confirmed, not stated: keylen 0 gives
   the unkeyed hash whatever the key block holds. The binding raises on an empty key, so C never
   sees that case.
8. **Brief 6.4's costs hold:** BLAKE2b over 64 KiB is 49 us and 64 KiB of random bytes 96 us
   (`run-5.out`). Not in the brief: the byte-by-byte `foreign-set!` copy of 64 KiB costs 1.8 ms
   plain, 36 times the hash, and 47.6 ms under Valgrind, 39 times the hash's 1.2 ms. At 32 bytes the
   copy is 0.9 us against 0.12 us for the hash. A copy loop, not the C call, is where the 64 KiB
   cap's critical-section time goes.
9. **Added in slice 0's review (M2S0-F6): a key length other than the size.** No vector above has
   one: the self-test sets keylen to outlen, the known answers are all 64 by 64, and `"abc"` is
   unkeyed. `keyed.sps` (`run-7.out`, on all four libraries) and `hashlib` (`run-7-python.out`)
   agree on three: a 16-byte key at size 32 and a 64-byte key at size 20 over `"abc"`, and a 17-byte
   key at size 64 over the empty input.
