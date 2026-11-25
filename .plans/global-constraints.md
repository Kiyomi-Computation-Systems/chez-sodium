# Global constraints

The hard rules from the decision records. Every task brief is bound by them. Each rule cites the
record it comes from, and where a rule and its record disagree, the record wins.

## Platforms and versions

- **Linux only.** No macOS or Windows code paths, no macOS or Windows CI, and no abstraction kept
  only so another platform could come later ([ADR-0010]). A release claims Linux on x86_64, and
  names arm64 as not run ([ADR-0010], amended).
- **libsodium and a threaded Chez, each at its floor in `packaging/floors.sexp`.**
  `(chez-sodium private require-threaded)` refuses an unthreaded Chez, and one below its floor,
  by name while it is expanded, and every library under `src/` imports it first ([ADR-0004]).
  `make check-nothreads` refuses every library under `src/` by name on CI's `--nothreads` Chez
  ([ADR-0004]).
- **libsodium's floor is read from `sodium_version_string`,** parsed strictly as three naturals,
  with no sign, space or leading zero, and compared with the file. NULL, or a string that is not
  three naturals, is `below-floor`. `sodium_library_version_major` and `_minor` are libtool
  numbers: reported beside it, never compared ([ADR-0003]).
- **The floors are written once, in `packaging/floors.sexp`, in their dotted form.**
  `make check-floors` holds README.org's Requirements to the file, and refuses a floor's dotted
  text wherever it reads. CI reads floors through `scripts/ci/floor.sh` and writes none. The code
  is held to the file by behaviour: the floor is accepted and the version below it refused
  ([ADR-0011]; chez-sqlite3 ADR-0008).
- **The libsodium floor is raised only by a record.** CI tests the floor, Guix's version and the
  latest point release, and `current` moves at each point release ([ADR-0003]).
- **A new libsodium release on any lane needs row 22's high-byte answer measured first:**
  `current`'s pin bumped, a `channels.scm` bump that moves Guix's libsodium, or a distribution's
  package. `test-native-codes`' tripwire fails on any release but 1.0.18 and 1.0.22
  ([ADR-0011], amended).
- **CI builds libsodium from a point-release tarball,** never `-stable` or `LATEST`, pinned by a
  SHA-256 the project computed and checked once against the `.minisig` with libsodium's
  published minisign key, and falls back to `releases/old/` ([ADR-0003]).

## What is bound

- **A function is bound only if Techo has a named use for it.** `constant-time-bytevector=?` is
  the one exception. Adding one takes a row in the brief's subset, a row in the convention table,
  and a test on every supported libsodium. `crypto_generichash_keybytes` has none, and is not
  bound ([ADR-0005], amended).
- **No verb holds state between calls: no handles.** `hmac-sha256` is one call, and streaming
  SHA-256 is out ([ADR-0005]).
- **The verbs' names are the brief's §4, with no prefix,** exported by `(chez-sodium)`. Every
  exported procedure has a Typed Racket style signature comment, and `docs/reference.md` is held
  to them by a test ([ADR-0005]).
- **`(chez-sodium)` defines nothing:** it re-exports its private libraries' names, each `eq?` to
  its definition. It exports predicates and accessors, never a condition's `&` name or
  constructor ([ADR-0012]). `make-password-limits` is exported; its record is opaque and sealed,
  and its type, predicate and accessors are not ([ADR-0012], amended).
- **The verbs live beside native,** which keeps the load, the raw bindings and the helpers:
  `(chez-sodium private byte-verbs)` holds M2's three, and `(chez-sodium private password-verbs)`
  M3's three and `make-password-limits`. Each imports `require-threaded` first and nothing from
  `(chezscheme)`, and holds its checks before its one `call-in-section`; rows read both as data
  ([ADR-0012], amended).
- **`(chez-sodium private password-text)` is pure:** the UTF-8 count, the hash string's
  pre-check and needs-rehash's shape check. It loads no libsodium ([ADR-0012], amended).
- **`check-seam` reads `src/` alone,** with chez-sqlite3's rules (c) to (i) and (k), and rule
  (m): only `native` imports `(chez-sodium private memory)`, and no library exports a name it
  imports from `memory` ([ADR-0012]).
- **Inside native, `foreign-block` and `free-foreign-block!` appear only in `call-with-block`'s
  definition,** and native imports `(chez-sodium private memory)` exactly once, as the plain
  import set. `test-native` rows read native's body and import clause as data ([ADR-0012],
  amended).

## Binding libsodium

- **No C shim; nothing is compiled at install.** Every binding is a `foreign-procedure` in a
  `(chez-sodium private …)` library, and every constant is read through libsodium's own function
  for it. `crypto_generichash`'s five sizes and M3's fourteen password constants are read once,
  at the load, and the decoy's `sizes-other` and `pwhash-limits-other` hold that by behaviour
  ([ADR-0001], amended).
- **A binding uses the type C names:** `size_t` for `size_t`, as argument and result;
  `unsigned-64` for `unsigned long long`; `uptr` for every pointer. An opslimit is read as
  `size_t` and passed as `unsigned-64` ([ADR-0001]).
- **No Scheme object crosses into C.** Every buffer is copied into a counted foreign block; no
  binding takes `u8*`, `string`, `utf-8` or a bytevector, in plain calls as in collect-safe ones
  ([ADR-0001]).
- **No pointer passed to libsodium is NULL,** even with a length of 0: it is a block of at least
  one byte ([ADR-0001]).
- **Every value fits its C type, checked before the section that makes the call.** `int` is C's
  range; `size_t` and `unsigned-64` run from 0 to 2⁶⁴−1; a length is never longer than its block
  ([ADR-0001]).
- **`crypto_pwhash_str` and `crypto_pwhash_str_verify` are `__collect_safe`.** Every other call is
  plain, bounded by the cap ([ADR-0001], [ADR-0007]). The convention table names each binding's
  convention, and row 19 holds the two by behaviour, from inside the verb's section
  ([ADR-0001], [ADR-0011], amended).
- **No `lock-object` for data** ([ADR-0001]).
- **One library holds `foreign-procedure`, and one holds `foreign-alloc`** ([ADR-0001]).
- **Every binding has a row in the convention table,** which `test-conventions` holds every
  `foreign-procedure` form to, and `test-constants`' compiled prototype check holds to
  `sodium.h`. The argument allow-list is every type a row uses as an argument or as a non-void
  result; the result allow-list is every result type, and `void` ([ADR-0001], amended).
- **Every return code the brief's §3.4 states is confirmed by a row against the real library**
  before code relies on it ([ADR-0001]).

## Loading libsodium

- **`CHEZ_SODIUM_LIBRARY`, if set, is an absolute path, loaded as given,** with no search and no
  fallback. Anything else is `invalid-override` ([ADR-0002]).
- **Otherwise, chez-sqlite3 ADR-0002's candidate list, by world.** A Guix world never yields a
  standard directory, and an FHS world never yields a Guix profile. In each directory,
  `libsodium.so.26`, then `libsodium.so.23`; never the bare `libsodium.so`. Discovery is a pure
  function of its inputs ([ADR-0002]).
- **One load, in order, never fall through:** choose, load, bind the version entries, check the
  floor, call `sodium_init`, bind the rest, read the sizes and the constants ([ADR-0002],
  amended). No entry point is optional. The load runs once, and a failure is remembered and raised again ([ADR-0002]).
- **`sodium_init` answering 0 or 1 loads,** and the load records the answer. Any other answer is
  `init-failed`, its detail the answer ([ADR-0002]).
- **Each milestone binds its own verbs' entry points** in step 6, "bind the rest", each with its
  convention row, its decoy entry, its `missing-api` row and row 22 ([ADR-0002], amended).
- **A refusal carries a reason symbol:** `invalid-override`, `not-found`, `load-failed`,
  `below-floor`, `missing-api` or `init-failed`. `not-found` lists every candidate it checked
  ([ADR-0002]).
- **CI's `main` finds Ubuntu 24.04's 1.0.18 by discovery, and asserts that it loaded the floor**
  ([ADR-0002], [ADR-0003]). A floor raise moves this too, by its own record ([ADR-0003],
  amended).

## Conditions and secrets

- **Every library condition is a `&chez-sodium-error`:** `&sodium-library-unavailable`, or
  `&sodium-failed`, raised when `crypto_pwhash_str` or `crypto_generichash` answers anything but
  0 for limits, sizes and a key that passed their checks, and when `crypto_pwhash_str` answers 0
  but leaves no readable string, or one that fails the pre-check, with code 0.
  `&sodium-failed`'s fields are `function` and `code` ([ADR-0006], amended).
- **Every raise carries `&who`:** `chez-sodium` for the load's refusals, the public verb for a
  refusal raised through the public surface, the given WHO for a helper's, and its own name for
  an internal invariant's. A condition Chez raises is passed on as raised ([ADR-0006]).
- **A caller's mistake refused through the public surface leads its irritants with the rule's
  symbol;** a load refusal carries its reason in its `reason` field ([ADR-0006]).
- **A caller's mistake is an assertion violation, raised before C:** a wrong type; a size, key
  length or limit out of range; an input over the cap, other than a hash string; an empty key
  ([ADR-0006]).
- **`password-verify` answers `#f` for libsodium's -1,** whatever caused it, short memory
  included, and raises no condition for it. The owner confirmed it on 2026-11-24, when Techo
  asked ([ADR-0006], amended).
- **A password or hash another thread changed during the call is refused after the section,**
  `changed-during-call`, by `password-hash` and `password-verify`. `password-needs-rehash?`
  answers `#t` for a hash changed during its call, since it never raises because of the hash
  ([ADR-0006], [ADR-0009], amended).
- **No secret reaches a condition.** A refusal of a secret parameter names the parameter and its
  kind only, whatever the value's type: irritants `(RULE PARAMETER (kind K))`, through
  `refuse-secret`, in every helper too. Every string and bytevector parameter is secret: a
  password, a hash string, `blake2b`'s input and key, `constant-time-bytevector=?`'s operands,
  and Tier 2's inputs and HMAC key. `shown-value` is for sizes, limits and preset names only
  ([ADR-0006]).
- **A secret's refusal may state its bound, and nothing else.** `refuse-secret` takes the bound
  as two exact naturals, LOW and HIGH, never text, and writes the sentence itself; anything
  else in their place is its own refusal, by kind. R16 holds each such refusal's print the same
  for three secrets under one rule, of two contents and two lengths: the empty key alone, with
  one value, is not varied ([ADR-0006], amended).
- **Tests assert a condition's reason symbol, never its message** ([ADR-0006]).

## Sections and the cap

- **A verb checks its arguments first, outside any section.** One `critical-section` then holds
  the rest: making the blocks, copying in, the C call, copying out, the wipe and the free
  ([ADR-0007]).
- **The section answers data, and the verb raises only after it.** Nothing raises inside: a
  failure to make a block is caught there and answered as data ([ADR-0007]).
- **Every byte or string input, and `random-bytes`' output, is at most 64 KiB, counted in
  bytes.** A string counts its UTF-8 bytes, summed from its characters, never through
  `string->utf8`. Above that is an assertion violation, raised before C. A hash string over the
  cap fails the pre-check instead ([ADR-0007], [ADR-0009]).
- **The cap is written once,** as `input-cap` in `(chez-sodium private cap)`, and checked for
  every input but `blake2b`'s key, and for every operand, whatever the verb does next: the
  compare checks both before it compares their lengths. `blake2b`'s key and output are capped through libsodium's own bounds,
  which a row holds within the cap ([ADR-0007], amended).
- **A size or key length is checked against libsodium's own bounds, before C,** since C accepts
  sizes and keys of 1 to 15 bytes ([ADR-0007], amended).
- **No claims, positions or sweeps:** a stateless verb shares no state across sections
  ([ADR-0007]).
- **`call-in-section` is the one section:** THUNK in one `critical-section`, a raise inside
  caught there and raised again once it ends. A path that makes no block and calls no C holds
  none: `sodium-version`, `random-bytes 0`, the compare of operands of different lengths, and
  the password verbs' answers without C, for a hash that fails the pre-check or needs-rehash's
  shape check ([ADR-0007], amended).
- **Native's load runs in one critical section,** which answers data, and a refusal is raised
  after it ([ADR-0007]).
- **Every engine row references the library once before its first engine.** A library first
  reached inside an engine that is then abandoned stays wedged. The load's section narrows the
  window to the ticks before it starts, and no code closes it ([ADR-0007]).
- **Every row that forks a thread which reaches the library references it once first.** A
  library body first reached on two threads at once refuses the second with Chez's "cyclic
  dependency" condition, not a refusal; a later reference answers. A critical section defers
  only its own thread's interrupts: another thread that needs a collection waits for it to end,
  and then answers, so the window is the whole body, and a row can pass by luck ([ADR-0007],
  amended).
- **An engine row runs every verb at each fuel from 1 until it completes,** and each run answers
  right, raises nothing and leaves no live block ([ADR-0007]).

## Wiping

- **Every block the library frees is wiped first,** secret or not. The wipe is fused with the
  free: `call-with-block`'s critical cleanup hands `free-foreign-block!` the wipe, which checks
  that the block is live, wipes it with one `sodium_memzero` call over its size, then frees it,
  as one step. A block that is not live is never wiped. Never in a wrapper, never inside the
  callback, never as a `foreign-set!` loop ([ADR-0008]).
- **No Scheme copy of a secret.** A password's UTF-8 is written straight into its block, and a
  caller's bytevector is copied straight into its block, with no `bytevector-copy`
  ([ADR-0008]). A row reads `password-text.sls` and `password-verbs.sls` as data and refuses
  each procedure that copies a string ([ADR-0012], amended).
- **A password is hashed as its UTF-8 bytes, exactly as given.** The binding never normalises
  it ([ADR-0008]).
- **The documents say what wiping cannot reach:** the caller's copies, the bytevectors a verb
  returns, and copies the collector leaves behind ([ADR-0008]).

## Passwords

- **`password-needs-rehash?` answers `#t` for a hash not made with today's algorithm,
  parallelism and limits:** the limits differ; libsodium cannot read it; it fails the
  pre-check; its prefix is not the loaded library's `crypto_pwhash_strprefix()`; or its
  parameters do not read `p=1`. It answers `#f` only otherwise, and never raises because of the
  hash. It reads no salt or tag size, so it is no check that a hash is whole, and the documents
  say so ([ADR-0009], amended).
- **Custom limits are made by `make-password-limits`, with memory in KiB,** each range checked
  when it is called, so a `Password-limits` is always in range. The default is `'interactive`
  ([ADR-0009], amended).
- **A password's UTF-8 length runs from 0 to the cap, then from `_passwd_min` to `_passwd_max`,**
  counted from its characters before the section. In the section it is written straight into
  its block, each character's bytes only if they fit; a string whose width changed is answered
  as data ([ADR-0007], amended).
- **needs-rehash's item 4 is exact:** the loaded prefix, then `v=` digits, `$m=` digits, `,t=`
  digits, `,p=1$`, and more. Anything else, a NULL prefix included, is `#t`. The pre-check and
  this check run before any section, and only a hash that passes both reaches libsodium
  ([ADR-0009], amended).
- **A hash string is checked before C:** printable ASCII, U+0021 to U+007E, with no U+0000,
  within the cap, and no limit tied to `crypto_pwhash_strbytes()`. One that fails gets `#f` from
  `password-verify` and `#t` from `password-needs-rehash?`, without reaching C. Its block ends in
  a 0 ([ADR-0009]).
- **The documents show the login pattern:** `password-needs-rehash?` only after
  `password-verify` answers `#t` ([ADR-0009]).

## Environment and tests

- **The harness is chez-sqlite3's, at v0.1.1.** chez-sqlite3 ADR-0005, chez-sqlite3 ADR-0006,
  chez-sqlite3 ADR-0007 and chez-sqlite3 ADR-0008 bind it wherever [ADR-0011] does not say
  otherwise ([ADR-0011]).
- **Builds and tests run through `scripts/guix-env` on a Guix host,** pinned at `b532aa7`. The
  container has no network but loopback, and no git. It exports `CHEZ`, `CC` and
  `CHEZ_SODIUM_LIBRARY`, the absolute path of its `lib/libsodium.so.26`, and sets no
  `LD_LIBRARY_PATH` ([ADR-0011]; chez-sqlite3 ADR-0006).
- **Network and git work runs on the host:** submodules, `make check-pins`, downloads
  ([ADR-0011]; chez-sqlite3 ADR-0006).
- **SRFI-64 comes from `vendor/chez-srfi` at `7879b52`,** pinned in `Akku.lock`. `make deps`
  never fetches. `Akku.manifest` lists development dependencies only, with no `scripts` clause
  ([ADR-0011]; chez-sqlite3 ADR-0007).
- **Every suite ends with `(exit (suite-exit-status runner))`,** and exits early only with
  `(exit 1)`. `make check-suites` checks it ([ADR-0011]; chez-sqlite3 ADR-0007).
- **`make test` runs every suite under `timeout`, even after a failure,** and fails on any
  failure, hang, or empty glob. `make check-test-fails` proves each of those ([ADR-0011];
  chez-sqlite3 ADR-0007).
- **Password rows hash at libsodium's minimum limits,** read from `_opslimit_min` and
  `_memlimit_min`, but for one cheap pair that is neither the minimum nor a preset, one hash at
  the default, row 22's code rows at the few cheap limits each code needs, and the docs'
  password examples, which `test-docs` runs at the default. Only the no-memory rows hash at a
  high limit, `'sensitive`, in gated children under a memory cap ([ADR-0011], amended).

## Memory and CI

- **The memory gate is Valgrind and our counters,** which count blocks alone. A block count must
  be zero when a suite exits; there is no reset, and a count below zero raises ([ADR-0011];
  chez-sqlite3 ADR-0005).
- **Valgrind's evidence comes from its log alone.** `timeout` wraps Valgrind and never sits
  between it and Chez, and `CHEZ` is the real binary. No suppression but Valgrind's own
  `default.supp` ([ADR-0011]; chez-sqlite3 ADR-0005).
- **`make check-memory-gate` must see the gate fail** on the planted leak and the planted
  overrun, and runs before `make test-memory` in CI ([ADR-0011]; chez-sqlite3 ADR-0005).
- **One memory job, with no shards** ([ADR-0011]).
- **A child that reaches native code starts through `gated-command`,** under the gate's own
  Valgrind, with its own log. A child started any other way runs outside Valgrind, unseen. A
  child that runs only Scheme is outside the rule. There are two exceptions: the wipe row's
  children, since Valgrind's allocator bypasses their `free()` interposer ([ADR-0011], [ADR-0008];
  chez-sqlite3 ADR-0005, amended); and `test-constants`' prototype check, a C program that calls
  no libsodium function ([ADR-0011], amended). Any other C program a suite runs is gated. Row
  19's FIFO writer and watchdog are shells, which run no Scheme and no libsodium. Row 19 waits
  for the decoy's marker before its rendezvous, or a plain binding passes. Every writer opens
  its FIFO read-write; each call has a FIFO and a marker of its own; the watchdog starts before
  the fork, outside the process; and the suite bounds each child with `timeout`.
  `test-no-memory`'s children are gated too: a capped child runs `ulimit -v` outside Valgrind,
  which runs Chez inside the cap ([ADR-0011], amended).
- **The C oracle is a program named `libsodium-oracle`.** The gate's rule for child logs names
  it ([ADR-0011]).
- **Each wipe row's child sets `LD_PRELOAD` to the interposer alone,** never appended: under the
  gate a suite's own holds Valgrind's preloads ([ADR-0011]).
- **No exit checks:** the block count is a suite's one check at its end ([ADR-0011]).
- **A decoy reads each pointer it logs through a `volatile uintptr_t`,** and tests only that.
  `test-decoy-source` holds it for every pointer parameter of every function `sodium.h` declares
  that a `tests/*.c` defines, since a compile holds it only for a `nonnull` one. The decoy's log
  ends in `overflow` when full ([ADR-0011], amended).
- **A decoy spells each array parameter as its header does:** `crypto_pwhash_str`'s `out` as an
  array, and `str` as an array at 1.0.18 and a pointer at 1.0.22, by
  `SODIUM_LIBRARY_VERSION_MAJOR` ([ADR-0011], amended).
- **Row 24 reaches a verb's blocks through the decoy,** whose entries name each block to the
  wipe child's interposer through a weak `watch_set`; the child asserts each call's whole list
  of blocks ([ADR-0011], amended).
- **CI's workflow has one shape, which `make check-ci` holds and `make test` runs.** M0's shape
  is `main`, without `make build` and `check-dev`; `memory`; and `nothreads`. M1 adds `floor` and
  `current`, and M4 `site`. `pages.yml` is held line for line. Actions are pinned by SHA
  ([ADR-0011], amended; chez-sqlite3 ADR-0005, amended).

## Docs, site and release

- **`docs/` is five pages,** a quick start, passwords, tokens, finding libsodium and the
  reference, in that order. `site/pages.sls` writes the order once, and README.org's Documentation
  list holds it ([ADR-0013]).
- **The reference holds one `` ### `NAME` `` entry per export,** whose one `text` line equals the
  export's signature comment, character for character. A signature comment is `;; NAME : TYPE`
  alone; a note goes on a line of its own ([ADR-0013]; [ADR-0012], amended).
- **`test-docs` holds every page:** block kinds, links and anchors, README.org's twin, the
  banned words, the export spans, run blocks evaluated, whole programs run through
  `gated-command`, and `finding-libsodium.md`'s tables against discovery's code. No page links
  into `.plans/`, or says `ADR-`, `TODO`, "yet", "unreleased", "slice" or a date ([ADR-0013]).
- **No page restates a floor:** `check-floors` reads `docs/`, and a page names a floor by a link
  to README.org's Requirements ([ADR-0011], amended).
- **Installing is a clone, with nothing built.** Every `git clone` line names the manifest's
  version's tag, or no branch at 0.0.0, and `test-manifest` holds it ([ADR-0013]).
- **The site's generator and its suites import nothing under `src/`,** so Ubuntu's Chez runs them.
  chez-cmark-gfm is a `depends/dev`, fetched on the host by `make site-deps` ([ADR-0011],
  amended).
- **A release is a signed, annotated tag the owner makes and pushes,** with its CHANGELOG entry,
  `Akku.manifest`'s version and the clone lines moved together, and a GitHub Release whose notes
  are the entry, read back byte for byte. `pages.yml` deploys the site on the tag's push
  ([ADR-0013]).
- **No Akku publish** until a later decision (brief §11.8; [ADR-0013]).

[ADR-0001]: decisions/0001-bind-libsodium-directly.md
[ADR-0002]: decisions/0002-runtime-discovery-and-the-sonames.md
[ADR-0003]: decisions/0003-libsodium-floor-1-0-18.md
[ADR-0004]: decisions/0004-a-threaded-chez.md
[ADR-0005]: decisions/0005-the-subset-rule.md
[ADR-0006]: decisions/0006-errors-and-no-secret-shown.md
[ADR-0007]: decisions/0007-one-critical-section-per-verb.md
[ADR-0008]: decisions/0008-every-block-wiped-before-free.md
[ADR-0009]: decisions/0009-what-needs-rehash-means.md
[ADR-0010]: decisions/0010-linux-only.md
[ADR-0011]: decisions/0011-the-harness-after-chez-sqlite3.md
[ADR-0012]: decisions/0012-the-public-library-and-the-seam.md
[ADR-0013]: decisions/0013-the-first-release.md
