# M2's closing review: its fixes' mutation log

Every run was in the Guix container (`scripts/guix-env`): Chez 10.4.0, threaded; libsodium 1.0.22,
and the floor, 1.0.18, from slice 5's source build, its headers first in `C_INCLUDE_PATH`. M2's
closing review ([research/m2-closing-review/](research/m2-closing-review/README.md)) found no
blocker, 1 major and 6 minors. One Sonnet fixer took the code (M2-F1, F2, F6 and F7's code
items); the caller took the records (M2-F1's texts, F3, F4, F5 and F7's plan item). Every mutant
was applied in a whole copy of the tree, never in place.

## Reproduced by the caller

- **The review's `oracle-f-twins`,** `bytes`' F read from `crypto_generichash_keybytes` and
  `keybytes-min`'s from `_bytes_min`: `test-library-loading-verbs` fails "the C oracle on the
  control build under sizes-other: its output whole, each size line the decoy's answer for its
  own function and the header's macro for it". `test-native` still passes 77, as the twins are
  equal at the release it loads.
- **Clean runs:** `test-decoy-source` 52, `test-conditions` 53, `test-library-loading-verbs` 12,
  `test-byte-verbs` 120.

## The fixer

Each mutant ran in a whole copy of the tree (`build/m2-closing-fix/mut/work/`, with `make deps`), one file edited at a time and restored after; the real files pass under each (the clean reruns below).

### M2-F1: the oracle against the decoy

Row: `test-library-loading-verbs`, "the C oracle on the control build under sizes-other: its output whole ...". It sets `CHEZ_SODIUM_DECOY=sizes-other` with `putenv` and runs `libsodium-oracle` on the control build; it is the last row that spawns (every other child sets or unsets its own switch). Expected: version (the floor), `(major . 10)`, `(minor . 3)`, `(init 0 0)`, the five size lines `(generichash-bytes 33 32)`, `(generichash-bytes-min 8 16)`, `(generichash-bytes-max 80 64)`, `(generichash-keybytes-min 9 16)`, `(generichash-keybytes-max 81 64)`, and `valgrind-line`.

| Mutant (tests/libsodium-oracle.c) | Result |
|---|---|
| `oracle-f-twins` (the review's two replacements) | the row fails; 11 pass |
| `FIND(bytes ...)` read from `crypto_generichash_bytes_min` | the row fails |
| `FIND(bytes_min ...)` from `_bytes_max` | the row fails |
| `FIND(bytes_max ...)` from `_keybytes_min` | the row fails |
| `FIND(keybytes_min ...)` from `_keybytes_max` | the row fails |
| `FIND(keybytes_max ...)` from `crypto_generichash_bytes` | the row fails |

Clean rerun: 12 passes, plain at 1.0.22 and at the floor, and under the gate. Children: 7 (6 and the oracle), at most 14.

### M2-F2: test-decoy-source

New refusals: `(FILE unreadable paste)`, `(FILE unreadable splice)`, `(FILE unreadable include)`, FILE being the file's path (scan's optional second argument; "file" when none). 16 new rows (plants, a positive control for each rule: comment and string `##`, a directive's own continuation, a backslash inside a string or comment, system headers and "sodium.h" with odd spacing, an include in a comment).

| Mutant | Result |
|---|---|
| `decoy-paste` (`#define DECOY_PARAM(n) b##n`, `DECOY_PARAM(1) ? "p"` in sodium_memcmp's `called`), on the real decoy | the whole-list row fails (50 pass, 1 fail). Before: exit 0 |
| `decoy-splice` (`b\` newline `1 ? "p"`) | the whole-list row fails |
| `decoy-include` (`#include "decoy-extra.h"`) | the whole-list row fails |
| `paste-rule-off` | 3 plants fail (paste, continued paste, all three) |
| `splice-rule-off` | 3 plants fail (splice, blanks after the backslash, all three) |
| `include-rule-off` | 5 plants fail |
| `splice-sees-directive-lines` | the real list and 3 plants fail |
| `include-refuses-sodium-h` | the system-headers plant fails |
| `include-refuses-angle` | the real list and the plant fail |
| `paste-reads-strings` | **survived** the first set (exit 0); the plant "a ## in a string inside a directive is no paste either" was added, and the mutant now fails it |

Clean rerun: 52 passes, plain at both releases and under the gate (7 s, no children). The header's "what it does not read" now says a macro that builds a name by other means than `##`, and a splice inside a comment or a string.

### M2-F6: the bounds in the messages

- `random-bytes` over the cap: "n is over the cap, 65536" (from `input-cap`).
- `blake2b` size: "size is from 16 to 64" (native's numbers, built before the section, at the call).
- `refuse-secret` takes an optional DETAIL; the key's two refusals say "a key is 16 to 64 bytes", and `input`, `a`, `b` over the cap say "at most 65536 bytes". Probed at 1.0.22, `build/m2-closing-fix/msg.sps`:

```
n is over the cap, 65536 | (over-the-cap n 1180591620717411303424)
size is from 16 to 64 | (size-out-of-range size 65)
key is refused: empty-key, shown by its kind alone; a key is 16 to 64 bytes | (empty-key key (kind bytevector))
key is refused: key-length-out-of-range, shown by its kind alone; a key is 16 to 64 bytes | (key-length-out-of-range key (kind bytevector))
input is refused: over-the-cap, shown by its kind alone; at most 65536 bytes | (over-the-cap input (kind bytevector))
a is refused: over-the-cap, shown by its kind alone; at most 65536 bytes | (over-the-cap a (kind bytevector))
```

- No row reads a message, so no row changed but the new ones in `test-conditions`: "refuse-secret refuses a detail that is no string ..." and "refuse-secret with a detail, a string, refuses as without it ...".
- S3's shape list did not change; `test-byte-verbs` passes with 120. S5 (`input-cap` written as many times as lengths checked) did fail once, while the not-a-natural message also named the cap; that message was put back.

| Mutant (conditions.sls) | Result |
|---|---|
| `detail-check-off` | the detail row fails |
| `detail-by-secret-shown` | the detail row fails |
| `detail-checked-from-who` | the detail row fails |
| `detail-irritant-added` | 4 rows fail |

Clean rerun: `test-conditions` 53 passes.

### M2-F7

`test-byte-verbs.sps` header rewrapped to 100 columns or fewer; the R15 row named "by the cap check"; the decoy's two comments say a NULL operand, "one or both". No check; wording only.

### Final outputs

Plain, 1.0.22 and the floor (1.0.18): `test-decoy-source` 52, `test-conditions` 53, `test-library-loading-verbs` 12, `test-byte-verbs` 120, `test-native` 77; every exit 0.

Under the gate (`make test-memory`, 5 suites passed):

| Suite | Time | Gated children |
|---|---|---|
| `test-byte-verbs` | 9 s | 0 |
| `test-library-loading-verbs` | 34 s | 7 |
| `test-decoy-source` | 7 s | 0 |
| `test-conditions` | 7 s | 0 |
| `test-native` | 9 s | 1 |

`make check-test-fails`: 13 of 13 cases failed as they must, exit 0.
