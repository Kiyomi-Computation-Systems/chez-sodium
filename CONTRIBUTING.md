# Contributing to chez-sodium

Thanks for helping. A **small fix**, such as a typo, a doc fix, or a bug with a
test that shows it, needs only the checks below. **Bigger work** starts as an
issue, so the design is agreed before the code is written.

**A new binding is a design decision.** chez-sodium binds only what Techo has a
named use for: the subset rule. Adding one takes a row in the brief's subset, a
row in the convention table, and a test on every supported libsodium.
Encryption, signatures and the rest are out on purpose (brief §3.3, in
`.plans/2026-11-22-chez-sodium-project-brief.md`).

## Setup

chez-sodium is Linux only; macOS and Windows are not supported. You need Chez
Scheme (threaded) and libsodium. [README.org](README.org) says which versions.

```sh
git clone --recursive https://github.com/Kiyomi-Computation-Systems/chez-sodium.git
cd chez-sodium
make test
```

`make help` lists every target.

On a Guix host, `scripts/guix-env make test` runs it in a container that has
the toolchain. Run `make check-guix` on the host to test the container itself.

## The checks

CI runs these on every pull request, on Linux x86_64. Keep them green:

- `make test`: every suite passes.
- `make check-test-fails`: planted bad suites and code make `make test` fail.
- `make test-memory`: every suite runs under Valgrind with no error or leak.
- `make check-memory-gate`: the Valgrind gate fails on a planted overrun and
  leak.
- `make check-pins`: `Akku.lock`, the submodule and its checkout agree.
- `make check-site-deps` and `make check-site`: the docs site builds, and every
  link and anchor in it resolves.
- `make check-help`: every target has a description in `make help`.

## When you change…

- **A pin or `Akku.lock`:** move the submodule, `Akku.manifest` and
  `Akku.lock` together. `make check-pins` fails until they agree.
- **The Makefile:** give each new target a `## ` description, so `make help`
  lists it.
- **`docs/`:** it is for people using the library. Keep it short and plain.
  A new page goes in `docs/` and in `site/pages.sls`; `make check-site` fails
  until both name it.
- **The container files** (`channels.scm`, `manifest.scm`, `scripts/guix-env*`):
  run `make check-guix` on the host.
- **A binding:** follow the subset rule above, with its rows and its test.

## Code

- Libraries are R6RS `.sls` files under `src/`, and each holds its own code:
  no shared include files.
- **Functional core, imperative shell.** The rules go in pure libraries, such
  as `(chez-sodium private password-text)`. Foreign calls and memory stay in
  the shell.
- Each export has a comment giving its type, Typed Racket style, on a line of
  its own: `;; NAME : TYPE`. `test-reference` holds `docs/reference.md` to
  these.
- No C shim: libsodium is found and loaded when the program runs.
- **Secrets.** Every string and bytevector a caller passes is a secret.
  - No condition, log line or test name holds one.
  - Every block is wiped before it is freed.
  - No Scheme copy of a secret: it goes straight into its block.
- **One critical section per verb**, covering its blocks, the C call and the
  wipe. Nothing raises inside it: answer data there, and raise after.
- Comments say what the code does and why, in the present tense. They don't
  cite plans, dates or issue numbers; that history belongs in commits and
  CHANGELOG.md.

## Tests

- Write the test first, and watch it fail before you make it pass. A test that
  passes whether the code is right or wrong is worse than none.
- A change in behaviour comes with a test that fails without it.
- A suite is `tests/test-NAME.sps`, written with SRFI-64, and ends with
  `(exit (suite-exit-status runner))`. `make check-suites` checks it.
- Assert a condition's reason symbol, never its message.
- Try a mutant in a copy of the tree, never in place.

## Pull requests

- Commit messages and PR titles follow
  [Conventional Commits](https://www.conventionalcommits.org): `feat:`,
  `fix:`, `docs:`, `test:`, `refactor:`, `chore:`.
- Pull requests are squash-merged, so the PR title becomes the commit's.
- A change users can see gets an entry under `## [Unreleased]` in
  [CHANGELOG.md](CHANGELOG.md).

## How the project is developed

Designs live in `.plans/`, and each lasting decision gets a numbered record in
`.plans/decisions/`. [AGENTS.md](AGENTS.md) holds the project's rules in full.
Following them is encouraged, not demanded of small fixes.

## Security

Don't open a public issue for a suspected vulnerability.
[SECURITY.md](SECURITY.md) says how to report it privately.
