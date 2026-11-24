# M3 plan's probes, set B

Costs of the password calls, the UTF-8 encoder, collect-safe by behaviour, and the types a
`__collect_safe` binding takes. Run from `build/m3-plan/b/` in the container (`scripts/guix-env`):
Chez 10.4.0 threaded, GCC, Valgrind 3.27.0 with the memory gate's flags
(`--error-exitcode=9 --leak-check=full --show-leak-kinds=definite --errors-for-leak-kinds=definite --child-silent-after-fork=yes -q`).
Two libsodium builds: the floor, `build/slice5/prefix-1.0.18/lib/libsodium.so.23`, and the profile's
1.0.22 (`$CHEZ_SODIUM_LIBRARY`). Python 3 on the host, for medians only. Paths in the outputs read
`<repo>` and `<home>`. The compiled `blocker.so` is built into a temp directory and not kept.

| What | Ran | Got |
|---|---|---|
| `crypto_pwhash_str` `(uptr uptr unsigned-64 unsigned-64 size_t) int` and `crypto_pwhash_str_verify` `(uptr uptr unsigned-64) int`, each plain and `__collect_safe`; ms per call, median of 7 (Valgrind: 7 runs of 20 calls at min and 16 KiB, 3 runs of 1 call at interactive) | `cost1.sps`, `run-1.sh`, `medians1.py` | `run-1.out` (raw: `run-1-raw.out`). Plain, both libraries: min (ops 1, 8 KiB) 0.013 to 0.014 ms; ops 2 / 16 KiB 0.017 to 0.019 ms; interactive (ops 2, 64 MiB) 55.4 to 56.5 ms. Valgrind, hash at min: 0.348 (floor), 0.361 (1.0.22) plain binding; 0.390, 0.413 collect-safe. Valgrind, 16 KiB: 0.47 to 0.55. Interactive under Valgrind: 651 to 685 ms. |
| Collect-safe binding against plain, at the minimum | same | Plain run: no difference (0.013 vs 0.013 floor hash; 0.013 vs 0.014 1.0.22). Valgrind hash: +0.04 ms (+12 percent, floor) and +0.05 ms (+14 percent, 1.0.22). Valgrind verify shows the reverse (plain 0.540 / 0.623, collect-safe 0.344 / 0.369): the plain verify is measured first, before any other verify, so Valgrind's translation cost lands on it; read it as noise of about 0.2 ms, not a cost of the plain binding. |
| 2a. Is every Chez character a scalar value? | `enc.sps`, `run-2.sh` | `run-2ab.out`: `(integer->char #xD800)`, `#xDFFF` and `#x110000` raise ("~s is not a valid unicode scalar value"; the condition message shows the unfilled `~s`). Every code point 0 to #x10FFFF outside D800..DFFF round-trips. `string-set!` of a surrogate raises the same way. Decoding the bytes `ED A0 80` (a surrogate) gives one U+FFFD (65533), not a surrogate. No string can hold one. |
| 2b. Encoder (count from `char->integer`, write with `foreign-set! 'unsigned-8`) against `string->utf8` | `enc.sps` | `run-2ab.out`, every row `match #t`: `""` (0 bytes), `"a"`, U+0000, U+007F, U+0080, U+07FF, U+0800, U+FFFF, U+10000, U+10FFFF, `"pässwörd€"` (13 bytes), a 65,536-character mixed string (163,840 bytes) and a 26,214-character mixed string of exactly 65,536 bytes. |
| 2c. Cost of 64 KiB of UTF-8 written by the encoder, microseconds, median of 7 (plain 200 calls a run, Valgrind 3) | `cost2.sps`, `run-2.sh`, `medians2.py`; M2's `cost.sps` for the copy | `run-2c.out`. Plain: ASCII 65,536 chars 1,978 us; 3-byte 21,845 chars 1,970 us; M2's bytevector copy 1,756 us. Valgrind: 54,584; 52,198; 48,197 us. The encoder, count included, costs 1.13 times the byte copy plain and 1.13 and 1.08 times under Valgrind. ASCII and 3-byte cost the same: the cost is the bytes written, not the characters. The encoder runs inside `critical-section`, as the copy does. |
| 2d. A string changed between the count and the write, one thread, simulated | `enc.sps` | `run-2ab.out`. Count 8, then one ASCII character becomes U+20AC. An unbounded writer wrote 10 bytes into the block counted for 8: overrun by 2 (its test block was 64 bytes, so nothing real was overwritten). The bounded writer answers `overrun` there, and `short` when a 3-byte character becomes ASCII (it ends 2 bytes before the end). Both answers are symbols; the bound is checked before each character's bytes. |
| 3. Collect-safe by behaviour: `blocker.c` `block_on(path)` opens a FIFO read-only (blocks), reads to EOF, answers 0; bound `(uptr) int`; the collector thread runs `collect-rendezvous`, times it, then releases the FIFO; a watchdog process releases it at 10 s. 5 runs each, plain and Valgrind | `blocker.c`, `blocker.sps`, `run-3.sh` | `run-3.out`. (a) `__collect_safe`, no critical section, and (b) `__collect_safe` inside `critical-section`: all 10 plain and all 10 Valgrind runs "collected", `released-by=collector`, opener answered 0. (c) plain and (d) plain inside `critical-section`: all 20 runs `released-by=watchdog`, the rendezvous did not return until the watchdog opened the FIFO (about 9.6 s plain; 6.8 to 7.0 s under Valgrind, which starts the process later than the watchdog's clock). |
| 3. Rendezvous time, (a) and (b) | same | Plain: 0 ms in all 10 runs. Valgrind: 11 to 12 ms; the largest is 12 ms (b, run 1; a, run 3). A bound of 5 s is more than 400 times that. |
| 4. Types under `__collect_safe` | `types4.sps`, `run-4.sh` | `run-4.out`, same on both libraries. Accepted: `uptr`, `unsigned-64`, `size_t`, `int` arguments, `int` result, and the two pwhash signatures. Also accepted, without a word: `u8*` argument. Refused: `string` and `utf-8` arguments, with "Exception in foreign-procedure: string argument not allowed with __collect_safe procedure". `u8*`, `string` and `utf-8` results are accepted. All three argument forms are accepted by a plain binding. |

## Rerun

```
scripts/guix-env sh build/m3-plan/b/run-1.sh      # about 2.5 minutes; then, on the host:
python3 -I build/m3-plan/b/medians1.py
scripts/guix-env sh build/m3-plan/b/run-2.sh      # writes run-2ab.out and run-2c-raw.out; then:
python3 -I build/m3-plan/b/medians2.py
scripts/guix-env sh build/m3-plan/b/run-3.sh > build/m3-plan/b/run-3.out   # about 6 minutes
scripts/guix-env sh build/m3-plan/b/run-4.sh > build/m3-plan/b/run-4.out
```

`run-2.sh` needs `build/m2-plan/cost.sps`. `run-3.out` and `run-4.out` were filtered of one
`guile: warning` locale line.

## What this changes

- **A test of `__collect_safe` needs no big hash.** The minimum limits cost 0.014 ms plain and
  about 0.4 to 0.8 ms under Valgrind, an interactive hash 56 ms plain and about 0.66 s under
  Valgrind (`run-1.out`). The suite's cheap password rows stay cheap on both libraries; the floor
  and 1.0.22 differ by under 10 percent.
- **The collect-safe binding costs nothing measurable plain** at the minimum, and at most 0.05 ms
  under Valgrind (`run-1.out`). Binding the two pwhash calls `__collect_safe` is free.
- **Chez refuses a string and a `utf-8` argument under `__collect_safe`, and accepts `u8*`**
  (`run-4.out`). So `check-seam` must refuse `u8*` itself; Chez will not. Every M3 argument is
  `uptr`, `unsigned-64` or `size_t`, all accepted.
- **No surrogate can reach the encoder** (`run-2ab.out`): the 1 to 4 byte split by `char->integer`
  covers every character, and the output equals `string->utf8` on every row, so the encoder's
  count is exact for an unchanged string.
- **A string changed during the write is caught by the bound**, not by luck: an unchecked writer
  writes past the counted size, a bounded one answers `overrun` or `short` (`run-2ab.out`). The
  verb must treat both as a refusal after the section, and wipe and free the block.
- **The encoder costs about 1.1 times M2's byte copy** (`run-2c.out`), for ASCII and 3-byte text
  alike: about 2 ms plain and 52 to 55 ms under Valgrind per 64 KiB. Inside the 64 KiB input cap,
  one password write holds interrupts for about 2 ms plain, the same order as the copy M2 accepted.
- **Collect-safe holds inside `critical-section`** (`run-3.out`, (b)): another thread's
  `collect-rendezvous` finished in 0 ms plain and at most 12 ms under Valgrind while the call
  blocked. The plain controls (c) and (d) did not return until the watchdog released the FIFO,
  so the row can fail, and can only be released from outside the process. A test needs a bound
  well above 12 ms (5 s is safe) and a watchdog for the controls.
