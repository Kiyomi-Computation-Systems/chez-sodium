# Review of M2's closing fixes (PR #13, `m2-closing`)

Read-only and adversarial, over `git diff main..m2-closing` (17 files), against the closing review
(M2-F1 to M2-F7) and its fixes' log. I changed no file in the checkout. Every probe ran in
`build/m2-cfr/tree/` (with `build/slice5` copied in for the floor), and each mutant in a whole copy
of its own, `build/m2-cfr/mut/NAME/`, through that copy's own `scripts/guix-env`, after
`make deps` in it. I made no network fetch. I ran `gh` read-only (`gh pr checks 13`).

The container had Chez 10.4.0 threaded, GCC 16.2.0, Valgrind, libsodium 1.0.22 (the profile's),
and the floor, 1.0.18, from `build/slice5/prefix-1.0.18`, with its headers first in
`C_INCLUDE_PATH`.

**Counts: 0 blockers, 2 majors, 6 minors.**

- **M2C-F1 (major):** `refuse-secret`'s new DETAIL is a free string that goes into every
  detail-carrying refusal's message. Only a comment says it is never the value. Two mutants pass
  all 31 suites: one writes the key's own bytes into the message, the other the input's length.
- **M2C-F2 (major):** a name or a `##` cut by a splice *inside a directive* gets past every rule.
  `directives` joins a continuation with a space, where C joins it with nothing. A CRLF line end
  has the same effect. This is M2-F2's own vector moved into a `#define`, and the header says
  neither case is unread.

---

## Findings

### M2C-F1 (major): the DETAIL channel is held by a comment alone, and R16 never reaches it

- **Where:**
  - `src/chez-sodium/private/conditions.sls:86-112`: `refuse-secret`'s DETAIL, "never the
    value", in a comment only.
  - `src/chez-sodium/private/byte-verbs.sls:114,124,128,161,165`: the five calls that pass one.
  - `tests/test-byte-verbs.sps:605-640`: R16. Its comment (:609-611) says it "holds the same,
    over every refusal at once, and that no refusal's condition holds the secret anywhere,
    message included".
- **What:**
  - R16 passes a symbol, a number and a list of characters as each secret. Each of the three is
    refused at the type check, by `not-a-bytevector`, which carries no DETAIL.
  - So no row prints the condition of a refusal that carries a DETAIL: `over-the-cap` for
    `input`, `a` and `b`, and `empty-key` and `key-length-out-of-range` for `key`. The R15 rows
    hold those refusals' irritants, and no row reads their messages.
  - Before this PR, those messages were built from symbols alone, so R16's narrow reach did not
    matter. DETAIL opens a channel from the call site into the message of every secret refusal,
    and nothing checks what goes through it.
  - Brief §5 and AGENTS.md: "A refusal of a secret parameter names the parameter and its kind
    only". `secret-shown`'s comment: "never the value, never its length".
- **Probes:** two mutants, each in a whole copy, each running the full `make test` at 1.0.22.
  - `detail-length`: in `byte-verbs.sls:114`, `cap-detail` becomes
    `(string-append "this input is " (number->string (bytevector-length input)) " bytes")`.
  - `detail-key-text`: in `byte-verbs.sls:128`, `(key-detail)` becomes `(utf8->string key)`.

  ```
  == detail-length     test: ran 31, passed 31, failed 0, hung 0   exit=0
  == detail-key-text   test: ran 31, passed 31, failed 0, hung 0   exit=0
  ```

  Through `(chez-sodium)`, in each mutant (`build/probes/msg.sps`):

  ```
  detail-length:   b2 input 65537 => "input is refused: over-the-cap, shown by its kind alone; this input is 65537 bytes" | (over-the-cap input (kind bytevector))
  detail-key-text: b2 key 15 hunter2... => "key is refused: key-length-out-of-range, shown by its kind alone; hunter2hunter2h" | (key-length-out-of-range key (kind bytevector))
  ```

  The key's own text reaches the message, and every suite passes.
- **Why major:** no code shows a secret today. I read all five call sites, and each passes a bound
  built from `input-cap` or native's sizes. But the rule is the project's first, the new
  parameter is its first free-text path into a secret refusal, and R16's comment claims a reach it
  does not have. M3 makes this worse: a password is a string. A call that swaps VALUE and DETAIL,
  `(refuse-secret 'password-hash 'over-the-cap 'password cap-detail password)`, passes the
  `string?` check and puts the password into the message whole.
- **Fix:**
  - Extend R16 to every refusal that carries a DETAIL, using bytevector secrets that pass the type
    check:
    - an input of 65,537 bytes holding `hunter2` repeated;
    - keys of 15 and 65 bytes holding `hunter2…`;
    - an `a` and a `b` of 65,537 bytes.
  - Assert that the printed condition names neither the secret's text nor its length (`65537`,
    `15`, `65`).
  - Watch the extended row fail on `detail-length` and `detail-key-text`, and log both mutants.
  - Owe the same to M3 in `progress.md`: R16 for the password verbs reaches every refusal that
    carries a DETAIL, with a secret-looking *string*.

### M2C-F2 (major): a splice inside a directive cuts a name, or a `##`, past every rule

- **Where:**
  - `tests/test-decoy-source.sps:342`: `(string-append current " " body)`, the join of a
    continuation.
  - `:339` and `:180`: `directives`' and `code-text`'s `more?` need `\` as the very last
    character.
  - `:45-56`: the header's "(FILE unreadable paste) a ## in any directive" and its list of what
    the scanner does not read.
- **What:**
  - C deletes a backslash-newline and joins the two lines with nothing between them (phase 2).
    `directives` joins them with a space. So `#define DECOY_P b\`⏎`1` is `#define DECOY_P b1` to
    C, but `b 1` to the macro rule, which then sees no `b1`.
  - `splice-outside-directive?` waves the line through as "a directive's own continuation".
  - The same space splits `b#\`⏎`#n` into `# #`, which is no `##` to `pasted?`.
  - A CRLF line end hides the `\` from `more?`, since the line's last character is `\r`.
    `spliced?` trims the `\r` and treats the next line as a continuation, but `directives` never
    joins it and `code-text` reads it as code. So the continued line falls between all three
    rules.
  - This is M2-F2's "a name cut in two", moved into a `#define`. The header scopes the splice
    rule to "outside a directive" and claims "a ## in any directive". Its list of what it does
    not read names neither case.
- **Probes:** each mutant edits the real decoy. It adds a definition after `DECOY_OVERFLOW`, and
  replaces `p1 ? "p"` in `sodium_memcmp`'s `called(...)` line with the macro. The compile is the
  suites' own: `$CC -Wall -Werror -shared -fPIC … -DDECOY_VERSION=… -DDECOY_BELOW=…`.

  | Mutant | Added | Decoy compiles | `test-decoy-source` |
  |---|---|---|---|
  | `dir-splice` | `#define DECOY_P b\`⏎`1`, used as `DECOY_P` | exit 0 | **exit 0, 52 passes** |
  | `dir-paste-split` | `#define DECOY_PARAM(n) b#\`⏎`#n`, used as `DECOY_PARAM(1)` | exit 0 | **exit 0, 52 passes** |
  | `dir-paste-crlf` | `#define DECOY_PARAM(n) \`␍⏎`  b##n` | exit 0 | **exit 0, 52 passes** |
  | `dir-paste-blank` | `#define DECOY_PARAM(n) \  `⏎`  b##n` (blanks after the `\`) | exit 1: `error: backslash and newline separated by space [-Werror]` | exit 0 (the compile holds this one) |
  | `decoy-paste` (the review's, rerun) | `#define DECOY_PARAM(n) b##n` | exit 0 | exit 1: `("tests/decoy-libsodium.c" unreadable paste)` |
  | `decoy-splice` (the review's, rerun) | `b\`⏎`1 ? "p"` in the body | exit 0 | exit 1: `(… unreadable splice)` |

  The preprocessor (`$CC -E -P`) gives the same `sodium_memcmp` line for each of the three
  survivors:

  ```
  called("sodium_memcmp(%s,%s,%zu)", b1 ? "p" : "NULL", p2 ? "p" : "NULL", len);
  ```

  That is a plain test of `b1`, the very thing the pointer rule forbids. `b1` is not `nonnull`, so
  the compile accepts it. `make test` on `dir-splice`: "ran 31, passed 31, failed 0, hung 0".
- **Fix:** join a continuation as C does, and read every continuation as `spliced?` reads it.
  I checked all three changes in a whole copy (`fix`):
  - `:342`: `(string-append current body)`;
  - `:339`: `(more? (spliced? line))`, and the body as the trimmed line less its `\`;
  - `:180`: `(more? (and skip? (spliced? line)))`.

  ```
  fix                    test-decoy-source exit=0, 52 passes (the real files and every plant)
  fix+dir-splice         exit=1: (("sodium_memcmp" "b1" macro))
  fix+dir-paste-split    exit=1: (("tests/decoy-libsodium.c" unreadable paste))
  fix+dir-paste-crlf     exit=1: (("tests/decoy-libsodium.c" unreadable paste))
  ```

  Add the three as plants, watch each fail before the fix, and log them. Correct the header's
  claim.

### M2C-F3 (minor): a splice that ends a comment or a string hides code, and the header calls it unread

- **Where:** `tests/test-decoy-source.sps:414-421` (`splice-outside-directive?` reads the
  stripped line), `:55` ("a splice inside a comment or a string"), `:913-917` (its plant).
- **What:**
  - In C the splice comes before comments and strings. In `/* *\`⏎`/`, the splice turns `*\`⏎`/`
    into `*/`, so C ends the comment there. The scanner's comment runs on to the next `*/`.
  - In a string, `"\\`⏎`\"` is `"\\"` to C, a closed string. The scanner escapes the second
    `\"` and keeps the string open.
  - Either way, code that C compiles lies inside what the scanner strips. The header lists "a
    splice inside a comment or a string" as unread, which sounds harmless. The real effect is a
    hidden use of a pointer.
- **Probes** (the real decoy, both compile under `-Wall -Werror`):

  ```
  comment-splice: called("sodium_memcmp(%s,%s,%zu)", /* *\
                  / b1 ? "p" : /* */ p1 ? "p" : "NULL", ...
                  -> test-decoy-source exit=0, 52 passes
                  -> cc -E: called("sodium_memcmp(%s,%s,%zu)", b1 ? "p" : p1 ? "p" : "NULL", ...
  string-splice:  const char *s = "\\
                  \"; (void) s; if (b1) {} //"
                  -> test-decoy-source exit=0, 52 passes
                  -> cc -E: const char *s = "\\"; (void) s; if (b1) {}
  ```

- **The plant at :913 tests nothing.** "a backslash in a string or a comment, at the end of a
  line, is no splice" holds `const char *s = "a\\";` and `/* b\ */`. Neither line ends in a
  backslash. In the `fix` copy below the rule reads raw lines, and the plant still passes, so it
  passes whichever way the rule reads.
- **Fix:** read the backslash from the raw line, and keep the stripped line to tell a directive
  apart:
  - loop over `(lines-of text)` beside `(lines-of (strip text #f))`;
  - refuse a line whose raw text is `spliced?` outside a directive.

  The real files have no such line. In the `fix` copy, the real files and every plant pass (52),
  and both mutants are refused by name:

  ```
  fix+comment-splice   exit=1: (("tests/decoy-libsodium.c" unreadable splice))
  fix+string-splice    exit=1: (("tests/decoy-libsodium.c" unreadable splice))
  ```

  Replace the :913 plant with a pair that ends a line in `\` inside a comment and inside a string,
  each expecting the refusal. Drop "a splice inside a comment or a string" from the header.

### M2C-F4 (minor): `%:` digraph directives escape the paste, include and macro rules

- **Where:** `tests/test-decoy-source.sps:131-136` (`directive` needs a literal `#`), and every
  rule built on it.
- **What:** `%:` is `#` and `%:%:` is `##` in every C mode since C99, GCC's default `gnu23`
  included. A line that starts with `%:` is code to the scanner. So these three mutants pass:
  - `%:define DECOY_PARAM(n) b%:%:n`, a paste;
  - `%:define DECOY_P b1`, which the macro rule never reads (this gap was there before this PR);
  - `%:include "decoy-extra.h"`, a local include, with that header defining `DECOY_P b1`.
- **Probes** (the real decoy):

  ```
  digraph-paste    decoy compile exit=0; test-decoy-source exit=0, 52 passes
  digraph-define   decoy compile exit=0; test-decoy-source exit=0, 52 passes
  digraph-include  decoy compile exit=0; test-decoy-source exit=0, 52 passes
  each: cc -E gives called("sodium_memcmp(%s,%s,%zu)", b1 ? "p" : "NULL", ...
  ```

  Trigraphs are no way in. `??/` and `??=` fail the compile: `error: trigraph '??/' ignored, use
  '-trigraphs' to enable [-Werror=trigraphs]`. A UTF-8 BOM before a directive is no way in
  either: Chez's UTF-8 transcoder drops it (the first character read is `#`, 35).
- **Fix:** refuse `%:` in the code text, comments and strings stripped, as
  `(FILE unreadable digraph)`, with a plant. Or read `%:` as `#` in `directive` and `%:%:` as
  `##` in `pasted?`.

### M2C-F5 (minor): the include rule's `"sodium.h"` reads a local file first, and runs only where sodium.h is included directly

- **Where:** `tests/test-decoy-source.sps:441` (`"sodium.h"` exempt), `:49-51` (the header's
  reason: "a local file may define what the glob never reads"), `:157-168` (`includes-sodium?`
  picks the files).
- **What:**
  - A quoted include searches the including file's own directory first. So
    `#include "sodium.h"` reads `tests/sodium.h` when one exists, and that is the local file the
    rule's own reason names.
  - The rule runs only on a file that includes sodium.h directly. A `tests/*.c` that reaches
    sodium.h through a local header is never read at all. The whole-list row does not notice,
    because the file was never on the list.
- **Probes:**

  ```
  quoted-sodium-h: the decoy's <sodium.h> -> "sodium.h"; tests/sodium.h = #include <sodium.h> / #define DECOY_P b1
                   decoy compile exit=0; test-decoy-source exit=0, 52 passes; cc -E: ... b1 ? "p" : "NULL" ...
  indirect-include: new tests/decoy-two.c (#include "decoy-two.h", which includes <sodium.h>), defining
                   sodium_memcmp with `return (b1 && b2 && len) ? 0 : -1;`
                   test-decoy-source exit=0, 52 passes
  ```

- **Fix:**
  - Exempt `<sodium.h>` alone. Both real files use it.
  - Run the include rule over every `tests/*.c`, or read any file that has a local include, so
    that a header cannot hide sodium.h.

### M2C-F6 (minor): a DETAIL that is no string is shown by `shown-value`, against the helper's own rule

- **Where:** `src/chez-sodium/private/conditions.sls:104-106`; `tests/test-conditions.sps:462-472`.
  The row beside it, `:452`, is named "a secret in the wrong place is not shown".
- **What:**
  - WHO, RULE and PARAMETER are refused through `refuse-field`, by kind. A number in the
    parameter's place shows as `(parameter (kind number))`.
  - DETAIL is refused through `shown-value`, so a number shows as it is. The likeliest wrong
    DETAIL is a length passed without `number->string`, such as `(bytevector-length input)`,
    which `refuse-secret` would then put into an irritant.
  - Today, R15 would catch that mistake at each of the five call sites, since the refusal's who
    becomes `refuse-secret`. A call site with no R15 row would show the length.
- **Fix:** the owner's call. The brief for this review names `shown-value`. `secret-shown`, the
  fail-safe, would match `refuse-field`, and the row's expected values change to `(kind …)`.

### M2C-F7 (minor): `progress.md`'s "Now" dates a merge that has not happened

- **Where:** `.plans/progress.md:36`: "PRs #10 to #13, squashed onto `main` on 2026-11-23".
- **What:** `main`'s log has #12 squashed on 2026-11-24 (`3a14085`, `2026-11-24 05:15:47 -0500`).
  #13 is open and unmerged: this PR is the one under review. #10 and #11 are
  dated 2026-11-23 in local time.
- **Fix:** write the dates the squashes have ("#10 and #11 on 2026-11-23, #12 on 2026-11-24"),
  and #13's when it merges.

### M2C-F8 (minor): wording in the records and the suites

- **`tests/test-library-loading-verbs.sps:38` and the log's `:26`** say the oracle row "is the
  last row that spawns". The scratch row (`:349-355`) runs `remove-temp-directory`, which spawns
  `rm -rf` (`chez-sodium-testing.sls:272-281`), and that child inherits
  `CHEZ_SODIUM_DECOY=sizes-other`. It is harmless, but the claim is not true. Say "the last row
  that spawns a libsodium". Or, more simply, the switch is safe in any order, since every
  `verb-row` child sets or unsets its own (`library-loading.sls:194-200`).
- **`.plans/m2-closing-mutation-log.md:41`:** "16 new rows". `main`'s suite has 37 rows and
  this one 52, so 15 are new. The same line calls the no-refusal plants "a positive control for
  each rule". They are negative controls.
- **Plan §2.2 (`.plans/2026-11-23-m2-plan.md:89`)** was edited in this PR to say "one child per
  switch, and two for the control", and it now leaves out the oracle child. The suite runs 7.
- **ADR-0011's new point (`:169-172`)** says "decision 1 and the M1 amendment say 'the wipe row's
  child'". The M1 amendment says "The wipe child's `LD_PRELOAD` is set alone".
- **`.plans/global-constraints.md:142-145`:** "checked for every input and operand", followed by
  "`blake2b`'s key … capped through libsodium's own bounds". The key is an input. Say "every
  input but `blake2b`'s key, and every operand".
- **`tests/test-decoy-source.sps:452`:** `scan`'s signature comment is still
  `scan : String -> …`. It now takes an optional NAME: `String [String] -> …`.
- **`.plans/progress.md`, "Owed to M3", the third new bullet:** "`test-decoy-source`'s list and
  `every-entry`". `every-entry` is `(library-loading)`'s (`library-loading.sls:305`), not
  `test-decoy-source`'s.

---

## Work list, item by item

### 1. Each finding: is it fixed, whole?

| Finding | Fixed? |
|---|---|
| M2-F1 | **Yes, the stronger of the two fixes.** Both texts are corrected, and the oracle child kills the F twins (item 2). |
| M2-F2 | **Partly.** The review's two plants are refused by name (`decoy-paste` and `decoy-splice`, rerun: each fails the whole-list row), and so is the local include. The same vectors get through inside a directive (M2C-F2), past a comment's or a string's end (M2C-F3), under `%:` (M2C-F4), and through `"sodium.h"` (M2C-F5). |
| M2-F3 | **Yes.** Both rows are in slice 2's log, with the review's results. |
| M2-F4 | **Yes.** ADR-0007 gains the no-section paths and the key's and output's cap, the constraint says the cap the same way, and ADR-0011 says "children" (with M2C-F8's quote). The code matches: `random-bytes 0` and the compare of unequal lengths hold no section, and `blake2b`'s key and size are never compared with `input-cap`. |
| M2-F5 | **Yes.** All three bullets are under "Owed to M3". |
| M2-F6 | **Yes for the messages** (item 4). The DETAIL it adds is unheld (M2C-F1). |
| M2-F7 | **Yes for all four items.** Plan §2.2 now misses the seventh child (M2C-F8). |

### 2. M2-F1, the oracle child

- **The output is asserted whole:** version, major, minor, init, the five `(NAME F M)` lines and
  Valgrind's line, against the parsed output of `libsodium-oracle`. A `no-oracle` answer fails the
  row.
- **No one size line can read the wrong function and pass.** The decoy's answers, 33, 8, 80, 9 and
  81, are all different from each other.
  - `oracle-f-twins`, rerun: fails, as `(no-oracle run (1 "" "… has no crypto_generichash_keybytes\n"))`.
  - `oracle-kbmin-from-bmin` (the review's second replacement alone, which only a value can catch):
    fails, `(generichash-keybytes-min 8 16)` against `(… 9 16)`.
  - `test-native` passes 77 under both, as the log says.
- **`putenv`:** every `verb-row` child is spawned through `env` with `CHEZ_SODIUM_DECOY=…` or
  `-u CHEZ_SODIUM_DECOY` (`switch-args`). So no row depends on the order of the children, and
  the value never reaches a row's child. The decoy builds' `gcc` runs come before.
  - `oracle-no-putenv` (the `putenv` removed): the row fails, reading the control's
    `32 16 64 16 64`. So the switch is what the row measures.
- **Children:** under `make test-memory`, `build/memory/test-library-loading-verbs.children/`
  holds 7 Valgrind logs (six probes and the oracle), within 14. The suite passed under the gate
  in 34 s.

### 3. M2-F2, `test-decoy-source`

- **Checked against the brief's cases:**

  | Case | Result |
  |---|---|
  | `#include` with a macro argument | refused (`include-argument` answers the macro's name, which is neither `<…>` nor `"sodium.h"`) |
  | `# include` with spaces | read, by `directive`'s trim and the plant |
  | `#  define` with `##` after a comment | refused: `spaced-comment-paste` fails with `(… unreadable paste)` |
  | a backslash-newline in a string or a comment | passes (M2C-F3) |
  | CRLF | passes (M2C-F2) |
  | `??/` trigraphs | held by the compile (`-Werror=trigraphs`) |
  | `%:` digraphs | pass (M2C-F4) |

- **Each refusal fires on its plant by name, and not on the real files.** The real list's `()`
  holds for the decoy and the oracle. The interposer, `free-watch.c`, includes no sodium.h, so it
  is never read, and the claim is empty for it.
- **The header's "what it does not read" is not true now.**
  - It leaves out the directive splice, the CRLF continuation, `%:` and the `"sodium.h"` shadow.
  - "a macro that builds a name by other means than ##" describes nothing C has, apart from `%:%:`,
    which is `##` spelled another way.

### 4. M2-F6, the messages

- **No path puts a value into a message or an irritant today.** All five DETAIL arguments are
  `cap-detail`, built from `input-cap`, or `(key-detail)`, built from native's sizes. But no row
  holds this, and the mutants survive (M2C-F1).
- **No message says the given length of a secret.** They say "at most 65536 bytes" and "a key is
  16 to 64 bytes". Probed at both releases (`build/probes/msg.sps`, through `(chez-sodium)`):

  ```
  rb 65537   => "n is over the cap, 65536" | (over-the-cap n 65537)
  b2 size 15 => "size is from 16 to 64" | (size-out-of-range size 15)       ; 16 and 64 accepted
  b2 key empty => "key is refused: empty-key, shown by its kind alone; a key is 16 to 64 bytes" | (empty-key key (kind bytevector))
  b2 key 15 hunter2... => "key is refused: key-length-out-of-range, shown by its kind alone; a key is 16 to 64 bytes"
  b2 input 65537 => "input is refused: over-the-cap, shown by its kind alone; at most 65536 bytes"
  ct a / b 65537 => "a is refused: over-the-cap, …; at most 65536 bytes" / "b is refused: …"
  b2 input symbol => "input is refused: not-a-bytevector, shown by its kind alone"   ; no DETAIL, no "; "
  ```

  The output at 1.0.18 is the same, line for line. Native's range in the message is the range the
  verb enforces, because both read the same variables, and keys and sizes of 16 and 64 are
  accepted at both releases.
- **Every message is built before the section.** `cap-detail` and `cap-message` are computed in
  the library's body, and `size-message` and `key-detail` are called in a refusal's branch,
  before `call-in-section`. S3's whole symbol lists show that no helper is named inside a
  section.
- **S1 to S5 are unchanged and pass** (120 at both releases). The helpers sit outside the verbs'
  definitions, so S5's counts still count checks.
- **A DETAIL that is no string is refused by `refuse-secret` itself, through `shown-value`.**
  `detail-check-off` and `detail-by-secret-shown`, rerun, each fail "refuse-secret refuses a detail
  that is no string …". On the choice of `shown-value`, see M2C-F6.

### 5. The records

- **Checked against the code, and true:**
  - ADR-0007's two new points;
  - ADR-0011's "children" and its new point (but for M2C-F8's quote);
  - the constraints' cap and no-section lines (but for M2C-F8's "every input");
  - AGENTS.md's "Where the project stands" and its no-section bullet;
  - the slice 1 log's second correction;
  - the slice 2 log's two rows;
  - `progress.md`'s slice 1 close-out correction.
- **`progress.md`, "Now":**
  - These hold: three verbs, `cap`, the exports with `&sodium-failed`'s three names, thirteen
    entry points, 31 suites (`ls tests/test-*.sps` gives 31), four switches, and row 24 through
    the decoy.
  - The date is wrong (M2C-F7). "`test-decoy-source` holds its pointer rule" overstates it
    (M2C-F2 to F5).
- **"Next", "Owed to M3" and "Owed to M4":**
  - Each M3 item is true and carried, but for M2C-F8's `every-entry`. M3 also needs R16 to reach
    DETAIL (M2C-F1).
  - The M4 list is complete for M2.
- **The close-outs:**
  - The closing review's close-out matches the review: 14 mutants, 11 killed, 3 surviving.
  - Slice 2's close-out matches its review.

### 6. The traps and rules, over the diff

- **Assertions:**
  - The rows assert reason symbols, who and irritants, never a message.
  - The two new `test-conditions` rows go through `raised`, whose no-raise case is the distinct
    `(no-raise V)`.
  - The oracle row's actual value is computed under a guard, with its own `not-compiled` and
    `raised` sentinels.
  - Its expected value uses `floor-values`, which an `(exit 1)` before it guards.
- **Order:** no assertion depends on order. The `putenv` happens in a top-level definition,
  evaluated in program order, and the children are safe in any order (item 2).
- **Tests that test nothing:** one, the :913 plant (M2C-F3). The plant "a ## in a comment or a
  string is no paste" can fail only if `pasted?` reads lines that are not directives. It is weak
  but true to its name.
- **The comment rule:** no milestone, slice, date, research path or "the maintainer" in any line
  the diff adds under `src/`, `tests/`, the Makefile, `scripts/` or `packaging/` (grepped).
- **Privacy:** no local path, user name or host distribution in the diff (grepped for home paths,
  the user's names and common distributions). The log's paths are relative, under `build/`.

### 7. Mutants

Each was applied in a whole copy by exact replacement, with its match count checked.

| Mutant | Check | Result |
|---|---|---|
| `decoy-paste` (rerun) | real-files row | killed: `(… unreadable paste)` |
| `decoy-splice` (rerun) | real-files row | killed: `(… unreadable splice)` |
| `spaced-comment-paste` (mine) | paste rule | killed |
| `oracle-f-twins` (rerun) | oracle row | killed (`no-oracle`: no `_keybytes` in the decoy) |
| `oracle-kbmin-from-bmin` (mine; by value alone) | oracle row | killed: `(generichash-keybytes-min 8 16)` |
| `oracle-no-putenv` (mine) | oracle row | killed |
| `detail-check-off` (rerun) | `test-conditions`' detail row | killed |
| `detail-by-secret-shown` (rerun) | `test-conditions`' detail row | killed |
| `dir-paste-blank` (mine) | the compile | killed by `-Werror` (the scanner alone passes it) |
| `dir-splice` (mine) | test-decoy-source | **survived** (M2C-F2); full `make test` 31 of 31 |
| `dir-paste-split` (mine) | test-decoy-source | **survived** (M2C-F2) |
| `dir-paste-crlf` (mine) | test-decoy-source | **survived** (M2C-F2) |
| `comment-splice` (mine) | test-decoy-source | **survived** (M2C-F3) |
| `string-splice` (mine) | test-decoy-source | **survived** (M2C-F3) |
| `digraph-paste` (mine) | test-decoy-source | **survived** (M2C-F4); full `make test` 31 of 31 |
| `digraph-define` (mine) | macro rule | **survived** (M2C-F4; the gap predates this PR) |
| `digraph-include` (mine) | include rule | **survived** (M2C-F4) |
| `quoted-sodium-h` (mine) | include rule | **survived** (M2C-F5) |
| `indirect-include` (mine) | file selection | **survived** (M2C-F5) |
| `detail-length` (mine) | R16 | **survived every suite**: `make test` 31 of 31 (M2C-F1) |
| `detail-key-text` (mine) | R16 | **survived every suite**: `make test` 31 of 31 (M2C-F1) |

- **Mutants I could not kill:** the twelve survivors above. Each finding names its fix, and the
  fix of M2C-F2 and M2C-F3 was checked in whole copies: it kills all five of their survivors and
  keeps 52 passes.
- **The log should add:** `detail-length` and `detail-key-text`, against a widened R16, and the
  decoy-source survivors as plants once the rules are fixed.

## Checked and found sound

- **The clean runs.** At 1.0.22 and at the floor: `test-decoy-source` 52, `test-conditions` 53,
  `test-library-loading-verbs` 12, `test-byte-verbs` 120, and `test-native` 77 at the floor. Each
  exited 0, and the counts match the log.
- **Under the gate:** `test-library-loading-verbs` 34 s with 7 children, `test-decoy-source` 7 s
  and `test-conditions` 6 s; ran 3, passed 3, slow 0.
- **The oracle row (M2-F1)** holds each F line to its own function. Its `putenv` is safe in any
  order. It is gated, and counted within 14.
- **The messages (M2-F6)** state the bounds the verbs enforce, at both releases. They are built
  before every section, carry no secret today, and S1 to S5 hold the verbs unchanged.
- **`refuse-secret`** keeps its four-argument messages byte for byte. It refuses a non-string
  DETAIL itself, after WHO, RULE and PARAMETER. DETAIL is never an irritant: `detail-irritant-added`
  is logged as killed in 4 rows, and the new row's irritants are the same with a DETAIL as without.
- **The file refusals** fire by name on the review's plants and on the spaced `#  define`, and
  never on the real files.
- **Records:** ADR-0007's and ADR-0011's amendments, the constraints, AGENTS.md, the slice logs'
  corrections and M3's owed items, against the code (but for M2C-F7 and M2C-F8).
- **CI on #13** (`gh pr checks 13`, at the time of this review): all five jobs pass, `memory` in 18 m 14 s
  (run 45373169598).

The copy, `build/m2-cfr/`, was removed after this report.
