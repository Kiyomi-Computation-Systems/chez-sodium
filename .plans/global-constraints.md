# Global constraints

The hard rules from the decision records. Every task brief is bound by them. Each rule cites the
record it comes from, and where a rule and its record disagree, the record wins.

## Platforms and versions

- **Linux only.** No macOS or Windows code paths, no macOS or Windows CI, and no abstraction kept
  only so another platform could come later ([ADR-0010]).
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
- **CI builds libsodium from a point-release tarball,** never `-stable` or `LATEST`, pinned by a
  SHA-256 the project computed and checked once against the `.minisig` with libsodium's
  published minisign key, and falls back to `releases/old/` ([ADR-0003]).

## What is bound

- **A function is bound only if Techo has a named use for it.** `constant-time-bytevector=?` is
  the one exception. Adding one takes a row in the brief's subset, a row in the convention table,
  and a test on every supported libsodium ([ADR-0005]).
- **No verb holds state between calls: no handles.** `hmac-sha256` is one call, and streaming
  SHA-256 is out ([ADR-0005]).
- **The verbs' names are the brief's §4, with no prefix,** exported by `(chez-sodium)`. Every
  exported procedure has a Typed Racket style signature comment, and `docs/reference.md` is held
  to them by a test ([ADR-0005]).
- **`(chez-sodium)` defines nothing:** it re-exports its private libraries' names, each `eq?` to
  its definition. It exports predicates and accessors, never a `&` name or a constructor
  ([ADR-0012]).
- **`check-seam` reads `src/` alone,** with chez-sqlite3's rules (c) to (i) and (k), and rule
  (m): only `native` imports `(chez-sodium private memory)`, and no library exports a name it
  imports from `memory` ([ADR-0012]).
- **Inside native, `foreign-block` and `free-foreign-block!` appear only in `call-with-block`'s
  definition,** held by a `test-native` row that reads native's body as data ([ADR-0012]).

## Binding libsodium

- **No C shim; nothing is compiled at install.** Every binding is a `foreign-procedure` in a
  `(chez-sodium private …)` library, and every constant is read through libsodium's own function
  for it ([ADR-0001]).
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
  plain, bounded by the cap ([ADR-0001], [ADR-0007]).
- **No `lock-object` for data** ([ADR-0001]).
- **One library holds `foreign-procedure`, and one holds `foreign-alloc`** ([ADR-0001]).
- **Every binding has a row in the convention table,** which `test-conventions` holds every
  `foreign-procedure` form to, and `test-constants`' compiled prototype check holds to
  `sodium.h`. The allow-lists are exactly the types the rows use ([ADR-0001]).
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
  floor, call `sodium_init`, bind the rest. No entry point is optional. The load runs once, and a
  failure is remembered and raised again ([ADR-0002]).
- **`sodium_init` answering 0 or 1 loads,** and the load records the answer. Any other answer is
  `init-failed`, its detail the answer ([ADR-0002]).
- **Each milestone binds its own verbs' entry points,** in the load's last step, each with its
  convention row, its decoy entry, its `missing-api` row and row 22 ([ADR-0002]).
- **A refusal carries a reason symbol:** `invalid-override`, `not-found`, `load-failed`,
  `below-floor`, `missing-api` or `init-failed`. `not-found` lists every candidate it checked
  ([ADR-0002]).
- **CI's `main` finds Ubuntu 24.04's 1.0.18 by discovery, and asserts that it loaded the floor**
  ([ADR-0002], [ADR-0003]).

## Conditions and secrets

- **Every library condition is a `&chez-sodium-error`:** `&sodium-library-unavailable`, or
  `&sodium-failed`, whose one case is `crypto_pwhash_str` answering -1 for limits that passed
  their range check. `&sodium-failed`'s fields are `function` and `code` ([ADR-0006]).
- **Every raise carries `&who`:** `chez-sodium` for the load's refusals, the public verb for a
  refusal raised through the public surface, the given WHO for a helper's, and its own name for
  an internal invariant's. A condition Chez raises is passed on as raised ([ADR-0006]).
- **A refusal raised through the public surface leads its irritants with the rule's symbol**
  ([ADR-0006]).
- **A caller's mistake is an assertion violation, raised before C:** a wrong type; a size, key
  length or limit out of range; an input over the cap, other than a hash string; an empty key
  ([ADR-0006]).
- **`password-verify` answers `#f` for libsodium's -1,** whatever caused it, and raises no
  condition for it ([ADR-0006]).
- **No secret reaches a condition.** A refusal of a secret parameter names the parameter and its
  kind only, whatever the value's type: irritants `(RULE PARAMETER (kind K))`, through
  `refuse-secret`, in every helper too. Every string and bytevector parameter is secret: a
  password, a hash string, `blake2b`'s input and key, `constant-time-bytevector=?`'s operands,
  and Tier 2's inputs and HMAC key. `shown-value` is for sizes, limits and preset names only
  ([ADR-0006]).
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
- **No claims, positions or sweeps:** a stateless verb shares no state across sections
  ([ADR-0007]).
- **`call-in-section` is the one section:** THUNK in one `critical-section`, a raise inside
  caught there and raised again once it ends. `sodium-version` holds none ([ADR-0007]).
- **Native's load runs in one critical section,** which answers data, and a refusal is raised
  after it ([ADR-0007]).
- **Every engine row references the library once before its first engine.** A library first
  reached inside an engine that is then abandoned stays wedged. The load's section narrows the
  window to the ticks before it starts, and no code closes it ([ADR-0007]).
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
  ([ADR-0008]).
- **A password is hashed as its UTF-8 bytes, exactly as given.** The binding never normalises
  it ([ADR-0008]).
- **The documents say what wiping cannot reach:** the caller's copies, the bytevectors a verb
  returns, and copies the collector leaves behind ([ADR-0008]).

## Passwords

- **`password-needs-rehash?` answers `#t` for any hash that is not what `password-hash` would
  make now:** the limits differ; libsodium cannot read it; it fails the pre-check; its prefix is
  not the loaded library's `crypto_pwhash_strprefix()`; or its parameters do not read `p=1`. It
  answers `#f` only otherwise, and never raises because of the hash ([ADR-0009]).
- **Custom limits are made by `make-password-limits`, with memory in KiB,** each range checked
  before C. The default is `'interactive` ([ADR-0009]).
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
  `_memlimit_min`, but for one cheap pair that is neither the minimum nor a preset, and one hash
  at the default. No row needs a high limit ([ADR-0011]).

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
  child that runs only Scheme is outside the rule. The wipe row's
  child is the exception: it runs outside Valgrind, whose allocator bypasses its `free()`
  interposer ([ADR-0011], [ADR-0008]; chez-sqlite3 ADR-0005, amended).
- **The C oracle is a program named `libsodium-oracle`.** The gate's rule for child logs names
  it ([ADR-0011]).
- **The wipe row's child sets `LD_PRELOAD` to the interposer alone,** never appended: under the
  gate a suite's own holds Valgrind's preloads ([ADR-0011]).
- **No exit checks:** the block count is a suite's one check at its end ([ADR-0011]).
- **A decoy reads each pointer it logs through a `volatile uintptr_t`,** and tests only that
  ([ADR-0011]).
- **CI's workflow has one shape, which `make check-ci` holds and `make test` runs.** M0's shape
  is `main`, without `make build` and `check-dev`; `memory`; and `nothreads`. M1 adds `floor` and
  `current`. Actions are pinned by SHA ([ADR-0011]; chez-sqlite3 ADR-0005, amended).

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
