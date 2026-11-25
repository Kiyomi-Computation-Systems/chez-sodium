# M4 pre-work A: chez-sqlite3's M5 mapped onto chez-sodium, and the owner's questions

Written 2026-11-25, on `main` at `d53e83c`, clean. chez-sqlite3 was read at `960d9f0` (its `main`,
tags `v0.1.0` and `v0.1.1`), and nothing was written there. `<repo>` is chez-sodium's checkout,
`<sibling>` chez-sqlite3's, `<home>` the user's home. "Inferred" marks a claim that was reasoned,
not read or run. Every probe's files are beside this note.

M4 is "`docs/`, and `docs/reference.md` with `test-reference`; the site and its job; `CHANGELOG.md`;
release 0.1.0" (brief §9, line 636). chez-sqlite3 did the same as its M5. This note maps that M5's
shape onto chez-sodium: what exists, what each copied file becomes, the checks, CI, the release,
the comments, and the owner's questions. **It leaves out what the pages say.** A second pre-work
covers the docs' content, the verbs' entries and the pages' text.

## 1. What chez-sodium has of M5's end state, and what it lacks

**Has:**

| What | Where |
|---|---|
| The archive rule: `/.plans` and `/AGENTS.md` `export-ignore` | `.gitattributes:3-4`, held by `tests/test-manifest.sps:22-26` and `:798-800` |
| The archive rule works: `git archive 527170d` (before it) lists 71 entries under `.plans/` and `AGENTS.md`; `0b800ed` (which added it) and `d53e83c` list none | [archive.out](archive.out) |
| A CHANGELOG skeleton, Keep a Changelog 1.1.0, `## [Unreleased]` empty | `CHANGELOG.md:1-7` |
| The changelog's reader and its rules, chez-sqlite3's closing review's among them: the version is the latest release or 0.0.0; the latest entry says something; `[Unreleased]` and the release's link reference, each once; no link reference before a release | `tests/test-manifest.sps:17-20`, `:27-42`, `:307`, `:644-648`, `:780-782` |
| `Akku.manifest` at 0.0.0, no `depends`, no `scripts`, "the version is CHANGELOG.md's latest release, or 0.0.0 while there is none" | `Akku.manifest:4-25` |
| CI runs on a `v*` tag's push; `permissions: contents: read` | `.github/workflows/ci.yml:49-57` |
| The memory job already takes `timeout-minutes: 120`, which `check-ci` holds | `ci.yml:192`; `tests/check-ci.sh:689` |
| `check-action-pins.sh` reads every file of the workflow directory, so a `pages.yml` is held too | `ci.yml:91-95` |
| `check-floors` already reads README.org whole: the floors in Requirements' list lines and nowhere else | `tests/check-floors.sps:1-17`; `Makefile:282-284` |
| `check-pins`' `sed` reads chez-srfi's line alone; on chez-sqlite3's two-project lock it answers `7879b52` (rerun here) | `Makefile:182`, the same line as `<sibling>/Makefile:298` |
| A signature comment for each of the 18 exports | `src/chez-sodium.sls:16-59` (§3) |
| The records already plan the site's container and dependency for M4: `cmark-gfm`, `tar` and `xz` in the manifest, `CHEZ_CMARK_GFM_LIBS`, chez-cmark-gfm a `depends/dev` | ADR-0011, decisions 2 and 3 (lines 71-81) |
| The comment rule, binding since PR #1, before any code | `AGENTS.md:128-130` |
| README.org's Requirements, AI disclosure and License | `README.org:33-39`, `:6-8`, `:41-44` |

**Lacks:**

- `docs/`, `test-reference`, `test-docs`: none exists (M0 plan §3 put them in M4).
- The site: `build-site.sps`, `site/`, `tests/site-*.sps`, `tests/site-testing.sls`,
  `tests/test-site-testing.sps`, `tests/check-site.sps`, `scripts/fetch-akku-lock` and its test,
  the four Makefile targets, `pages.yml`, a `site` job, `packaging/debian-site-prereqs.txt`.
- The container's `cmark-gfm`, `tar` and `xz`: `manifest.scm:14-19` lists none. The container
  has none of them, nor curl, wget or python3 ([store.out](store.out)).
- chez-cmark-gfm in `Akku.manifest` and `Akku.lock`.
- The clone check. `test-manifest` has neither the check nor chez-sqlite3's old tripwire. No file
  holds a `git clone` line today ("Owed to M4", `progress.md:186-187`).
- `check-floors`' docs input (`progress.md:185`).
- `check-suites`' `site-exit-form` and `check-test-fails`' two site cases.
- A current README: its Status says "One verb is built so far" (`README.org:24-31`). It links
  into `.plans/` (`README.org:30`), which a release archive leaves out and chez-sqlite3's
  `test-docs` refuses. It has no Installing, example, Documentation section or CI badge.
- On GitHub ([settings.out](settings.out)): Pages is off (`pages` 404, `has_pages` false); no
  environment; `main` is unprotected ("Branch not protected"; `rules/branches/main` is `[]`); no
  ruleset; no tag; no release.

## 2. The trim table

Each chez-sqlite3 file M4 would copy, with its verdict and what it protected there. "As is" means
byte for byte. "Names" means `chez-sqlite3` to `chez-sodium`, `CHEZ_SQLITE3_` to `CHEZ_SODIUM_`,
`(chez-sqlite3-testing)` to `(chez-sodium-testing)`, and SQLite's ADR numbers to chez-sodium's.

### 2.1 The generator (brief §7.1, "copy nearly as it is")

| File | Verdict | What changes | What it protected (chez-sqlite3's record) |
|---|---|---|---|
| `build-site.sps` | as is | nothing | the one shell: `SITE_REF` pins `../` links to a ref, `SITE_OUT` the output (ADR-0022, d4) |
| `site/io.sls` | as is | nothing | the only filesystem access; writes through a binary port, so no host turns line ends to CRLF; a rerun overwrites |
| `site/pages.sls` | adapt | the page list and labels, which Q2 decides, equal to README.org's Documentation list | one source of the nav's order and file set; the first page is the home, written `index.html` (M5 Q11, and slice 2's amendment: three rules, not two) |
| `site/links.sls` | adapt | `repo-blob`'s URL | `../` becomes `blob/REF/`; `.md` becomes `.html`; a dangling link is recorded; only an `a` or `img`'s `href`/`src` is rewritten, so a `javascript:` string in a `pre` stays text |
| `site/render.sls` | as is | nothing | two passes, so every anchor is known before links are checked; left-to-right accumulation |
| `site/template.sls` | adapt | the description and keywords, the source link, the wordmark | the theme script holds no `<`, `>` or `&`, which the serializer escapes; `localStorage` only inside `try` |
| `site/slug.sls` | as is | nothing | GitHub's anchor rule: decimal digits only, repeats numbered. On the 18 export names it gives 18 distinct anchors, `constant-time-bytevector=?` to `constant-time-bytevector` ([render/run.out](render/run.out)) |
| `site/transform.sls`, `site/serializer.sls` | as is | nothing | heading ids, ⚠ callouts, escaping, no `<pre>` reflow |
| `site/style.css` | adapt | the header comment's name | |

The copied generator ran on the host and rendered two stub pages (§10, P1): it needs no change
but the names and the page list.

### 2.2 The site's suites and check

| File | Verdict | What changes | What it protected |
|---|---|---|---|
| `tests/site-testing.sls` | adapt | names in its header (lines 4-7) | the site's suites run on Ubuntu's Chez, below the floor, so they import nothing under `src/`; a verdict of 0 or 1, never a count |
| `tests/test-site-testing.sps` | adapt | `(chez-sodium-testing)` | the verdict itself, held on the floor's Chez in `make test` |
| `tests/site-unit.sps` | adapt | the wordmark and source-link rows (327-333) and the blob URLs (247, 250). Its anchor fixtures "as GitHub rendered it" (116-128, 171) are GitHub's rule's evidence, measured on other pages: keep them as data | slug parity with GitHub (P4); every page's file name by a rule written out (slice 2's review); the theme script's `try` |
| `tests/site-render-unit.sps` | as is | nothing (no project name in it) | the footer, the nav, a render's danglers |
| `tests/check-site.sps` | adapt | names in comments; invariant 7 reads README.org's `** Documentation`, which chez-sodium's README lacks today: the copy fails there by name ([render/run.out](render/run.out)) | eight invariants on the real pages: nav = `docs/*.md`, no dangling anchor, no `.md` leak, no `<pre>` reflow, every relative link a written file, every `../` a checkout file, nav = README's list, each H1 its label |
| `tests/check-suites.sps` | adapt | its `exit-form`: `site-exit-form` for `tests/site-*.sps` | a site suite can't end with the floor's exit form, which would need `src/` |
| `tests/check-test-fails.sh` | adapt | the two site cases, `site-exit-line` and `site-no-exit`: 13 cases become 15 | check-suites fails on each, by name |

### 2.3 The dependency and the container

| File | Verdict | What changes | What it protected |
|---|---|---|---|
| `scripts/fetch-akku-lock` | as is | nothing | the lock's sha256 checked; a rerun works offline from `dl/`; a `file://` URL copied with `cp`, since the container has no downloader (chez-sqlite3 traps, line 1007) |
| `tests/fetch-akku-lock.sh` | as is | nothing | the script's offline test, 30 checks (P5) |
| `Akku.manifest` | adapt | `depends/dev` gains `("chez-cmark-gfm" "^2.0.0")`; its comment says so | the site's dependency never reaches a consumer |
| `Akku.lock` | adapt | chez-cmark-gfm's entry, chez-sqlite3's byte for byte: its sha256 `bb647e07…` is the sibling's fetched archive's (`sha256sum`, rerun here) | the archive `make site-deps` takes is the one pinned |
| `tests/test-manifest.sps` | adapt | two `depends/dev` entries, two projects; the clone check (§6.3) and its `tests/fixtures/clone-lines/` | the manifest, the lock and the changelog move together |
| `manifest.scm` | adapt | `"cmark-gfm"`, `"tar"`, `"xz"`, each with its need (ADR-0011, d2 already says so) | |
| `scripts/guix-env-enter` | adapt | `need` the two cmark-gfm libraries; export `CHEZ_CMARK_GFM_LIBS`, the core first | chez-cmark-gfm otherwise searches `/usr/lib`, which the container lacks |
| `scripts/guix-env-selftest` | adapt | `tar` and `xz` in the tools; an assertion that the variable names the two files and Chez loads both, each part checked to name a file first; the Makefile assertion becomes the tenth | `(load-shared-object "")` answers as if it loaded (chez-sqlite3 traps, 1001-1005) |
| `tests/guix-env-launcher.sh` | adapt | T7's fake profile gains the two libraries | the entry script's exports, on the host |
| The Makefile's site section | adapt | names; `SITE_CMARK`, `SITE_LIBDIRS`, `SITE_REF`, `SITE_SUITES`; `site-deps`, `site`, `check-site`, `check-site-deps`; `.PHONY`; `check-suites`' recipe gains `$(SITE_SUITES)` | `site-unit` runs with no chez-cmark-gfm on its path, so a pure site library that starts importing it fails at import |

### 2.4 CI (§5)

| File | Verdict | What changes |
|---|---|---|
| `.github/workflows/pages.yml` | adapt | its header comments only (they name libsqlite3, chez-sqlite3 and ADR-0022). Every held line stays: `v*` tags and by hand; `contents: read`; one deployment at a time; the deploy job alone with `pages: write` and `id-token: write`; `persist-credentials: false`; the three pinned actions |
| `ci.yml`'s `site` job | adapt | the job as is; `ci.yml`'s header lists six jobs |
| `tests/check-ci.sh`'s site and pages parts | adapt: a port, not a copy | §5.2 |
| `tests/test-check-ci.sps`' site and pages rows | adapt | §5.2 |
| `packaging/debian-site-prereqs.txt` | adapt | the header's names. Packages as is: `chezscheme`, `cmark-gfm`, `ca-certificates`, `curl`, `make`, `xz-utils` |
| `packaging/debian-prereqs.txt`'s header | adapt | "every job but `site`" (line 4) |

### 2.5 The docs' checks

| File | Verdict | What changes |
|---|---|---|
| `tests/test-reference.sps` | adapt | names; the rows that pin named signatures; the trailing notes (§3, Q5) |
| `tests/test-docs.sps` | adapt, heavily | §4 |
| `tests/check-floors.sps`, `tests/floors.sls`, `tests/test-check-floors.sps`, `tests/fixtures/floors/docs-*` | adapt | the docs input alone. chez-sodium dropped SQLite's numeric forms (ADR-0011, d4), so only the dotted text is refused. The Makefile's recipe gains `docs` |
| `docs/*.md`, README.org | content pre-work's | structure only: README's sections in the siblings' order, a `** Documentation` list equal to the nav |

### 2.6 The release

| File | Verdict | What changes |
|---|---|---|
| `<sibling>/.plans/research/m5-closing-review/live-check.sh` | adapt, into chez-sodium's research directory | the repository, the page list |
| `<sibling>/.plans/research/m5-release/check.py`; chez-curl's `extract.py` | adapt | the repository |
| CHANGELOG.md's entry | write | §6.4 |

### 2.7 Left out

- `memory-1` and `memory-2`'s timeout (M5 Q9): chez-sodium has one memory job, already at 120.
- The Mac steps, `release-0.1.1/mac.md`, and `finding-sqlite.md`'s macOS and "any other system"
  rows: Linux only (ADR-0010).
- `examples/` and its `test-docs` rules, unless Q2 or Q3 asks for them (chez-sqlite3 added them
  after 0.1.0, ADR-0022's amendment of 2026-11-21).
- `test-docs`' "some whole program leaves a file" clause: nothing here writes one.
- The tripwire: chez-sodium never had one; the clone check comes whole.

## 3. `test-reference`

### 3.1 How chez-sqlite3's reads

(`<sibling>/tests/test-reference.sps:1-47`, `:235-284`.)

- **The exports are Chez's:** `library-exports` of `(chez-sqlite3)`, after `environment` imports
  it. Each name is evaluated there, and must be a procedure or a value; syntax fails.
- **The signature comments are read as text, up to the `(import` line.** A line counts when,
  trimmed, it starts `;; ` and its second word is `:`. The signature is the whole trimmed line
  after `;; `.
- **The page is read as CommonMark:** ATX headings outside fences, and `text` fenced blocks.
- **The form of `docs/reference.md`:**
  - one `` ### `NAME` `` heading per export, and no `###` of another shape;
  - an entry runs to the next heading of level 1 to 3, so `####` sub-headings are free;
  - each entry holds exactly one `text` block of one line, `NAME : TYPE`, its own NAME;
  - a procedure's TYPE holds `->`, a value's doesn't;
  - the line equals its export's comment, character for character;
  - exports and entries are compared as whole sorted lists, so the page's order is free.

### 3.2 What differs here

The probe ran those readers, copied verbatim, on `src/chez-sodium.sls`
([reference/probe.out](reference/probe.out)):

| Export | Comment at `src/chez-sodium.sls` | Note |
|---|---|---|
| `sodium-version` | 16 | |
| `random-bytes` | 20 | |
| `blake2b` | 22 | trailing `   ; input, size, key` |
| `constant-time-bytevector=?` | 24 | |
| `password-hash` | 29 | `Limits` defined at 28 |
| `password-verify` | 31 | trailing `              ; hash, password` |
| `password-needs-rehash?` | 33 | trailing `      ; hash` |
| `make-password-limits` | 35 | trailing ` ; ops, memory in KiB` |
| `chez-sodium-error?` | 39 | |
| `sodium-library-unavailable?` | 41 | |
| `sodium-library-unavailable-reason` | 43 | `Reason` defined at 44-45 |
| `sodium-library-unavailable-path` | 47 | |
| `sodium-library-unavailable-source` | 49 | |
| `sodium-library-unavailable-detail` | 51 | |
| `sodium-library-unavailable-candidates` | 53 | |
| `sodium-failed?` | 55 | |
| `sodium-failed-function` | 57 | |
| `sodium-failed-code` | 59 | |

- **No export lacks a comment.** There are 18 exports, each a procedure, each with exactly one
  signature comment, and none for a name not exported. The section headers and the `Limits` and
  `Reason` lines are skipped, their second word not `:`.
- **Four comments carry a trailing note,** which the copied reader keeps in the signature. The
  reference would repeat `; hash, password`, padding and all, in a `text` block (Q5).
- **The type names need the reference's intro:** `Limits`, `Password-limits`, `Reason`,
  `SodiumFailed` and `SodiumLibraryUnavailable`, and the bracket notation of an optional argument,
  `[Natural]`, which is not Typed Racket's own (`->*` or `case->`, as chez-sqlite3 writes
  `with-transaction`). The content pre-work words them.
- **Condition predicates and accessors** are procedures like any other, so they need no rule of
  their own. ADR-0012 exports no `&` name or constructor, so none can appear.

## 4. `test-docs`

### 4.1 chez-sqlite3's rules, and how each applies

(`<sibling>/tests/test-docs.sps:2-122`.)

| Rule | Here |
|---|---|
| Every block names `scheme`, `sh` or `text` | as is |
| Every Scheme block is a fragment Chez's `read` reads, or runnable | as is |
| Relative links and anchors resolve, by GitHub's rule; none points into `.plans/` | as is. README.org:30 fails it today |
| README.org links every page | as is |
| README.org's Scheme block is the twin of a `scheme run` block | Q3 |
| No page says `ADR-`, `TODO`, any "yet", "unreleased", "slice", a `.plans` path, a date | as is. "Owed to M4"'s notes cite findings (M3S2-F4, M3C-F4): the pages must drop them |
| A code span that is one name beginning `sqlite-` or `chez-sqlite3-` is an export | adapt: chez-sodium's exports share no prefix. Spans of one name beginning `sodium-`, `chez-sodium-`, `password-` or `make-password-`, and the exact names `random-bytes`, `blake2b` and `constant-time-bytevector=?`. C names use `_`, so they never match |
| A whole program (a block whose first datum is `(import …)`) runs in a fresh Chez through `gated-command`, `src` alone, from a fresh directory: exit 0, no stderr, prints its text block | adapt the names. A hash is random, so a program prints a verify's `#t`, never a hash |
| A guarded program (`(sodium-library-unavailable? V)`) prints what the suite reads, and runs again with the override naming no file | adapt: chez-sodium exports `sodium-version` alone (no path or source accessor), so the first run prints the version |
| No whole program names a `(chez-sodium private …)` library | names |
| `examples.md` and `examples/` are twins | left out unless Q2 or Q3 |
| `finding-sqlite.md`'s tables are the code's | adapt to a page on finding libsodium, if Q2 has one: its reasons table held to `sodium-library-unavailable-reasons` (`conditions.sls:28`); its discovery table to `libsodium-candidates` and `libsodium-sources` (`discovery.sls`), two worlds, Guix and FHS, each on x86_64 and arm64 (`discovery.sls:99-102`); no macOS row |
| Every word holding `CHEZ_` is `CHEZ_SQLITE3_LIBRARY`; each set value is absolute | `CHEZ_SODIUM_LIBRARY` |
| Each page has one H1, its first line | as is |
| `scheme run`: the body of `(let () …)` in `(rnrs)` and the library; its `;; => DATUM`; every native count zero after | `(rnrs)` and `(chez-sodium)`; the counters count blocks. **`(rnrs)` has no `bytevector`:** a block that calls it raises "unbound identifier" ([cost/run-1.out](cost/run-1.out)). It has `u8-list->bytevector`. `import` is unbound there too (chez-sqlite3's P3) |

### 4.2 What it costs under the gate

chez-sqlite3 needed nothing special: its blocks open `:memory:`, which is cheap, and its cost is
its gated children. On CI the gate gave `test-docs` 68 s at v0.1.0, and 125 s once 13 children ran
(`<sibling>/.plans/progress.md:345` and `:356`).

Measured here in the container, Chez 10.4.0 and Guix's libsodium 1.0.22, each block as `test-docs`
would run it, plain and under the gate's own Valgrind options. Three runs agree within 4%
([cost/run-2.out](cost/run-2.out), [cost/run-3.out](cost/run-3.out)).

| What | Plain | Under the gate |
|---|---|---|
| a `'interactive` hash, in process | 53 to 58 ms | 686 to 705 ms |
| a verify of it, right or wrong | 49 to 58 ms | 678 to 703 ms |
| `password-needs-rehash?` | 0 to 1 ms | 7 to 8 ms |
| the login pattern: hash, verify, needs-rehash | 99 to 114 ms | 1,347 to 1,375 ms |
| a hash and a verify at the minimum, the first hash of the process | 0 to 1 ms | 77 to 80 ms |
| `random-bytes` and `blake2b`; the compare | 0 to 1 ms | 2 to 14 ms |
| a whole program as a gated child: load, `random-bytes`, exit | 106 to 114 ms | 4,736 to 4,891 ms |
| the same, with a hash and a verify at the minimum | 108 to 111 ms | 4,879 to 4,966 ms |
| the same, with an `'interactive` hash and verify | 211 to 219 ms | 6,241 to 6,301 ms |

Each Valgrind log: 0 errors from 0 contexts.

**A model (inferred):** about 0.7 s for each `'interactive` hash or verify in a block, and about
4.9 s for each whole program, plus 1.4 s if it hashes and verifies at `'interactive`. A guarded
program runs twice. So 15 blocks that each hash and verify once, and 6 whole programs at the
default, cost about 21 s and 38 s: about 60 s in the container. CI's runners differ about two to
one (chez-sqlite3's pre-work §8), so up to about 120 s, against the 450 s `SLOW` line. The
slowest suite today is `test-check-ci`, 111 s on CI ([ci-times.out](ci-times.out)).

### 4.3 The limits rule

AGENTS.md and ADR-0011, amended (lines 57-62 and 254-259), let password rows hash above the
minimum only in these rows: row 5's pair, row 7's one default hash, row 22's code rows, and the
no-memory rows. A run block that shows a reader `(password-hash password)` hashes at
`'interactive`, which none of those exceptions covers. So the docs either take a new exception, or
show other limits (Q4).

## 5. CI

### 5.1 The `site` job and `pages.yml`

- **The site job** (`<sibling>/.github/workflows/ci.yml`, its last job):
  - `runs-on: ubuntu-24.04`, `timeout-minutes: 10`;
  - the checkout with `submodules: recursive`, since the site's suites need SRFI-64;
  - the site's install step;
  - then `make check-site-deps`, `make site-deps`, `make check-site` and `make site`, each with
    `env: CHEZ: chezscheme`;
  - no cache, no `if:`, no `SITE_REF`: it builds for `main`.

  chez-sqlite3's took 28 s on its first run (`<sibling>/.plans/progress.md:572`).
- **`pages.yml`**, 99 lines (`<sibling>/.github/workflows/pages.yml`):
  - it runs on a `v*` tag's push or by hand, never on a pull request;
  - its `build` job installs the site's packages, runs `make site-deps`, then `check-site` and
    `site` with `SITE_REF` the tag, and uploads `build/site`;
  - its `deploy` job needs `build`, holds `pages: write` and `id-token: write`, and runs in the
    `github-pages` environment.

  The build's artifact is kept one day, so a deploy retried after a day reruns the whole run
  (chez-sqlite3's plan, §4.9, step 6).

### 5.2 `check-ci`'s shape, and `test-check-ci`

**chez-sodium's `check-ci.sh` has diverged from chez-sqlite3's,** so the site and pages parts are
ported, not pasted:
- it has five jobs and one memory job (`tests/check-ci.sh:28-47`);
- it has a per-job timeout table, `twant` (`:689`);
- it requires the step "Identify the runner image" in every job, before the job's first cache
  restore (`:64-69`, `:527-550`).

chez-sqlite3's check has no image rule. What changes:

- **The directory:** `ci.yml` and `pages.yml` alone, each a regular file and no link, read by a
  glob. `:6-7` and `:147` say `ci.yml` alone today.
- **Six jobs,** `site` the sixth, with a `twant` of 10.
- **The site job's rules,** chez-sqlite3's:
  - six steps: the checkout with submodules, then the install step;
  - the install step held line for line to the copy `pages.yml`'s install step is held to;
  - its four checks, in order, each a whole run line with `CHEZ` `chezscheme`;
  - no `uses:` but the checkout, and no `if:`.
- **The image rule:** the site job, which has no cache, must be exempted from it (the copy has no
  image step), or carry an image step for nothing. A plan decision.
- **Two more banned words:** `SITE_REF` and `CHEZ_CMARK_GFM_LIBS` join `bw` (`:650`).
- **`pages.yml` held to `check-ci.sh`'s copy,** every line but a comment or a blank line outside a
  run block. A run block's lines are script and are held whole (chez-sqlite3's slice 3 amendment;
  its traps, 1025-1040). The text rules hold on every line.
- **The pass line stays word for word.** `check-memory-gate`'s case o compares it whole
  (`tests/check-memory-gate.sh:1530`).
- **The Makefile's `check-ci` help line** names both files (`Makefile:296`).

**`test-check-ci`'s rows and time.**
- **Today:** 766 rows. It takes 29 s plain in the container ([ci-times.out](ci-times.out)), 111 s
  under the gate on CI, and 114 to 117 s in the container (`progress.md:244`, `:289`).
- **chez-sqlite3's slice 3** took its suite from 496 rows to 573, +585 lines
  (`<sibling>/.plans/progress.md:560`; `git show --stat 047ee91`).
- **Inferred:** a port adds 80 to 100 rows. At this suite's rate under the gate, about 0.15 s a
  row, that is +12 to +15 s: about 130 s of 450 in the container, and up to about 260 s on a slow
  runner. M3's rule splits a suite past a third of `MEMORY_TIMEOUT`, 200 s, so the slice measures
  it first.

### 5.3 Ubuntu's Chez for the generator

chez-sqlite3's P5 (`<sibling>/.plans/m5-slice-3-mutation-log.md:176-206`) ran the site job's steps,
then `pages.yml`'s build job, in a fresh `ubuntu:24.04`: nine steps, none failing.
- **The versions:** Chez Scheme 9.5.8 (`chezscheme 9.5.8+dfsg-1`), below the floor. cmark-gfm
  0.29.0.gfm.6, whose two libraries chez-cmark-gfm found by itself.
- **`make site-deps` downloaded with curl.**
- **Nothing failed in Ubuntu that passed in the container.**
- **One trap:** `chezscheme` makes `scheme` an alternative, so a site step that lost its
  `env: CHEZ` still passes. Only `check-ci` sees the loss (chez-sqlite3 traps, 1011-1015).

What it means here:
- The generator, its suites and `check-site` import nothing of chez-sodium's, so 9.5.8 runs them,
  as it did there. `tests/test-site-testing.sps` imports `(chez-sodium-testing)`, and runs only in
  `make test`, on the floor's Chez.
- The container's cmark-gfm is 0.29.0.gfm.13, Ubuntu's gfm.6, so `check-site` runs on both.
- **Inferred, for the content pre-work:** a reader on Ubuntu 24.04 can't use apt's Chez for the
  library. It is below `packaging/floors.sexp:4`'s floor, and `require-threaded` refuses it, so
  the quick start says to build Chez.

### 5.4 The repository's settings

Read with GETs alone ([settings.out](settings.out)). Nothing was changed.

| Setting | chez-sodium today | chez-sqlite3 | What the owner sets, and when |
|---|---|---|---|
| Pages | off: 404, `has_pages` false | `build_type: workflow` | turn on, built from GitHub Actions, after the site's CI slice merges and before the tag |
| The `github-pages` environment | none (`environments` empty) | custom policy, the tag rule `v*` alone | the tag rule `v*`, and no branch rule, before the tag. Pages made through the API creates the environment with `main` alone, which must be deleted (chez-sqlite3's pre-work §4, item 5; its closing review's "Drop main, keep v*") |
| Branch protection on `main` | none: "Branch not protected"; no branch rules | every job required, `strict: true` | Q8. If chosen, as the site's CI slice merges, so its context exists: `site (the docs site, on Ubuntu's Chez)` |
| A tag ruleset | none (`rulesets` is `[]`) | "release tags", active, `refs/tags/v*`, `update` and `deletion`, no bypass | Q8, before the tag |
| Tags, releases | none | `v0.1.0`, `v0.1.1` | the release |

The repository is public, with `default_workflow_permissions: read`.

## 6. The release

### 6.1 chez-sqlite3's steps

From its plan's §4.9, ADR-0022's decision 12 and its amendment, and the release record
(`<sibling>/.plans/research/m5-release/README.md`). (M) marks the maintainer's.

1. **The release branch:** the entry dated, the manifest and the clone lines bumped; CI green.
2. **The Mac's `make test`** (M).
3. **The squash merge** (M). `main`'s push run is read, and the squash's tree compared with the
   tested branch's.
4. **Before the tag, since its push deploys at once:**
   - Pages, the environment's `v*` rule and the ruleset are read;
   - `SITE_REF=v0.1.0 make site` is rendered in the container and served on loopback;
   - `live-check.sh` exits 0 on that render, and 1 on a `main` render.
5. **The tag** (M): annotated and signed, checked absent locally and on `origin` first.
   `git tag -v` is read, and the tag pushed alone. `git ls-remote` reads back the tag object and
   `^{}`.
6. **The tag's runs:** its CI run and its Pages run are read. A failed deploy is retried at the
   tag, never by moving it. Only a fault in the tag's tree takes a new tag.
7. **The live site:** `live-check.sh` exits 0 against it.
8. **The GitHub Release** (M), by chez-curl ADR-0042's recipe:
   - a draft from `--verify-tag`;
   - its title the tag message's subject;
   - its notes the tag's CHANGELOG entry, intro to last bullet;
   - its body compared byte for byte (`check.py`), then published as the latest, read again, and
     its links checked.
9. **The archives listed:** GitHub's tarball and `git archive`, no `.plans/` and no `AGENTS.md`.
   The listing is watched failing on a commit before `.gitattributes`.
10. **The README's clone line run verbatim,** and the quick start's first program from that clone.

### 6.2 Mapped onto chez-sodium

The same ten steps, but:
- **Step 2 goes:** no Mac (ADR-0010).
- **Step 3 reads six jobs,** five plus `site`.
- **Step 9's watched failure is `527170d`,** 71 entries ([archive.out](archive.out)).
- **The live check names chez-sodium's pages** and `https://kiyomi-computation-systems.github.io/chez-sodium/`.
- **A new last step:** tell Techo's session the tag's commit. Techo pins by submodule (brief §9),
  so moving its pin is Techo's choice.

Steps 3, 5 and 8 are the owner's, and so are the settings of §5.4.

### 6.3 The two "Owed to M4" items

- **`check-floors`' docs rule** (`progress.md:185`). `check-floors` takes `docs` as a fifth
  argument: no line of any file under `docs/` holds either floor's dotted text, `10.4.0` or
  `1.0.18`. README.org is already read whole.
  - **A page names a floor by a link** to README.org's Requirements, and a library whose version
    is the floor's text by whose it is: "Ubuntu 24.04's libsodium" (chez-sqlite3's ADR-0008,
    amended).
  - **The content pre-work should know:** M3's notes on the floor say "at 1.0.18". The pages must
    word them by whose library it is.
  - CHANGELOG.md isn't read.
- **`test-manifest`'s clone lines** (`progress.md:186-187`). Every line of README.org, or of a
  file under `docs/`, that holds `git clone` is, past its leading spaces, exactly
  `git clone --branch vX.Y.Z https://github.com/Kiyomi-Computation-Systems/chez-sodium.git`, X.Y.Z
  the manifest's version.
  - **At 0.0.0** it is the same line with no `--branch`, so `main`'s docs clone `main` until the
    release (chez-sqlite3's S1).
  - **README.org and the quick start hold one each,** if the quick start is a page (Q2).
  - **Held on fixture trees first,** chez-sqlite3's `tests/fixtures/clone-lines/`.

### 6.4 What 0.1.0's CHANGELOG entry must hold

chez-sodium's `test-manifest` already holds every rule chez-sqlite3's does (§1):

- `## [0.1.0] - YYYY-MM-DD`, below an `## [Unreleased]`;
- a body: some line past its blanks that begins with no `#` and is no link reference;
- `[Unreleased]: https://github.com/Kiyomi-Computation-Systems/chez-sodium/compare/v0.1.0...HEAD`
  and `[0.1.0]: https://github.com/Kiyomi-Computation-Systems/chez-sodium/releases/tag/v0.1.0`,
  each given once (`tests/test-manifest.sps:657-661`);
- `Akku.manifest` at 0.1.0, its comment (lines 18-19) saying the clone lines move too;
- the clone lines at `--branch v0.1.0`, once the clone check exists.

chez-sqlite3's ADR-0022, decision 11, shapes the rest:
- an intro;
- Added, by area, linking each page;
- Known limitations;
- link references closing the file;
- dated by the release branch's local day, never CI's UTC day;
- held to the suites, not to the docs it sums up.

The limitations' content is the content pre-work's: Linux only, arm64 not run (Q6), Tier 2
later, not on Akku, what wiping can't reach, and `#f` covering three causes.

### 6.5 Akku (brief §11.8, lines 723-727)

0.1.0 is not published on Akku: that waits until Techo has battle-tested the library.
- `Akku.manifest`'s 0.1.0 is for `test-manifest` alone.
- No `.akkuignore`.
- Installing is a clone of the tag, with `src` on Chez's library path and nothing built.
  Techo needs no release: it pins a commit.

## 7. The comment sweep

**The banned categories:** milestones, slices, finding ids, research paths, dates and "the
maintainer". [comment-scan.py](comment-scan.py) reads every comment of the 348 files under `src/`,
`tests/`, the Makefile, `scripts/` and `packaging/` ([comment-scan.out](comment-scan.out)). Its
comment readers:
- Scheme: `;` outside strings and characters, and `#| |#`;
- C: `//` and `/* */`;
- shell, the Makefile and text: a `#` line, or a `#` after a blank outside quotes. A heredoc's
  lines count as shell, an approximation.

`git grep` on the same patterns, comments and code alike, found nothing the scan missed.

| Category | Lines | Files | Real |
|---|---|---|---|
| milestone | 3 | 1 | 0: `tests/guix-env-launcher.sh:274`, `:287`, `:314`, the case labels M1 and M2 beside T1 to T11 and R1 to R6 |
| slice | 3 | 3 | 0: English, "slices a string" (`password-verbs.sls:24`), a procedure named `slice` (`test-decoy-source.sps:255`), an engine's slice of ticks (`test-public.sps:187`) |
| finding id | 0 | 0 | 0 |
| research path | 2 | 2 | 0: the path a row reads (`test-conventions.sps:310`) and the attribute line itself (`test-manifest.sps:23`) |
| date | 0 | 0 | 0 |
| "the maintainer" or "the owner" | 0 | 0 | 0 |

**No comment breaks the rule.** AGENTS.md has carried it since PR #1 (`527170d`, `git log -S`),
before any code, and no fixture is touched.

**History in other words** (the same file):

| What | Lines | Files | Where |
|---|---|---|---|
| "decision N" after an ADR | 18 | 9 | `byte-verbs.sls:8`, `cap.sls:8`, `conditions.sls:19`, `native.sls:43`, `:170`, `:376`, `:913`, `:925`, `password-verbs.sls:8`; `tests/check-seam.sps:37`, `:76`, `:195`; `foreign-conventions.sls:4`, `:67`, `:70`; `test-constants.sps:196`; `test-conventions.sps:2`, `:98` |
| "amended" after an ADR | 3 | 2 | `foreign-conventions.sls:16`, `:256`; `test-decoy-source.sps:2` |
| the brief by section or row | 5 | 5 | `test-conditions.sps:419` ("brief section 8.1, row 16"), `test-native-codes.sps:5`, `test-native.sps:30`, `test-library-loading-passwords.sps:399`, `test-library-loading-verbs.sps:301`, `test-wipe.sps:2` |
| "review" | 12 | 7 | none provenance: each is "a reviewed change" or "held by review" |

**Judgement.**
- **Decision numbers and "amended" go.** AGENTS.md's "a bare `ADR-NNNN` may point to why" (line
  130) is the family's rule, which chez-sqlite3's sweep took from chez-curl's ledger: "a bare ADR
  number stays, as a pointer to why, its amendment dates and decision numbers gone" (its M5 plan,
  S6).
- **A brief or row number points into `.plans/`,** which no archive holds, so those go too, as
  chez-sqlite3's "plan sections" went. A row number inside a test's name is a string, and stays.
- **About 26 lines in 15 files.**

**No sweep slice is needed.** The 26 lines are one small PR, or part of the closing review's fix
PR. chez-sqlite3's three checks hold it:
- each edited Scheme file reads as the same datums;
- each changed shell line is a whole-line comment;
- each C file compiles to the same object.

The closing review reruns the scanner over what M4 adds. The convention table's ADR citations are
strings, which the datum check holds.

## 8. The owner's questions

### Settled already, so not asked

| chez-sqlite3's | Settled by |
|---|---|
| Q1, a site from v0.1.0 | brief §9's M4 row, "the site and its job" (line 636); §7.1's "The docs site, at M4" (line 526); ADR-0011, decisions 2 and 3 |
| Q3, the archive | `.gitattributes:3-4`, held by `test-manifest` since M0; [archive.out](archive.out) |
| Q4, Akku | brief §11.8 (lines 723-727) |
| Q7, a comment sweep | AGENTS.md:128-130 binds already; §7 finds nothing it bans, and the rest goes by its "bare `ADR-NNNN`" |
| Q9, the memory jobs' timeout | one memory job, already at 120 (`ci.yml:192`), held by `check-ci.sh:689`; `main`'s last run took 27 min 15 s ([ci-times.out](ci-times.out)) |
| Q11, the home page | the generator, copied as is (brief §7.1), carries the quick start as home: `<sibling>/site/pages.sls:7-27`. Asked again only if Q2 has no quick start |

Platforms, Linux only, are ADR-0010's. Q6 below asks only about the architecture, which no record
names.

### The questions

**Q1. A GitHub Release for each tag** (chez-sqlite3's Q2). Settles: the M4 record.
- **A. For every tag from v0.1.0, by chez-curl ADR-0042's recipe (recommended).** A draft from
  `--verify-tag`, its notes the tag's CHANGELOG entry, read back byte for byte, then published.
  Nothing in the tree changes.
- **B. The tag alone.**

Evidence:
- chez-sqlite3 made v0.1.0's by the recipe, its body byte-equal as a draft and once published
  (`<sibling>/.plans/research/m5-release/README.md:76-86`);
- a later change of mind makes Releases for old tags, as chez-curl's did (chez-sqlite3 ADR-0022,
  Rejected).

**Q2. The pages of `docs/`** (chez-sqlite3's Q5). Settles: the M4 record, `site/pages.sls`,
README.org's Documentation list, `check-site`'s invariant 7, the clone check's homes, and whether
`test-docs` holds a discovery table. *The content pre-work maps what each page says; its findings
may move this recommendation.*
- **A. Four pages (recommended, provisional):**
  - a quick start, the home;
  - finding libsodium: the override, discovery's two worlds, the refusals;
  - passwords: the login pattern and the notes M3 owes;
  - the reference.
- **B. Three:** the quick start, finding libsodium and the reference, with the password notes in
  the reference's entries.
- **C. The quick start and the reference.**

Evidence:
- **The notes M1 to M3 owe the documents:** 20, 12 of them on passwords (`progress.md:155-184`).
  In entries they would swell the reference's 18.
- **chez-sqlite3's four-page shape** (its ADR-0022, d2) and its tables held to the code
  (`<sibling>/tests/test-docs.sps:58-70`).
- **Its fifth page, examples, came after its release** (ADR-0022's amendment of 2026-11-21).

**Q3. The README's example** (chez-sqlite3's Q8). Settles: the M4 record.
- **A. A fragment in README.org, held equal to a `scheme run` block of a page (recommended).** One
  `test-docs` rule, watched failing. The block holds a body, with no `import` (chez-sqlite3's S8).
- **B. No example:** README.org links a page's.
- **C. `examples/*.sps`, run as whole programs,** chez-sqlite3's fifth page's shape.

Evidence:
- `test-docs` runs Markdown's `scheme run` blocks alone, so an Org block is read, never run
  (`<sibling>/tests/test-docs.sps:79-93`);
- chez-sqlite3's twin rule cost one rule (its plan, §4.10).

**Q4. The limits a docs example hashes at** (new). Settles: an amendment of ADR-0011 and the
constraints' limits rule, or the pages' examples.
- **A. The default, run (recommended).** The examples show `(password-hash password)`, the call a
  reader copies. `test-docs` runs them at `'interactive`, a fifth exception to the limits rule.
- **B. Cheap custom limits in every example,** `(make-password-limits 1 8)`. The suite stays fast,
  but every example teaches the weakest limits.
- **C. The default call in fragments, which `test-docs` reads but never runs,** with run blocks
  only for the other verbs. The password examples go unrun.

Evidence:
- **The cost, measured:** about 0.7 s a hash or a verify under the gate, and 1.4 s for the login
  pattern. A whole program at the default costs 6.3 s against 4.9 s at the minimum (§4.2;
  [cost/run-3.out](cost/run-3.out)). It adds about 20 s to a 60 s suite against 450 s.
- **The rule:** ADR-0011, amended, lines 57-62 and 254-259; global constraints, "Password rows
  hash at libsodium's minimum limits".
- **The default's 64 MiB runs under the gate** with 0 errors, in process and in a gated child
  (P3). The gate sets no memory cap; only `test-no-memory`'s children run under one (ADR-0011,
  amended, lines 239-249).

**Q5. The signature comments' trailing notes** (new). Settles: `src/chez-sodium.sls`'s comments,
which are the contract (AGENTS.md:154), and `test-reference`.
- **A. Each note moves to a comment line of its own under the signature (recommended),**
  `;;   input, size, key`. Each signature is then its type alone, and the reference's line is that,
  character for character. The second word of the new line is no `:`, so the reader skips it.
- **B. Keep them.** The reference's `text` line repeats `; hash, password` and its padding.
- **C. `test-reference` drops a trailing `; …` before it compares,** a rule of its own, to be
  watched failing.

Evidence:
- the probe: four of 18 comments carry a note, and the copied reader keeps it
  ([reference/probe.out](reference/probe.out));
- `<sibling>/tests/test-reference.sps:268-284`.

The bracket notation, `[Natural]`, stays either way, and the reference's intro explains it. If the
owner wants Typed Racket's own `->*` or chez-sqlite3's `case->`, it is the same edit, in A.

**Q6. What 0.1.0 claims** (chez-sqlite3's Q6, narrowed by ADR-0010). Settles: the M4 record, and
ADR-0010's amendment if a lane is added.
- **A. What ran (recommended):** Linux on x86_64, with the libsodiums CI and the container ran:
  - Ubuntu 24.04's package, found by discovery;
  - the floor and the current release, each built from source;
  - Guix's 1.0.22.

  Linux on arm64 is named as not run in README.org and the Known limitations, with no job added.
- **B. An arm64 lane before the tag,** on `ubuntu-24.04-arm`:
  - a sixth or seventh job, so `check-ci`'s shape changes;
  - discovery's `aarch64-linux-gnu` directory runs for the first time;
  - chez-curl found such runners free for a public repository (chez-sqlite3's pre-work §5), and
    this one is public ([settings.out](settings.out)).

Evidence:
- every `runs-on` is `ubuntu-24.04` (`ci.yml`);
- `discovery.sls:99-102` names `aarch64-linux-gnu`, which nothing has reached;
- ADR-0010 names no architecture.

**Q7. The tag's signature** (chez-sqlite3's Q10). Settles: the M4 record's release steps.
- **A. Annotated and signed by the owner,** with the release key that signs chez-curl's and
  chez-sqlite3's tags, `git tag -v v0.1.0` read before the push (recommended).
- **B. Annotated, unsigned.**

Evidence:
- chez-sqlite3's v0.1.0 is signed, "a good signature, key `…8EAC5130`", by the releases identity
  that signs chez-curl's (`<sibling>/.plans/research/m5-release/README.md:52`, `:68-70`);
- a signature can't be added to a pushed tag without moving it (chez-sqlite3 ADR-0022, Rejected).

**Q8. Protecting `main` and the tags** (new: chez-sodium has neither). Settles: the M4 record's
release steps; the owner sets each on GitHub, and the lead reads it back.
- **A. As chez-sqlite3's (recommended):**
  - `main` protected, every `ci.yml` job a required check, `strict`, set as the site's CI slice
    merges;
  - a "release tags" ruleset, active on `refs/tags/v*`, refusing `update` and `deletion`, with no
    bypass, set before the tag.
- **B. The tag ruleset alone,** with `main` unprotected as today.
- **C. Neither.**

Evidence:
- today `main` is unprotected and there is no ruleset; chez-sqlite3 has both ([settings.out](settings.out));
- a pushed, signed tag that can't be moved is one Techo can pin, and once the tag deploys, its site
  stays the signed one (chez-sqlite3 ADR-0022's amendment, "Protect update and deletion");
- `strict` asks a PR to be up to date with `main`, which chez-sodium's stacked PRs are already:
  each takes a merge of `main` before its squash (`progress.md:20-22`).

Pages and its environment need no question: the site is settled. The owner must still turn Pages
on and set the environment's tag rule `v*` before the tag (§5.4).

## 9. A proposed slice order

Each slice is one PR, stacked on the one below, with its own mutation log and an Opus review.
Builders are Sonnet; the pages' text is judgement, so it is the caller's or Opus's.

**The Makefile is the caller's alone.** Before each slice's builders start, the caller writes that
slice's Makefile lines, as M3's caller wrote stubs: no two agents share it.

0. **The plan and the records** (the caller; `.plans/` only):
   - the M4 plan;
   - a new record, ADR-0013, "the first release";
   - ADR-0011 amended: the site job, `pages.yml`, the container's cmark-gfm, chez-cmark-gfm, the
     clone lines, the docs floors rule, and Q4's exception if chosen;
   - ADR-0010 amended, if Q6 asks;
   - the brief's §9 line, the constraints, AGENTS.md, the ledger.

   *Needs the owner's answers to Q1 to Q8.*
1. **The docs and their checks.** Three builders in one tree, on disjoint files:
   - **1a, the reference:** `tests/test-reference.sps`, `docs/reference.md`, and
     `src/chez-sodium.sls`' comments (Q5).
   - **1b, the pages:** `tests/test-docs.sps`, README.org, `docs/quickstart.md` and the other pages
     (Q2), and `examples/` if chosen.
   - **1c, floors and clones:** `tests/floors.sls`, `tests/check-floors.sps`,
     `tests/test-check-floors.sps`, `tests/fixtures/floors/docs-*`, `tests/test-manifest.sps`' clone
     check, `tests/fixtures/clone-lines/`.

   The caller writes `check-floors`' fifth argument and its help line.

   Red until the join, each named in its builder's hand-back:
   - `test-docs` on the reference's blocks;
   - `check-floors`' real tree, which needs `docs/`;
   - the clone check, which needs README.org's and the quick start's lines.

   Host steps (network): the walk as a reader, in `ubuntu:24.04` with Chez built from its tarball
   and apt's libsodium, then on the development workstation; and GitHub's anchors, read on the
   PR's rendered pages (P4).
2. **The site's generator and its dependency.** One builder, in a worktree of its own. It can start
   with slice 1, its files disjoint:
   - `build-site.sps`, `site/`, `tests/site-*.sps`, `tests/site-testing.sls`,
     `tests/test-site-testing.sps`, `tests/check-site.sps`;
   - `scripts/fetch-akku-lock`, `tests/fetch-akku-lock.sh`, `tests/check-suites.sps`,
     `tests/check-test-fails.sh`;
   - `Akku.manifest`, `Akku.lock`, `manifest.scm`, `scripts/guix-env-enter`,
     `scripts/guix-env-selftest`, `tests/guix-env-launcher.sh`.

   The caller writes the Makefile's site section first. At the join, after merging slice 1's
   branch, the caller adds `test-manifest`'s dependency rows, since 1c holds that file. The page
   list comes from Q2, fixed in the plan. Host steps: `make site-deps`, `make check-guix`,
   `make check-pins`.
3. **The site in CI, and Pages.** One builder, in a worktree of its own. It can start with slices 1
   and 2, since `check-ci` reads text:
   - `.github/workflows/ci.yml`, `.github/workflows/pages.yml`;
   - `packaging/debian-site-prereqs.txt`, `packaging/debian-prereqs.txt`;
   - `tests/check-ci.sh`, `tests/test-check-ci.sps`.

   The caller writes the `check-ci` help line. Before the PR, the host runs P5's steps in
   `ubuntu:24.04`, which needs the network. **Owner, as it merges:** branch protection (Q8);
   Pages on; the environment's `v*` rule, with `main`'s removed; the ruleset (Q8).
4. **The comment pass.** One rote builder, Haiku or Sonnet, on §7's 15 files, none of which slices
   1 to 3 touch. It runs at once with them, its PR stacked last, with the three equality checks.
   It could fold into the closing review's fixes instead.

Then **M4's closing review**, on Opus, read-only. It covers the slices, the pages against the code,
the scanner rerun on the whole tree, and the plan. Its fixes are a PR of their own.

5. **The release:**
   - CHANGELOG.md, `Akku.manifest`'s version and comment, the clone lines of README.org and the
     quick start;
   - §6.2's steps 1 and 3 to 11;
   - **owner:** the merge, the tag and its signature, and the Release.

**Shared files:**

| File | Slices |
|---|---|
| the Makefile | the caller, in 1 (`check-floors`), 2 (the site section, `.PHONY`, `check-suites`' recipe), 3 (`check-ci`'s help) |
| `tests/test-manifest.sps` | 1c (the clone check), then the caller at 2's join (dependencies) |
| README.org | 1b, then 5 (its clone line) |
| `docs/quickstart.md` | 1b, then 5 |
| `docs/reference.md` | 1a, then the closing review |
| `src/chez-sodium.sls` | 1a (comments) |
| `site/pages.sls`, `tests/check-site.sps` | 2, from the plan's page list, which 1b's README must match |
| `Akku.manifest` | 2 (`depends/dev`), then 5 (the version) |
| `.github/workflows/ci.yml`, `packaging/debian-prereqs.txt` | 3 |
| §7's 15 files under `src/` and `tests/` | 4 |
| `.plans/` | the caller |

**PRs:** slices 0 to 5 and the closing fixes, seven, or six if slice 4 folds. They merge bottom up,
by squash, as M1 to M3's did.

## 10. Probes

**Run:**

- **P1. The generator, on chez-sodium's shape.**
  - **Where:** the host: the container has no cmark-gfm (P2). Chez 10.4.0 from `<home>`'s Guix
    profile, and the pin's cmark-gfm by absolute path. [render/run.sh](render/run.sh) copies
    `<sibling>`'s generator, `check-site` and its fetched chez-cmark-gfm tree into
    `build/m4-plan/a/render`, renames them, and renders [two stub pages](render/docs/)
    ([render/run.out](render/run.out)).
  - **The render:**
    - two pages written, each with `SITE_REF=main` and `v0.1.0`;
    - `../README.org#requirements` became `blob/main/…` and then `blob/v0.1.0/…`;
    - `reference.md#password-hash` became `reference.html#password-hash`;
    - the `scheme run` block rendered as `language-scheme`, its non-ASCII text kept, and the ⚠
      quote became a callout.
  - **`check-site`** failed on chez-sodium's README.org, by name: no `** Documentation`.
  - **README.org handed to cmark-gfm** comes out as Markdown's reading of Org: `* chez-sodium` a
    list item, `#+begin_quote` text, `[[…][…]]` literal. So README.org stays GitHub's alone, as in
    chez-sqlite3.
  - **The slug rule** gives 18 distinct anchors for the exports.
- **P2. The container's cmark-gfm** ([store.out](store.out)):
  - **The container has none of it:** no cmark-gfm in its profile's `lib/`, and no `tar`, `xz`,
    `curl`, `wget` or `python3`. It sees 63 store items.
  - **The host's store already holds what the pin gives**, read with `ls` and a profile's manifest
    file alone:
    - a chez-sqlite3 container profile at the same pin, `b532aa7`, uses
      `prn4x0x9…-cmark-gfm-0.29.0.gfm.13`, `qd17ddkv…-tar-1.35` and `h878s2cm…-xz-5.4.5`, each
      present;
    - its Chez, Valgrind and gcc-toolchain are the very store items chez-sodium's container uses;
    - the two `channels.scm` differ in a comment alone.
  - **What the manifest and the self-test need:** §2.3's rows.
  - **Inferred:** the new profile builds offline, from items already in the store.
- **P3. The docs' cost under the gate** ([cost/](cost/), §4.2): three runs. The first, with the
  `bytevector` slip, kept as [cost/run-1.out](cost/run-1.out).
- **P4'. The signature reader on `(chez-sodium)`** ([reference/](reference/), §3.2), rerun from the
  research directory, identical.
- **P5'. The comment scan** (§7).
- **P6'. The archive listings** ([archive.out](archive.out)).
- **P7'. The settings and CI's times,** by GETs ([settings.out](settings.out),
  [ci-times.out](ci-times.out)).
- **P8'. `test-check-ci` outside the gate:** 766 rows, 29 s.

**Read, not rerun:** chez-sqlite3's P5, Ubuntu 24.04's Chez running the generator (§5.3).

**Owed, each for its reason:**

- **A Guix dry run of the manifest with cmark-gfm, `tar` and `xz`.** The command would be
  `guix time-machine -C channels.scm -- shell --no-substitutes --dry-run -m <manifest>`. Not run:
  this pre-work runs no guix command that could fetch. Slice 2 runs the real thing, on the host.
- **The render in the container:** only once the manifest holds cmark-gfm, in slice 2.
- **`make site-deps`' real download:** it needs the network, on the host. The copied tree's
  archive's sha256 equals the lock's already.
- **P5 for chez-sodium:** the site job's and `pages.yml`'s steps in `ubuntu:24.04`, which needs
  apt and curl, so the network. Docker and a cached `ubuntu:24.04` are on the host. Slice 3.
- **The walk as a reader:** `ubuntu:24.04` with apt's libsodium and Chez from its tarball, so the
  network; then the development workstation. Slice 1.
- **GitHub's anchors for chez-sodium's headings:** a page must be on GitHub first. Slice 1's PR.
- **The live check, loopback and live:** it needs a release copy. The release.

## What surprised

- **`main` has no protection at all, and there is no ruleset.** chez-sqlite3's plan rested its
  required site check on protection that exists there (its S4).
- **The container can't render a page:** no cmark-gfm, `tar` or `xz`. The store already holds the
  pin's.
- **Four of 18 signature comments carry a trailing note** that the copied `test-reference` would
  make the reference repeat.
- **`(rnrs)` has no `bytevector`,** so a run block that builds one by that name raises.
- **A gated whole program costs about 4.9 s before it does anything.** As in chez-sqlite3, the
  children, not the hashes, dominate `test-docs`' time.
- **The comments are already clean:** no banned comment at all, and about 26 lines of decision
  numbers and brief references.
- **chez-sodium's `check-ci.sh` has rules chez-sqlite3's lacks**, the image step in every job and
  the timeout table, so its site and pages parts must be ported.
- **README.org's Status is three milestones stale,** and links into `.plans/`.

## Commands to rerun

From `<repo>`'s root.

```sh
sh .plans/research/m4-plan/a/render/run.sh            # on the host; compare render/run.out
scripts/guix-env sh .plans/research/m4-plan/a/cost/run.sh   # compare cost/run-3.out
scripts/guix-env sh -c '"$CHEZ" --libdirs src --program .plans/research/m4-plan/a/reference/probe.sps'
python3 -I .plans/research/m4-plan/a/comment-scan.py .     # compare comment-scan.out
scripts/guix-env sh -c '"$CHEZ" --libdirs src:tests:build/scheme-libs --program tests/test-check-ci.sps | tail -1'
git archive 527170d | tar -t | grep -c -E '^(\.plans/.|AGENTS\.md$)'   # 71
git archive d53e83c | tar -t | grep -c -E '^(\.plans/.|AGENTS\.md$)'   # 0
sha256sum ../chez-sqlite3/build/akku/dl/chez-cmark-gfm.tar.xz         # bb647e07…, the lock's
gh api repos/Kiyomi-Computation-Systems/chez-sodium/pages              # 404
gh api repos/Kiyomi-Computation-Systems/chez-sodium/branches/main/protection   # 404
gh api repos/Kiyomi-Computation-Systems/chez-sodium/rulesets           # []
gh api repos/Kiyomi-Computation-Systems/chez-sodium/environments       # empty
```

`store.out`'s commands read `/gnu/store` with `ls` and `grep` alone. The render and cost probes
write under `build/m4-plan/a/`.
