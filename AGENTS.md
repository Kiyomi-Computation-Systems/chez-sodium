# AGENTS.md

## Where the project stands

* Nothing is built yet. The plan is the brief,
  `.plans/2026-11-22-chez-sodium-project-brief.md`. Read it before any work.
  - Its §11 holds the owner's decisions; its §10 lists the questions still open.
  - Its adversarial review, every finding with its evidence and probes, is in
    `.plans/research/brief-review/`.
* M0 comes next. Brief §9 says exactly what it holds: the records, the scaffolding
  copied from chez-sqlite3 (brief §7), and CI green on an empty suite. M0 brings the
  Makefile, `scripts/guix-env`, CI, `.plans/progress.md` and
  `.plans/global-constraints.md`. The rules below that name them apply from then on.
* The brief's pattern is chez-sqlite3, at `../chez-sqlite3`. Its FFI rules come from
  chez-sqlite3 and chez-libuv, at `../chez-libuv`. Read the file there before copying
  it, and copy what the brief says to copy.

## Project guidelines

### Architecture & portability

* Use the functional core / imperative shell pattern
* Follow the 12 Factor Apps philosophy
* Project is built for Chez Scheme
* A Chez Scheme library binding a small part of libsodium (`libsodium`) through
  the FFI; handle C *safely*, and secrets with care.
* **No C shim.** libsodium is found and loaded when the program runs, and every
  constant is read through libsodium's own function for it (brief §2).
* A function is bound only if Techo has a named use for it (brief §3).
  `constant-time-bytevector=?` is the one exception, by decision. Adding one means a
  row in the brief's subset, a row in the convention table, and a test on every
  supported libsodium.
* No verb holds state between calls: no handles. That is why streaming SHA-256 is out
  and `hmac-sha256` is one call (brief §3.2).
* **DO NOT** setup macos CI runners: linux only!
* Exported functions should have a comment with a Typed Racket style type signature
* The public library is `(chez-sodium)`. Internals live under
  `(chez-sodium private …)` and never escape it.

### Secrets

* No condition message, log line or test name holds a secret: a password, a hash
  string, a key, `constant-time-bytevector=?`'s operands, or an HMAC key (brief §5).
  - A refusal of a secret parameter names the parameter and its kind only, whatever
    the value's type.
  - `shown-value` shows numbers, symbols, characters and lists of them as they are,
    so it is for values that are not secret: sizes and limits.
* Every block the library frees is wiped first, by one `sodium_memzero` call inside
  `call-with-block`'s critical cleanup, just before the free (brief §6.3).
  - Never in a wrapper: the block is already freed by then.
  - Never as a `foreign-set!` loop: it costs as much as the copy.
* No Scheme copy of a secret. A password's UTF-8 goes straight into its block, and a
  caller's bytevector is copied straight into its block. The documents say what
  wiping cannot reach: the caller's copies, the bytevectors a verb returns, and copies
  the collector leaves behind.
* A hash string is checked before C: printable ASCII, with no U+0000, within the input
  cap. Its block ends in a 0, since C reads it up to its first NUL (brief §4.1).
* A password is hashed as its UTF-8 bytes, exactly as given. The binding never
  normalises it.
* `password-needs-rehash?` answers `#t` for any hash that is not what `password-hash`
  would make now, unreadable ones included, and never raises because of the hash
  (brief §4.2).

### Dependencies

* libsodium, found and loaded at runtime, and Chez Scheme, threaded, each at or
  above its floor in `packaging/floors.sexp`, the one place the floors are written
  (chez-sqlite3 ADR-0008). The proposed floors are libsodium 1.0.18 and Chez 10.4.0.
  libsodium's floor is read from `sodium_version_string`, never from
  `sodium_library_version_major` and `_minor`, which are libtool numbers.
* chez-srfi, vendored as a git submodule, for SRFI-64 in the tests only
* chez-cmark-gfm and the system cmark-gfm library, for the docs site alone, as
  chez-sqlite3 has them
* `Akku.manifest` lists development dependencies only; nothing is built, so it has
  no `scripts` clause (brief §7.2)

### Guix development container

* **On a Guix host, run every build and test through `scripts/guix-env`**,
  e.g. `scripts/guix-env make test`. Batch commands with
  `scripts/guix-env sh -c 'make a && make b'`: each call takes a second or
  more to start.
* Edit, commit and push on the host. The container has no git identity,
  agents or tokens, and no network but loopback (chez-sqlite3 ADR-0006).
* Verify it with `make check-guix`, run on the host.
* `CHEZ_SODIUM_LIBRARY` names a libsodium by its absolute path. A floor run sets it
  to the floor's library, and `C_INCLUDE_PATH` to the floor's headers, so a C oracle
  compiles against the library the suite loads.
* Anything that needs the network or git runs on the host: fetches, pushes,
  downloads, `make check-pins`, `make site-deps`, and
  `git submodule update --init --recursive`,
  which a fresh clone needs once before `make deps`. The container has no git.

### Layout, process & libraries

* Plans live in `/.plans`, decision records in `/.plans/decisions`
* `/.plans/references/` holds copies of other projects' documents. They bind nothing
  here except where the brief says they do.
* The ledger is `/.plans/progress.md`: where the project stands, the next
  slice, and a close-out for each merged slice. `/.plans/global-constraints.md`
  holds the decision records' hard rules and binds every task brief. Read both
  before starting slice work.
* Add entries to `CHANGELOG.md` for each release
* A comment in `src/`, `tests/`, the Makefile, `scripts/` or `packaging/` is
  for a developer reading the code: no milestone, slice, research path, date
  or "the maintainer". A bare `ADR-NNNN` may point to why.
* `/docs` is for user facing documentation only.
* Documentation should be very concise, focused, to the point, ELI5 style.
* `Makefile` should have a `help` command which lists all of its commands
* Libraries are R6RS `.sls`; libraries and programs contain their own code —
  no shared include bodies. R6RS forbids assigning an exported variable —
  reach mutable state through procedures.
* Cite a sibling's record with its repository's name (`chez-sqlite3 ADR-0011`),
  never by its number alone.
* Before a global replace, predict how many matches it should hit, and check
  the count afterwards: the sentence that defines a marker contains the
  marker (chez-sqlite3 `.plans/traps.md`).

### Testing & mutation discipline

* Use TDD / test-driven development
* A test that passes whether the code is right or wrong is worse than no test.
* A test is not finished when it passes. It is finished when you have watched
  it fail.
* Prefer a check to a comment.
* **Do not** write tests that rely on reading code comments. The one exception:
  `test-reference` holds `docs/reference.md`'s signatures to the Typed Racket
  signature comments of `(chez-sodium)`'s exports, which are the contract.

**Tests**

* Tests assert a condition's reason symbol, never its message.
* Every return code the brief states is confirmed by a row against the real library
  before any code relies on it.
* Password tests use libsodium's minimum limits, read from `_opslimit_min` and
  `_memlimit_min`, so the suite stays fast under Valgrind. The exceptions are one cheap
  pair that is neither the minimum nor a preset, and one hash at the default
  (brief §8.2). No row needs a high limit: the collect-safe row blocks a decoy on a
  FIFO.
* A row that says C was not reached proves it from the decoy's call log. libsodium
  accepts many mistakes, for example sizes of 1 to 15 bytes, so its answer proves
  nothing.
* A test that needs the binding's behaviour on non-ASCII text uses non-ASCII text. An
  ASCII password cannot tell a byte count from a character count.
* `guard` returns the body's value when nothing raises, and `0` is truthy.
  Assert *what was raised* against an expected value, with a distinct sentinel
  for the no-raise case.
* SRFI-64 turns an exception in the *actual* expression into `#f`. Never
  expect `#f` from something that can raise. `password-verify` answers `#f`, so
  a row that expects it also asserts that nothing was raised.
* SRFI-64 does not catch an exception in the *expected* expression, nor in a
  suite's top-level definitions: the suite dies and no test is named. Compute
  anything that can raise under a `guard`.
* Every `tests/test-*.sps` must end with `(exit (suite-exit-status runner))`:
  SRFI-64 sets no exit status. Anything after that line never runs, and
  `make check-suites` checks it is there.
* An exit status is taken modulo 256, so `(exit 256)` exits 0. Exit with 0 or
  1, never a count.
* SRFI-64 keeps one result per runner. Never run a test inside another test's
  actual expression: the outer verdict is reported under the inner test's name.
* Chez fixes no order for a call's arguments, and `map` calls its procedure in
  no fixed order; a `let`'s inits are arguments too. No assertion may depend
  on any order; use `for-each` for effects, and `let*` when one init must
  follow another (chez-sqlite3 `.plans/research/evaluation-order/`).
* An assertion passes whenever *another* rule can produce its expected value.
  Assert whole outputs, not substrings, and build a test's base from
  non-default values: a hash made at the minimum limits cannot show that
  `password-hash` used the limits it was given.
* A thread a suite forks dies on a raise it does not catch, and a waiter with
  no bound then hangs the suite, naming no test. Make whatever a thread raises
  its answer, and bound every wait for one.

**Chez and the FFI**

* No Scheme object crosses into C. Every buffer is copied into a counted foreign
  block, and every pointer is a `uptr`. Chez accepts `u8*` under `__collect_safe`
  without a word, and a collection can move the bytevector during the call
  (chez-sqlite3 ADR-0011; chez-libuv `tests/test-source-rules.sps`, rule 4).
* A call that can block or run long is `__collect_safe`: here `crypto_pwhash_str` and
  `crypto_pwhash_str_verify`. A plain call stops every other thread's collection for
  as long as it runs (chez-sqlite3 ADR-0011). The input cap keeps every other call
  short (brief §4.4).
* **Each verb's whole extent is one `critical-section`** (brief §6.2): making the
  blocks, copying in, the C call, copying out, the wipe and the free.
  - Arguments are checked before it.
  - It answers data, and the verb raises only after it.
  - Without it, an engine's expiry frees the block, and the resume is refused as a
    re-entry.
  - A collect-safe call inside it still lets other threads collect. Scheme's copy
    loops inside it do not, so inputs are capped at 64 KiB.
* No `lock-object` for data: every raising path would need an unlock, and a
  missed one is invisible (chez-sqlite3 ADR-0011).
* Only one library holds `foreign-procedure`, and only one holds `foreign-alloc`,
  so `check-seam` can read the seam.
* `foreign-procedure` resolves its entry point when evaluated, so every
  binding must follow the library's load. Mistakes fail at *import*.
* A library body runs only when one of its bindings is *referenced*. A test of
  load-time behaviour must call into the library.
* A `guard` in a program cannot catch a raise from an imported library's body.
  A probe must `eval` its call inside the guard.
* The load runs once, and a failure is remembered and raised again: Chez wedges
  on a library body that failed with a non-serious raise (chez-sqlite3
  `private/load-state.sls`).
* Nothing raises inside `critical-section` or a critical `dynamic-wind` thunk:
  a handler of the raise runs with interrupts disabled, and another thread's
  collection waits. Answer data there, and raise after the section.
* A `guard` whose clauses don't match re-enters the raise's extent to raise
  again, so a `dynamic-wind` before thunk that refuses a re-entry replaces the
  caller's condition with its own. Let a re-entry through. An after thunk whose
  work isn't idempotent, such as wiping and freeing a block, acts once, behind a
  flag, and whatever runs after a re-entry reads that flag first.
* Chez's foreign `int` takes −2³¹ to 2³²−1, hands 2³¹ and above to C as
  negatives, and raises beyond, inside the section that makes the call. `size_t`,
  `unsigned-64` and `uptr` take −1 as 2⁶⁴−1. Check that each value fits its C type
  before the section (chez-sqlite3 ADR-0011, amended).
* No pointer passed to libsodium is ever NULL, even with a length of 0: pass a block
  of at least one byte. libsodium's headers mark its pointers `nonnull`, and a NULL
  with a nonzero length aborts the process.
* libsodium answers an opslimit as `size_t` and takes one as `unsigned long long`.
  Bind each by the type C names, in the convention table (brief §3.4, §10).
* A decoy or oracle that includes `sodium.h` logs a pointer through a
  `volatile uintptr_t`. Testing a `nonnull` parameter against NULL is an error under
  `-Wall -Werror`, and GCC may delete the test.

## Closing ritual

We run this when we're done and ready to merge the PR.

**Important**: ALWAYS ask before running this.

1. Squash merge the PR.
2. Catch up local `main`.
3. Clean up branches. Delete the merged branch locally and on the remote.
4. Reflect.
