# M4 slice 1 review: the docs half

Reviewer: Opus, read-only and adversarial. Tree: `m4-slice-1` at `7928da4` (PR #19), stacked on
`m4-slice-0` at `1d4b8c1`, clean. The slice is `git diff 1d4b8c1..7928da4`; its first commit,
`3fabcfe`, the site's base, and the site and CI files are the second reviewer's. `<repo>` is
chez-sodium's checkout, `<sibling>` chez-sqlite3's (`960d9f0`, read only), `<home>` the host's
home.

**Read:** AGENTS.md whole; the M4 plan's §3, §4.1 to §4.5, §4.8, §4.11 and §4.12; ADR-0013;
ADR-0009 and its 2026-11-25 amendment; `.plans/global-constraints.md`, "Docs, site and release";
set B's README and `out/timing.out`; the builders' logs 1a to 1g and
`.plans/m4-slice-1-mutation-log.md` (there is no `1h.md`: the mutation log's 1h row says the
contributor files have no check of their own). The pages: README.org and the five under `docs/`.
The contributor files: `CONTRIBUTING.md`, `SECURITY.md`, the two issue templates and the
pull-request template. Their checks: `tests/test-docs.sps` and `tests/test-reference.sps` whole;
`tests/check-floors.sps`, `tests/floors.sls`, `tests/test-check-floors.sps` and their fixtures, by
the slice's diff; `tests/test-manifest.sps`' clone check and its fixtures; the Makefile's
`check-floors` line. The code: `src/chez-sodium.sls`, `password-verbs.sls`, `password-text.sls`,
`byte-verbs.sls`, `conditions.sls`, `discovery.sls`, `cap.sls`, native's writers and header, the
slice's diff of every comment-pass file, and `require-threaded.sls`' refusals. The repository's
settings, by `gh api` GETs.

**Where probes ran:** in the container (`scripts/guix-env`, Chez 10.4.0 threaded), each probe
through set B's `probes/both.sh`: Guix's libsodium 1.0.22, then the floor's build,
`build/slice5/prefix-1.0.18`. `test-docs` ran clean at both: 127 of 127 each. Mutants ran in
whole copies under `build/m4s1-review-docs/mut/`, made by `mutants.py` (kept here). The scanner,
the privacy grep and the `gh api` GETs ran on the host. No permission check was denied, and no
tracked file was changed.

**Counts: 0 blockers, 4 majors, 14 minors.**

**The caller's checks.** F1 reproduced: `same-width-race.sps` gave `(answered #f #f)` in 10 of 10
trials, and with `wide` `(refused changed-during-call)` in 10 of 10. F2 and F4 are read from the
mutants' table; F3 was read with `gh api`, `enabled:false`.

**The owner's answers, 2026-11-25:** F3, "You turn it on now": the caller turned private
vulnerability reporting on, and read back `{"enabled":true}`. F16, "Conventional for outsiders":
CONTRIBUTING.md asks it of an outside contributor's PR title, and the milestone PRs keep their
own.

**Every finding is fixed in slice 1,** by four fix agents on disjoint files: the pages (F1, F2,
F7 to F11, F14, F15, F18), `test-docs` (F2's fragments, F4 to F6, F13), the site's fix agent's
`check-test-fails` case (F12), and the contributor files and comments (F16, F17).

No page leads a user to an insecure login or token handling. The login pattern verifies first and
rehashes only after `#t`; an unknown name is checked against one real hash and refused whatever it
answers; the password is bounded before any verify, the same way for every name; needs-rehash is
said in so many words to be no integrity check; API keys are looked up by their BLAKE2b hash, and a
raw secret or tag is compared with `constant-time-bytevector=?`, its length leak stated.

---

## Majors

### M4S1D-F1 (major): the pages say a password another thread changes mid-call is always refused, and "never answered wrongly"; a change of the same width is answered

- **Where:** `docs/passwords.md:236-238` ("If another thread does, the call is refused, as
  `changed-during-call`, and never answered wrongly"); `docs/reference.md:186` and `:226-227`
  ("another thread changed the password while it ran"). The source is the plan's §3, `:187-188`,
  which states the fact without its limit.
- **Evidence:**
  - The writer sees only a change of byte count: `call-with-utf8` refuses when a character's bytes
    no longer fit the count taken before the section, or the write ends short
    (`native.sls:469-470`, `:495`). `call-with-c-string` refuses a hash character outside
    U+0021 to U+007E (`:427-431`). AGENTS.md says so: "seen when it changes a character's width, or
    puts a hash character out of range".
  - `same-width-race.sps`: a second thread rewrites a 60000-character password between all `a`
    and all `b` while `password-hash` reads it. 20 of 20 trials, 10 at each release, answered a
    hash that verifies against neither string, and nothing was refused
    (`build/m4s1-review-docs/same-width-race.out`).
  - The control, `same-width-race.sps wide`, writes U+00E9, two bytes, instead of `b`: 20 of 20
    refused as `changed-during-call` (`same-width-race-wide.out`).
- **Why major:** a false statement of a safety net. A reader who shares a mutable password buffer
  across threads is told the library catches it; instead `password-hash` can store a hash of a
  password nobody typed, which locks its owner out.
- **Fix:** passwords.md: "Don't change a password string while a verb reads it. A change that
  alters a character's UTF-8 width is refused, as `changed-during-call`; any other change goes
  unseen, and the verb answers for whatever it read." The reference's two bullets: "another thread
  changed the password's UTF-8 length while it ran" (and, for the hash, "put a character outside
  `!` to `~`"). Correct the plan's §3 line.

### M4S1D-F2 (major): the password fragments a reader copies are held by nothing; a swapped `(password-verify password hash)` in the login pattern passes every check

- **Where:** `docs/passwords.md:69-78` (`log-in!`), `:196-204` (`check`, the memory guess),
  `:36-38`; `tests/test-docs.sps:1594-1604`, which only reads a fragment as data. ADR-0013,
  "Rejected" (`:132-133`): "unrun password fragments, which would leave the examples a reader
  copies unchecked".
- **Evidence:**
  - Mutant `gap-fragment-order`: the login fragment's `(password-verify hash password)` made
    `(password-verify password hash)`. `test-docs` passes, 127 of 127.
  - Mutant `gap-fragment-name`: `password-verify` made `password-verfy` in the same fragment.
    Passes, 127 of 127. The export-span rule reads prose code spans only (`:1757-1764`).
  - "All together" runs a variant of the login pattern, but `check` appears nowhere else, and the
    fragment a reader meets first is not the one that runs.
- **Why major:** ADR-0013 rejected exactly this; the plan's §4.1 allows a fragment only for a fact
  that is not runnable, and the login pattern is runnable with a stand-in store. Today both
  fragments are right; nothing keeps them so.
- **Fix:** make the login pattern a `scheme run` block, its store a hashtable defined in the block,
  so the argument order and the names run at the default; and hold every name-like symbol in a
  fragment's data to the exports, by the prose rule's prefixes, watched failing on
  `password-verfy`. `check` can run too: without short memory it answers `right` and `wrong`.

### M4S1D-F3 (major): `SECURITY.md` and README.org send reporters to GitHub's private reporting, which is off on a public repository, and the plan turns it on only after this slice merges

- **Where:** `SECURITY.md:12-14` ("Security → Report a vulnerability ... Do not open a public
  issue"); `README.org:101`; the plan's §4.11, `:576`, "before the tag", and §4.12, `:594`.
- **Evidence:** `gh api repos/Kiyomi-Computation-Systems/chez-sodium/private-vulnerability-reporting`
  answers `{"enabled":false}`; the repository's `visibility` is `public`. SECURITY.md gives no
  other channel, by design (no email).
- **Why major:** from the merge until the owner's setting, the default branch's security process is
  false: GitHub shows no "Report a vulnerability" button, and the only way left is the public issue
  the page forbids.
- **Fix:** turn private vulnerability reporting on before slice 1 merges, and read it back with the
  GET above; move §4.11's row to "as slice 1 merges".

### M4S1D-F4 (major): two of §3's bans on what a page may say are held by nothing: a finding id, and "printable ASCII" for a hash string

- **Where:** plan §3, `:223` ("a finding id, an ADR, a date, ... (§4.3)") and `:224`; §4.3's list,
  which omits the finding id; `tests/test-docs.sps:648-653`, `forbidden`.
- **Evidence:** mutant `gap-finding-id` adds "As M4S0-F9 found:" to passwords.md; mutant
  `gap-printable` makes passwords.md:182 "printable ASCII.". `test-docs` passes both, 127 of 127.
  Builder 1b's `grep.sh` checked "printable" once, by hand; it is no suite.
- **Why major:** a rule the plan requires, missing. §3 points the finding id to §4.3, and §4.3 lost
  it: a flaw in the brief, which the builder inherited.
- **Fix:** add a finding-id pattern (letters and digits, `-F`, digits, as `M4S0-F9` and `L-F7`) and
  "printable ascii" to `forbidden`, each watched failing; add the finding id to §4.3's list.

---

## Minors

### M4S1D-F5 (minor): the export-span rule cannot fail for README.org

- **Where:** `tests/test-docs.sps:1757-1764`, run over README.org among the pages; `code-spans`
  reads backtick spans only, and README.org writes code as Org's `=…=` and `~…~`.
- **Evidence:** mutant `gap-readme-span` writes `=password-hashes=` in README.org's prose: passes.
- **Fix:** read Org's verbatim and code spans for README.org; watch it fail on that mutant.

### M4S1D-F6 (minor): the reference's refusal reasons, its own reasons table and its glossary's `Reason` are held by nothing

- **Where:** `docs/reference.md:18-19`, `:333-340`, and each entry's "Refuses" list.
- **Evidence:** mutant `gap-ref-reason` renames `key-length-out-of-range`; `gap-ref-table` renames
  `init-failed` in the reference's table. `test-docs` and `test-reference` pass both. The finding
  page's copy of the same table is held (mutant `reason-renamed` fails).
- **Why it matters:** a caller's guard tests these symbols. All of them are right today:
  `refusals.sps` raised every reason the reference lists, at both releases.
- **Fix:** hold the reference's `Reason` table and glossary line to
  `sodium-library-unavailable-reasons`, as the finding page's; and every reason-shaped code span of
  the reference to the set the verbs raise, from a probe like `refusals.sps`.

### M4S1D-F7 (minor): "What every call shares" gets the irritants wrong for two cases

- **Where:** `docs/reference.md:26-31`: "Its irritants are `(REASON PARAMETER VALUE)` ... A string or
  bytevector is a secret, so it shows only its kind."
- **Evidence (`refusals.sps`):** a secret parameter shows its kind whatever the value is:
  `(password-verify h #f)` gives `(not-a-string password (kind boolean))`, and
  `(blake2b bv 32 #f)` `(not-a-bytevector key (kind boolean))`. An accessor gives two irritants and
  no parameter: `(sodium-failed-code 1)` gives `(not-a-sodium-failed (kind number))`.
- **Fix:** "A secret parameter, a password, a hash, an input, a key or an operand, shows only its
  kind, whatever was passed. An accessor's irritants are its reason and the kind."

### M4S1D-F8 (minor): `sodium-library-unavailable-source` is `override`, not `#f`, when an invalid override chose nothing

- **Where:** `docs/reference.md:356-357`, "or `#f` when none was chosen".
- **Evidence:** `discovery.sls:66` refuses with path `#f` and source `override`; `make build` with
  `CHEZ_SODIUM_LIBRARY=relative.so` prints `path: none`, `source: override`; `same-condition.sps`
  with an empty override gives `(invalid-override #t 0 override "")`.
- **Fix:** "or `#f` for `not-found`".

### M4S1D-F9 (minor): the reference's pre-check names four exclusions, and there are more

- **Where:** `docs/reference.md:212-213`: "none a space, newline, U+0000 or non-ASCII character".
- **Evidence:** the pre-check takes U+0021 to U+007E (`password-text.sls:37-44`); a tab or a DEL
  appended to a good hash answers `#f` without C (`refusals.sps`, `pv-hash-tab`, `pv-hash-del`). As
  written, a tab passes the stated test.
- **Fix:** "each character from `!` to `~`, so no space, control character or non-ASCII".

### M4S1D-F10 (minor): two sentences say what the code does not

- `docs/reference.md:52`: "A program that names a chez-sodium procedure loads the library": the
  predicates and accessors are procedures and load nothing, as `:43` says. Write "a procedure that
  reaches libsodium", as the quick start does (`:122`).
- `docs/passwords.md:225`: "whatever limits you pass": `password-verify` takes no limits. Write
  "whatever limits you hash new passwords at".

### M4S1D-F11 (minor): README.org states things nothing holds, and links a site that is not there

- `README.org:42` names `1.0.22`, the current lane, which lives in `scripts/ci/build-sodium.sh:84`
  and `check-sodium.sh:101`. No check reads README's copy, so a moved lane leaves it stale.
- `README.org:93` links the docs site; `gh api repos/.../pages` answers 404 until the tag's deploy,
  so `main` links a dead page between this merge and the tag.
- A floor written short passes `check-floors`: mutant `gap-short-floor` adds "Chez Scheme 10.4 or
  later" to the quick start. The rule searches for the dotted text, `10.4.0`.
- **Fix:** name the current lane without its number, or hold it; say nothing of the site until the
  tag, or accept the window; note the short-floor limit beside `docs-problems`.

### M4S1D-F12 (minor): the Makefile's new `check-floors` inputs are held by nothing

- **Where:** `Makefile:287`.
- **Evidence:** in a copy, `CONTRIBUTING.md SECURITY.md` dropped from the recipe and `10.4.0`
  planted in SECURITY.md: `make check-floors` exits 0 (`mut/makefile-wiring`). `check-test-fails`
  holds the scripts input (case `floors-script`, `:439`) but has no case for the docs or the house
  files.
- **Fix:** a `check-test-fails` case that plants a floor in a page and in SECURITY.md, as
  `floors-script` plants one in a script.

### M4S1D-F13 (minor): the guarded program's refusal is held only by its first element

- **Where:** `tests/test-docs.sps:1045-1053`, `refusal-shape`; `docs/quickstart.md:117-118`
  promises "the reason ... and the path".
- **Evidence:** any one datum headed `refused` passes, `(refused)` included. With the missing file
  the answer is fixed: `(refused load-failed "/no/such/directory/libsodium.so.26")`.
- **Fix:** compare the whole datum.

### M4S1D-F14 (minor): two cost and timing notes the pages leave out

- **No such account** (`passwords.md:93-97`): a name whose stored hash is at older limits still
  answers in another time than the dummy, until its owner's next login rehashes it (Ada's
  `2, 19456` hash against an `'interactive` dummy; inferred from the limits, not timed here).
- **The memory guess** (`:193-204`): every wrong password costs a verify and a throwaway hash, twice
  the work an attacker's guess costs the server. Say to guess only where the answer is used, such
  as for a log line.

### M4S1D-F15 (minor): nothing says how to store the hash string

`passwords.md:180-185` says "exactly", but not how. A reader sizing a column picks `CHAR(97)`,
which pads, or a width a custom limit overruns (the presets' are 97 to 99 characters, more at
higher custom limits; the plan bars lengths from the reference, §4.2). One sentence: "a text column
of no fixed width; never `CHAR(n)`, which pads with spaces".

### M4S1D-F16 (minor): the contributor files

- `CONTRIBUTING.md:89-92` and `PULL_REQUEST_TEMPLATE.md:13` require Conventional Commits; every PR
  title on `main` is "M3 slice 2: the verbs (#16)" and the like (`git log --format=%s main`). The
  rule is chez-libuv's; ask the owner which holds.
- `CONTRIBUTING.md:7` and `feature_request.md:18`: "what Techo has a named use for". No public
  page says what Techo is.
- `bug_report.md:13`: `chez --version`. The quick start installs `scheme`; there is no `chez` on
  Linux unless a packager makes one.
- `CONTRIBUTING.md:49-51`: a new page also goes in README.org's Documentation list, which
  `check-site` and `test-docs` both hold.
- `CONTRIBUTING.md:73-75`: "They don't cite plans", while every library cites a bare `ADR-NNNN`,
  which AGENTS.md allows. Say "no milestone, slice, date or research path; a bare ADR number may
  say why".
- Targets named all exist; every link resolves; no version text and no email address in any of
  them.

### M4S1D-F17 (minor): the comment pass left two overlong lines and one ragged one

`password-verbs.sls:215` is 119 characters, joined and not rewrapped ("three are answered without
a section and without C. It never raises because of HASH, a HASH another thread changed");
`check-floors.sps:17` is 120. `native.sls:43` ends after six words. The datums are the same; the
text wants rewrapping.

### M4S1D-F18 (minor): the docs rule

- **Worst bloat:** `docs/reference.md`, 2198 words, repeats the guides' advice entry by entry: the
  worker thread (`:176-177`), the container (`:190-192`), the memory guess (`:207-210`), the
  16384-character bound (`:229-230`), verify first (`:243-244`), the rehash's wrap (`:252-253`).
  A reference can link the passwords page once.
- **Worst jargon:** "the condition's who" (`reference.md:398`); "irritants" (`:28`); "engine
  expiries" (`passwords.md:232`).
- **Wording:** README.org's "tell when a hash needs redoing because its limits were raised"
  (`:11-12`; lowered limits, another algorithm and an unreadable hash answer `#t` too: "changed");
  "Every verb is built" (`:37`); "Catch it, if at all, beside `password-hash`'s"
  (`reference.md:131-132`).
- **Missing:** no page says what an unthreaded or too-old Chez does: it refuses at import with a
  plain message (`require-threaded.sls:77-86`). One line in the quick start's "What you need".

---

## The eight items

1. **Every claim, against the code and the library.** Every refusal's reason symbol, order and
   irritant shape, every default and size, `make-password-limits`' bounds, `equal?` on two limits,
   `sodium-version`'s fresh string and the predicates' answers ran in `refusals.sps`, identical at
   both releases. `hash-edits.sps`: six edits to a hash each verify `#f` and read stale, at both.
   `same-condition.sps`: a refusal is remembered as the same condition, `eq?`; `""` is
   `invalid-override`; an uncaught not-found exits 255 with one line. `make build` prints the path,
   its source and the version, as the quick start says. Discovery's order is `test-docs`' (held on
   both machine types); below-floor, missing-api and init-failed's details are held by
   `test-library-loading-*`. The prose `test-docs` cannot read: the login pattern, unknown
   accounts, the bound, the `#f` guess and its three limits, memory and containers, wiping's reach,
   the entropy abort and the tokens pattern each match §3. Threads and Ctrl-C does not (F1).
2. **Misleading on security:** no blocker. F1 is a false safety claim; F14 two missing caveats.
3. **The checks, by planted faults** (`mutants.py`, each a whole copy):

   | Mutant | Check | Result |
   |---|---|---|
   | clean, clean-ref, clean-man, clean-floors | each | exit 0 |
   | `result`: tokens.md `;; => (32 32)` | test-docs | FAIL `docs/tokens.md:119: the runnable example gives the result it states` |
   | `span`: `constant-time-bytevectors=?` | test-docs | FAIL the export-span row |
   | `floor-page`, `floor-contrib`, `floor-security` | check-floors | each names its file and line, exit 1 |
   | `dead-link` (anchor), `dead-file` | test-docs | FAIL the link row |
   | `discovery-order` | test-docs | FAIL row 2, other Linux |
   | `reason-renamed` (finding page) | test-docs | FAIL the reasons row |
   | `guarded-text` | test-docs | FAIL the guarded-text row |
   | `second-clone` | test-manifest | FAIL the clone row |
   | `signature`: `[Bytes]` | test-reference | FAIL two rows |
   | `gap-readme-span` | test-docs | passes (F5) |
   | `gap-fragment-name`, `gap-fragment-order` | test-docs | pass (F2) |
   | `gap-ref-reason`, `gap-ref-table` | test-docs and test-reference | pass (F6) |
   | `gap-finding-id`, `gap-printable` | test-docs | pass (F4) |
   | `gap-short-floor` | check-floors | passes (F11) |
   | `makefile-wiring` | make check-floors | passes (F12) |

   The guarded-text mutant shows the rule earns its place: its text block held `"1.0.22"`, so the
   row "prints the text block after it" passed in the container; only the guarded-text row failed.
4. **`test-docs` and `test-reference`:** each rule of §4.3 exists, and the brief's plants fail it
   by name. Every guard that answers data feeds a row that fails on it (`docs-pages`,
   `finding-prose`, `run-env`, `library-reasons`, `export-strings`, `override-source`,
   `loaded-line`); the rows that expect `#f` do so inside mixed lists, beside a positive row
   (`row-agrees?` `'(#t #t)`), so a raise cannot pass them. Effects run through `each-in-order`.
   Top-level computations that can raise are pure readers of the suite's own texts. Gaps: F4, F5,
   F13.
5. **The comment pass:** `datums.sh` reads the 19 edited Scheme files as the same datums, and the
   two controls, `floors.sls` and `check-floors.sps`, as different. Set A's scanner over the tree:
   `amended`, `decision N`, brief or plan section and `row N` at 0; its milestone, slice and
   research-path hits are case labels (`M1:` in `guix-env-launcher.sh`), the verb "slices", and
   comments that describe `test-docs`' own rule. The rewritten comments are true: the entropy abort
   at the load; any reference to `make-password-limits` running the load; needs-rehash's amended
   rule; a 42-character tag decoding only when its last four bits are zero, `A`, `Q`, `g` or `w`,
   1 in 16. No added comment cites a milestone, slice, date or research path. F17 is layout.
6. **The docs rule:** F18.
7. **The contributor files:** F3 and F16.
8. **Privacy:** the slice's added lines hold no home path (the one `/home/` is a grep pattern in
   1b's `grep.sh`), no email address, and no name of the host's distribution.

## Where it is sound

- Every reason symbol, default, size and bound the reference states is what the library raises
  and answers, at the floor and at 1.0.22.
- The security patterns: verify first, then needs-rehash; a real dummy hash, refused whatever it
  answers; the bound checked before any verify; the rehash wrapped, the user logged in on failure;
  "no check that the hash is intact"; tokens looked up by hash, with the reason a lookup needs no
  constant-time compare stated correctly; a keyed BLAKE2b tag compared in constant time.
- README.org and the quick start say plainly what chez-sodium is and is not, as the owner asked;
  README.org carries the CI badge; the contributor files exist in the siblings' shape.
- `test-reference` holds the signatures, the exports and the trailing-note rule, each watched
  failing; `check-floors` reads docs, CONTRIBUTING.md and SECURITY.md, each watched failing;
  `test-manifest`'s clone check is held on ten fixture trees and the real one.
- The comment pass changed no datum.

## Probes kept here

- `refusals.sps`: every refusal, default and answer the reference states.
- `hash-edits.sps`: six edits to a stored hash.
- `same-width-race.sps`: F1, and its `wide` control.
- `same-condition.sps`: a remembered refusal, run with a not-found or an empty override.
- `mutants.py`: the 24 copies and their `run.sh`.
- `datums.sh`, `datums.sps`: the comment pass's datum check.

## Commands to rerun

From `<repo>`; outputs land under `build/m4s1-review-docs/`.

```sh
# the suites, at both libraries
scripts/guix-env sh -c '"$CHEZ" --libdirs src:tests:build/scheme-libs --program tests/test-docs.sps; CHEZ_SODIUM_LIBRARY=$PWD/build/slice5/prefix-1.0.18/lib/libsodium.so.23 C_INCLUDE_PATH=$PWD/build/slice5/prefix-1.0.18/include:$C_INCLUDE_PATH "$CHEZ" --libdirs src:tests:build/scheme-libs --program tests/test-docs.sps'
scripts/guix-env sh -c '"$CHEZ" --libdirs src:tests:build/scheme-libs --program tests/test-reference.sps'

# the probes, each at 1.0.22 then the floor
d=.plans/research/m4-slice-1-docs-review
scripts/guix-env sh .plans/research/m4-plan/b/probes/both.sh $d/refusals.sps
scripts/guix-env sh .plans/research/m4-plan/b/probes/both.sh $d/hash-edits.sps
scripts/guix-env sh .plans/research/m4-plan/b/probes/both.sh $d/same-width-race.sps
scripts/guix-env sh -c "sh .plans/research/m4-plan/b/probes/both.sh $d/same-width-race.sps wide"
scripts/guix-env sh -c 'env -u CHEZ_SODIUM_LIBRARY -u GUIX_ENVIRONMENT -u GUIX_PROFILE HOME=/nonexistent scheme --libdirs src --program .plans/research/m4-slice-1-docs-review/same-condition.sps; CHEZ_SODIUM_LIBRARY= scheme --libdirs src --program .plans/research/m4-slice-1-docs-review/same-condition.sps'
scripts/guix-env sh -c 'CHEZ_SODIUM_LIBRARY=relative.so make build'

# the mutants
python3 -I $d/mutants.py
scripts/guix-env sh build/m4s1-review-docs/mut/run.sh

# F12: the Makefile's inputs, in a copy of the clean mutant
cp -a build/m4s1-review-docs/mut/clean-floors build/m4s1-review-docs/mut/makefile-wiring
#   then drop " CONTRIBUTING.md SECURITY.md" from its Makefile's check-floors line, and write
#   "Chez version (10.4.0 or later)," in its SECURITY.md
scripts/guix-env sh -c 'cd build/m4s1-review-docs/mut/makefile-wiring && make check-floors'

# the comment pass
sh $d/datums.sh
python3 -I .plans/research/m4-plan/a/comment-scan.py .

# privacy, on the slice's added lines
git diff 1d4b8c1..7928da4 | grep '^+' | grep -n -i -E '/home/|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}'

# the repository's settings
gh api repos/Kiyomi-Computation-Systems/chez-sodium/private-vulnerability-reporting
gh api repos/Kiyomi-Computation-Systems/chez-sodium --jq .visibility
gh api repos/Kiyomi-Computation-Systems/chez-sodium/pages
```
