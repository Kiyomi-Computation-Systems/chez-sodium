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

Row: `test-library-loading-verbs`, "the C oracle on the control build under sizes-other: its output whole ...". It sets `CHEZ_SODIUM_DECOY=sizes-other` with `putenv` and runs `libsodium-oracle` on the control build; its switch is set in this process's environment, which is safe in any order, since every verb row's child sets or unsets its own (corrected after the second review, M2C-F8). Expected: version (the floor), `(major . 10)`, `(minor . 3)`, `(init 0 0)`, the five size lines `(generichash-bytes 33 32)`, `(generichash-bytes-min 8 16)`, `(generichash-bytes-max 80 64)`, `(generichash-keybytes-min 9 16)`, `(generichash-keybytes-max 81 64)`, and `valgrind-line`.

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

Superseded in part after the second and third reviews: `"sodium.h"` in quotes is now refused, and a splice in a comment or a string is read. See "The second review and its fixes" and "The third review and its fixes".

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
- `test-conditions`: the two DETAIL rows replaced by 7 rows: low no exact natural; high no exact natural (each: string, 1.5, -1, a bytevector holding hunter2, #f, by kind); low checked before high; LOW above HIGH is `high` and LOW = HIGH is no refusal of the bound; WHO/RULE/PARAMETER before the bound; "with a bound refuses as without it" (irritants whole at no bound, 0 65536, 16 64, 0 0); the 5-argument call. Chez raises an assertion violation with message "incorrect number of arguments ~s to ~s", irritants `(5 #<procedure refuse-secret ...>)`: the count and the procedure, none of the arguments. The row prints the condition and its irritants and finds none of hunter2, 4242424, the who, the rule or the parameter.
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

## The third review and its fixes

The second round changed rules too, so a third review read it alone, on Opus, read-only
([research/m2-closing-third-review/](research/m2-closing-third-review/README.md)). It found no
blocker, 2 majors and 7 minors, and no code that shows a secret. Two Sonnet fixers took the
code on disjoint files, the scanner and R16; the caller took the records. By the owner's choice
of 2026-11-24, no fourth review follows: the caller rebuilt every mutant the third review
planted, by hand, below.

### The scanner fixer: tests/test-decoy-source.sps

Each mutant ran in a whole copy of the tree (`build/m2c3-scanner/mut/NAME/`, `make deps` run in each copy, that copy's own `scripts/guix-env`). Every decoy, free-watch and decoy-two mutant compiled under the suites' own `-Wall -Werror -shared -fPIC` line (exit 0). Only `tests/test-decoy-source.sps` changed; 66 passes became 88.

#### Changes

| Item | Change | Rows |
|---|---|---|
| F2 | `strip` is now `strip-with` (JOINED? writes a block comment's newlines as spaces); `strip-joined` is that form. `directives` and `code-text` read it, so a directive runs on to the end of its logical line. `includes-sodium?` reads `(directives text #t)`, so a split or wrapped `#include <sodium.h>` is found. | "a comment that wraps inside a directive continues it: the macro names the pointer" (`(("sodium_memcmp" "b1" macro))`), "a comment that wraps inside a directive holds the next line out of the code ...", "... closes on its own line ... is read as before" (control), "a wrapped comment with a directive after it keeps the directive a directive" (control), "an include of <sodium.h> cut by a splice, or after a wrapped comment, is read" (plain `scan` row and an `includes` row) |
| F2 | `bad-splice?` (was `splice-outside-directive?`): a raw line ending in `\` is refused when outside a directive, or when its stripped line does not end in one (the backslash sits in a comment or a string). | "a splice inside a comment inside a directive ends the comment ...", "... hides a ## ...", "a splice inside a string inside a directive ..." (all `splice`) |
| F2 | `digraph?` also reads the joined directives. | "a %: cut by splices inside a directive is a digraph ..." |
| F2 | `lone-cr?`: a CR no LF follows is `(FILE unreadable line-end)`, last-but-one in `file-refusals`. | "a directive after a lone CR ...", "a ## after a lone CR ...", "a lone CR at the very end of the text ...", control "a file with CRLF line ends throughout has no lone CR" |
| F3 | `prefixed-literal?`: a walk as `strip` walks; a quote opening a literal right after an identifier character is `(FILE unreadable literal)`, last in `file-refusals`. | "a digit separator ...", "a raw string ...", "a u8 string prefix ...", "a wide character prefix ..."; controls "strings and characters after a space, a paren or a comma are no prefixed literal", "a quote after an identifier character inside a comment or a string is no prefixed literal" |
| F4 | `foreign-include?`: a `<...>` argument whose path starts with `/` or holds `..` is foreign. | "an include in <...> by an absolute path ...", "an include in <...> with .. in its path ..." |
| F5 | The every-file row asserts `(apply append (map file-refusals ...))` over every `tests/*.c`, not the include rule alone. | "every real tests/*.c: the files read, whole, and no file refusal" |
| | "all four at once" is now "all six at once, in the order paste, splice, include, digraph, line-end, literal". | |
| Header | Says what the scanner reads (line ends, splices, comments, literals, in C's order), each refusal by name, what it does not read, and that it guards against an honest mistake, not a file written to deceive it. | none |

Watched fail on today's scanner (the old scanner section joined to the new rows, `build/m2c3-scanner/old-scanner.sps`): 16 rows failed, 71 passed: all six-at-once, the 4 F3 plants, the 2 F4 plants, the 3 splice plants, the digraph plant, the 3 CR plants, the wrapped-comment macro plant, and the cut-include row. Every control passed there too, as they must.

#### Mutants on the real files

Each edits the real decoy (or `free-watch.c`) in a whole copy; the `called` line of `sodium_memcmp` uses the macro (`DECOY_P`, `DECOY_PARAM(1)`) or the body gets the form. All compile; the suite exits 1.

| Mutant | Result |
|---|---|
| `dir-multiline-comment` | killed: whole-list row `("sodium_memcmp" "b1" macro)` |
| `dir-comment-splice` | killed: whole-list row, and the every-file row `(... unreadable splice)` |
| `dir-comment-splice-paste` | killed: both rows, `unreadable splice` |
| `dir-string-splice` | killed: both rows, `unreadable splice` |
| `dir-digraph-splice` | killed: both rows, `unreadable digraph` |
| `lone-cr-define` | killed: both rows, `unreadable line-end` |
| `lone-cr-paste` | killed: both rows, `unreadable line-end` |
| `digit-sep` | killed: both rows, `unreadable literal` |
| `raw-string` | killed: both rows, `unreadable literal` |
| `abs-include` (`</proc/self/cwd/tests/decoy-extra.h>`) | killed: both rows, `unreadable include` |
| `indirect-digraph` (`free-watch.c`) | killed: the every-file row, `(("tests/free-watch.c" unreadable digraph))` |
| `dir-splice` | killed: whole-list row, `("sodium_memcmp" "b1" macro)` |
| `dir-paste-split` | killed: both rows, `unreadable paste` |
| `dir-paste-crlf` | killed: both rows, `unreadable paste` |
| `comment-splice` | killed: both rows, `unreadable splice` |
| `string-splice` | killed: both rows, `unreadable splice` |
| `digraph-paste`, `digraph-define`, `digraph-include` | each killed: both rows, `unreadable digraph` |
| `quoted-sodium-h` | killed: both rows, `unreadable include` |
| `indirect-include` (`tests/decoy-two.c`) | killed: the every-file row, `(("tests/decoy-two.c" unreadable include))` |
| `decoy-paste` | killed: both rows, `unreadable paste` |
| `decoy-splice` | killed: both rows, `unreadable splice` |

The last twelve are last round's mutants and the review's `decoy-paste` and `decoy-splice`, recreated from the log's description (their text is not in it). The two macro-only mutants (`dir-multiline-comment`, `dir-splice`) fail the whole-list row alone, since the file refusal list stays empty for them: the breach is the row's.

Each rule turned off in a copy of the suite, run on the real files, with the rows that fail:

| Rule off | Failing rows |
|---|---|
| `strip-joined-off` (strip-joined = strip) | the macro-names-the-pointer plant, the holds-next-line plant, the cut-include `scan` row (3) |
| `code-text-unjoined` (only `code-text` unjoined) | the holds-next-line plant (1) |
| `includes-sodium-unjoined` | the cut-include `includes` row (1) |
| `splice-code-only` (only code outside a directive refused) | the three comment/string-splice-in-directive plants (3) |
| `digraph-joined-off` | the cut-`%:` plant (1) |
| `lone-cr-off` | the three CR plants and "all six at once" (4) |
| `lone-cr-any` (every CR refused, CRLF too) | the CRLF paste plant, CRLF holds-next-line plant, CRLF end-of-directive control, CRLF whole-file control (4) |
| `literal-off` | the four literal plants and "all six at once" (5) |
| `abs-include-off` | the absolute-path plant (1) |
| `dotdot-off` | the `..` plant (1) |
| `every-file-includes-only` (row back to `foreign-includers`) | no row on the real files, as the old rule saw nothing; with `indirect-digraph` added to that copy the suite passes (87): the old row cannot see it, the new one kills it above |

The real files have none of the new forms: they pass clean (below).

#### Clean reruns

- `test-decoy-source` plain at 1.0.22: 88 passes, exit 0.
- At the floor (1.0.18; `CHEZ_SODIUM_LIBRARY` and `C_INCLUDE_PATH` set): 88 passes.
- `make check-test-fails` in the checkout: "make test failed, as it must, in all 13 cases".

### The R16 fixer: the printed refusal does not depend on the secret

Each mutant ran in a whole copy of the tree (`build/m2c3-r16/mut/NAME/`, with `make deps`), at 1.0.22; the real files pass under each (clean reruns below). Files owned: `tests/test-byte-verbs.sps`, `tests/test-conditions.sps`. `src/` untouched in the real tree.

#### Changes

- **M2C3-F1, `test-byte-verbs`:** `printed-refusal`, `bound-twins` and 5 rows "R16 ... the printed refusal is the same for other bytes of the same length, and for another length under the same rule": input 65537/65538, key 15/14, key 65/66, a 65537/65538, b 65537/65538. Each prints the condition for `hunter-bytes n`, `(make-bytevector n 0)` and `hunter-bytes m`; expects `'(refused same same)`. The empty key has one value only, so it cannot vary; the comment says so.
- **M2C3-F9, `test-byte-verbs`:** `bound-calls` lost its bound-string column. Each of the 5 bound rows asserts `states-message`: the printed text holds `(condition-message c)` whole. No wording is read.
- **M2C3-F7, `test-conditions`:** the five-argument row becomes two calls per arity (string secret, bytes secret), with needles "hunter2", its bytes as written, "4242424", "extra7", who, rule, parameter (`arity-leaks`, `arity-parts`). New row for seven arguments, the same form.
- **M2C3-F8, `test-conditions`:** one row, three calls: WHO, RULE and PARAMETER bad gives `(who (kind string))`; RULE and PARAMETER bad gives `(rule (kind string))`; the same with a bound gives `(who (kind string))`.
- **F6's last item:** the suite header's R16 line describes the type rows, the bound rows and the differential rows; the R16 comment points at the rows after it.
- **Traps:** every new top-level definition checked: `printed-refusal` and `arity-leaks` run under a guard; `bound-twins` holds lambdas only; `arity-parts` is constants. No expected `#f`; no order from `map` or `let` (`let*` for p, q, r).

#### Mutants

| Mutant | Edit | Rows that fail |
|---|---|---|
| `rs-atmost-excess` | `conditions.sls`, at-most branch appends ", N over" | 3 differential rows: input, a, b |
| `rs-range-prefix` | `conditions.sls`, LOW-to-HIGH branch appends ", begins " and the first 4 bytes | 2 differential rows: key 15/14, key 65/66 |
| `site-first-byte` | `byte-verbs.sls` input's LOW is the first byte | 1 differential row: input |
| `print-drops-message` | `tests/chez-sodium-testing.sls` `describe` prints a condition's irritants only | 5 bound rows (`message-missing`); test-conditions unaffected |
| `rs-five-value` | `conditions.sls`, a 5-argument clause printing VALUE | test-conditions: the five-argument row |
| `rs-seven` | `conditions.sls`, a 7-argument clause with a note | test-conditions: the seven-argument row |
| `rs-field-order` | `conditions.sls`, checks PARAMETER, RULE, WHO | test-conditions: the order row |

Counts under each: byte-verbs 127, 128, 129, 125, 130, 130, 130 of 130; conditions 60, 60, 60, 60, 59, 59, 59 of 60.

#### Clean reruns

| Suite | 1.0.22 plain | floor 1.0.18 | gate |
|---|---|---|---|
| test-byte-verbs | 130 pass (was 125) | 130 pass | 9 s |
| test-conditions | 60 pass (was 58) | 60 pass | 7 s |

`make test-memory` on the two: ran 2, passed 2, failed 0, hung 0, slow 0. `make check-test-fails` not run, by the brief.

### Verified by the caller: the third review's 17 mutants, by hand

Each in a fresh copy of `src/` and `tests/`, built from the review's text, not from the fixers'
scripts. Each C mutant compiles under the suites' own `-Wall -Werror` line, and `gcc -E -P`
shows the plain test of `b1` (or of `k`, for `indirect-digraph`) that it hides.

| Mutant | Result |
|---|---|
| clean copy | `test-decoy-source` 88, `test-byte-verbs` 130, `test-conditions` 60 |
| `dir-multiline-comment` | 1 row fails, `("sodium_memcmp" "b1" macro)` |
| `dir-comment-splice` | 2 rows fail, `unreadable splice` |
| `dir-comment-splice-paste` | 2 rows fail, `unreadable splice` |
| `dir-string-splice` | 2 rows fail, `unreadable splice` |
| `dir-digraph-splice` | 2 rows fail, `unreadable digraph` |
| `lone-cr-define` | 2 rows fail, `unreadable line-end` |
| `lone-cr-paste` | 2 rows fail, `unreadable line-end` |
| `digit-sep` | 2 rows fail, `unreadable literal` |
| `raw-string` | 2 rows fail, `unreadable literal` |
| `abs-include` | 2 rows fail, `unreadable include` |
| `indirect-digraph` (in `free-watch.c`) | the every-file row fails, `unreadable digraph` |
| `rs-atmost-excess` | 3 differential rows fail: input, `a`, `b` |
| `rs-range-prefix` | 2 differential rows fail: keys of 15 and 14, 65 and 66 |
| `site-first-byte` | the input's differential row fails |
| `rs-five-value` | the five-argument row fails |
| `rs-seven` | the seven-argument row fails |
| `rs-field-order` | the WHO, RULE, PARAMETER order row fails |

### Clean reruns, in the checkout, after the third round

- `make test`: ran 31, passed 31, failed 0, hung 0.
- `make check-test-fails`: make test failed, as it must, in all 13 cases.
- `make test-memory`: ran 31, passed 31, failed 0, hung 0, slow 0.
- At the floor, 1.0.18: `test-byte-verbs` 130, `test-conditions` 60, `test-decoy-source` 88,
  `test-library-loading-verbs` 12, `test-native` 77.
