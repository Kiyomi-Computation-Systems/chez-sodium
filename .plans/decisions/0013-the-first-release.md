# ADR-0013: The first release: five pages held to the code, a site from the tag, and a signed 0.1.0

- **Status:** Accepted (the owner, 2026-11-25), proposed in [the M4 plan](../2026-11-25-m4-plan.md),
  §2 and §4. The owner answered the plan's four questions that day, each with its recommendation.
- **Date:** 2026-11-25
- **Scope:** `docs/`, README.org, `test-reference`, `test-docs`, the docs site and its CI, the
  comment pass, CHANGELOG.md, `Akku.manifest`'s version, and the release's steps
- **Settles:** [brief](../2026-11-22-chez-sodium-project-brief.md) §4's reference, §7.1's site row,
  and §9's M4 row
- **Related:** chez-sqlite3 ADR-0022, which this follows · chez-curl ADR-0042 (the Release's
  recipe) · [ADR-0010] (Linux only) · [ADR-0011] (the harness, amended for the site) · [ADR-0012]
  (the signature comments)

## Context

- **M0 to M3 built every verb Techo's first release needs,** each export with a signature comment,
  and left 20 notes "Owed to M4" for the documents (progress.md). README.org still described one
  verb.
- **chez-sqlite3's M5 made its first release the same way:** pages held to the code by
  `test-reference` and `test-docs`, a site on GitHub Pages deployed by the tag, a signed tag, and a
  GitHub Release (chez-sqlite3 ADR-0022). Its generator is brief §7.1's "copy nearly as it is".
- **Some of that is here already:** `.gitattributes` keeps `.plans/` and `AGENTS.md` out of every
  archive, held by `test-manifest`, and CHANGELOG.md's reader holds Keep a Changelog's form
  ([the M4 plan's pre-work](../research/m4-plan/a/README.md), §1).
- **Nothing on GitHub is set yet:** Pages is off, there is no environment, `main` is unprotected,
  and there is no ruleset (pre-work A, §5.4).
- **Every fact the pages will state was checked** against the code and the real library, at the
  floor and at 1.0.22 ([pre-work B](../research/m4-plan/b/README.md)). Six of the notes needed
  correcting (the M4 plan, §3).

## Decision

1. **v0.1.0 is a signed, annotated tag** on the squash of the release's PR. The owner makes, signs
   and pushes it with the release key that signs chez-sqlite3's tags, and reads `git tag -v v0.1.0`
   before the push.
2. **The docs are five pages and README.org:**
   - `docs/` holds a quick start, which is the site's home, passwords, tokens, finding libsodium,
     and the reference, in that order. `site/pages.sls` writes the order once, and README.org's
     Documentation list holds it;
   - README.org follows the siblings' order: what it is, the AI disclosure, Status, Requirements,
     Installing, a taste, the pages and the site, and the licence. Its Status names the platform
     and the libraries CI runs, and no version. It links nothing under `.plans/`;
   - **its one Scheme block is a twin:** `test-docs` holds it equal, line for line, to the whole of
     a `scheme run` block of a page, so it runs through its twin;
   - **no page restates a floor:** `check-floors` reads `docs/` ([ADR-0011], amended);
   - each safety note sits on the page where a reader needs it. There is no safety page and no
     examples page.
3. **The reference is one entry per export, held to the code:**
   - each entry is a `` ### `NAME` `` heading with one `text` block, `NAME : TYPE`;
   - `test-reference` holds the block to the export's signature comment, character for character,
     and the exports to the entries, as whole lists;
   - a signature comment is its type alone ([ADR-0012], amended).
4. **`test-docs` holds every page, and installing is a clone:**
   - it holds chez-sqlite3's rules, adapted (the M4 plan, §4.3). Run blocks are evaluated in
     `(rnrs)` and `(chez-sodium)`; whole programs run through `gated-command`; and
     `finding-libsodium.md`'s tables are held to discovery's code;
   - its password blocks hash at the default, the call a reader copies ([ADR-0011], amended);
   - **installing is a clone of the tag,** with its `src` on Chez's library path and nothing built.
     Every `git clone` line of README.org, and of any file under `docs/`, names the manifest's
     version's tag, or, at 0.0.0, no branch. `test-manifest` holds it.
5. **A docs site on GitHub Pages from v0.1.0:**
   - chez-sqlite3's generator, `build-site.sps` and `site/`, its suites and `check-site`, and the
     targets `site-deps`, `site`, `check-site` and `check-site-deps`;
   - chez-cmark-gfm, a second `depends/dev`, and cmark-gfm in the container ([ADR-0011], amended);
   - a sixth CI job, `site`, and a second workflow, `pages.yml`, which deploys on a `v*` tag's
     push. `check-ci` holds both;
   - Pages is built from GitHub Actions. Its `github-pages` environment takes the tag rule `v*`
     alone, set before the tag, so the tag's push deploys the first site, its links naming
     `blob/v0.1.0/`.
6. **The comments carry no history,** as AGENTS.md's rule has required since PR #1. One pass
   before the tag removes the rest:
   - "decision N" and "amended" after an ADR go. A bare `ADR-NNNN` stays;
   - so does the brief cited by section or row;
   - each edited Scheme file reads as the same datums, each changed shell line is a whole-line
     comment, and each C file compiles to the same object.
7. **A release archive leaves out `.plans/` and `AGENTS.md`,** by `.gitattributes`, as it has since
   M0. Each tag's archive is listed after its push.
8. **No Akku publish at 0.1.0** (brief §11.8). `Akku.manifest`'s 0.1.0 is for `test-manifest`.
9. **0.1.0 claims what ran:** Linux on x86_64, with the libsodiums CI runs. Linux on arm64 is named
   as not run, in README.org and the changelog's Known limitations ([ADR-0010], amended).
10. **The docs state what M1 to M3 owe them,** as the M4 plan's §3 corrects them. A time is the
    development workstation's, written "about … here".
11. **CHANGELOG.md's `[0.1.0]`** is in Keep a Changelog's form:
    - an intro;
    - Added, by area, linking each page;
    - Known limitations;
    - link references closing the file.

    It is dated by the release branch's local day. `Akku.manifest` names 0.1.0 and the clone lines
    its tag, so `test-manifest` fails a release that moves one alone.
12. **A GitHub Release for every tag from v0.1.0,** by chez-curl ADR-0042's recipe:
    - made on the host with `gh`, from the tag with `--verify-tag`, first as a draft;
    - titled by the tag message's subject;
    - its notes the tag's CHANGELOG entry, the intro to the last bullet;
    - its body read back and compared byte for byte, then published, then read again.

    Nothing in the tree changes.
13. **The release's steps, in order,** each recorded in its close-out (the M4 plan, §4.10):
    - CI on the release branch, then the squash merge;
    - `main`'s run read, and the squash's tree compared with the branch's;
    - the settings read;
    - the live check watched failing before the deploy;
    - the tag, then its CI and Pages runs read;
    - the site checked live;
    - the Release;
    - the archives listed;
    - the README's clone line run verbatim;
    - Techo told the tag's commit.

    Before the tag, `main` is protected, with every CI job required, `strict`, and a "release tags"
    ruleset refuses the update and deletion of `v*`, with no bypass.

### Rejected

- **Tightening `password-needs-rehash?` before the docs describe it** (the M4 plan, §2.2): no
  string check finds a damaged hash, and the tag's size would be a constant libsodium has no
  function for. [ADR-0009], amended, restates the rule as built.
- **Four pages, with tokens in the quick start;** and **seven, adding examples and safety:** the
  first crowds the quick start, and the second splits notes from the verbs they concern.
- **Cheap limits in the docs' examples,** which would teach the weakest limits; and **unrun
  password fragments,** which would leave the examples a reader copies unchecked.
- **Trailing notes kept in the signature comments,** which the reference would have to repeat,
  padding and all.
- **The tag alone, with no Release:** a later change of mind makes Releases for old tags.
- **An unsigned tag:** a signature cannot be added to a pushed tag without moving it.
- **An arm64 lane before the tag:** a seventh job, and a changed `check-ci` shape, for a platform
  Techo does not run.
- **`main` left unprotected:** a required check is what makes the site job bind a merge.

## Consequences

- **The pages cannot drift from the code silently.** A change to an export's signature fails
  `test-reference`; a change to discovery or the refusal reasons fails `test-docs`; a floor's move
  fails `check-floors` on any page that restates it.
- **`test-docs` costs about a minute under the gate,** most of it gated whole programs (pre-work A,
  §4.2).
- **Each later release** dates its entry, bumps the manifest and the clone lines together, signs
  its tag, and makes its Release by the same recipe.
- **Publishing on Akku stays a later decision,** after Techo has battle-tested the library
  (brief §11.8).

[ADR-0009]: 0009-what-needs-rehash-means.md
[ADR-0010]: 0010-linux-only.md
[ADR-0011]: 0011-the-harness-after-chez-sqlite3.md
[ADR-0012]: 0012-the-public-library-and-the-seam.md
