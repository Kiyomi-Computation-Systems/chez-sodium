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

New refusals: `(FILE unreadable paste)`, `(FILE unreadable splice)`, `(FILE unreadable include)`, FILE being the file's path (scan's optional second argument; "file" when none). 15 new rows (plants, and a negative control for each rule: comment and string `##`, a directive's own continuation, a backslash inside a string or comment, system headers and "sodium.h" with odd spacing, an include in a comment).

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

The DETAIL form below was replaced after the second review (M2C-F1): `refuse-secret` now takes
the bound as two naturals. See "The second review and its fixes".

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

## The second review and its fixes

The closing fixes changed rules, so a second review read them, on Opus, read-only
([research/m2-closing-fix-review/](research/m2-closing-fix-review/README.md)). It found no
blocker, 2 majors and 6 minors. The owner chose, on 2026-11-24, bounds as numbers for M2C-F1,
which settles M2C-F6. Two Sonnet fixers took the code on disjoint files, the scanner and the
bound; the caller took the records and R16's bytes needle.

### Reproduced by the caller, before the fixes

- **M2C-F1, `detail-key-text`:** with `(utf8->string key)` as the key's DETAIL, `blake2b`'s
  message ends in `hunter2hunter2h`, and `test-byte-verbs` (120) and `test-conditions` (53)
  pass.
- **M2C-F2, `dir-splice`:** `#define DECOY_P b\` and `1` on the next line, used in
  `sodium_memcmp`'s `called` line. The decoy compiles under `-Wall -Werror`, `gcc -E -P` shows
  `b1 ? "p" : "NULL"`, and `test-decoy-source` passes 52.

### The scanner fixer: tests/test-decoy-source.sps

Each mutant ran in a whole copy of the tree (`build/m2c2-scanner/mut/NAME/`, `make deps` first, that copy's own `scripts/guix-env`), applied by exact replacement with its match count checked. Every decoy mutant compiled under the suites' own `-Wall -Werror` line (exit 0; the first `string-splice` draft did not compile, an unused variable, and was corrected before the run counted). Only `tests/test-decoy-source.sps` changed; 52 passes became 66.

#### Changes

| Item | Change | Rows |
|---|---|---|
| F2 | `directives` joins a continuation with nothing between, and reads `more?` as `spliced?` does (new `without-backslash`); `code-text`'s `more?` reads `spliced?` too | "a name cut by a backslash inside a directive ... the macro names the pointer" (`(("sodium_memcmp" "b1" macro))`), "a ## cut by a backslash inside a directive is a paste", "a ## on the line after a CRLF continuation is a paste", "a CRLF continuation holds the next line out of the code ...", "a CRLF line end at the end of a directive's last line is no continuation" (control) |
| F3 | `splice-outside-directive?` reads the splice from the raw line, the stripped line only tells a directive apart. The :913 plant is replaced | "a backslash at the end of a line inside a comment is a splice ...", "... inside a string is a splice too", "a backslash inside a string or a comment, not at the end of its line, is no splice" (control) |
| F4 | `digraph?`: `%:` in the stripped text is `(FILE unreadable digraph)`, last in `file-refusals` | "a %: digraph ...", "a %:%: digraph ...", "a %: in a string, a character, a comment or a line comment is no digraph" (control); "all four at once" replaces "all three at once" |
| F5 | `"sodium.h"` no longer exempt; `foreign-includers` and `read-all` run the include rule over every `tests/*.c` | "an include of \"sodium.h\" in quotes ... unreadable, by include", "system headers in <...>, <sodium.h> too, are no refusal", "a local include in a file that does not include sodium.h is found, by path", "a quoted \"sodium.h\" is found too", "every real tests/*.c: the files read, whole, and no include but <...>" |
| F8 | `scan : String [String] -> ...` | none |
| Header | splice and paste lines rewritten, `digraph` and the every-file include rule added, "a splice inside a comment or a string" dropped from what is not read | none |

Every real `tests/*.c` passes the include rule: decoy-libsodium.c, free-watch.c and libsodium-oracle.c have `<...>` includes only.

#### Mutants on the real files

Decoy mutants: the decoy edited, the new suite run. All compile (exit 0).

| Mutant | Result |
|---|---|
| `dir-splice` | killed: whole-list row, `("sodium_memcmp" "b1" macro)` |
| `dir-paste-split` | killed: whole-list row, `(... unreadable paste)` |
| `dir-paste-crlf` | killed: whole-list row, `(... unreadable paste)` |
| `comment-splice` | killed: whole-list row, `(... unreadable splice)` |
| `string-splice` | killed: whole-list row, `(... unreadable splice)` |
| `digraph-paste` | killed: whole-list row, `(... unreadable digraph)` |
| `digraph-define` | killed: whole-list row, `(... unreadable digraph)` |
| `digraph-include` | killed: whole-list row, `(... unreadable digraph)` |
| `quoted-sodium-h` (decoy includes "sodium.h"; tests/sodium.h defines `DECOY_P b1`) | killed: whole-list row `(... unreadable include)`, and the every-file row |
| `indirect-include` (new tests/decoy-two.c via a local header; compiles) | killed: the every-file row, which lists `tests/decoy-two.c` |
| `decoy-paste` (rerun) | killed: `(... unreadable paste)` |
| `decoy-splice` (rerun) | killed: `(... unreadable splice)` |

Each rule turned off in a copy of the suite, with the plant rows that fail:

| Rule off | Failing rows |
|---|---|
| `join-space` (continuation joined with a space) | the macro-names-the-pointer plant, the `#\`-split paste plant (2) |
| `more-last-char` (`directives`' `more?` needs `\` last) | the CRLF paste plant (1) |
| `code-more-old` (`code-text`'s `more?` needs `\` last) | the CRLF continuation holds-next-line plant (1) |
| `splice-stripped` (splice read from the stripped line) | the comment and string splice plants (2) |
| `digraph-off` | the two digraph plants and "all four at once" (3) |
| `quoted-exempt` ("sodium.h" exempt again) | the quoted-include plant and the `foreign-includers` quoted plant (2) |
| `includers-filtered` (`foreign-includers` only over sodium.h includers) | the local-include-without-sodium.h plant (1) |
| `read-all-filtered` (every-file row reads only sodium.h includers) | the every-file row (1) |

#### Clean reruns

- `test-decoy-source` plain at 1.0.22: 66 passes, exit 0.
- At the floor (1.0.18; `CHEZ_SODIUM_LIBRARY` and `C_INCLUDE_PATH` set): 66 passes.
- `make check-test-fails`: "make test failed, as it must, in all 13 cases".

### The bound fixer: refuse-secret's bound as numbers

Each mutant ran in a whole copy of the tree (`build/m2c2-bounds/mut/NAME/`, with `make deps`); the real files pass under each (clean reruns below).

#### Changes

- `conditions.sls`: `refuse-secret : Symbol Symbol Symbol Any [Natural Natural] -> Nothing`. DETAIL is gone. Clauses of 4 and 6 arguments; a call of 5 matches no clause. LOW and HIGH are each an exact natural, LOW <= HIGH, checked after WHO, RULE, PARAMETER (LOW, then HIGH), refused through `refuse-field` as `low` or `high`, by kind. LOW above HIGH is refused as `high`. "No bound" is a private sentinel, so a bound of `#f` is still refused. The sentence is written from the two numbers; irritants unchanged.
- `byte-verbs.sls`: `cap-detail` and `key-detail` dropped. Five calls pass `0 input-cap` (input, a, b) or `generichash-keybytes-min` and `-max` (empty-key, key-length-out-of-range).
- `test-conditions`: the two DETAIL rows replaced by 6 rows: low no exact natural; high no exact natural (each: string, 1.5, -1, a bytevector holding hunter2, #f, by kind); low checked before high; LOW above HIGH is `high` and LOW = HIGH is no refusal of the bound; WHO/RULE/PARAMETER before the bound; "with a bound refuses as without it" (irritants whole at no bound, 0 65536, 16 64, 0 0); the 5-argument call. Chez raises an assertion violation with message "incorrect number of arguments ~s to ~s", irritants `(5 #<procedure refuse-secret ...>)`: the count and the procedure, none of the arguments. The row prints the condition and its irritants and finds none of hunter2, 4242424, the who, the rule or the parameter.
- `test-byte-verbs`: R16 extended with 5 rows from `bound-calls` (input of 65537, key of 15, key of 65, a of 65537, valid a with b of 65537), each a bytevector of `hunter2` repeated. Each row asserts: refused; the printed condition states its bound (65536, 16, 64: a positive control that the print reaches the message); no `hunter2`; no length in decimal. No needle is a substring of a stated bound (65537, 15, 65 vs 65536, 16, 64). Empty key: carries a bound but has no text, its length 0 is its rule, so R16 does not search it (its irritants are R15's row). R16's comment now claims the type refusals and the bound-carrying refusals. S5's counts changed because each refusal now names `input-cap`: blake2b 1 to 2, compare 2 to 4 (random-bytes stays 1); the row's name says why. S1 to S4 unchanged, S3's list too.
- `test-library-loading-verbs`: comment says the switch is safe in any order, since every verb row's child sets or unsets its own.

#### Mutants

| Mutant | Rows that fail | Old DETAIL form could show it? |
|---|---|---|
| `detail-length` (input's bound `(bytevector-length input)`) | R16 blake2b input of 65537; S5 | yes (it survived, M2C-F1) |
| `key-length-leak` (key's LOW is `(bytevector-length key)`) | R16 key of 15, key of 65; R15 key one over greatest, key of 65537 | no |
| `key-as-bound` (key as LOW) | R16 key of 15, key of 65; R15 key one under least, one over greatest, 65537 | no |
| `bound-check-off` (LOW, HIGH unchecked) | test-conditions: low, high, low-before-high, low-above-high (4) | no |
| `bound-shown` (bad low by `shown-value`) | test-conditions: low row | no (it was M2C-F6's, held by a different row) |
| `bound-order` (LOW above HIGH accepted) | test-conditions: low above high row | no |
| `bound-irritant-added` | test-conditions 5 rows; test-byte-verbs 36 R15 rows | no |
| `detail-key-text` (key as text passed as the key) | R15 key-range rows (3): refused as `key`'s kind is string | n/a (the old form's survivor) |
| `message-length` (message appends the value's length in the LOW-to-HIGH branch) | R16 key of 15, key of 65 | no |
| `r16-no-length` (R16's length check dropped, with `message-length`) | none: 125 pass | shows the length check is what catches `message-length` |

`detail-length` also fails through R16's bound-stated control, since the mutant drops "65536". The `message-length` pair is the R16 mutant of its own: with the length check it fails 2 rows, without it it passes.

#### Clean reruns

| Suite | 1.0.22 plain | floor 1.0.18 | gate |
|---|---|---|---|
| test-conditions | 58 pass | 58 pass | 7 s |
| test-byte-verbs | 125 pass | 125 pass | 9 s |
| test-library-loading-verbs | 12 pass | 12 pass | 33 s |

`make test-memory`: ran 3, passed 3. `make check-test-fails` not run, by the brief.

### Verified by the caller, after the fixes

Each in a fresh copy of `src/` and `tests/`, built by hand, not from the fixers' scripts:

| Mutant | Compiles | Result |
|---|---|---|
| clean copy | yes | `test-decoy-source` 66 passes |
| `dir-paste-crlf` | yes; `gcc -E` tests `b1` | 1 row fails, `unreadable paste` |
| `comment-splice` | yes; `gcc -E` tests `b1` | 1 row fails, `unreadable splice` |
| `string-splice` | yes; `gcc -E` tests `b1` | 1 row fails, `unreadable splice` |
| `digraph-include` | yes; `gcc -E` tests `b1` | 1 row fails, `unreadable digraph` |
| `quoted-sodium-h` | yes; `gcc -E` tests `b1` | 2 rows fail, `unreadable include` |
| `indirect-include` | yes | the every-file row fails, naming `tests/decoy-two.c` |
| `key-length-msg`: the key's LOW is `(min (bytevector-length key) generichash-keybytes-min)` | n/a | R16 "blake2b key of 15 bytes" fails |

**R16's bytes needle, added by the caller.** The bound rows searched the printed condition for
`hunter2` as text, and a bytevector prints as `#vu8(104 117 110 …)`. The rows now search for
`104 117 110 116 101 114 50` too.

| Mutant | Without the needle | With it |
|---|---|---|
| `bound-branch-written`: the value written into the message's at-most branch alone | 125 pass: survives | 3 R16 bound rows fail |
| `value-written`: the value written into every refusal's message | 4 R16 type rows fail | 9 R16 rows fail |

### Clean reruns, in the checkout, after both fixes and the needle

- `make test`: ran 31, passed 31, failed 0, hung 0.
- `make check-test-fails`: make test failed, as it must, in all 13 cases.
- `make test-memory`: ran 31, passed 31, failed 0, hung 0, slow 0.
- At the floor, 1.0.18: `test-byte-verbs` 125, `test-conditions` 58, `test-decoy-source` 66,
  `test-library-loading-verbs` 12.
