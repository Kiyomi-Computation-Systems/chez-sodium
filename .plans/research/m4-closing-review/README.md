# M4 closing review: the docs, the site and the release, whole

**Reviewer:** Opus, read-only and adversarial.

**Tree:** `m4-slice-1` at `b34b7ee` (PR #19), stacked on `m4-slice-0` at `1d4b8c1` (PR #18), clean.
The milestone is `git diff d53e83c..b34b7ee`, 243 files. `<repo>` is chez-sodium's checkout,
`<sibling>` chez-sqlite3's (`960d9f0`, read only), `<home>` the host's home.

**Read:**
- AGENTS.md whole; the M4 plan whole; ADR-0013; the 2026-11-25 amendments of ADR-0006, 0009, 0010,
  0011 and 0012; the brief's changed lines and its §4.2, §5 and §6.3; the constraints, the ledger's
  Now, "Answered for M4" and "Owed to M4", and the traps;
- the slice 0 review, both slice 1 reviews with the caller's notes, the slice 1 mutation log and the
  builders' logs 1a to 1g; pre-work sets A and B;
- the pages, README.org, the contributor files, `src/chez-sodium.sls` and the verbs' libraries;
  `test-reference`, `test-docs`, `test-manifest`'s clone check, `check-floors` and `floors.sls`'
  docs inputs, `check-site`, `site/links.sls`, `build-site.sps`, `site-testing.sls`,
  `test-site-testing`, `check-suites`' and `check-test-fails`' diffs, `pages.yml` and `ci.yml`'s
  `site` job;
- from the sibling: its M5 closing review and live check, its CHANGELOG and quick start, and its
  release notes (`.plans/research/m5-release/`);
- Techo's two briefs, and its slice 3 and 3b plans where they name chez-sodium.

**Where the probes ran:**
- in the container (`scripts/guix-env`, Chez 10.4.0 threaded), the profile's libsodium 1.0.22,
  and the floor's build at `build/slice5/prefix-1.0.18` through set B's `both.sh`;
- 21 whole copies under `build/m4-closing-review/mut/`, made by [mutants.py](mutants.py) with
  `shutil.copytree(..., symlinks=True)`, `build/akku` copied in and a `scheme-libs` link to the
  real `build/scheme-libs`; `make deps` in a copy links the copy's own `vendor/chez-srfi`;
- `make test-memory` on four M4 suites in one of those copies, its logs inside it;
- pages.yml's build steps offline under Docker, `--network none`, in a local image of
  Ubuntu 24.04.5 that holds Ubuntu's `chezscheme` 9.5.8, `cmark-gfm`, `make` and `xz-utils`
  ([ubuntu-site.sh](ubuntu-site.sh));
- the render the task names, `scripts/guix-env sh -c 'rm -rf build/site && SITE_REF=v0.1.0 make site'`,
  which wrote `build/site`;
- on the host: the comment scanner, the privacy grep, the anchor check and ten read-only `gh`
  calls (the rate limit read 4792 left at the first).

**Refused or blocked:** two, and each line of work stopped there.
- A foreground `sleep 60` before reading a local log was blocked by the harness. The run it waited
  for, a background one, finished on its own.
- A background loop that would read PR #19's run at `b34b7ee` with `gh run view` every two minutes,
  until its memory job ended, was denied by the auto-mode classifier. So this review has not read
  that job's times, `test-check-ci`'s among them: the job was in progress at 13:26 UTC, its five
  other jobs green (item 4).

No command was rerun another way, and no tracked file was changed.

**Counts: 0 blockers, 3 majors, 11 minors.**

**The caller's checks.** F1 reproduced by grep: the constraints, brief §5, ADR-0006, ADR-0009, the
ledger and three comments of `password-verbs.sls` each still said every change another thread
makes is refused. F2: `reference.md:236` read as quoted. F3: the "All together" program's dummy was
made from a password the page printed.

**The reviewer stopped at two blocks,** a foreground `sleep` and a polling loop the auto-mode
classifier refused, and reran neither. The caller read the CI times it could not: PR #19's run on
`b34b7ee` passed all six jobs.

**Fixed in M4's closing PR,** by four fix agents on disjoint files and the caller:
- the pages: F2, F3 (a random dummy, and the unknown name shown refused), F12;
- `test-docs`: F8;
- the site and the Makefile: F5, F9, F10, F14's two lines;
- comments and the synopsis: F1's comments, F14's synopsis and header;
- the records, by the caller: F1's records, F4 to F7, F11, F13, and F14's ADR-0011 line.

---

## Majors

### M4C-F1 (major): changed-during-call's reach, corrected on the pages, is still uncorrected in the records and in three source comments

- **Where:**
  - `.plans/global-constraints.md:136-139`, which binds every brief: "A password or hash another
    thread changed during the call is refused after the section ... `password-needs-rehash?`
    answers `#t` for a hash changed during its call";
  - brief §5, `:373-374`, and §4.2, `:253-254` ("even one another thread changes during the call,
    which answers `#t`");
  - ADR-0006's M3 amendment, `:220` and `:225-229`; ADR-0009's, `:137-139`;
  - the ledger's "Owed to M4", `progress.md:197`: "a password changed by another thread during the
    call is refused", under a preamble that says the bullets are stated as the plan's §3 states
    them;
  - `src/chez-sodium/private/password-verbs.sls:146-148`, `:184-186` and `:215-217`.
- **Evidence:**
  - The writers see only two changes: a hash character outside U+0021 to U+007E
    (`native.sls:427`), and a password whose UTF-8, as read during the write, overruns or falls
    short of the count taken before the section (`:469`, `:495`). A change that keeps every hash
    character in range, or keeps the total UTF-8 length, is written as it stood mid-change.
  - `same-width-race.sps` rerun here at both releases: `(answered #f #f)` in 10 of 10, a hash
    that verifies against neither string, and nothing refused ([same-width-race.out](same-width-race.out)).
  - Slice 1's docs review found this (M4S1D-F1). Its fix corrected `passwords.md`,
    `reference.md` and the plan's §3 only. AGENTS.md already says it right.
- **Why major:** a false record, in the file every brief inherits. A builder told "any change is
  refused" writes a test or a page that promises it, which the docs review showed is a false
  safety claim.
- **Fix:** restate each as AGENTS.md and `passwords.md` do: a change is refused when the writer sees
  it, a hash character out of range or a password whose UTF-8 length changes; any other change is
  hashed or checked as the string stood mid-change. For needs-rehash: a change the writer sees
  answers `#t`; any other is read as it stood. Rewrite the three comments, and strike or restate
  the ledger's bullet.

### M4C-F2 (major): the reference's needs-rehash entry keeps the first wording's frame, which ADR-0009's amendment withdrew

- **Where:** `docs/reference.md:236-237`: "Answers `#f` only when the hash reads as one
  `password-hash` makes at the limits".
- **Evidence:**
  - Set B's `other-tag.sps`, rerun at both releases ([other-tag.out](other-tag.out)): an argon2id
    hash with a 16-byte tag, 72 characters, which `password-hash` never makes (it makes 93 at
    these limits), verifies `#t` and answers `#f`.
  - ADR-0009's amendment: "So decision 1's first wording overstated it. 'Not what `password-hash`
    would make now' read wider than decision 2's rules". The reference's sentence is that wording's
    converse. `passwords.md:99-102` says the rule as amended; the reference, which readers consult
    as the contract, does not.
  - Its next paragraph covers a damaged hash only, not an imported hash of another shape.
  - No check reads this prose: mutant `ref-needs-rehash-first-wording`, which makes the entry say
    needs-rehash is a check that a hash is intact, passes `test-docs` and `test-reference`.
- **Why major:** a false page statement about the verb the owner's Q1 settled, on the page a reader
  takes as the contract.
- **Fix:** "Answers `#f` only when the hash was made with today's algorithm and parallelism at the
  limits, which default to `'interactive`, and libsodium reads it. Everything else is `#t` ...".
  Keep the paragraph after it.

### M4C-F3 (major): the login program's refusal of the dummy hash is held by nothing, and the dummy's password is printed on the page

- **Where:** `docs/passwords.md:147` and `:158`, "All together":
  `(define no-account (password-hash "no one's password" limits))` and
  `((eq? hash no-account) 'refused)`.
- **Evidence:**
  - Mutant `all-together-no-dummy-refusal` removes line 158. `test-docs` passes, 152 of 152. No
    row of the program tries the dummy's own password, so its output is the same.
  - Without that line, `(log-in! "cal" "no one's password")` verifies `#t` against the dummy and
    answers `logged-in` for a name with no account: a reader's version that opens a session there
    opens one for an account that does not exist, to anyone who reads the page.
  - The fix is shown to work: mutant `all-together-dummy-row` adds
    `(show (log-in! "cal" "no one's password"))` and `refused` to the text block, and passes; mutant
    `all-together-dummy-row-mutant`, the same with line 158 removed, fails by name: "docs/passwords.md:137:
    the whole program, run as written, prints the text block after it, line for line"
    ([mut-run.out](mut-run.out)).
  - Techo's plan makes its stand-in "the hash of 32 random bytes as hex" (`techo/.plans/2026-11-24-slice-3b-login.md`,
    L5). The page teaches a known literal.
  - Two lesser lines are held by nothing either: the login run block's `guard` around the rehash
    (`login-run-no-guard`), and `key-owner`'s length check in `tokens.md`, which its bullet explains
    (`tokens-no-length-check`). Both pass 152 of 152.
- **Why major:** the safety line of the pattern Techo's login copies can be dropped without any check
  noticing, as the slice 1 docs review's M4S1D-F2 found for the fragments, and its fix made the
  pattern run but did not exercise this branch. ADR-0013 rejected "unrun password fragments, which
  would leave the examples a reader copies unchecked".
- **Fix:** make the dummy's password random, `(define no-one (hex-of (random-bytes 16)))` or the like,
  so the page teaches what Techo does; add a row that tries it on a name with no account, stated
  `refused`. One sentence: "make the dummy from a password nobody knows".

---

## Minors

### M4C-F4 (minor): README.org no longer links the docs site, and no release step puts the link back

- **Where:** README.org's Documentation section; ADR-0013, decision 2 ("the pages and the site");
  the plan's §4.1, `:255` ("Documentation: the five pages and the site"); §4.10.
- **Evidence:** `git diff 7928da4..b34b7ee -- README.org` removes "The same pages are on the [[…github.io/chez-sodium/][docs
  site]]", the docs review's M4S1D-F11 fix for a link that 404s until the tag. The records were not
  changed, and §4.10 names no step that adds it back. Nothing else in README.org or `docs/` names
  the site's address.
- **Fix:** a release step: put the link back in the release PR (the tag deploys minutes after the
  merge), or in a follow-up once the live check passes. Say which in §4.10, and say in §4.1 that
  README.org links the site from the release.

### M4C-F5 (minor): pages.yml deploys a `v*` tag that is not `vX.Y.Z` whatever the manifest says; the plan says no disagreeing tag can deploy

- **Where:** the plan's §4.6, `:452-454`: "a release tag's version is `Akku.manifest`'s, so a tag that
  disagrees with the manifest cannot deploy"; `site/links.sls`, `release-tag-version`;
  `pages.yml`'s `tags: ["v*"]`, and the environment's planned tag rule `v*`.
- **Evidence:** at the manifest's 0.0.0, in the container, `SITE_REF=v0.1.0 make check-site` exits
  2, naming invariant 9; `SITE_REF=v0.1.0-rc.1 make -s check-site` and `SITE_REF=v0.2 make -s
  check-site` each print the green line and exit 0 (mutant `release-rc-tag`). Both are `v*` tags,
  so the push would build and deploy a site whose clone lines name `main`.
- **Why minor:** only a writer can push a tag, and check-site's own comment says "Any other ref is
  not held". The plan's sentence overstates it.
- **Fix:** have invariant 9 refuse a ref that begins with `v` and is no release tag, or narrow
  `pages.yml`'s trigger and the environment's rule to `v[0-9]*.[0-9]*.[0-9]*`; or write the limit
  into §4.6.

### M4C-F6 (minor): the release's local render never runs check-site, so the ninth invariant first runs at the tag

- **Where:** the plan's §4.10, step 3, `:552`: `scripts/guix-env sh -c 'rm -rf build/site &&
  SITE_REF=v0.1.0 make site'`.
- **Evidence:**
  - Run here as the task names it, at the manifest's 0.0.0: `make site` writes the five pages and
    exits 0. `make site` depends on `site-deps` alone (`Makefile:694`); only `check-site` refuses,
    and only `pages.yml` runs it with `SITE_REF` set, after the tag is pushed.
  - The plan's Docker run of pages.yml's build (§4.7) was slice 1's, before invariant 9 existed. No
    record runs invariant 9 on Ubuntu's Chez, the Chez pages.yml uses.
  - Run here, offline, on Ubuntu's Chez 9.5.8 ([ubuntu-site.out](ubuntu-site.out)): on the release's
    edits (mutant `release`) `SITE_REF=v0.1.0 make check-site` is green and the render's clone line
    is `--branch v0.1.0`; on the unbumped tree it exits 2 with invariant 9's message. So the gate
    works today; nothing in the steps shows it on the release's own tree before the tag, and a
    fault there would cost a tag (§4.10, step 5).
- **Fix:** step 3 runs `SITE_REF=v0.1.0 make check-site` before `make site`, in the container and once
  more on Ubuntu's Chez (an `ubuntu:24.04` with `packaging/debian-site-prereqs.txt`), as
  [ubuntu-site.sh](ubuntu-site.sh) does.

### M4C-F7 (minor): the tag's clone warns "is not a commit!", which the sibling had to explain in 0.1.1, and the release plan does not

- **Where:** the plan's §4.10, steps 1 and 9; `docs/quickstart.md`, "Get it".
- **Evidence:** `<sibling>/.plans/research/m5-release/README.md`, step 10: "The clone printed `warning:
  refs/tags/v0.1.0 cfaf268… is not a commit!`", git 2.54's warning for any annotated tag given to
  `--branch`. The sibling's 0.1.1 entry, under Changed, adds to its quick start: "Git may warn that
  the tag 'is not a commit!', and say you are in a 'detached HEAD' state. Both are expected"
  (`<sibling>/docs/quickstart.md:21-23`). chez-sodium's tag is annotated too (ADR-0013, decision 1).
- **Fix:** the release slice adds the same two sentences to the quick start as it bumps the clone line.
  They hold no `git clone`, so the clone check stays at one line.

### M4C-F8 (minor): the reference's refusals and glossary are held one way only

- **Where:** `tests/test-docs.sps`, `entry-problems` (`:2286`), which asks only that each listed
  reason is one the verb raises; `docs/reference.md`'s "Refuses, in this order" lists and the
  glossary's `Limits` line; `src/chez-sodium.sls`'s `;;   Limits = …` line.
- **Evidence** (each a whole copy, [mut-run.out](mut-run.out)):
  - `ref-bullet-dropped`: blake2b's `empty-key` bullet removed. `test-docs` and `test-reference` pass.
  - `ref-order-swapped`: blake2b's `not-a-natural` and `size-out-of-range` swapped under "in this
    order". Both pass.
  - `ref-glossary-limits` and `src-limits-comment`: `'sensitive` dropped from the glossary, or from
    the source's `Limits` definition. Both pass.
  - The control, `ref-reason-wrong-verb`, an `empty-key` bullet under `password-hash`, fails by name.
- **Why it matters:** a caller's `guard` tests these symbols, and the reference says the order. All
  are right today: the reason probes raise each listed reason, in the code's order.
- **Fix:** hold each verb's bullets, in order, to `raised-by`'s list, the probes ordered as the code
  checks; hold the glossary's `Limits` line to the presets the verbs take.

### M4C-F9 (minor): check-floors' wiring of CONTRIBUTING.md is held by nothing, and the templates are not read

- **Where:** `Makefile:287`; `tests/check-test-fails.sh`, case floors-house, which plants SECURITY.md
  alone; `.github/ISSUE_TEMPLATE/` and `.github/PULL_REQUEST_TEMPLATE.md`.
- **Evidence:**
  - `floor-contributing-unwired`: `CONTRIBUTING.md` dropped from the Makefile's `check-floors` line,
    and `1.0.18` planted in it. `make check-floors` exits 0, and `make check-test-fails` reports
    "make test failed, as it must, in all 17 cases".
  - `floor-issue-template`: "10.4.0 or later" planted in the bug-report template. `check-floors`
    exits 0, direct and through make: only `.github/workflows` is read under `.github/`.
- **Fix:** floors-house plants both files, one case each or one case with two lines; add
  `.github/ISSUE_TEMPLATE` and `.github/PULL_REQUEST_TEMPLATE.md` to the documents check-floors
  reads, or say in §4.5 that they are not.

### M4C-F10 (minor): the `SITE_REF` fix is held by no suite, and its watched failure rests on a probe run from a file after the removal guard refused it

- **Where:** `Makefile:671-674` (`export SITE_REF`); `build-site.sps`' and `check-site.sps`' `valid-ref?`;
  `.plans/research/m4-slice-1-site-review/probes/inject-probe.sh`; the mutation log's
  "SITE_REF by the environment" row and builder 1f's two F1 rows (`1f.md:31-32`).
- **Evidence:**
  - The site reviewer's command holding backticks and `$$` was refused by the guard; it reran it as
    `inject-probe.sh`, and the site's fix agent did the same (mutation log, "Two agents ran a
    probe from a file"). Every record of F1, its finding, the caller's reproduction, the fix's
    watched failure and the clean rerun, comes from that file.
  - No suite reads the Makefile for `$(SITE_REF)` in a recipe, or for its `export`. 1f's own row:
    "`build-site.sps`'s `valid-ref?` test off ... SURVIVES: 5 pages written. No suite runs
    build-site.sps". A recipe given back its `SITE_REF="$(SITE_REF)"` prefix expands the tag name in
    the shell before either Chez guard runs. 1f's mutant for that turned both guards off as well,
    so it does not show the prefix alone is caught.
  - This review did not run the probe: it is the refused command in another form. The Makefile
    today holds `export SITE_REF` and no `$(SITE_REF)` in any recipe (read, `grep -n SITE_REF
    Makefile`).
- **Fix:** a check that reads the Makefile as text: no recipe line holds `$(SITE_REF)` or
  `${SITE_REF}`, and `export SITE_REF` is there; a `check-test-fails` case that plants the prefix.
  Both run no injected command. Hold `build-site.sps`' refusal with a row that renders `SITE_REF=a;b`
  in a copy and expects exit 1 and no page.

### M4C-F11 (minor): the ledger and the plan lag the slice, and two times are still called estimates

- **Where:** `progress.md:64-67` (Now); the plan's §7 ("`test-docs`' time under the gate, at slice 1's
  join: set A's 60 s is an estimate"); ADR-0013's Consequences, `:150` ("`test-docs` is estimated
  at about a minute under the gate ... slice 1's join measures it").
- **Evidence:**
  - Now says "Slice 0, the plan and the records, is on `m4-slice-0`". Slice 1 is built, reviewed
    twice and fixed, on `m4-slice-1` (#19), stacked on #18.
  - PR #19's first CI run measured `test-docs` at 86 s under the gate (the site review, item 9); this
    review measured 59 s in the container ([gate-times.out](gate-times.out)).
  - `test-check-ci`: 147 s under the gate in the container here, against 154 s in 1g's log and 193 s
    on PR #19's first CI run. The run at `b34b7ee` is the one to read before the merge (item 4).
- **Fix:** Now names slice 1 and its PR; §7 and ADR-0013 record the measured times; the close-out
  records `test-check-ci`'s CI time at `b34b7ee`.

### M4C-F12 (minor): four things a security reviewer would want on the passwords and tokens pages

- **The rehash's write can put back an old password.** `log-in!` stores the new hash
  unconditionally (`passwords.md:81`, `:162`). A login that verified the old password, racing a
  password change or an admin's reset, can overwrite the new hash with a fresh hash of the old
  password. Techo guards it: `set-password-hash!` "only when the old hash matches"
  (`techo/.plans/2026-11-24-slice-3b-login.md:397`). One sentence: store it only if the account
  still holds the hash you verified.
- **Nothing says to bound how many hashes run at once.** "Size a container for every hash that can
  run at once" (`:245-247`) assumes a bound the page never asks for. Each login costs 64 MiB and
  about 50 ms of a thread; an unbounded login route is a memory denial of service, and under a
  container's limit a kill. Say: run hashes on a fixed pool or queue, and limit tries, as Techo's
  one-thread worker and rate limit do.
- **Sign-up is refused too.** "Before you verify" names `password-verify` only; `password-hash`
  refuses a non-string and an over-cap password the same way, and `sign-up!` (`:149-150`) checks
  neither.
- **A bytevector changed mid-call.** Brief §5: "A caller who changes the bytes from another thread
  meanwhile hashes what it wrote". `tokens.md` and the reference say it for no bytevector verb; the
  passwords page says it for strings alone.

### M4C-F13 (minor): AGENTS.md and the constraints lag three of M4's rules

- AGENTS.md's signature rule, "Exported functions should have a comment with a Typed Racket style type
  signature", does not say the comment is `;; NAME : TYPE` alone, its note on a line of its own
  (ADR-0012, amended). `test-reference` holds it, and CONTRIBUTING.md says it.
- AGENTS.md's "seen when it changes a character's width" is looser than the code: a change that
  widens one character and narrows another keeps the count, and is not seen. The pages' "alters the
  password's length as UTF-8" is right.
- AGENTS.md's comment rule names `src/`, `tests/`, the Makefile, `scripts/` and `packaging/`. M4 adds
  `site/` and `build-site.sps`, Scheme the scanner does not read. Their comments are clean today
  (grep below).
- The constraints' "Docs, site and release" lists the banned words without the finding id and
  "printable ASCII", which `test-docs` added after the docs review (M4S1D-F4).

### M4C-F14 (minor): small text faults

- ADR-0011's amendment, `:288`: "No docs example hashes above the default." `passwords.md:36-38`
  shows `(password-hash "correct horse" 'moderate)`, an unrun fragment. Say "no run example".
- `Makefile:660` is one comment line of 135 characters, written in `b34b7ee`.
- `site/links.sls:14`: `;; valid-ref? : String -> Boolean` sits at column 0 inside the library.
- `Akku.manifest`'s synopsis, "libsodium bindings for Chez Scheme", and `src/chez-sodium.sls`'
  header, "libsodium for Chez Scheme", claim what the site's description stopped claiming
  (M4S1S-F2). The synopsis ships in the archive.

---

## Where M4 is sound

- **The pages agree with the code where a check can read them, and nearly everywhere a reader
  can.** `test-docs` 152 of 152, `test-reference` 23, `test-manifest` 107, `test-check-floors`
  442, `test-site-testing` 7, `test-check-ci` 882, and `check-floors`, `check-ci`, `check-suites`
  and `check-site` green, in the container ([baseline.out](baseline.out)).
- **The mutants that should fail did.** Of 21 copies, the four meant to pass did: the two
  controls, F3's fix and the release's edits. The six meant to fail did, each by name: F3's fix with
  its line removed, the login program's swapped verify, its dropped bound, its changed output, a
  reason under the wrong verb, and the manifest bumped alone. The 11 survivors are F2's, F3's, F5's,
  F8's and F9's.
- **The release can go as planned.** The release's edits, the manifest at 0.1.0, a `[0.1.0]`
  entry in Keep a Changelog's form and both clone lines at `--branch v0.1.0`, pass `test-manifest`,
  `test-docs`, `check-floors` and `check-site` at `main` and at `v0.1.0`, in the container and on
  Ubuntu's Chez 9.5.8; the render's clone line and `blob/v0.1.0/` links are right.
- **The ninth invariant works on the Chez pages.yml uses:** it refuses `v0.1.0` at 0.0.0 on
  Ubuntu's 9.5.8, and passes it at 0.1.0.
- **The comment pass is complete.** Set A's scanner, rerun over the tree, gives 0 for "amended",
  "decision N", the brief or a plan's section, and "row N" ([comment-scan.out](comment-scan.out)).
- **The archive is right today:** `git archive HEAD` holds `CHANGELOG.md`, `LICENSE`, `README.org`,
  `Akku.manifest`, `docs/`, `src/` and an empty `vendor/chez-srfi/`, and no `.plans/` or
  `AGENTS.md`; `527170d`, the planned negative, predates `.gitattributes`.
- **The security patterns, as written, are safe:** verify first, needs-rehash only after `#t`, the
  rehash wrapped; one real dummy hash, refused whatever it answers; the bound checked before any
  verify, the same for every name; needs-rehash said to be no integrity check on the passwords page;
  API keys looked up by BLAKE2b hash, the reason no compare is needed stated; a keyed tag compared
  in constant time, its length leak stated; the container kill, the hash's own cost and the entropy
  abort stated.
- **The records' links all resolve:** the slice 0 review's `anchors.py` gives 0 bad links over the
  ADRs, the plan, the constraints, the ledger, the traps, the mutation log, the slice reviews, the
  builders' logs and the contributor files.
- **The settings are as the plan expects before the tag:** Pages 404, no environment, no ruleset,
  `main` unprotected, private vulnerability reporting `{"enabled":true}`.

---

## The seven items

1. **Done (plan §6).**
   - **Holds now:** the walk as a reader ran in `ubuntu:24.04` and on the workstation (slice 1's
     mutation log), and the fixes after it changed prose only (`git diff 7928da4..b34b7ee --
     docs/quickstart.md` adds the unthreaded refusal's text). This review has run.
   - **Not yet:** slices 0 and 1 merged with CI green (PR #19's run at `b34b7ee`: five jobs green, the
     memory job running when read); the closing fixes merged; the tag, its runs, the live site, the
     Release, the archives, Techo told; AGENTS.md and the ledger saying M4 is done.
   - **Feasible as written:**
     - the clone lines, the manifest and CHANGELOG move together, and the suites pass them (the
       `release` mutant; F7 adds a note);
     - check-site's ninth invariant passes at the tag on both Chezes (F6 asks it run before the tag);
     - Pages from Actions and the environment's `v*` rule: as the sibling's, whose `main` rule the API
       adds and the plan deletes;
     - the tag ruleset: `refs/tags/v*`, `update` and `deletion`, no bypass, as the sibling's reads;
     - branch protection by the six `name:` values, `strict`: each is a check run's name;
     - the live check: the sibling's adapts by its page list, `index.html passwords.html tokens.html
       finding-libsodium.html reference.html style.css`, and its repository;
     - the Release: the sibling's recipe resolved its relative links to `blob/v0.1.0/`, so the
       entry's page links work in the body;
     - the archive listing, with `527170d` as its failing case.
   - **Missing:** README.org's site link (F4); check-site in step 3, and on Ubuntu's Chez (F6); the
     detached-HEAD note (F7). A `v*` tag that is no `vX.Y.Z` is not held (F5). No step would fail.
2. **The records against the code and each other.**
   - Stale: changed-during-call's reach in the constraints, the brief, ADR-0006, ADR-0009, the ledger
     and three comments (F1); the reference's needs-rehash sentence (F2); README's site link against
     ADR-0013 (F4); the plan's "cannot deploy" (F5); the ledger's Now, two estimates (F11);
     AGENTS.md and the constraints (F13); ADR-0011's "no docs example" (F14).
   - The greps: needs-rehash's first wording survives only where the records quote it as
     withdrawn, and in the reference (F2). The limits rule carries the docs' exception in AGENTS.md,
     the constraints, the brief's §8.2 and ADR-0011. The platforms say Linux on x86_64, arm64 not
     run, everywhere they are named; the brief's "Ubuntu 22.04's package" (`:137`) predates M4. The
     floors rule agrees; AGENTS.md's "the one place the floors are written" means the source,
     which README.org's Requirements restate under `check-floors`.
3. **The pages, as a whole.**
   - Planted faults: 21 copies, 11 survivors (F2, F3, F5, F8, F9).
   - As a security reviewer: no page leads to an unsafe login or token scheme as written. The weak
     points are a safety line no check holds and a dummy whose password is printed (F3), and four
     notes (F12).
   - As Techo's developer: the login, the unknown account, the bound, the memory guess, the worker
     thread and the API-key scheme are all there, and match what Techo's 3b plan builds. Techo would
     need F12's rehash race and concurrency notes from its own plan, not from these pages.
   - Brief §5 and §6.3 and the owed notes: each owed note is on the page where it applies. Missing:
     brief §5's bytevector changed mid-call (F12); §6.3's "It is not a guarantee" is implied by
     "What is wiped", not said.
4. **The suites M4 added.**
   - No row found that cannot fail: each real-page row has a reader held on the suite's own texts and
     a "some" row beside it; the `#f`-expecting rows sit in mixed lists. Guards answer data that a row
     then compares; none turns a raise into the expected value. Effects run through
     `each-in-order`; `map` is used only over pure readers. Top-level reads of pages and sources are
     guarded; `leak-env` is not, and can raise only if `(chez-sodium private counters)` is missing.
   - Survivors: F3, F8 and F9. F10's fix has no suite.
   - Times: `test-check-ci` 147 s, `test-docs` 59 s, `test-reference` 8 s, `test-manifest` 7 s under
     the gate in the container. On CI `test-check-ci` was 193 s at `7928da4`. The split rule (§7)
     turns on the `b34b7ee` run's memory job, which was still running when read, and which this
     review could not wait for (the denial above). The caller reads it: past 200 s, the plan splits
     the suite in the fixes PR.
5. **The whole-tree scans.**
   - The scanner: 12 banned-category lines in 7 files, none real: `guix-env-launcher.sh`'s "M1:"
     and "M2:" are case labels, "slices" a verb, and `test-docs`' and `test-manifest`'s hits describe
     their own rules.
   - Privacy: every added line of `git diff d53e83c..b34b7ee` grepped for a home path, the user's
     name, an email address and the host's distribution. The only `/home/` hits are stand-in
     directories under `<repo>/build/` in set B's outputs; research paths are masked.
   - The comment rule in the files M4 touched: no milestone, slice, finding id, date or research
     path; `site/` and `build-site.sps` are clean too (F13). Layout: F14.
6. **The site and CI, end to end.**
   - The render: `scripts/guix-env sh -c 'rm -rf build/site && SITE_REF=v0.1.0 make site'` writes the
     five pages and `style.css`, exit 0, at the manifest's 0.0.0. **`make site` does not refuse;
     only `check-site` does,** exit 2, "SITE_REF v0.1.0 is a release tag, but Akku.manifest's version
     is 0.0.0, not 0.1.0".
   - The HTML: each page's `<title>` its label; the description "Password hashing for Chez Scheme,
     through libsodium, with random bytes, BLAKE2b and a constant-time compare"; no repeated id,
     no raw HTML; the reference's 18 `h3` ids; four tables; every repository link
     `blob/v0.1.0/README.org`; the quick start's clone line `main`'s, as at 0.0.0.
   - `pages.yml` deploys only after `make check-site` with `SITE_REF` the tag, so a `vX.Y.Z` tag on a
     tree whose manifest disagrees cannot deploy, on Ubuntu's Chez as in the container. A `v*` tag
     of another shape can (F5).
7. **The process.**
   - The mutation log shows every check it lists watched failing, by a named row or invariant, each
     with a clean rerun. The base's network fetch, and the two probes run from files, are recorded.
   - What depends on those probes: the F1 fix's every record (F10). Nothing in the tree runs them,
     and nothing in the tree holds the fix either.

---

## Commands to reproduce

From `<repo>`'s root. Scratch goes under `build/m4-closing-review/`.

```sh
R=.plans/research/m4-closing-review
B=.plans/research/m4-plan/b/probes

# the suites M4 added, timed, and the checks
mkdir -p build/m4-closing-review && cp $R/baseline.sh build/m4-closing-review/
scripts/guix-env sh build/m4-closing-review/baseline.sh     # baseline.out

# the render the plan names, then the refusal
scripts/guix-env sh -c 'rm -rf build/site && SITE_REF=v0.1.0 make site'                  # exit 0, five pages
scripts/guix-env sh -c 'SITE_REF=v0.1.0 make check-site'                                  # exit 2, invariant 9
scripts/guix-env sh -c 'SITE_REF=v0.1.0-rc.1 make -s check-site; SITE_REF=v0.2 make -s check-site'   # green: F5

# the mutants
python3 -I $R/mutants.py
scripts/guix-env sh build/m4-closing-review/mut/run.sh      # mut-run.out

# pages.yml's build on Ubuntu's Chez 9.5.8, offline, in two copies (any image with
# packaging/debian-site-prereqs.txt installed; here a local one)
cp $R/ubuntu-site.sh build/m4-closing-review/
cd build/m4-closing-review && for c in release clean-make; do
  docker run --rm --network none --user "$(id -u):$(id -g)" -v "$PWD:$PWD" -w "$PWD" IMAGE \
    sh "$PWD/ubuntu-site.sh" "$PWD/mut/$c"; done; cd -    # ubuntu-site.out

# the gate's times, in a copy
scripts/guix-env sh -c 'cd build/m4-closing-review/mut/clean-make && make test-memory MEMORY_SUITES="tests/test-check-ci.sps tests/test-docs.sps tests/test-reference.sps tests/test-manifest.sps"'

# F1 and F2's probes, at both releases
scripts/guix-env sh -c 'sh .plans/research/m4-plan/b/probes/both.sh .plans/research/m4-slice-1-docs-review/same-width-race.sps'
scripts/guix-env sh $B/both.sh $B/other-tag.sps

# the scans
python3 -I .plans/research/m4-plan/a/comment-scan.py .                                    # comment-scan.out
grep -n -E ';' site/*.sls build-site.sps | grep -i -E 'M[0-9]|slice|ADR|decision|amended|brief|§|review|sqlite|20[0-9][0-9]-'
git diff d53e83c..b34b7ee | grep '^+' | grep -n -i -E '/home/|[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[A-Za-z]{2,}'
python3 -I .plans/research/m4-slice-0-review/anchors.py .plans/decisions/*.md .plans/2026-11-25-m4-plan.md \
  .plans/global-constraints.md .plans/progress.md .plans/traps.md .plans/m4-slice-1-mutation-log.md \
  .plans/research/m4-slice-1-docs-review/README.md .plans/research/m4-slice-1-site-review/README.md \
  .plans/research/m4-slice-1/*.md CONTRIBUTING.md SECURITY.md                             # bad links: 0
git archive --format=tar HEAD | tar -t | grep -E '^(vendor|\.plans|AGENTS|CHANGELOG|LICENSE|README|docs/$|src/$|Akku)'

# the settings, read only
for p in pages environments rulesets branches/main/protection private-vulnerability-reporting; do
  gh api repos/Kiyomi-Computation-Systems/chez-sodium/$p; done
gh run view 45620300156 --json jobs     # the run at b34b7ee
```
