# M4 slice 0 review: the M4 plan and its records

Reviewer: Opus, read-only and adversarial. Tree: `m4-slice-0` at `4e0bd20`, one commit on `main`
(`d53e83c`), clean. The sibling, chez-sqlite3, was read at `960d9f0` and nothing was written there.
`<repo>` is chez-sodium's checkout and `<sibling>` chez-sqlite3's.

**Read:** the plan (`.plans/2026-11-25-m4-plan.md`); ADR-0013; the 2026-11-25 amendments of ADR-0006,
0009, 0010, 0011 and 0012; the brief's changed lines; the M4 changes to the constraints, AGENTS.md
and the ledger; pre-work sets A and B with their probes and outputs. From the sibling: its M5 plan,
ADR-0022, `tests/test-docs.sps`, `tests/test-reference.sps`, `tests/check-site.sps`, `site/pages.sls`,
`pages.yml`, its `site` job, `tests/check-test-fails.sh`, `tests/check-floors.sps`, its quick start,
finding page, README, live check and traps. From chez-sodium: `src/` (the public library,
discovery, conditions, require-threaded, the verbs' comments), the Makefile, `tests/check-ci.sh`,
`tests/check-floors.sps`, `tests/floors.sls`, `tests/test-check-floors.sps`, `tests/test-manifest.sps`,
`tests/check-test-fails.sh`, `tests/test-native-codes.sps`, `ci.yml`, the package list,
`scripts/guix-env` and `scripts/guix-env-enter`, and libsodium's sources under `build/slice5/`.

**Where probes ran:** in the container (`scripts/guix-env`, Chez 10.4.0 threaded), each through set
B's `probes/both.sh`: Guix's 1.0.22, then the floor's build, `build/slice5/prefix-1.0.18`. The anchor
check and the `gh api` GETs ran on the host. Scratch is under `build/m4s0-review/`. No permission
check was denied, and no tracked file was changed.

**Counts: 0 blockers, 8 majors, 13 minors.**

**The caller's checks.** Each major was reproduced before it was fixed:
- F1: discovery's two sonames a directory (`discovery.sls:168-181`) against the sibling's
  one-file cell reader (`<sibling>/tests/test-docs.sps:1501-1512`);
- F2: the sibling's "when" (`:28-31`);
- F3: `check-floors.sps:163`, exactly four arguments;
- F4: `progress.md:696`;
- F6: `require-threaded.sls:79-87`;
- F7: `tag42.sps` rerun at both releases, the same as `tag42.out`.

F5 and F8 are read from the text.

**Every finding is fixed in slice 0,** in the plan and the records. The plan's §5 now builds the
docs and the site as one slice in one tree: a base builder changes the container first, alone,
and the builders run their own suites until the join, with each planned red named (F3, F4). The
comment pass's list is the scanner's, line by line (F14), with F7's and F12's comments added.

---

## Majors

### M4S0-F1 (major): the finding page's discovery table cannot be written in the copied grammar, and the plan's rule asks it for a source no row holds

- **Where:** plan §4.3, `:300-303` ("Each names `libsodium-candidates`' paths on x86_64 and arm64,
  and `libsodium-sources`' sources, in order"); ADR-0013, decision 4; slice 1's 1b and 1c, which
  build the page and its check side by side.
- **Evidence:**
  - chez-sodium tries two sonames in every directory, directory by directory:
    `/usr/local/lib/libsodium.so.26`, `/usr/local/lib/libsodium.so.23`, then
    `/usr/lib/x86_64-linux-gnu/libsodium.so.26`, … (`discovery.sls:168-181`; set B
    `out/load.out:113-116`).
  - The sibling's cell reader takes the first code span as the one FILE and every later span as a
    DIR: `` `FILE` in `DIR`, `DIR`, … ``, each path DIR/FILE (`<sibling>/tests/test-docs.sps:1501-1512`,
    `looks-in`). A cell that names both sonames reads the second as a directory. No sentence the
    copied grammar reads gives chez-sodium's interleaved order.
  - `libsodium-sources` begins with `override` (`discovery.sls:39-41`), which neither world's row
    can hold. The sibling reads it from prose, "the code span before `` for `CHEZ_SQLITE3_LIBRARY` ``"
    (`<sibling>/tests/test-docs.sps:66-69`, `:2089`). The plan drops that clause, so its rule read
    literally cannot pass.
  - The plan gives no first-cell names for the two worlds, no path notation (`$GUIX_ENVIRONMENT`,
    `~` for HOME), and no arm64 form. 1b (Opus) and 1c (Sonnet) work in parallel and meet only at
    the join.
- **Why major:** two builders would build halves that cannot meet, and the rule as written is
  unbuildable.
- **Fix:** before the briefs, write the table's grammar into the plan:
  - each row's first cell: one holding "Guix", one beginning "Other Linux";
  - the second cell, for example `` `libsodium.so.26`, then `libsodium.so.23`, in `DIR`, `DIR` … ``,
    read directory by directory, with the sibling's `` (`ALT` on arm64) `` form and its stand-ins;
  - the third cell's sources;
  - `override` named by the prose span before `` for `CHEZ_SODIUM_LIBRARY` ``, as the sibling's.

  Then say the rows' and the prose's sources together are `libsodium-sources`, each once.

### M4S0-F2 (major): a guarded program cannot have the text block the plan requires of every whole program

- **Where:** plan §4.3, `:290-298`: a whole program "exits 0, with nothing on stderr, and prints the
  text block that follows it"; a guarded program "prints `(sodium-version)`, as the suite reads it".
- **Evidence:**
  - The sibling's rule holds the text block only **when** one follows before the next Scheme block,
    "whatever lies between" (`<sibling>/tests/test-docs.sps:28-37`). Its guarded program has no text
    block after it (`<sibling>/docs/quickstart.md`, "Which SQLite did it load?").
  - The version a guarded program prints differs by lane. `main`, `memory` and `floor` load 1.0.18;
    `current` and the container load 1.0.22 (`ci.yml:163`, "The runner's libsodium is the floor").
    A text block of `"1.0.18"` is also refused by `check-floors`' docs rule (§4.5).
  - Set B's quick start puts `make build` after the guarded program, its output as a block
    (README §3.2 and §5.1, item 2). Under the sibling's rule, a `text` block of that output, with no
    Scheme block between, becomes the guarded program's expected output, and fails.
- **Why major:** a builder following the plan's wording requires a text block that cannot exist.
- **Fix:** state the sibling's "when", and add: a guarded program has no `text` block before the
  next Scheme block of its page. Show `make build`'s output, if at all, after another Scheme block,
  or in prose.

### M4S0-F3 (major): in slice 1's shared tree, `make test` stops at `check-floors` for all five builders, and the plan drops set A's "red until the join" list

- **Where:** plan §5, `:494-495` ("Before each slice's builders start, the caller writes that slice's
  Makefile lines") and `:512-514`; set A §9, slice 1, "Red until the join".
- **Evidence:**
  - `test` depends on `check-floors` (Makefile `:228`). Today's `check-floors.sps` refuses any count
    of arguments but four: `(if (not (= (length args) 4))`, a usage error (`tests/check-floors.sps:163`).
    With a fifth input written first, every builder's `make test` fails before any suite runs. Once
    1d's version lands, it fails again until 1b's `docs/` exists.
  - The clone check fails until 1b writes README.org's and the quick start's lines, and `test-docs`
    fails until 1b's pages exist. Set A listed these three reds; the plan lists none.
  - Slice 2's worktree has its own reds:
    - `test-manifest` holds "depends/dev is exactly chez-srfi" and "Akku.lock holds exactly one
      project" (`tests/test-manifest.sps:481-488`), so it fails as soon as slice 2 edits
      `Akku.manifest`. That file is 1d's, and the plan routes its rows to the caller at the join;
    - `check-site` fails with no `docs/` and no `** Documentation` (set A `render/run.out`).
      chez-sqlite3 kept a fallback in invariant 7 for exactly this window (its M5 plan, slice 2's
      amendment). The copy has none.
- **Why major:** without the list, builders treat a planned red as their own fault, or report green
  from a partial run.
- **Fix:**
  - The caller writes `check-floors`' fifth input at the join, not before.
  - Each brief names its expected reds and the suites to run directly instead:
    - slice 1: `check-floors` on the real tree, the clone check, `test-docs` on the real pages;
    - slice 2: `test-manifest`, and `check-site` on the real tree (it is run on stub pages in a
      scratch copy instead);
    - each red is cleared at its join.

### M4S0-F4 (major): the worktree mechanics, as written, repeat a trap the ledger records, and slice 3's base is unstated

- **Where:** plan §5, slices 2 and 3 (`:515-524`).
- **Evidence:**
  - `progress.md:696` (M1 slice 2): "the harness's worktrees came from `main`, and fast-forwarding
    one was denied." An Agent `isolation: worktree` would start slice 2 at `d53e83c`, without slice 0.
  - A new worktree's `vendor/chez-srfi` is empty, and `make deps` refuses it (Makefile `:121-125`).
    Filling it is `git submodule update --init`, a host step, which the container cannot run. Slices
    2 and 3 list no such step.
  - Slice 3's `site` job runs `make check-site-deps`, `site-deps`, `check-site` and `site`. P5 runs
    them in `ubuntu:24.04`. Both need slice 2's targets and slice 1's pages. The plan says when
    slice 1 merges into slice 2, but never when slices 1 and 2 merge into slice 3.
  - The sibling's trap: "Research kept only in a git-ignored scratch directory dies with its
    worktree" (`<sibling>/.plans/progress.md:1772-1776`). Builders keep their scratch under `build/`.
- **Fix:**
  - The caller makes each worktree on the host,
    `git worktree add -b m4-slice-N <path> m4-slice-0`, then
    `git -C <path> submodule update --init --recursive`.
  - Slice 3 merges slice 2's branch, which holds slice 1, before P5 and before its PR.
  - Anything a record cites is copied out of a worktree's `build/` before it is removed.

### M4S0-F5 (major): ADR-0013, decision 6, most naturally says the brief's citations stay; the plan removes them

- **Where:** ADR-0013, `:70-73`; plan §4.8, `:399-404`.
- **Evidence:** the ADR reads:

  ```
  - "decision N" and "amended" after an ADR go. A bare `ADR-NNNN` stays;
  - so does the brief cited by section or row;
  ```

  "So does" follows "stays". The plan says the brief by section or row goes, 5 lines. The
  constraints' first paragraph says "where a rule and its record disagree, the record wins", so a
  builder who reads the ADR keeps them.
- **Fix:** "the brief cited by section or row goes too, since `.plans/` is in no archive; a row
  number inside a test's name is a string, and stays."

### M4S0-F6 (major): "What a page may not say" names a message that holds no floor, and misses the ones that do

- **Where:** plan §3, `:208-211` ("nor the unthreaded-Chez refusal, which holds the Chez floor");
  set B §2, "The other two lines".
- **Evidence:**
  - The unthreaded refusal holds no version: "chez-sodium needs a threaded Chez Scheme, and
    (threaded?) is #f in this one. Chez builds threaded unless configured with --nothreads"
    (`require-threaded.sls:79-81`; set B `out/nothreads-message.out`). A page may quote it.
  - These do hold a floor's text, and the finding page or the reference would naturally quote them:
    - **below-floor:** "libsodium 1.0.17 is older than chez-sodium's floor, 1.0.18; …" (set B
      `out/load.out:50`);
    - **a NULL version:** "… and chez-sodium's floor is 1.0.18; …" (`:59`);
    - **a Chez below its floor:** "chez-sodium needs Chez Scheme 10.4.0 or later, and this one is X"
      (`require-threaded.sls:82-87`);
    - **set B's soname line:** "`.so.23` for 1.0.17 and 1.0.18, `.so.26` for 1.0.19 to 1.0.22"
      (§3.1), which the finding page's "the sonames" section would copy;
    - **`make build`'s version line** on Ubuntu's library, and `sodium-version`'s answer at the floor.
- **Why major:** the plan steers 1b away from a safe message and toward the unsafe ones.
  `check-floors` would catch them only at the join.
- **Fix:** replace the clause with the list above: quote none of these; name the soname's releases
  as "the oldest releases chez-sodium takes", or by a link to the Requirements.

### M4S0-F7 (major): the brief's convention row, and two comments the comment pass does not route, still say a salt or tag of the wrong length answers -1

- **Where:**
  - brief §3.4, `:147`: "-1 when … a salt or tag of the wrong length";
  - `tests/test-native-codes.sps:39` and `:565`: "a salt of 21 characters or a tag of 42 is -1";
  - plan §4.8's five comments, which name neither.
- **Evidence:**
  - libsodium requires only a salt of at least 8 bytes and a tag of at least 16
    (`argon2.h:35`, `:62`; `argon2-core.c:265`, `:295`). The ADR-0009 amendment now says so:
    "libsodium decodes a tag at whatever length it finds, at 16 bytes or more".
  - **Probe** (`tag42.sps`, `tag42.out`, both releases). This is the suite's own moderate string,
    its tag cut to 42 characters and its last character swapped, read by `password-needs-rehash?`
    at `'moderate`:

    | Tag's 42nd character | Low 4 bits | needs-rehash |
    |---|---|---|
    | `7`, the suite's | 11 | `#t` (libsodium -1) |
    | `g`, `w`, `A`, `Q` | 0 | **`#f`** (libsodium 0) |
    | `h` | 1 | `#t` |

    Salts of 20 and 16 characters, 15 and 12 bytes, answer `#f` too; 21 answers `#t`, since a lone
    trailing character never decodes.
  - So the row's -1 for "a tag of 42" comes from its fixed string's last character, not from the
    length. It is the same spare-bits effect as §2.2's truncated hash. The row passes
    deterministically, and its comments state a rule that is false.
  - Brief §8.1, row 22 says "every return code §3.4 states, checked against the real library".
    §3.4 now states a code that holds only for some strings.
- **Fix:**
  - Amend brief §3.4's row: -1 for a salt under 8 bytes or a tag under 16, or base64 libsodium
    cannot decode, including spare bits that are not zero.
  - Route the two comments to 1e: a comment-only edit saying the 42-character tag is -1 because of
    its last character's bits. The test name is a datum and stays; it is true of its string.

### M4S0-F8 (major): the export-span rule's exact-name clause can never fail

- **Where:** plan §4.3, `:281-283` ("or exactly `random-bytes`, `blake2b` or
  `constant-time-bytevector=?`, is an export"); `:309-310` (every rule watched failing).
- **Evidence:**
  - A span that is exactly one of those three strings is an export by definition, so the clause
    refuses nothing. `random-byte`, `blake2`, `constant-time-bytevector?` and `random-bytes!` match
    no prefix and no exact name, so they pass unchecked.
  - The sibling's `name-like?` allows only `a-z`, digits, `-`, `!` and `?`
    (`<sibling>/tests/test-docs.sps:663-667`). A copied character set leaves
    `constant-time-bytevector=?` outside the rule under any prefix, since it holds `=`.
- **Why major:** the plan asks a builder to watch fail a clause that cannot fail. AGENTS.md calls
  such a check worse than none.
- **Fix:** prefixes `random-`, `blake2b` and `constant-time-` beside the four, and `=` in the name
  characters. Plant a typo of each, and write `BLAKE2b-512` outside code spans.

---

## Minors

### M4S0-F9 (minor): set B's §1.2, which the plan hands 1a for every entry, says each preset's hash is 97 characters

- **Where:** set B README `:168` ("At the presets it is 97 … computed, not printed"); plan §4.2,
  `:263` ("Each entry, from set B's §1.2").
- **Evidence:** `preset-lengths.out`, both releases: `'interactive` 97, `'moderate` 98, `'sensitive`
  99. The parameter field grows: `m=262144,t=3` and `m=1048576,t=4`.
- **Fix:** correct §1.2, or have the reference state no length.

### M4S0-F10 (minor): ADR-0006's Status puts M4's line before "Its last points added after M3's slice reviews"

- **Where:** ADR-0006 `:13-15`. The other four ADRs append M4's line after that sentence.
- **Why:** "its last points" now reads as if the M4 amendment came before M3's reviews.
- **Fix:** move the line below it, as in ADR-0009, 0011 and 0012.

### M4S0-F11 (minor): ADR-0010's amendment counts Guix's libsodium, "in the container", among "the libsodiums CI runs"

- **Where:** ADR-0010 `:40-42`; ADR-0013, decision 9, "with the libsodiums CI runs"; plan §4.1's
  README Status, "the libraries CI runs".
- **Evidence:** `ci.yml:6-8`: "The Guix container. Nothing in CI runs it."
- **Fix:** "the libsodiums CI runs … and, in the development container, Guix's". Say the same in
  the README's Status.

### M4S0-F12 (minor): the other signature sketches keep the trailing notes ADR-0012 now bars

- **Where:**
  - brief §4, `:176-183`: edited in this slice from `Nat` to `Natural`, but keeping
    `; hash, password` and the rest;
  - ADR-0005 `:39-44`: `Nat`, with the notes;
  - the private libraries' own signature comments: `byte-verbs.sls:83`, `password-verbs.sls:78`,
    `:175` and `:207`. These are 1e's files, and the plan does not say whether their notes move.
- **Fix:** move the brief's notes too, or say it is a sketch, and say in 1e's brief whether the
  private comments follow the public ones.

### M4S0-F13 (minor): needs-rehash's rule is worded two ways, and D10 is not routed

- **Where:**
  - "algorithm and limits": ADR-0009's title, the constraints `:209`, brief §3's table `:61`;
  - "algorithm, parallelism and limits": ADR-0009, decision 1 (`:39`), brief §4.2 (`:229`) and
    AGENTS.md `:82`;
  - D10: AGENTS.md `:76` says "printable ASCII" with no range, and the space is printable ASCII,
    which the pre-check refuses (`password-text.sls:57-64`).
- **Fix:** one wording everywhere. Add "U+0021 to U+007E, so no space" to AGENTS.md, and give 1b
  set B's "no spaces".

### M4S0-F14 (minor): the comment pass's list and counts are off, and "set A's 15 files" is no list

- **Where:** plan §4.8, `:399-404` ("the brief by section or row, 5 lines … about 26 lines in 15
  files"); §5, 1e.
- **Evidence:**
  - The scanner, rerun, is identical to set A's output (`comment-scan.out`).
  - Its own categories give 18 "decision N" lines, 3 "amended" and 7 distinct brief or row lines:
    28 lines in 17 files.
  - Set A's table counts its brief row "5 lines, 5 files" but lists 6. It omits
    `tests/test-password-verbs.sps:208`, "rows 5 and 7's", which are brief §8.1's rows 5 and 7.
- **Fix:** give 1e the exact list of files and lines from the scanner's output, that line included.

### M4S0-F15 (minor): the ledger's "Owed to M4" bullets still state what §3 corrects, and one contradicts the plan

- **Where:** `progress.md:191`, `:200-204` and `:211-212`; plan §8 ("'Owed to M4' brought up to §3").
- **Evidence:**
  - The preamble points to §3, but the bullets still say "or with no overcommit", "about 55 ms",
    "seconds at `'sensitive`", "a stray space or newline", and "never a string the pre-check refuses".
  - The last bullet says the install-line checks "wait for the first release". The plan builds the
    clone check in slice 1, with the lines at 0.0.0.
- **Fix:** restate the bullets as §3 does, or strike each with a pointer. Rewrite the last.

### M4S0-F16 (minor): "confirmed" is used where set B did not measure, and an estimate is called measured

- **Where:**
  - plan `:145` (the engine and two-thread notes, "confirmed") and `:182` (changed-during-call,
    "confirmed"). Set B says "Not re-measured" (`:305`) and "Not re-run" (`:446`), and the plan
    defines "Confirmed" as "set B measured the note as written" (`:141`);
  - plan `:307` ("measured by set A … about 60 s for the suite") and ADR-0013 `:135` ("costs about a
    minute"). Set A §4.2 calls the 60 s "a model (inferred)".
- **Fix:** "confirmed by the records, not rerun"; "an estimate, about 60 s".

### M4S0-F17 (minor): four facts the pages' builders need, which the plan leaves out

- **H1 = the nav label.** `check-site`'s invariant 8 requires each page's first line to be `# ` and
  its label (`<sibling>/tests/check-site.sps:33-34`). 1a, copying the sibling's reference, would
  write "API reference" where the plan's label is "Reference".
- **The README's Requirements list is exactly the two floor lines.** `check-floors` compares every
  list line under `** Requirements` whole, as one list (`tests/floors.sls:45-55`). The test tools go
  in prose, as the sibling's README has them.
- **A link to README.org takes no anchor.** `test-docs` refuses an anchor into a page that is not
  Markdown (`<sibling>/tests/test-docs.sps:10-14`). Set A's stub page used
  `../README.org#requirements`.
- **Two anchor collisions.** By GitHub's rule, `` ### `sodium-failed?` `` and a heading
  `&sodium-failed` both slug to `sodium-failed`; so do `sodium-library-unavailable?` and
  `&sodium-library-unavailable`. A conditions heading takes `-1`, and a link can land on the wrong
  one, with no check noticing.
- **Fix:** state all four in §4.1 to §4.3.

### M4S0-F18 (minor): the release's checks lose three of the sibling's details

- **The live check** has no named home or author. A `main` render fails only its links and clone
  clauses, so the pages clause is never watched failing. The sibling's closing review planted each
  clause (`<sibling>/.plans/2026-11-20-m5-plan.md`, its closing-review amendment).
- **The archive listing** checks only what is absent. The sibling also lists what must be there:
  `src/`, `docs/`, README.org, `LICENSE`, `CHANGELOG.md`, `Akku.manifest` at 0.1.0, and an empty
  `vendor/chez-srfi` (its §4.9, step 9).
- **The required checks are the jobs' `name:` values,** such as
  `site (the docs site, on Ubuntu's Chez)`, not their keys (the sibling's slice 3 amendment). §4.11
  says "all six jobs".
- **`SITE_REF` and `CHEZ_CMARK_GFM_LIBS` are banned in `ci.yml` alone.** `pages.yml`'s build job
  sets `SITE_REF`. §4.7's bullets read as if both files are held to the list.
- **Fix:** name the live check's path (set A suggests the research directory), its three plants, the
  archive's positive list, the six contexts by name, and the banned words' scope.

### M4S0-F19 (minor): a variable set on the host never reaches the container, a sibling trap that chez-sodium's traps do not hold

- **Where:** plan §4.10, step 3 ("`SITE_REF=v0.1.0 make site` is rendered in the container"); any
  floor run of `test-docs`.
- **Evidence:**
  - `scripts/guix-env:33` preserves only `TERM`, `COLORTERM` and `LANG`.
  - `guix-env-enter:34` re-exports `CHEZ_SODIUM_LIBRARY` as the profile's.
  - So `SITE_REF=v0.1.0 scripts/guix-env make site` renders `main`, and
    `CHEZ_SODIUM_LIBRARY=<floor> scripts/guix-env sh -c 'make test'` runs at 1.0.22
    (`<sibling>/.plans/traps.md:961-964`). `both.sh` avoids it by setting the variable inside.
- **Fix:** write each such command as `scripts/guix-env sh -c 'SITE_REF=v0.1.0 make site'`, and copy
  the trap into `.plans/traps.md`.

### M4S0-F20 (minor): the Makefile lines the plan names are not the ones that change

- **Where:** plan §5, `:512`.
- **Evidence:**
  - `SUITES` is `$(sort $(wildcard tests/test-*.sps))` (Makefile `:31`), so `test-docs` and
    `test-reference` need no line.
  - What does change is text the plan does not name:
    - `check-floors`' comment and help, which name four inputs (`:275-284`);
    - `check-ci`'s comment, "its five jobs" (`:286-295`), beside the help line §4.7 names;
    - `check-test-fails`' help and its "13 cases" text, with slice 2's two cases.
- **Fix:** list these lines.

### M4S0-F21 (minor): the walk's two runs each need a word the pages don't yet plan

- **In `ubuntu:24.04`:**
  - the base image has no libsodium; the page must name `libsodium23`;
  - Chez builds with `build-essential` and `./configure --disable-x11 --disable-curses`, as CI's
    package list says (`packaging/debian-prereqs.txt:21-28`). Without those flags the build needs
    X11 and ncurses headers.
- **On the development workstation:** its Chez is Guix's, on another distribution. Discovery sees
  Guix's libc and searches the Guix profiles alone (`discovery.sls:109-118`, `:147-158`). The
  system's `/usr/lib/x86_64-linux-gnu/libsodium.so.23` is never tried, so a profile without
  libsodium answers `not-found`. That is by design, but the finding page's "Who needs the override"
  must say it.
- **Fix:** add these to §4.1's quick start and finding page lines.

---

## The seven items

1. **Facts, §3 and §2.2.**
   - Rerun at both releases:
     - the truncated tag (`truncated-tag.sps`): 22 and 19 of 400 answered `#f`, against the plan's
       "22 to 26". That is about 1 in 16 again, so the range is an observation, not a bound;
     - every one-character change of a real hash, 8649 substitutions: none verifies `#t`
       (`any-change.out`), so "any change" holds;
     - the preset lengths (F9).
   - The caller's correction is right. A claim of the same kind is F7: "a tag of 42 is -1" holds
     for one string's last character, not for the length.
   - Labels and estimates: F16.
2. **Records against each other and the code.** Stale or contradictory: F5, F7, F10 to F13, F15.
   - Every relative link and `#anchor` in `.plans/decisions/`, the plan, the constraints, the
     ledger and both pre-work READMEs resolves by GitHub's rule. `anchors.py` reported 0 bad links,
     and failed on a planted `what-0.1.0-claims`.
   - The five new Status anchors are right, including ADR-0010's `what-010-claims`.
3. **Buildability.** F1 to F4, F8, F17, F20.
   - The five slice-1 builders' files are disjoint. Slices 2 and 3 are disjoint from slice 1 but for
     the Makefile and `test-manifest`, which the plan routes. Existing floors fixtures need no
     `docs/` of their own: `test-check-floors` passes one shared scripts directory, and can pass one
     shared docs directory the same way.
   - The guarded-program rule can work with `sodium-version` alone, the suite reading its own
     answer, once F2 is fixed.
   - The export-span prefixes refuse no legitimate span:
     - `Password-limits` is capitalised, and `sodium_init` has an underscore;
     - `password-hash`'s arguments, `password` and `limits`, carry no prefix;
     - `&sodium-failed` fails the name characters;
     - `chez-sodium`, and archive names holding a `.`, are not name-like.

     The fault is the clauses that cannot fail (F8).
   - The walk is workable as planned, with F21. In `ubuntu:24.04`:
     1. `apt-get install` `build-essential`, `ca-certificates`, `curl`, `git` and `libsodium23`,
        plus `libsodium-dev` for the tests;
     2. Chez from its release tarball, `--disable-x11 --disable-curses`, `make install`;
     3. a clone of the branch;
     4. the quick start's programs, by discovery on Ubuntu's `.so.23` in the FHS world;
     5. `git submodule update --init --recursive` and `make test`, as root.

     No suite depends on a file being unreadable, so running as root changes nothing.
4. **Gaps against chez-sqlite3's M5.**
   - Kept: `SITE_REF`; dropping the environment's `main` rule; Pages set before the tag; the
     Release's byte-for-byte check and its links checked once published; the archive's watched
     failure on `527170d`; the run blocks of `pages.yml` held whole; the tag read back with
     `ls-remote`; the rerun-at-the-tag path.
   - Dropped, and unsafe as written:
     - `check-site`'s invariant-7 fallback, without the reds it covered (F3);
     - the prose rule for the override's source (F1);
     - the "when" of the text-block rule (F2);
     - the live check's per-clause plants and the archive's positive list (F18).
   - Dropped, and safe:
     - the Mac steps, and the memory-timeout slice;
     - the sweep of the Makefile, `scripts/` and `packaging/`: the scan finds nothing banned
       there, and the closing review reruns it;
     - P4 for the site's slug rule on every heading: `check-site`'s invariant 2 catches every
       linked anchor the two rules disagree on.
   - Thin:
     - the docs review that plants faults in the pages, from the sibling's decision 2 and §4.1,
       is not named in the closing review;
     - "the suites run from a clone, not an archive" and `C_INCLUDE_PATH` for another library's
       headers are not in §4.1's quick start items.
5. **The comment rule and the docs rule.**
   - Pages: F6.
   - Comments: the scanner rerun matches set A's output exactly. Its list misses one line (F14).
     The pass misses two false comments (F7), and leaves the private signature comments'
     notes undecided (F12).
   - A grep for `brief`, `§`, `M[0-9]`, `PR #`, finding ids, "no longer" and "first wording" in
     `src/`, `tests/`, `scripts/`, `packaging/` and the Makefile finds nothing beyond the scanner's
     categories.
6. **Privacy and hygiene.**
   - The slice's files hold no home path, no email address and no name of the host's distribution.
     The research masks paths as `<repo>`, `<sibling>` and `<home>`. Its store paths are the
     container's, and `load.out`'s `home` directories are stand-ins under `<repo>/build/`.
   - The brief's "Ubuntu 22.04's package" (`:137`) dates from `527170d` and is not this slice's.
7. **The owner's steps.**
   - The order is sound:
     - `main` is protected as slice 3, the last stacked PR, merges, so `strict` binds only the
       fix PR and the release, each branched from `main`;
     - Pages, the environment's `v*` rule and the ruleset come before the tag;
     - the owner makes, signs, verifies and pushes the tag alone; the caller drafts the Release,
       and the owner publishes it.
   - The live GitHub state agrees with set A: Pages 404, no protection, `rulesets` and
     `environments` empty, no tags or releases.
   - The sibling's ruleset reads `refs/tags/v*`, `update` and `deletion`, no bypass actors. Its
     protection reads `strict` true, `enforce_admins` false.
   - Gaps: the contexts by job name, and the live check's home (F18).

## Where it is sound

- **The needs-rehash restatement is accurate.** ADR-0009's amendment, the brief's §4.2, the
  constraints and AGENTS.md now say what the code checks. The salt and tag bounds were confirmed in
  libsodium's source: 8 and 16 bytes minimum, and `STR_HASHBYTES` 32 with no function for it.
- **§3's corrections hold where rerun:**
  - the entropy abort is at `sodium_init`: `core.c:40` stirs, and `randombytes_sysrandom.c:280-281`
    calls `sodium_misuse`, at both releases;
  - a stored hash changed anywhere verifies `#f`;
  - the truncated tag is randomness, not the release.
- **The test-reference reader keeps working.** It skips each planned note line (`;;   input, size,
  key` has "size," as its second word). Its proposed row, no `;` after a type, is sound.
- **The settings are as reported.** `gh api` reads today match set A's `settings.out`, and the
  sibling's lock entry hashes to `bb647e07…` against its fetched archive.
- **The slice's own hygiene is clean.** Every relative link and anchor in the records resolves. No
  research file leaks a host path, an email address or the host's distribution.

## Probes kept here

| File | What it shows |
|---|---|
| `anchors.py` | every relative link and anchor of the given Markdown files, by GitHub's rule |
| `tag42.sps`, `tag42.out` | F7: a 42-character tag's answer turns on its last character's low bits; salts of 15 and 12 bytes parse |
| `any-change.sps`, `any-change.out` | §3: every one-character change of a real hash verifies `#f`, at both releases |
| `preset-lengths.sps`, `preset-lengths.out` | F9: 97, 98 and 99 characters |

## Commands to rerun

From `<repo>`'s root:

```sh
R=.plans/research/m4-slice-0-review
B=.plans/research/m4-plan/b/probes
python3 -I $R/anchors.py .plans/decisions/*.md .plans/2026-11-25-m4-plan.md \
  .plans/global-constraints.md .plans/progress.md \
  .plans/research/m4-plan/a/README.md .plans/research/m4-plan/b/README.md   # bad links: 0
scripts/guix-env sh $B/both.sh $R/tag42.sps                                  # tag42.out
scripts/guix-env sh $B/both.sh $R/any-change.sps                             # any-change.out
scripts/guix-env sh $B/both.sh $R/preset-lengths.sps                         # preset-lengths.out
scripts/guix-env sh $B/both.sh $B/truncated-tag.sps                          # (378 22), (381 19) here
python3 -I .plans/research/m4-plan/a/comment-scan.py . | diff - .plans/research/m4-plan/a/comment-scan.out  # no output: same
sed -n 160,170p tests/check-floors.sps                                       # four arguments only
sed -n 1501,1512p ../chez-sqlite3/tests/test-docs.sps                        # one FILE per cell
sed -n 663,667p ../chez-sqlite3/tests/test-docs.sps                          # no = in a name
grep -n 'Its last points\|Amended 2026-11-25' .plans/decisions/0006-errors-and-no-secret-shown.md
sed -n 70,73p .plans/decisions/0013-the-first-release.md
for p in pages branches/main/protection rulesets environments tags releases; do
  gh api repos/Kiyomi-Computation-Systems/chez-sodium/$p; done                # read-only
```
