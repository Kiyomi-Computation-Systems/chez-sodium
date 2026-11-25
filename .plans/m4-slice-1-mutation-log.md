# M4 slice 1: mutation log

Each check watched failing, by a mutant in a whole copy of the tree made with
`shutil.copytree(..., symlinks=True)`, never in place. Each entry: what guards, the mutation, the
result, the clean rerun.

## The base: the container and the site's dependency

Built by a Sonnet builder, first and alone; mutants in copies under `build/m4s1-base/`.

| Guards | Mutation | Result | Clean rerun |
|---|---|---|---|
| `test-manifest`'s `depends/dev` and lock rows | chez-cmark-gfm dropped from `Akku.manifest`'s `depends/dev` | 2 rows fail: "…depends/dev is exactly chez-srfi … and chez-cmark-gfm at ^2.0.0", "Akku.lock's chez-cmark-gfm url holds the version Akku.manifest asks for, and the pinned one" | 93 of 93 |
| the lock's sha256 | one digit of chez-cmark-gfm's sha256 changed in `Akku.lock` | 1 row fails: "Akku.lock's chez-cmark-gfm project is the archive make site-deps fetches, and its sha256" | pass |
| the lock's projects | a lock with chez-cmark-gfm alone | 3 rows fail: "…exactly two projects…", "…chez-srfi url…", "…every project carries a sha256 of 64 hex digits" | pass |
| the self-test's new assertion | `CHEZ_CMARK_GFM_LIBS` without the extensions library, in the copy's own `guix-env-enter`, run through the copy's own `scripts/guix-env` | `cmark-gfm-variable` and `cmark-gfm-loads` fail | `make check-guix`: ALL CHECKS PASSED |
| `fetch-akku-lock`'s sha check | a corrupted archive in the copy's `dl/`, then `fetch-akku-lock --check` | refused: "has sha256 5777…, but Akku.lock pins bb64…", exit 1 | pass |
| `check-site-deps` | the script mutated to skip its sha comparison | "FAIL: an archive whose sha256 differs from the lock is refused, and nothing is unpacked", 1 check failed | "all checks passed" |
| the caller's rerun | chez-cmark-gfm's range `^2.0.0` → `^2.1.0` in a copy's `Akku.manifest` | 2 rows fail, the same two as the first mutant | 93 of 93 |

**A host step reached the network once.** The builder's first corrupted-archive mutant ran `make
site-deps` on the host in its copy. The script re-downloads when the sha differs, so it fetched
the pinned public archive into that copy alone. The real tree's `build/akku` was not touched. The
builder then used `--check`, which downloads nothing.

**Checks:** on the host, `make check-guix` (ALL CHECKS PASSED, 41 of 41 suites, the profile rebuilt
with no download), and `make site-deps` offline from chez-sqlite3's fetched archive. In the
container, `make check-site-deps`, `make test` 41 of 41, `make check-test-fails` 13 cases, and
`make check-suites`.

## The builders

Each builder kept its own log, in [research/m4-slice-1/](research/m4-slice-1/):

| Builder | What | Model | Its log |
|---|---|---|---|
| 1a | `docs/reference.md`, `test-reference`, the signature comments | Sonnet | [1a.md](research/m4-slice-1/1a.md): six mutants, each failing a named row |
| 1b | README.org and the four pages | Opus | [1b.md](research/m4-slice-1/1b.md): its self-checks, each watched failing on 23 planted faults, and their scripts in `1b/` |
| 1c | `test-docs` | Sonnet | [1c.md](research/m4-slice-1/1c.md): 47 suite mutants, 53 on stand-in pages, 6 on the real pages; one survives a plain run and fails under the gate |
| 1d | `check-floors`' docs inputs, the clone check | Sonnet | [1d.md](research/m4-slice-1/1d.md) |
| 1e | the comment pass | Sonnet | [1e.md](research/m4-slice-1/1e.md): the datum check watched failing, then 18 files the same |
| 1f | the generator, its suites, `check-suites`, `check-test-fails` | Sonnet | [1f.md](research/m4-slice-1/1f.md) |
| 1g | the `site` job, `pages.yml`, `check-ci` | Sonnet | [1g.md](research/m4-slice-1/1g.md): 12 workflow mutants and 16 rule drops |
| 1h | `CONTRIBUTING.md`, `SECURITY.md`, the templates | Sonnet | no check of its own: `check-floors` reads the first two, and the links were checked by script |

## The caller's mutants, at the join

Each in a whole copy of the joined tree under `build/m4v/`, against a clean copy, `base`, which
passed every suite run here.

| Guards | Mutation | Result | Clean rerun |
|---|---|---|---|
| `test-docs`' export spans | `password-verify` → `password-verfy` in a span of `docs/passwords.md` | 1 row fails: "every code span of the prose that is one name of a prefix of the library is an export…" | 127 of 127 |
| `test-docs`' run blocks and the twin | the quick start's run block's `;; => (#t #f)` → `(#t #t)` | 2 rows fail: "docs/quickstart.md:92: the runnable example gives the result it states", and the README twin row | 127 of 127 |
| `test-manifest`'s clone check | README.org's clone line given `--branch v0.0.0` at 0.0.0 | 1 row fails: "README.org and docs/ hold the clone lines Akku.manifest's version calls for…" | 107 of 107 |
| `test-reference` | `random-bytes : Natural -> Bytevector` → `Nat` in the page | 1 row fails: "each entry's line is its export's source signature comment, character for character…" | 23 of 23 |
| `check-ci` | the `site` job's `timeout-minutes: 10` → 11 | "job site has timeout-minutes 11, not 10", FAILED | "has the one shape check-ci reads" |
| `check-site` | `docs/tokens.md`'s `# Tokens` → `# API keys` | "a page's H1 is not its nav label, in docs/tokens.md" | all green |

## The walk as a reader, and the site job, in `ubuntu:24.04`

Run on the host under Docker, each in a fresh `ubuntu:24.04`, cloning `m4-slice-1` from GitHub at
`7928da4` ([research/m4-slice-1/walk/](research/m4-slice-1/walk/)).

- **The walk** (`walk.sh`, `walk.out`): the quick start's steps, verbatim but for four things the
  script's header names: `sudo` installed first, `apt-get -y`, `version=10.4.0`, and the clone's
  branch.
  - Chez built from its tarball with `--disable-x11 --disable-curses`.
  - The first program printed `(#t #f 32)`, as the page says.
  - The version program printed Ubuntu 24.04's libsodium's version, found by discovery. With
    an override naming no file it printed `(refused load-failed "/no/such/libsodium.so.23")`.
  - `make build` named the system's `.so.23`.
  - Then `libsodium-dev` and `valgrind`, the submodule, and `make test`: 44 of 44, as root.
- **The site job and `pages.yml`'s build** (`site.sh`, `site.out`), on Ubuntu's Chez 9.5.8, from
  `packaging/debian-site-prereqs.txt`. It installs `git` first, to clone, which brings 46 packages
  of its own, `ca-certificates` among them, and it reads the list with its own `sed`, not the
  workflow's step. So it shows the steps run on Ubuntu's Chez, not that the list is all a bare
  runner needs; CI's `site` job, green on PR #19, shows that (M4S1S-F6):
  - `make check-site-deps`, then `make site-deps`, which downloaded with curl;
  - `make check-site` and `make site`, all green;
  - then both again with `SITE_REF=v0.1.0`, the repository links naming `blob/v0.1.0/`.
- **The walk on the development workstation,** from a fresh clone of `m4-slice-1`, with its Chez
  10.4.0, which comes from a Guix profile on a distribution that is not Guix:
  - by discovery, the first program raised `not-found`, and the version program printed
    `(refused not-found #f)`: Chez runs on Guix's C library, so chez-sodium looks only in Guix
    profiles, and this profile holds no libsodium. That is the finding page's "A Chez from Guix,
    on another distribution" case, as written;
  - with `CHEZ_SODIUM_LIBRARY` naming the system's `.so.23`, the first program printed
    `(#t #f 32)`, and the version program the system library's version.

## After the two reviews

Two Opus reviews, the docs ([research/m4-slice-1-docs-review/](research/m4-slice-1-docs-review/README.md),
0 blockers, 4 majors, 14 minors) and the site ([research/m4-slice-1-site-review/](research/m4-slice-1-site-review/README.md),
0 blockers, 1 major, 8 minors), then four fix agents on disjoint files: the pages (Opus);
`test-docs` (Sonnet), whose mutants are in [1c.md](research/m4-slice-1/1c.md), "After the docs
review"; the site and the Makefile (Sonnet), in [1f.md](research/m4-slice-1/1f.md), "After the site
review"; and the contributor files and three comments (Sonnet), their datums checked the same.

The caller's checks of the fixes, each in a whole copy, against a clean copy that passed 152 of
152:

| Guards | Mutation | Result | Clean rerun |
|---|---|---|---|
| `test-docs`' banned phrases (M4S1D-F4) | "As M3S2-F4 found, …" added to `docs/tokens.md` | "no page says a banned phrase, by page" fails | 152 of 152 |
| the login pattern as a run block (M4S1D-F2) | `(password-verify hash password)` → `(password-verify password hash)` in `docs/passwords.md` | "docs/passwords.md:70: the runnable example gives the result it states" fails | 152 of 152 |
| `SITE_REF` by the environment (M4S1S-F1) | the review's `inject-probe.sh`, pointed at the fixed tree | no `INJECTED` line; `v0.1.0;x` and `-x` refused by name, nothing written | the reviewer's copy of the old tree still prints both `INJECTED` lines |
| `check-site`'s ninth invariant (M4S1S-F5) | `SITE_REF=v0.1.0` while `Akku.manifest` reads 0.0.0 | "SITE_REF v0.1.0 is a release tag, but Akku.manifest's version is 0.0.0, not 0.1.0" | `main` all green |

**In the container, after the fixes:** `make test` 44 of 44, `check-test-fails` 17 cases,
`check-site` all green with its ninth invariant, `check-floors`, `check-ci`.

**Two agents ran a probe from a file after Claude Code's removal guard refused it** (the site
reviewer, and the site's fix agent, each on a command holding backticks or `$$`). Neither should
have: a refused command is reported, never rerun another way. The commands deleted nothing, and
every later brief says so outright.
