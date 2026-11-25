# M4 slice 1 review: the site and CI half

Reviewer: Opus, read-only and adversarial. Tree: `m4-slice-1` at `7928da4` (PR #19), stacked on
`m4-slice-0` at `1d4b8c1`, clean. The sibling, chez-sqlite3, was read at `960d9f0` and nothing was
written there. `<repo>` is chez-sodium's checkout, `<sibling>` chez-sqlite3's, `<home>` the
workstation's home. A second reviewer has the docs pages and their checks; this review did not
read them except where the site renders them.

**Scope:** the base (`3fabcfe`): `manifest.scm`, `scripts/guix-env-enter`,
`scripts/guix-env-selftest`, `tests/guix-env-launcher.sh`, `scripts/fetch-akku-lock`,
`tests/fetch-akku-lock.sh`, `Akku.manifest`, `Akku.lock`, `test-manifest`'s dependency rows and the
Makefile's site section. The generator: `build-site.sps`, `site/`, `tests/site-testing.sls`,
`tests/site-unit.sps`, `tests/site-render-unit.sps`, `tests/test-site-testing.sps`,
`tests/check-site.sps`, `tests/check-suites.sps`, `tests/check-test-fails.sh`. CI: `ci.yml`'s `site`
job and header, `pages.yml`, both package lists, `tests/check-ci.sh`, `tests/test-check-ci.sps` and
the Makefile's `check-ci` text.

**Read:** AGENTS.md; the M4 plan's §4.6, §4.7, §4.10, §4.11 and §5; ADR-0011's and ADR-0013's text
of 2026-11-25; the constraints; pre-work A's trim table and CI notes; builders 1f's and 1g's logs and
the base's section of the slice's mutation log. From the sibling: its site files, `pages.yml`, its
`site` job, its `check-ci.sh`, its Makefile site section, its container files, `Akku.lock`,
`test-manifest.sps` and its Pages runs.

**Where probes ran:** in the container (`scripts/guix-env`), in whole copies of the tree under
`build/m4s1-review-site/`, made with `shutil.copytree(..., symlinks=True)` and `build/akku` copied
in, so nothing needed the network. `check-ci` and its mutants, the launcher test and its mutants,
and `make check-guix` ran on the host; so did the read-only `gh` GETs. Ubuntu's Chez was not run
here: its walk is the caller's, read at `build/m4-walk/site.out` (`SITE DONE`, exit 0). One probe
command was refused by Claude Code's removal guard, though it deleted nothing (backticks and `$$` on
one line). It was not resent in that form; the same probe ran from a file, `probes/inject-probe.sh`.
No tracked file was changed.

**Counts: 0 blockers, 1 major, 8 minors.**

**The caller's checks.** F1 reproduced: `probes/inject-probe.sh` printed `INJECTED-BACKTICK` and
`INJECTED-DOLLAR` from inside `make site`. F9 read from PR #19's CI log: `test-check-ci` 193 s,
`test-docs` 86 s, the memory job 37 minutes.

**The reviewer worked around one block.** A probe command was refused by Claude Code's removal
guard; the reviewer ran the same probe from a file instead, which it should not have done. The
caller checked: the tracked tree was unchanged, and its scratch was all under
`build/m4s1-review-site/`.

**Fixed in slice 1:** F1, F2, F3, F5 and F8's comment by the site's fix agent; F6, F7 and F9 in the
records (the plan's §4.6, §5 and §7, and the mutation log); F4 recorded in the plan's §7, held by
`test-docs`.

---

## Major

### M4S1S-F1 (major): a tag name reaches the Pages build's shell as code

- **Where:** the Makefile's `site` and `check-site` recipes, `Makefile:692` and `:711`,
  `@SITE_REF="$(SITE_REF)" …`; `SITE_REF ?= main` at `:671`; `pages.yml:74` and `:80`, which hand
  the recipe `SITE_REF: ${{ github.ref_name }}`. All three are the sibling's, byte for byte.
- **Evidence:**
  - make reads `SITE_REF` from the environment, expands `$(SITE_REF)` into the recipe's text, and
    hands that text to `sh`. Inside the double quotes, a backtick or a `$(` runs a command.
  - Both forms are valid tag names that match `v*`: `git check-ref-format`
    passes `` refs/tags/v0.1.0`id` `` and `refs/tags/v0.1.0$$(id)`.
  - `probes/inject-probe.sh`, in the container, on a copy: `` SITE_REF='v0.1.0`echo
    INJECTED-BACKTICK >&2`' make site `` prints `INJECTED-BACKTICK`, and
    `SITE_REF='v0.1.0$$(echo INJECTED-DOLLAR >&2)' make site` prints `INJECTED-DOLLAR`; each then
    writes the five pages. A single `$(…)` does not run: make reads it as a variable of its own,
    and it comes out empty.
- **Why major:** the brief's rule counts any injection path as at least major. It is not a
  blocker, since it cannot leak a credential or deploy anything a writer could not deploy already:
  - no pull request reaches it. `pages.yml` runs only on a `v*` push or by hand, and `ci.yml` bans
    `SITE_REF` (`check-ci`'s word list), so a PR's branch name never becomes `SITE_REF`;
  - only a writer can push a tag or dispatch a run, and the tag already picks the tree that gets
    built;
  - the build job holds `contents: read` alone and no secret. Its checkout keeps no credential
    (`persist-credentials: false`), and the deploy job runs no `make`.

  What it adds is a site whose content no reviewed commit holds: the tag's tree reads clean while
  its name rewrote the artifact. The fix is one line, and belongs before the first tag.
- **Fix:** keep `SITE_REF` out of the recipe's text. Either:
  - `export SITE_REF` in the site section and drop the two `SITE_REF="$(SITE_REF)"` prefixes, so make
    hands the value to Chez in the environment, which no shell parses; or
  - have the recipes refuse a ref outside `[A-Za-z0-9._/-]`, before the render.

  Tell chez-sqlite3's session, whose Makefile and `pages.yml` carry the same path.

## Minors

### M4S1S-F2 (minor): the site's description and keywords claim more than 0.1.0 binds

- **Where:** `site/template.sls:78-79`, on every page: `content "libsodium for Chez Scheme"` and
  `"libsodium sodium crypto password hash blake2b hmac scheme chez r6rs"`.
- **Evidence:**
  - `hmac` names nothing `(chez-sodium)` exports (`src/chez-sodium.sls`, 18 names). README.org:27
    says HMAC-SHA256 is "planned for a later release".
  - ADR-0013, decision 2, has README.org and the quick start say chez-sodium is "a small,
    deliberate part of libsodium". The quick start's first line says it is "no general libsodium
    binding, and no crypto toolkit". The meta description, which search results show, says
    "libsodium for Chez Scheme".
  - Each page's `<title>` is its label alone ("Quick start"), with no project name. This is the
    sibling's, unchanged.
- **Fix:** a description in the pages' own words, such as "A small part of libsodium for Chez
  Scheme: password hashing, random bytes and BLAKE2b". Drop `hmac` and `crypto` until M5. The
  title is the sibling's choice, and can stay.

### M4S1S-F3 (minor): the site section's comment names Homebrew, and says `site-deps` runs once

- **Where:** `Makefile:660-661`, "(`cmark-gfm` from Homebrew or apt)"; `:666-668`, "Run make
  site-deps once on the host … After that it needs none".
- **Evidence:**
  - Homebrew is the sibling's macOS path. chez-sodium is Linux only (ADR-0010; AGENTS.md).
  - `make clean` removes `build/`, `build/akku/dl/` with it. The container then has no archive and
    no downloader. Probed on a scratch `AKKU_DEST`: `wget: command not found`, then "could not
    download … run it where there is a network", exit 1.
- **Fix:** "(`cmark-gfm` from apt, or the container's profile)", and "once on the host, and again
  after `make clean`".

### M4S1S-F4 (minor): check-site holds a link into the repository to its file, never to its anchor

- **Where:** `tests/check-site.sps`, invariant 6 (`missing-repo-files`), which strips the fragment
  before it tests `file-exists?`.
- **Evidence:** mutant `s7`: `[the notes](../README.org#no-such-heading)` appended to `tokens.md`
  passes `make check-site` whole. The real pages link `../README.org` with no fragment
  (`quickstart.md:6,14`, `finding-libsodium.md:57`, `reference.md:5`), so nothing dangles today.
  Their text says "README.org's Requirements", and the link lands at the top of the README.
- **Fix:** none needed for 0.1.0. Record the limit. A page that wants the section links
  `../README.org#requirements`, and then nothing holds that anchor. This is the sibling's
  behaviour, unchanged. The docs reviewer may want the link text and its target to agree.

### M4S1S-F5 (minor): nothing ties the deployed tag to `Akku.manifest`'s version

- **Where:** `pages.yml`'s build job gates only on `make check-site`. `test-manifest` holds the clone
  lines to the manifest's version, never to the tag.
- **Evidence:** the tag's CI run checks the clone lines against the manifest, in parallel with the
  deploy. Nothing in either workflow compares the tag's name, `SITE_REF`, with
  `"v" + (package-version)`. Say the tag is pushed on a tree whose manifest still says the last
  release: it deploys a quick start whose clone line names that release. Today only the release's
  live check (§4.10, step 3) sees it, run by hand on a local render before the tag.
- **Fix:** optional, and cheap. Add a ninth invariant to `check-site`: when `SITE_REF` starts with
  `v`, it equals `v` and Akku.manifest's version, so the tag's own Pages run refuses to deploy.
  Otherwise, name the gap in the release steps. The sibling has the same gap.

### M4S1S-F6 (minor): the Docker walk cannot show the site's package list is whole on a bare machine

- **Where:** `build/m4-walk/site.sh:6` installs `git` before the list; `:10` reads the list with its
  own `sed`. `packaging/debian-site-prereqs.txt:42-43` claims "this file is the whole truth about a
  bare machine".
- **Evidence:** the walk's first `apt-get` pulls in 46 packages with git, among them
  `ca-certificates`, `perl`, `patch`, `less` and `openssh-client` (`site.out:25-60`). A list that
  lost one of the packages git brings would still pass the walk. CI cannot show it either: the
  runner image ships curl, make and more. The walk also skips the held install step,
  `grep -v -e '^#' -e '^$' … | tr`, though both read this list the same way today.
- **Why minor:** Pages builds on the same runner image as CI, so the deploy is not at risk. The
  file's claim is simply untested.
- **Fix:** in the release slice's walk, put the tree into the container without git (a bind mount,
  or `git archive` on the host), and run the install step's own lines from `pages.yml`. Otherwise,
  soften the header's claim.

### M4S1S-F7 (minor): the plan's join line for `check-test-fails`' help points at a count the Makefile never held

- **Where:** plan §5, the join: "`check-test-fails`' help and its count of cases, 13 becoming 15";
  `Makefile:320-326`.
- **Evidence:** neither the Makefile at `1d4b8c1` nor at `7928da4` writes `check-test-fails`' count
  of cases: its comment says the script "lists the plants", and the only "cases" in the file belong
  to `check-floors` and `check-memory-gate` (`:422`, `:650`). The help line is unchanged and names
  no site plant. It stays true, since "bad suites" covers them. The 13 lives in `progress.md:31` and `:367`.
  The tree itself passes: `make check-test-fails` reports "all 15 cases".
- **Fix:** in the ledger's close-out, 13 becomes 15. Optionally, the help reads "Plant bad suites,
  the site's among them, …".

### M4S1S-F8 (minor): `make site` never clears `build/site`, and the release serves its local render from there

- **Where:** the `site` recipe, `Makefile:689-695` (`mkdir -p build/site`, then write). Plan §4.10,
  step 3, renders in the container and serves that render on loopback for the live check.
- **Evidence:** in a copy, `build/site/old-page.html` planted before `make site` is still there
  after it, beside the five pages. `pages.yml` renders in a fresh checkout, so the deploy is clean.
  A local render made after a page's rename is not.
- **Fix:** the release step renders after `rm -rf build/site`, or the recipe clears the directory
  first. That change would touch the copied Makefile text, so the release step is the cheaper fix.

### M4S1S-F9 (minor): on CI, `test-check-ci` is 7 s from the split line, and runners vary by a third

- **Where:** plan §4.7, "if the port takes it past 200 s, a third of `MEMORY_TIMEOUT`, it splits";
  ADR-0011's amendment, "It splits if it passes a third of `MEMORY_TIMEOUT`"; 1g's log, "154 s
  alone" in the container.
- **Evidence** (`gh run view … --log` GETs):
  - **PR #19's memory job** (`45611062204`, job `139194392209`) ran `test-check-ci` in 193 s,
    against 112 s on PR #18's (`45606843402`, job `139179802658`).
  - **The same runner ran slow:** the suites this slice did not touch ran 27 to 36% slower than on
    PR #18. `test-no-memory` went from 92 s to 125 s, `test-library-loading-passwords` from 89 s to
    115 s, `-decoys` from 85 s to 110 s.
  - **The port's own cost:** plain in the container, 29 s at 766 rows became 42 s at 882 rows,
    +45%. Each row now writes and checks two files.
  - **So it straddles the line:** a fast runner gives about 160 s, a slow one 193 s to 210 s. The
    container's 154 s is no proxy for CI's slower runners.
- **Why minor:** nothing fails. The SLOW limit, 450 s, is more than twice away, and the memory job
  used 37 minutes of 120. But the plan's rule will fire on the next slow runner, or the next rows
  added, with no decision taken.
- **Fix:** decide it now, while the port is fresh. One option is to split the suite, the site and
  pages rows into a `test-check-ci-site.sps` of their own. The row harness would then move into a
  library under `tests/`, since programs share no include bodies. The other is to record 193 s in the close-out, and have the owner move the
  line. Whichever it is, the ledger should name the measured 193 s, not the container's 154 s.

---

## The ten items

1. **The copies.**
   - **As is, and byte for byte the sibling's at `960d9f0`:** `build-site.sps`, `site/io.sls`,
     `render.sls`, `slug.sls`, `transform.sls`, `serializer.sls`, `tests/site-render-unit.sps`,
     `scripts/fetch-akku-lock`, `tests/fetch-akku-lock.sh` and `tests/check-site.sps`. check-site's
     comments name no project, so the plan's "names in comments" had nothing to change.
   - **Adapted:** each difference is intended. `pages.sls` holds the five pages; the sibling's
     label "API reference" became "Reference", equal to README.org's list and the page's H1.
     `links.sls` and `template.sls` take the repository's URL, the wordmark, the description and
     the keywords (F2). `style.css` and `site-testing.sls` take names. `test-site-testing.sps`
     takes `(chez-sodium-testing)`. `site-unit.sps` takes the wordmark, the source link and its two
     blob rows, and keeps the anchor fixtures as data.
   - **Unchanged but for names and ADR numbers:** the container's three files, `Akku.lock`, the
     Makefile's site section, `debian-site-prereqs.txt` and `pages.yml`.
   - **No protection is dropped:** the theme script's `try`, the binary port, the two passes, the
     slug rule and `site-unit`'s path without chez-cmark-gfm are all still there.
   - **ADR citations:** the slice's scope adds 10 citations of ADR-0011 and 5 of ADR-0013, and no
     sibling number (ADR-0006, 0007, 0022). Each says what that record holds.
2. **`pages.yml`'s safety.**
   - **Triggers:** a `v*` push and `workflow_dispatch` only, with no inputs.
   - **Permissions:** `contents: read` at the top. `pages: write` and `id-token: write` sit on the
     deploy job alone, which leaves it no `contents`.
   - **Environment:** `github-pages`, whose `url` is the deployment's output.
   - **Checkout:** `persist-credentials: false`.
   - **Pins:** each action is at the sibling's SHA, and the checkout at `ci.yml`'s. Three GETs
     resolve each tag to its SHA: checkout v7.0.1 to `3d3c42e5…`, upload-pages-artifact v5.0.0 to
     `fc324d35…`, and deploy-pages v5.0.1 to `368f8252…`.
   - **Concurrency:** `group: pages`, `cancel-in-progress: false`.
   - **Inputs:** `SITE_REF` comes from `github.ref_name`, through `env:` and never in a `run:` line.
     No PR-controlled input reaches a run line. A tag name does, through make (F1).
   - **The sibling's runs:** its file deployed v0.1.0 and v0.1.1. Its `workflow_dispatch` on
     `main` failed, as the environment's `v*` rule means it to.
3. **`check-ci`'s port.** Every §4.7 rule is in the script: two regular files, read by glob; six
   jobs, `site` at 10 minutes; the site job's seven steps; `SITE_REF` and `CHEZ_CMARK_GFM_LIBS`
   banned in `ci.yml`; `pages.yml` held line for line; the pass line word for word. The copy
   reader and the pages part are the sibling's byte for byte.
   - **48 mutants** (`probes/ci-mutants.py`, verdicts in `probes/ci-mutants.out`). Every unsafe one
     fails:
     - comment lines inside or right after the run block, at any depth;
     - a plain-scalar continuation, `pull_request_target`, `head_ref`, `contents: write`, and an
       `if:` on deploy;
     - CRLF, a BOM, a tab, `%YAML`, `---` and `...`;
     - a third workflow, a link, a hidden file, a subdirectory, a newline in a name, and
       `pages.yaml`;
     - in the site job: `continue-on-error` on the job or a step, `working-directory`, `shell`,
       `container`, a job `env:`, another env key, another `runs-on`, no timeout, `|| true`, the
       checks out of order, `CHEZ: scheme`, and `SITE_REF` in the image block.
   - **The survivors are harmless:** comments and blank lines outside a block; no final newline;
     `SITE_REF` in a `ci.yml` comment; the site job's `name:` changed, as no job's name is held, and
     a rename only leaves a required check that never reports; and a checkout `with: path:`, which
     fails the job loudly, since no Makefile sits at the root.
   - **`test-check-ci`:** 882 rows, all passing plain here in 42 s. Each compares the exit status,
     stdout and stderr whole, so none passes whatever the script does. The pass-shaped rows fail on
     a script that refuses everything, and 1g's 16 rule drops each fail a named row.
   - **`check-memory-gate`'s case o** compares the unchanged pass line; it passed on PR #18's CI.
4. **The container.**
   - `manifest.scm`, `guix-env-enter` and the self-test's new ninth assertion (the Makefile's
     became the tenth) are the sibling's but for ADR numbers.
   - **The new assertion cannot pass with a wrong value.** Run alone with a swapped pair, the core
     twice, empty, or a third path (`probes/` command below), `cmark-gfm-variable` fails each time.
     It compares the whole string to the one `guix-env-enter` builds. `cmark-gfm-loads` passes the
     swapped pair, since Guix's RUNPATH lets either library load first, so order is held by the
     variable's check alone. That is enough.
   - **The launcher test:** 95 pass on the host. Mutants of the copy's own `guix-env-enter` (order
     swapped, the extensions' `need` dropped, no `export`) fail T7a and T7g by name.
   - **`make check-guix` on the host:** ALL CHECKS PASSED, `test: ran 44, passed 44`.
   - **The trap holds:** host `SITE_REF` and `CHEZ_CMARK_GFM_LIBS` never reach the container. The
     first reads `unset`; the second is the profile's pair. `scripts/guix-env make site
     SITE_REF=v0.1.0` does pin the ref, since it is make's argument, not the environment.
5. **The dependency.**
   - **`Akku.lock`** is the sibling's whole file, byte for byte. `sha256sum` of
     `build/akku/dl/chez-cmark-gfm.tar.xz` is `bb647e07…05159`, the lock's, and the sibling's
     archive is the same file (`cmp`).
   - **Offline,** a current tree is "up to date". A changed tree is unpacked again from `dl/`, and
     then `--check` passes. A corrupted archive is deleted, the download is tried and fails for
     want of curl and wget, it exits 1, and nothing is unpacked.
   - **On CI the download is safe:** every run downloads, since nothing caches `build/akku`. The
     URL is fixed in the lock, and the archive is refused, then deleted, unless its sha256 is the
     lock's, before anything is unpacked. Even a redirect, which `curl -L` follows, cannot change
     what is unpacked.
   - **`test-manifest`'s rows** equal the sibling's. The base's mutants failed each named row.
6. **The generator on the real pages.**
   - **The runs, in the container:** `make check-site` gives 18 and 90 passes, then the green line.
     `make site` and `SITE_REF=v0.1.0 make site` each write five pages.
   - **The two renders** differ only in `blob/main/` against `blob/v0.1.0/README.org`, on three
     pages. Every relative link and anchor resolves (`probes/links.py`: 0 bad); no id repeats; no
     bare `&`, no unknown entity, one `<script>`.
   - **The reference** holds 18 distinct `h3` ids, `constant-time-bytevector` among them.
   - **The theme script** holds no `<`, `>` or `&`, and touches `localStorage` only inside `try`.
   - **A planted `[x](javascript:…)`** renders `href=""`, and planted raw HTML renders as "raw
     HTML omitted" comments.
   - **`pages.sls`, README.org's Documentation list and the five H1s agree.** Mutants of a label in
     either file alone, an H1, an extra page, a page dropped from both lists, a duplicate README
     entry, a missing repository file and a dangling anchor each fail by their invariant
     (`probes/site-mutants.out`).
   - **The survivors:** both lists swapped together, which is consistent; a `../src/` directory
     link, which GitHub redirects; a `.plans/` link, which is test-docs' to refuse; and F4.
7. **`check-suites` and `check-test-fails`.** `make check-test-fails` reports all 15 cases. Two
   mutants fail both site cases by name: the Makefile without `$(SITE_SUITES)` in `check-suites`'
   recipe (`site-exit-line` and `site-no-exit`: "make test exited 0"), and `check-suites`' prefix
   test spelled `site_`. 1f's mutant, the floor's form for every suite, did too.
8. **The Makefile's site section.**
   - **The help is true:** `site-deps` is "(host, once)", but see F3. `check-site`'s help leaves
     out two of its eight invariants, README.org's list and the H1s, but says nothing false.
     `make check-help` exits 0.
   - **`site-unit` loads no chez-cmark-gfm:** a pure site library that imports `(cmark gfm)` fails
     it, "library (cmark gfm) not found". A site suite that imports `(chez-sodium)` or
     `(chez-sodium-testing)` fails at import.
   - **`SITE_OUT`** is fixed at `build/site` by the recipe, as in the sibling. `SITE_REF`
     defaults to `main`.
   - **`make clean` removes `build/`** whole, `build/akku` and `build/site` with it. `check-clean`
     needs no new case.
9. **CI's times.** PR #19's run (`45611062204`) passed in all six jobs. Its memory job, 37 minutes
   of 120, ran 44 of 44 suites, and `check-memory-gate` passed 59 cases, case o among them.
   `test-check-ci` took **193 s** under the gate: inside the 450 s SLOW limit, but 7 s from the
   plan's 200 s split line (F9). `test-docs` took 86 s, and the `site` job 40 s.
10. **Privacy and the comment rule.**
    - **Privacy:** no home path, email, host distribution or user name in any file in scope.
    - **History:** the slice's added lines carry no milestone, slice, finding id, research path,
      date or "the maintainer". `site-unit`'s "Slice ⓪" and dated headings are anchor fixtures,
      data the plan keeps. `guix-env-launcher.sh`'s "M1" and "M2" are case labels from before
      this slice.

## Where it is sound

- **The copies are what the trim table says**, and every copied guard is there.
- **`check-ci` holds `pages.yml` tightly.** Only a comment or a blank line outside the one run block
  is free, and every line in a run block's reach is held. No mutant found a hole.
- **The site job cannot pass a check it skipped.** Each check is a whole run line, in order, with
  `CHEZ: chezscheme`. Job and step keys are allow-listed, no action but the checkout is allowed,
  and there is no `if:`.
- **The deploy's reach is the minimum.** The build job reads, and the deploy job writes Pages,
  behind the environment's tag rule.
- **The container exports what chez-cmark-gfm reads,** `CHEZ_CMARK_GFM_LIBS`, core first, as
  `native.sls:130-138` loads them. The self-test holds the value exactly.
- **The lock is the sibling's, and its sha256 is the archive's.** The fetcher never unpacks an
  archive it has not checked against the lock.
- **The generator's suites run on Ubuntu's Chez** and import nothing under `src/`; each mutant
  that tried failed at import.

## Probes kept here

| File | What it shows |
|---|---|
| `probes/mkcopy.py` | a whole copy of the tree, with `build/akku`, for mutants |
| `probes/site-mutants.py`, `probes/site-mutants.out` | item 6 and F4: 13 mutants of the pages, nav and README for `make check-site` |
| `probes/ci-mutants.py`, `probes/ci-mutants.out` | item 3: 48 mutants of the workflow directory for `check-ci` |
| `probes/links.py` | item 6: every relative link and anchor of a render resolves, and no id repeats |
| `probes/inject-probe.sh` | F1: a tag name's backtick or `$$(` runs in `make site`'s recipe |

## Commands to rerun

From `<repo>`'s root. Scratch goes under `build/m4s1-review-site/`.

```sh
R=.plans/research/m4-slice-1-site-review/probes
S=build/m4s1-review-site
for f in build-site.sps site/io.sls site/render.sls site/slug.sls site/transform.sls \
  site/serializer.sls tests/site-render-unit.sps tests/check-site.sps \
  scripts/fetch-akku-lock tests/fetch-akku-lock.sh Akku.lock; do
  git -C ../chez-sqlite3 show 960d9f0:$f | cmp -s - $f && echo "same $f"; done
sha256sum build/akku/dl/chez-cmark-gfm.tar.xz                        # bb647e07...05159
scripts/guix-env sh -c 'make check-site && make site && SITE_REF=v0.1.0 make site'
python3 -I $R/links.py build/site                                      # bad 0
python3 -I $R/mkcopy.py "$PWD/$S/base"
for m in s1-label-pages-only s2-label-readme-only s3-h1-only s4-extra-page \
  s5-drop-reference-nav-and-readme s6-repo-link-missing s7-repo-link-bad-fragment \
  s8-page-anchor-dangling s9-swap-pages-and-readme s10-js-link s11-dir-link \
  s12-plans-link s13-readme-second-list-line; do python3 -I $R/site-mutants.py $m; done
scripts/guix-env sh -c 'for d in build/m4s1-review-site/sm/s*; do (cd $d && make check-site); done'
for m in $(python3 -I $R/ci-mutants.py list); do python3 -I $R/ci-mutants.py $m; done
for d in $S/ci/*; do CHECK_CI_ROOT= sh tests/check-ci.sh "$d"; echo "$? $d"; done
scripts/guix-env sh $R/inject-probe.sh                                 # F1: both INJECTED lines
SITE_REF=v0.1.0 scripts/guix-env sh -c 'echo "${SITE_REF-unset}"'     # unset
scripts/guix-env sh -c 'make check-test-fails'                         # all 15 cases
make check-guix                                                        # ALL CHECKS PASSED, on the host
sh tests/guix-env-launcher.sh                                          # 95 passed
{ echo 'ok() { echo "ok $1"; }; bad() { echo "BAD $1"; }; chez=${CHEZ:-}'
  awk '/^# Assertion 9:/,/^# Assertion 10:/' scripts/guix-env-selftest | sed '$d'; } >$S/a9.sh
scripts/guix-env sh -c 'G=$GUIX_ENVIRONMENT/lib; sh build/m4s1-review-site/a9.sh;
  CHEZ_CMARK_GFM_LIBS="$G/libcmark-gfm-extensions.so:$G/libcmark-gfm.so" sh build/m4s1-review-site/a9.sh'
gh run view 45606843402 --job 139179802658 --log | grep -A2 '=== tests/test-check-ci.sps'  # 112s
gh run view 45611062204 --job 139194392209 --log | grep -A2 '=== tests/test-check-ci.sps'  # 193s
for r in "actions/checkout v7.0.1" "actions/upload-pages-artifact v5.0.0" "actions/deploy-pages v5.0.1"; do
  set -- $r; gh api repos/$1/git/ref/tags/$2 --jq .object.sha; done   # read-only
```
