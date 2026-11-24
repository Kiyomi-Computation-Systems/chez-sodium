# Third review of M2's closing fixes: the second review's fixes (`63d3226..06516ad`)

Read-only and adversarial, over `git diff 63d3226..06516ad` on `m2-closing` (PR #13), against the
second review (M2C-F1 to M2C-F8), its log section, and the owner's decision of 2026-11-24, which I
did not reopen. I changed no project file. Every probe ran in `build/m2c3/tree/` (with
`build/slice5` copied in for the floor), and each mutant in a whole copy of its own,
`build/m2c3/mut/NAME/`, each one built by exact replacement with its match count checked, then
`make deps`, through that copy's own `scripts/guix-env`. I made no network fetch and ran no `gh`
command. No command was denied.

The container: Chez 10.4.0 threaded, GCC 16.2.0, libsodium 1.0.22 (the profile's), and the floor,
1.0.18, from `build/slice5/prefix-1.0.18`, with its headers first in `C_INCLUDE_PATH`.

**Counts: 0 blockers, 2 majors, 7 minors.**

- **M2C3-F1 (major):** R16 holds three encodings of the secret, not "nothing else of the call".
  Three mutants pass all 31 suites. Two are in `refuse-secret`, one in each branch of its
  sentence, and one is at a call site. They print the input's excess over the cap, the key's
  first four bytes as text, and the input's first byte as LOW.
- **M2C3-F2 (major):** `test-decoy-source` reads directives from text with its comments and
  strings stripped before any line is joined, the reverse of C's order. A `#define` whose comment
  wraps onto the next line hides `b1` with no splice at all. So do a splice inside a comment or
  a string in a directive, a `%:` split by splices, and a lone CR. Each compiles under
  `-Wall -Werror` and passes 66. The header's "joined as C joins them" is untrue.

---

## Findings

### M2C3-F1 (major): R16 searches for three encodings, so a part of the secret, or its length, passes it

- **Where:**
  - `tests/test-byte-verbs.sps:657-691`: R16's bound rows. Each searches the printed condition
    for `"hunter2"`, `"104 117 110 116 101 114 50"` and the length in decimal.
  - `src/chez-sodium/private/conditions.sls:126-138`: the sentence.
  - `src/chez-sodium/private/byte-verbs.sls:103,113-114,118-119,152,156`: the five calls.
  - The records that rest on R16: ADR-0006's amendment, `:154` ("may state its bound, and nothing
    else of the call") and `:165`; `.plans/global-constraints.md:129-133`; `.plans/progress.md:119-122`.
- **What:**
  - The owner's design closes the free-text channel: the sentence is written from two exact
    naturals. Two ways in are left:
    - `refuse-secret`'s own sentence, which holds VALUE in scope;
    - a call site that passes a natural computed from the secret.
  - R16 catches one spelling of each of three things: the text as UTF-8, the bytes as `write`
    prints all seven, and the length in decimal. Anything else passes: an excess over the cap, a
    prefix, a byte, hex.
  - The bytes needle cannot match an irritant at all. `display-condition` prints at most six
    elements of a bytevector irritant (probe below). R15 holds irritants whole at today's call
    sites, so this is no gap now, but the needle reaches only the message.
- **Probes:** three mutants, each in a whole copy, each run through the four nearest suites and
  then the whole `make test` at 1.0.22.
  - `rs-atmost-excess`: in `conditions.sls`'s `(= low 0)` branch, after `" bytes"`, append
    `(if (bytevector? value) (string-append ", " (number->string (- (bytevector-length value) high)) " over") "")`.
  - `rs-range-prefix`: in the `else` branch, after `" bytes"`, append `", begins "` and the
    value's first 4 bytes, read through `utf8->string`, when VALUE is a bytevector of 4 bytes or more.
  - `site-first-byte`: at `byte-verbs.sls:103`,
    `(refuse-secret 'blake2b 'over-the-cap 'input input (bytevector-u8-ref input 0) input-cap)`.

  ```
  == rs-atmost-excess   test-byte-verbs 125, test-conditions 58, test-public 8, test-library-loading-verbs 12: exit 0
     blake2b input 65537 => Exception in blake2b: input is refused: over-the-cap, shown by its kind alone; input is at most 65536 bytes, 1 over with irritants (over-the-cap input (kind bytevector))
     ct a 65537          => Exception in constant-time-bytevector=?: a is refused: over-the-cap, shown by its kind alone; a is at most 65536 bytes, 1 over with irritants (over-the-cap a (kind bytevector))
  == rs-range-prefix    (same four suites, same counts, exit 0)
     blake2b key 15      => Exception in blake2b: key is refused: key-length-out-of-range, shown by its kind alone; key is 16 to 64 bytes, begins hunt with irritants (key-length-out-of-range key (kind bytevector))
  == site-first-byte    (same four suites, same counts, exit 0)
     blake2b input 65537 => Exception in blake2b: input is refused: over-the-cap, shown by its kind alone; input is 104 to 65536 bytes with irritants (over-the-cap input (kind bytevector))

  make test, each of the three: test: ran 31, passed 31, failed 0, hung 0   exit=0
  ```

  The irritant limit (`build/probes/dc.sps`):

  ```
  (assertion-violation 'w "m" (string->utf8 "hunter2hunter2"))
    => Exception in w: m with irritant #vu8(104 117 110 116 101 114 ...)
  ```

  S1 to S5 do not see `site-first-byte` either. It adds no lambda, no section symbol and no
  `input-cap`.
- **Why major:** no code shows a secret today. All five calls pass `0 input-cap` or native's
  two sizes. But the rule is the project's first. The records say R16 holds it, and R16 holds
  three spellings. M3 makes this sharper: a password's prefix or its UTF-8 length is what a
  helpful message would print.
- **Fix:** hold that the printed refusal does not depend on the value at all, and keep the
  needles as they are.
  - **What to add:** a row per bound refusal that prints the condition for three secrets under
    the same rule:
    - `hunter-bytes n`;
    - `(make-bytevector n 0)`, the same length with other bytes;
    - `hunter-bytes m`, another length that breaks the same rule: 65538, or keys of 14 and 66.
  - **What it asserts:** `'(refused same same)`. This asserts no message text, and catches any
    encoding, in the message or an irritant.
  - **Checked in whole copies.** The rows, as tried (`build/m2c3/specs/fix-r16.json`):

    ```scheme
    (define (printed-refusal thunk)
      (let ((c (guard (e (#t e)) (thunk) 'no-raise)))
        (if (assertion-violation? c) (describe c) (list 'not-refused c))))
    ;; per row: p (hunter-bytes n), q (make-bytevector n 0), r (hunter-bytes m)
    ;; actual (list (if (string? p) 'refused p)
    ;;              (if (equal? p q) 'same (list 'differs q))
    ;;              (if (equal? p r) 'same (list 'differs r)))
    ```

    ```
    fix-r16                    test-byte-verbs exit=0, 130 passes
    fix-r16+rs-atmost-excess   3 fail: (refused same (differs "...; input is at most 65536 bytes, 2 over ..."))
    fix-r16+rs-range-prefix    2 fail: (refused (differs "...; key is 16 to 64 bytes, begins \x0;\x0;\x0;\x0; ...") same)
    fix-r16+site-first-byte    1 fails: (refused (differs "...; input is at most 65536 bytes ...") same)
    ```

  - **Records:** log the three mutants. Owe M3 the same differential row for every password
    refusal that states a bound, with two strings of one UTF-8 length and one of another, and
    non-ASCII among them. Say in ADR-0006's amendment, the constraint and `progress.md` that R16
    holds the printed refusal constant across secrets, not only that it finds no needle.

### M2C3-F2 (major): directives are read from stripped text before lines are joined, so a comment, a string, a split `%:` or a lone CR still hides a name

- **Where:**
  - `tests/test-decoy-source.sps:343-344`: `directives` reads `(lines-of (strip text keep-strings?))`.
    `strip` (`:102`) blanks each comment and string but keeps its newlines, before any line is
    joined.
  - `:184-191`: `code-text`, which does the same.
  - `:430-436`: `splice-outside-directive?` reads the raw line only outside a directive.
  - `:439-440`: `digraph?` reads the stripped text, before its lines are joined.
  - `:142-149`: `lines-of` splits at LF alone.
  - The header's claims: `:45-48`, a `##` "in any directive, its backslash continuations joined as
    C joins them"; `:49-52`, a splice "in a comment or a string too"; `:65-67`, what it does not
    read.
- **What:** C works in phases. It deletes each backslash-newline (phase 2), then makes each
  comment one space, newlines and all (phase 3), and only then reads directives (phase 4). The
  scanner strips first and joins after, and only at a backslash it can still see.
  - **A comment that wraps** inside a `#define` continues the directive in C, with no backslash.
    To the scanner the next line is code at the top level, outside every body. This is the most
    natural of the vectors: a comment in a macro that wraps.
  - **A splice inside a comment or a string in a directive.** `strip` blanks the backslash, so
    the stripped line is no continuation. F3's raw-line rule runs only outside a directive.
  - **A `%:` split by splices.** `b%\`⏎`:%\`⏎`:n` is `b%:%:n`, that is `b##n`, to C. `digraph?`
    reads unjoined text, which holds no `%:`. `pasted?` reads the joined directive, which holds
    no `##`.
  - **A lone CR.** GCC takes CR as a line end. `lines-of` does not, so a directive after a CR
    is mid-line code to the scanner.
- **Probes:** each mutant edits the real decoy. It adds a definition after `DECOY_OVERFLOW`'s
  line, and replaces `p1 ? "p"` in `sodium_memcmp`'s `called(...)` line with the macro. The
  compile is the suites' own: `gcc -Wall -Werror -shared -fPIC -o … tests/decoy-libsodium.c
  -DDECOY_VERSION="1.0.22" -DDECOY_BELOW="1.0.17"`. "cpp" is `gcc -E -P` on the same line.

  | Mutant | Added (⏎ is a newline, ␍ a lone CR) | Compile | cpp's `called` line | `test-decoy-source` |
  |---|---|---|---|---|
  | `dir-multiline-comment` | `#define DECOY_P /* the pointer,`⏎`   as the macro names it */ b1` | exit 0 | `b1 ? "p" : "NULL"` | **exit 0, 66 passes** |
  | `dir-comment-splice` | `#define DECOY_P /* *\`⏎`/ b1 /* */` | exit 0 | `b1 ? "p" : "NULL"` | **exit 0, 66** |
  | `dir-comment-splice-paste` | `#define DECOY_PARAM(n) b/* *\`⏎`/##n /* */` | exit 0 | `b1 ? "p" : "NULL"` | **exit 0, 66** |
  | `dir-string-splice` | `#define DECOY_P ((void) "\\`⏎`\", b1) /* " */` | exit 0 | `((void) "\\", b1) ? "p" : "NULL"` | **exit 0, 66** |
  | `dir-digraph-splice` | `#define DECOY_PARAM(n) b%\`⏎`:%\`⏎`:n` | exit 0 | `b1 ? "p" : "NULL"` | **exit 0, 66** |
  | `lone-cr-define` | `int decoy_cr = 0;`␍`#define DECOY_P b1` | exit 0 | `b1 ? "p" : "NULL"` | **exit 0, 66** |
  | `lone-cr-paste` | `int decoy_cr = 0;`␍`#define DECOY_PARAM(n) b##n` | exit 0 | `b1 ? "p" : "NULL"` | **exit 0, 66** |

  `make test` on `dir-multiline-comment` and on `dir-comment-splice`: "ran 31, passed 31, failed
  0, hung 0", exit 0 each. `b1` is no `nonnull` parameter, so the compile accepts a plain test
  of it.
- **Fix:** read directives and code as C does.
  - **Line ends:** first take CRLF as LF, and refuse a lone CR.
  - **Comments:** make each block comment one space, its newlines included, so that a directive
    runs on to the end of its logical line.
  - **Splices:** refuse a raw line that ends in `\` where the stripped line does not, inside a
    directive or out: that backslash sits in a comment or a string.
  - **Digraphs:** read `%:` in the joined directives too.

  I checked this in whole copies (`build/m2c3/specs/fix-scan2.json`):
  - `strip-joined`, which is `strip` with a block comment's newlines written as spaces, is used by
    `directives` and `code-text`;
  - the splice rule refuses a raw splice whose stripped line has none;
  - `digraph?` also reads `(directives text #f)`;
  - `lone-cr?` gives `(FILE unreadable line-end)`.

  ```
  fix-scan2                        test-decoy-source exit=0, 66 passes (the real files and every plant)
  +dir-multiline-comment           exit=1: (("sodium_memcmp" "b1" macro))
  +dir-comment-splice              exit=1: (("tests/decoy-libsodium.c" unreadable splice))
  +dir-comment-splice-paste        exit=1: (... unreadable splice)
  +dir-string-splice               exit=1: (... unreadable splice)
  +dir-digraph-splice              exit=1: (... unreadable digraph)
  +lone-cr-define / +lone-cr-paste exit=1: (... unreadable line-end)
  ```

  - **The real files have none of these forms.** None has a CR. None opens a block comment in a
    directive without closing it on the same line. The oracle's five splices sit after code.
  - **Plants:** add the seven as plants, watch each fail on today's scanner, and log them.
  - **The header:** correct `:45-52`, and add these forms to `:65-67` for as long as any is
    unread.

### M2C3-F3 (minor): `strip` lexes neither C23's digit separators nor GNU raw strings

- **Where:** `tests/test-decoy-source.sps:124-138`, `strip`'s literal branch. Every `'` or `"`
  opens a literal there.
- **What:** GCC 16 defaults to `gnu23`.
  - `1'0` is a number with a digit separator. The scanner opens a character literal at the `'`
    and closes it at the next one.
  - `R"(a")"` is one raw string. The scanner ends a string at the inner `"`, then opens another.
  - Either way, code C compiles lies inside what the scanner strips. This predates this round,
    but item 4 asks whether a file can still hide a name, and the header's list leaves it out.
- **Probes** (the real decoy's `sodium_memcmp` body, after `int equal = 1;`):

  ```
  digit-sep:  { int decoy_q = 1'0; if (b1) decoy_q = 2'0; (void) decoy_q; }
              compile exit=0; test-decoy-source exit=0, 66 passes; make test: ran 31, passed 31
  raw-string: { const char *decoy_r = R"(a")"; if (b1) decoy_r = 0; (void) decoy_r; /* " */ }
              compile exit=0; test-decoy-source exit=0, 66 passes
  ```

- **Fix:** refuse, as `(FILE unreadable literal)`, a quote that opens a literal right after an
  identifier character. That covers `R"`, `u8"`, `L'` and `1'0`. Real files have none
  (`build/m2c3/lexcheck.py` over `tests/*.c`: no hit). In `fix-scan`, both mutants fail
  `(… unreadable literal)`, and the real files and plants pass 66.

### M2C3-F4 (minor): an include in `<...>` may name a local file by an absolute path

- **Where:** `tests/test-decoy-source.sps:454-461`: `foreign-include?` accepts any `<...>`.
- **What:** GCC opens an absolute path in `<...>` as it is. A relative one with `..` resolves
  against the search path. `</proc/self/cwd/tests/decoy-extra.h>` reaches the checkout from any
  machine, since the suites compile from the project's root.
- **Probe:** `abs-include` adds `#include </proc/self/cwd/tests/decoy-extra.h>` after
  `<sodium.h>`. `tests/decoy-extra.h` is `#define DECOY_P b1`, and `DECOY_P` is used in the
  `called` line. The compile exits 0, and cpp gives `b1 ? "p" : "NULL"`. `test-decoy-source`
  exits 0 with 66 passes.
- **Fix:** refuse a `<...>` argument whose path starts with `/` or holds `..`. In `fix-scan` the
  mutant fails `(… unreadable include)`, and the real files pass.

### M2C3-F5 (minor): the every-file row runs the include rule alone, so a `%:include` hides sodium.h

- **Where:** `tests/test-decoy-source.sps:619-626` (the every-file row) and `:576-578`
  (`foreign-includers`). Header `:61-62`: "so that a local header cannot hide sodium.h from the
  glob".
- **What:**
  - A file that includes sodium.h by no `#include` gets no scan, and so no digraph or line-end
    rule.
  - The every-file row reads only `#` directives, so `%:include "x.h"` in such a file passes. So
    does a directive after a lone CR.
  - M2C-F5's indirect route is open again by another spelling.
- **Probe:** `indirect-digraph` changes the real `tests/free-watch.c`. It adds
  `%:include "decoy-two.h"`, where `tests/decoy-two.h` is `#include <sodium.h>`, and adds
  `int crypto_decoy_probe(const unsigned char *k) { return k ? 1 : 0; }`.

  ```
  free-watch compile (gcc -Wall -Werror -shared -fPIC … -ldl): exit=0; cpp names crypto_generichash 32 times
  test-decoy-source: exit=0, 66 passes
  ```

- **Fix:** have the every-file row assert every file refusal of every `tests/*.c`:
  `(apply append (map (lambda (f) (file-refusals (cdr f) (car f))) files))`. In `fix-scan` the
  row then fails `(("tests/free-watch.c" unreadable digraph))`, and the real files pass.

### M2C3-F6 (minor): the records overstate the fixes, and two items of the second review are still stale

- **"R16 reaches every refusal that states a bound"** (ADR-0006 `:165`,
  `global-constraints.md:131`, `progress.md:119`).
  - The empty key's refusal states one ("key is 16 to 64 bytes"), and R16 skips it by design
    (`test-byte-verbs.sps:657-661`).
  - Say "every one but the empty key's, whose length is its rule".
- **ADR-0006 `:158-159`:** "or "at most HIGH bytes" when LOW is 0". The code writes "PARAMETER is
  at most HIGH bytes" (`conditions.sls:132-133`).
- **`progress.md`:**
  - **`:46`:** "`test-decoy-source` holds its pointer rule". The second review called this
    overstated (its item 5), and it still is (M2C3-F2 to F5).
  - **`:180`:** "It now joins as C does". It does not for comments, strings or CR (M2C3-F2).
  - **`:181`:** "a splice that ends a comment or a string is refused". That holds outside a
    directive only.
- **The log:**
  - **`:26`:** "it is the last row that spawns". M2C-F8 named this line beside the suite's
    `:38`, and only the suite was corrected.
  - **`:41` and `:55`:** M2-F2's section still lists `"sodium.h"` with odd spacing as a negative
    control. It also says the header names "a splice inside a comment or a string" as unread.
    Both are superseded, and the section has no note, unlike M2-F6's (`:60-61`).
  - **`:188`:** "the two DETAIL rows replaced by 6 rows". The item lists 7, and the suite went
    from 53 rows to 58: 53 − 2 + 7.
- **`tests/test-byte-verbs.sps:25-26`:** the suite header's R16 line still describes the type
  rows alone ("a symbol, a number and a list of characters"). The bound rows are new.
- **Fix:** correct each as above.

### M2C3-F7 (minor): the five-argument row's secret needle cannot fail, and no row calls with seven

- **Where:** `tests/test-conditions.sps:517-534`.
- **What:**
  - The row passes `(string->utf8 "hunter2")`, which prints as `#vu8(104 117 …)`, and searches
    for `"hunter2"`. That needle can never match.
  - The other needles name the who, the rule, the parameter and 4242424. A clause that printed
    the value alone would print none of them.
  - Today the call raises Chez's arity refusal, and a 7-argument call does the same (probe
    below). But no row holds 7.
- **Probes:**

  ```
  (refuse-secret 'whoever 'ruling 'param <bv hunter2> 4242424)   => Exception: incorrect number of arguments 5 to #<procedure refuse-secret at conditions.sls:4271>
  (refuse-secret 'whoever 'ruling 'param "hunter2" 0 10 "hunter2") => Exception: incorrect number of arguments 7 to #<procedure refuse-secret at conditions.sls:4271>
  (0, 3 and 8 arguments: the same, the count and the procedure only)

  rs-five-value: a clause ((who rule parameter value extra) (assertion-violation 'refuse-secret "no such clause" value))
    test-conditions exit=0, 58 passes
    printed: Exception in refuse-secret: no such clause with irritant #vu8(104 117 110 116 101 114 ...)
  rs-seven: a clause ((who rule parameter value low high note) (assertion-violation who note rule parameter (secret-shown value)))
    test-conditions 58, test-byte-verbs 125: exit 0
  ```

- **Fix:**
  - Pass a string secret, or add the bytes needle as R16 did.
  - Make it two calls, of 5 and of 7 arguments.
  - Log `rs-five-value`.

### M2C3-F8 (minor): no row holds WHO before RULE before PARAMETER

- **Where:** `tests/test-conditions.sps:452-460` and `:499-505`. Each call there has one bad field
  among the three.
- **What:** the code checks WHO, RULE, PARAMETER, LOW, then HIGH (`conditions.sls:115-125`).
  The rows hold LOW before HIGH and the three before the bound, but not the order of the three.
  This predates this round; the brief asks whether the order holds.
- **Probe:** `rs-field-order` checks PARAMETER, then RULE, then WHO.

  ```
  test-conditions exit=0, 58 passes; test-byte-verbs exit=0, 125 passes
  ```

- **Fix:** add a row with all three bad, which expects `(who (kind string))`, and one with RULE
  and PARAMETER bad, which expects `(rule (kind string))`.

### M2C3-F9 (minor): R16's bound control reads the message's wording

- **Where:** `tests/test-byte-verbs.sps:684`, `(occurs-in? (caddr call) text)`, which expects
  `"65536"`, `"16"` or `"64"` in the printed text. Against it: AGENTS.md `:147` and
  `global-constraints.md:134`, "Tests assert a condition's reason symbol, never its message".
- **What:**
  - The control is there so that a print that lost the message cannot pass. But it fixes how the
    message is worded: "64 KiB", say, would fail it.
  - AGENTS.md names `test-reference` as the one exception to a similar rule. R16's control is not
    named.
- **Fix:** either name R16's control as the exception, since it holds the owner's choice that the
  message states its bound, or make it structural, `(occurs-in? (condition-message c) text)`.
  The structural form shows the print carries the message without fixing its words. With
  M2C3-F1's rows, the second is enough.

---

## Work list, item by item

### 1. M2C-F1 to M2C-F8: is each fixed, whole?

| Finding | Fixed? |
|---|---|
| M2C-F1 | **The design, yes; its hold, partly.** No free text reaches the message: a bad bound is refused by kind (probes, item 2). The new R16 rows reach every bound refusal but the empty key's, and the two named mutants would now fail. But "nothing else of the call" is held by three needles (M2C3-F1). |
| M2C-F2 | **Partly.** Code-level continuations inside a directive are joined with nothing between, and CRLF continuations are read. The plants pass in the clean tree, and by the log its `join-space`, `more-last-char` and `code-more-old` mutants each fail a plant. But a comment or string inside a directive, a split `%:`, and a lone CR still hide a name or a paste (M2C3-F2). |
| M2C-F3 | **Outside a directive, yes; inside, no.** The raw line is read outside a directive, and the `:913` plant is replaced by two that fail on the old rule. Inside a directive the splice is still read from the stripped line (M2C3-F2's `dir-comment-splice`, `dir-string-splice`). |
| M2C-F4 | **Partly.** `%:` in the stripped text is refused. A `%:` cut by splices in a directive is not (`dir-digraph-splice`). A file read by the every-file row alone is not checked for one (M2C3-F5). |
| M2C-F5 | **Yes for both named vectors.** `"sodium.h"` is refused, and the include rule runs over every `tests/*.c`. Left open: an absolute `<...>` path (M2C3-F4), and an include the every-file row cannot see (M2C3-F5). |
| M2C-F6 | **Yes, by the decision.** A bad bound is refused through `refuse-field`, by kind, whatever it is. |
| M2C-F7 | **Yes.** "#10 and #11 … on 2026-11-23, #12 on 2026-11-24, and #13 after it", and the close-out is dated 2026-11-24. |
| M2C-F8 | **Six of seven.** Fixed: 15 rows and "negative control", plan §2.2's seventh child, ADR-0011's quote, the constraints' "every input but `blake2b`'s key", `scan`'s signature, and `every-entry`. Left: the log's `:26` (M2C3-F6). |

### 2. `refuse-secret`

- **No path inside `refuse-secret` puts VALUE, a part of it or its length into a message or an
  irritant.**
  - VALUE is read only by `secret-shown`.
  - The message is built from two checked symbols and two checked naturals.
  - A tilde in a symbol is printed as it is: `display-condition` formats no message here.
  - Probed at every arity and every kind of bad bound (`build/probes/rs.sps`):

  ```
  4 args          => Exception in w: p is refused: r, shown by its kind alone with irritants (r p (kind bytevector))
  6 args 0 65536  => …; p is at most 65536 bytes with irritants (r p (kind bytevector))
  6 args 16 64    => …; p is 16 to 64 bytes …        6 args 0 0 => …; p is at most 0 bytes …
  0, 3, 5, 7, 8   => Exception: incorrect number of arguments N to #<procedure refuse-secret at conditions.sls:4271>, irritants (N #<procedure …>)
  low "hunter2"   => Exception in refuse-secret: not an exact natural with irritants (low (kind string))
  low #vu8(hunter2) => … (low (kind bytevector))     high #vu8(hunter2) => … (high (kind bytevector))
  low 1.0, 1/2    => (low (kind number))   high +inf.0, 1+2i => (high (kind number))   11 10 => (high (kind number))
  who "hunter2" with low "hunter2" => (who (kind string))
  param '~s       => Exception in w: ~s is refused: r, …; ~s is at most 10 bytes …
  ```

- **A secret string or bytevector in LOW or HIGH is shown by its kind alone,** and the message
  says only "not an exact natural". A natural computed from the secret is shown as it is. That
  is the decision, and only R16 can hold it (M2C3-F1).
- **The order:**
  - The code checks WHO, RULE, PARAMETER, LOW, then HIGH, and LOW above HIGH is refused as
    `high`.
  - The rows hold LOW before HIGH, and the three fields before the bound.
  - They do not hold the order of the three (M2C3-F8).
- **`no-bound` is safe.**
  - It is a fresh list, and neither it nor `refuse-secret*` is exported (`conditions.sls:34`).
  - No caller can pass it: the 6-argument clause passes the caller's own values.
  - `bound?` reads LOW alone, which is sound, since only the 4-argument clause passes `no-bound`,
    and it passes it as both.
  - `refuse-secret` refers to `no-bound`, defined after it, only when called, and nothing in the
    library's body calls it.

### 3. R16 and the conditions rows

- **Mutants that leak through a refusal stating a bound and pass every suite:** one in the
  `0 to HIGH` branch, one in the `LOW to HIGH` branch and one at a call site (M2C3-F1).
- **The traps:**
  - Every new row computes what can raise under a guard, with a sentinel of its own: `no-raise`,
    `(not-refused C)` and `(no-raise V)`.
  - No row expects `#f`.
  - R16's expected `(refused states-bound clean clean)` cannot come from another rule's refusal:
    a type refusal states no bound.
  - No needle is a substring of a stated bound: 65537, 15 and 65, against 65536, 16 and 64.
  - The rows depend on no order of evaluation.
  - Two needles can never match: the five-argument row's `"hunter2"` (M2C3-F7), and R16's bytes
    needle against an irritant (M2C3-F1).
- **S1 to S5 hold the verbs unchanged** (125 passes at both releases).
  - S5's new counts are right. `blake2b`'s definition names `input-cap` at `byte-verbs.sls:102`
    and `:103`. The compare names it at `:151`, `:152`, `:155` and `:156`. `random-bytes` names
    it at `:71`, with `cap-message` written apart at `:53`.
  - The count is a sum, and cannot tell a check from a statement. R15's boundary rows hold the
    checks, and R16's control holds the statements.

### 4. `test-decoy-source`

- **Can a file still hide a pointer's name and compile under `-Wall -Werror`? Yes, eleven ways,**
  each passing 66:
  - seven in M2C3-F2;
  - two in M2C3-F3;
  - one in M2C3-F4;
  - one in M2C3-F5.

  Each is killed, with the real files and every plant still passing, by the fixes checked in
  `fix-scan` (the line-end, literal, include and every-file rules) and `fix-scan2` (the logical
  lines).
- **The new rules refuse nothing in the real files** (66 passes at both releases).
  - A plausible M3 addition: `crypto_pwhash_str*` entries, or a FIFO decoy built on `<fcntl.h>`
    and `<unistd.h>`. Nothing I can see in either is refused.
  - The forms my fixes add refusals for are not in the real files: no CR, no prefixed literal,
    no comment that wraps inside a directive, no absolute include.
- **The header's list of what it does not read is not true.** It leaves out:
  - a comment, a string or a `%:` inside a directive's continuation, or a comment that wraps;
  - a lone CR;
  - digit separators and raw strings;
  - an absolute `<...>`;
  - `%:include` in a file read by the every-file row alone.

  "a macro that builds a name by other means than ##" still names nothing C has apart from
  `%:%:`, as the second review said.

### 5. The records

- **True against the code:**
  - ADR-0006's amendment: LOW and HIGH, two exact naturals; the sentence written in
    `refuse-secret`; anything else refused by kind; irritants unchanged.
  - The constraint's first two sentences.
  - `progress.md`'s M3 items, with M2C3-F1's addition.
  - The log's change list and its clean-rerun counts.
- **Overstated or stale:** M2C3-F6.
- **The log's mutants:**
  - **Rerun:** one, `detail-length` in its new form (`0 (bytevector-length input)`). It fails R16,
    `(refused no-bound-stated clean leaks)`, and S5, `(blake2b 1)`, as the log says.
  - **Not rerun:** the rest. Instead, in the clean tree, the plants for the log's vectors pass,
    and each rule the log names is in the code. I spent the probes on new mutants.

### 6. The rules over the diff

- **The comment rule:** no milestone, slice, finding id, research path, date or "the
  maintainer" on any line the diff adds under `src/`, `tests/`, the Makefile, `scripts/` or
  `packaging/`. I grepped the added lines for `M[0-9]`, `F[0-9]`, `slice`, `review`, `2026`,
  `.plans` and `research`. The only hits were `utf8` and "searching".
- **Privacy:** no local path, user name or host distribution in the diff. I grepped for home
  paths, the user's names, the host's distribution and its vendor. The log's paths are relative,
  under `build/`.

## Mutants

| Mutant | Where | Result |
|---|---|---|
| `rs-atmost-excess` | `conditions.sls`, at-most branch | **survived every suite** (make test 31/31): M2C3-F1 |
| `rs-range-prefix` | `conditions.sls`, LOW-to-HIGH branch | **survived every suite** (31/31): M2C3-F1 |
| `site-first-byte` | `byte-verbs.sls:103` | **survived every suite** (31/31): M2C3-F1 |
| `rs-five-value` | `conditions.sls`, a 5-argument clause | **survived** `test-conditions` (58): M2C3-F7 |
| `rs-seven` | `conditions.sls`, a 7-argument clause | **survived** `test-conditions` and `test-byte-verbs`: M2C3-F7 |
| `rs-field-order` | `conditions.sls`, the order of the three checks | **survived** `test-conditions` and `test-byte-verbs`: M2C3-F8 |
| `dir-multiline-comment` | the decoy | **survived every suite** (31/31): M2C3-F2 |
| `dir-comment-splice` | the decoy | **survived every suite** (31/31): M2C3-F2 |
| `dir-comment-splice-paste`, `dir-string-splice`, `dir-digraph-splice`, `lone-cr-define`, `lone-cr-paste` | the decoy | **survived** `test-decoy-source` (66): M2C3-F2 |
| `digit-sep` | the decoy | **survived every suite** (31/31): M2C3-F3 |
| `raw-string` | the decoy | **survived** `test-decoy-source`: M2C3-F3 |
| `abs-include` | the decoy, and a header | **survived** `test-decoy-source`: M2C3-F4 |
| `indirect-digraph` | `free-watch.c`, and a header | **survived** `test-decoy-source`: M2C3-F5 |
| `detail-length-new` (rerun of the log's, in the new form) | `byte-verbs.sls:103` | killed: R16 input row and S5 |
| `fix-r16` + each of the first three | R16's differential rows | each killed (3, 2 and 1 rows); clean 130 |
| `fix-scan` + each decoy mutant but the wrapped comment, and `indirect-digraph` | the scanner fix | each killed by name; clean 66 |
| `fix-scan2` + `dir-multiline-comment` | the logical-lines fix | killed: `("sodium_memcmp" "b1" macro)`; clean 66 |

Every decoy mutant compiled under the suites' own `-Wall -Werror` line, exit 0, and `gcc -E -P`
showed a plain test of `b1` (or, for the two body mutants, the `if (b1)` they add).

## Checked and found sound

- **The clean runs.**
  - At 1.0.22: `test-decoy-source` 66, `test-conditions` 58, `test-byte-verbs` 125 and
    `test-library-loading-verbs` 12.
  - At the floor: the same four, and `test-native` 77.
  - The clean tree's `make test`: "ran 31, passed 31, failed 0, hung 0".
  - These match the log.
- **`refuse-secret`'s design.**
  - Two clauses only. A bound that is no exact natural, or LOW above HIGH, is refused by kind.
  - WHO, RULE and PARAMETER are checked before the bound, and LOW before HIGH.
  - The sentence is written from the numbers alone, and the irritants are unchanged.
  - Chez's arity refusal names the count and the procedure only, at 0, 3, 5, 7 and 8 arguments.
- **The five calls.** They pass `0 input-cap` for `input`, `a` and `b`, and native's two key
  sizes for the key's two refusals. Each is before its verb's section, and S2's and S3's whole
  lists are unchanged.
- **R16's new rows:**
  - They are refused, state the bound, and print neither "hunter2", the seven bytes nor the
    length.
  - Under the second review's `detail-length`, rebuilt as `0 (bytevector-length input)`, the
    input row fails twice over, `(refused no-bound-stated clean leaks)`, and S5 fails too
    (rerun).
- **The scanner's new rules fire on their plants by name, and never on the real files:**
  - the join with nothing between;
  - the CRLF continuation;
  - the raw-line splice outside a directive;
  - `%:` in code;
  - `"sodium.h"` refused;
  - the every-file include row.
- **Records:**
  - ADR-0006's amendment, but for M2C3-F6's two lines.
  - The constraint's design sentence.
  - ADR-0011's corrected quote.
  - The constraints' cap line.
  - Plan §2.2's seven children.
  - The M3 item naming `(library-loading)`'s `every-entry`.
  - The close-out's counts, against the review and the log: 2 majors and 6 minors; seven mutants
    rebuilt, each listed as failing.
- **The comment rule and privacy,** over every added line.

## Appendix: the fixes as checked

The copy is gone, so the paths `build/m2c3/…` above no longer exist. These are the changes as I
checked them. They are a sketch for a fixer, not finished code: their comments and signatures
are not written.

**R16's differential rows** (`tests/test-byte-verbs.sps`, after `bound-calls`' `for-each`):

```scheme
(define (printed-refusal thunk)
  (let ((c (guard (e (#t e)) (thunk) 'no-raise)))
    (if (assertion-violation? c) (describe c) (list 'not-refused c))))

(define bound-twins
  (list (list "blake2b input of 65537 and 65538 bytes" (lambda (s) (blake2b s)) 65537 65538)
        (list "blake2b key of 15 and 14 bytes" (lambda (s) (blake2b abc 32 s)) 15 14)
        (list "blake2b key of 65 and 66 bytes" (lambda (s) (blake2b abc 32 s)) 65 66)
        (list "constant-time-bytevector=? a of 65537 and 65538 bytes" (lambda (s) (constant-time-bytevector=? s abc)) 65537 65538)
        (list "constant-time-bytevector=? b of 65537 and 65538 bytes" (lambda (s) (constant-time-bytevector=? abc s)) 65537 65538)))

(for-each
 (lambda (row)
   (test-equal (string-append "R16 " (car row) ": the printed refusal is the same for other bytes of the same length, and for another length under the same rule")
     '(refused same same)
     (let* ((call (cadr row)) (n (caddr row)) (m (cadddr row))
            (p (printed-refusal (lambda () (call (hunter-bytes n)))))
            (q (printed-refusal (lambda () (call (make-bytevector n 0)))))
            (r (printed-refusal (lambda () (call (hunter-bytes m))))))
       (list (if (string? p) 'refused p)
             (if (equal? p q) 'same (list 'differs q))
             (if (equal? p r) 'same (list 'differs r))))))
 bound-twins)
```

**The scanner** (`tests/test-decoy-source.sps`):

- **`strip-joined`:** a copy of `strip` whose block-comment branch writes `#\space` for every
  character, its newlines included. `directives` and `code-text` read `(lines-of (strip-joined …))`
  in place of `(lines-of (strip …))`.
- **`splice-outside-directive?`:** the test becomes
  `(and (spliced? (car raw)) (or (not in-directive?) (not (spliced? (car stripped)))))`.
- **`digraph?`:** `(or (contains? (strip text #f) "%:") (exists (lambda (d) (contains? d "%:")) (directives text #f)))`.
- **`lone-cr?`:** a `#\return` not followed by `#\newline` gives `(FILE unreadable line-end)`.
- **`prefixed-literal?`:** a walk that skips comments and literals as `strip` does. When a `"` or
  `'` opens a literal right after an `ident-char?` character, the answer is `#t`, given as
  `(FILE unreadable literal)`.
- **`foreign-include?`:** a `<...>` argument is foreign when `(char=? (string-ref arg 1) #\/)` or
  `(contains? arg "..")`.
- **`file-refusals`:** it appends `line-end` and `literal` after `digraph`.
- **The every-file row:** its second element is
  `(apply append (map (lambda (f) (file-refusals (cdr f) (car f))) files))`.

Each new refusal needs its plants, a negative control and the header's line, as the existing
ones have.

The copy, `build/m2c3/`, was removed after this report.
