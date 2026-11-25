# The release of 0.1.0: its checks

The M4 plan's §4.10, step by step, as each ran. `<repo>` is the checkout.

## Before the tag

- **The repository's settings,** set by the caller with `gh api` at the owner's word (2026-11-25,
  "You set them via gh api"), after M4's closing PR was green, and read back. Each matches
  chez-sqlite3's:
  - `main` protected: the six jobs required by their `name:`, `strict`, `enforce_admins` off,
    no force push and no deletion;
  - Pages on, built from GitHub Actions, at `https://kiyomi-computation-systems.github.io/chez-sodium/`;
  - the `github-pages` environment: the tag rule `v*` alone. The Pages API added a `main` branch
    rule, which the caller deleted;
  - the "release tags" ruleset: active, `refs/tags/v*`, refusing `update` and `deletion`, with
    no bypass actor;
  - private vulnerability reporting on, since slice 1's review.
- **The release branch,** `m4-release`, from `main` at `aee5f90`:
  - CHANGELOG.md's `[0.1.0] - 2026-11-25`, the branch's local day, with its link references;
  - `Akku.manifest` at 0.1.0, its comment naming the clone lines;
  - both clone lines at `--branch v0.1.0`;
  - README.org's link to the site, put back;
  - the quick start's note that git may warn the tag "is not a commit!".
- **In the container:** `make test` 44 of 44; `SITE_REF=v0.1.0 make check-site` all green, its
  ninth invariant passing now the manifest reads 0.1.0; and the site rendered into an empty
  `build/site` with `SITE_REF=v0.1.0`.
- **The live check,** [live-check.sh](live-check.sh), chez-sqlite3's with the repository and the
  page list changed. On loopback ([run-live.sh](run-live.sh), [run-live.out](run-live.out)):
  - the `v0.1.0` render passes;
  - `main`'s render fails the links clause;
  - a render with `tokens.html` removed fails the pages clause;
  - a render whose quick start clones with no `--branch` fails the clone clause.
- **`pages.yml`'s build on Ubuntu's Chez 9.5.8,** in `ubuntu:24.04`
  ([ubuntu-check.sh](ubuntu-check.sh)), on the branch's tree without `build/`: the site's packages,
  `make site-deps`, then `check-site` and `site` with `SITE_REF=v0.1.0`, all green, the clone line
  `--branch v0.1.0` and the links `blob/v0.1.0/`. It ran with the network, to install the
  packages, not offline as the plan's step 3 has it; what it shows is the same.

## The merge, the tag and after

- **The merge:** the release PR, #21, squash-merged as `981ba2e`, its tree equal to the tested
  head's (run 45648811236, all six jobs).
- **The tag,** made by the caller at the owner's word ("you do ritual and you do the tagging"),
  after the owner's own attempt had found `main` still before the merge and created nothing:
  - checked absent, locally and on `origin`, and the settings read once more;
  - `git tag -s -u CC2923E50902E936049B696B9EBA259B8EAC5130 -F tag-message.txt v0.1.0 981ba2e`,
    the release key that signs chez-sqlite3's tags, its passphrase already cached by gpg-agent.
    The message is [out/tag-message.txt](out/tag-message.txt), its subject the Release's title;
  - `git tag -v v0.1.0`: a good signature from the release key ([out/tag-v.txt](out/tag-v.txt));
  - pushed alone. `git ls-remote` reads the tag object `b8c5acb` and `^{}` `981ba2e`, as they are
    locally.
- **The order changed in one place:** the plan reads `main`'s push run before the tag. The tag
  was made while `main`'s run, 45660098876, was still running, on the tree the release PR's run
  had passed, so the owner was at hand for the key; both runs were read after.
- **The tag's runs:** Pages, 45660318750, built and deployed. CI, 45660318788, passed all six
  jobs, and so did `main`'s push run, 45660098876.
- **The live site:** [live-check.sh](live-check.sh) exits 0 against
  `https://kiyomi-computation-systems.github.io/chez-sodium/` ([out/live-site.txt](out/live-site.txt)).
  Each of the five live pages equals, byte for byte, a render of the tag in the container with
  `SITE_REF=v0.1.0`.
- **The archives:** GitHub's tarball ([out/github-tarball.txt](out/github-tarball.txt)) and
  `git archive v0.1.0` ([out/git-archive.txt](out/git-archive.txt)) list the same 758 entries but
  the tarball's `chez-sodium-0.1.0/` prefix. Neither holds `.plans/` or `AGENTS.md`; the same
  count on `527170d` gives 71. Both hold `src/`, `docs/`, README.org, `LICENSE`, `CHANGELOG.md`,
  `Akku.manifest` at 0.1.0, and an empty `vendor/chez-srfi/`.
- **The clone line:** README.org's, run verbatim in a fresh directory, cloned `981ba2e`, git
  printing its detached-HEAD advice as the quick start says. The quick start's first program,
  taken from that clone's page, printed `(#t #f 32)` at 1.0.22 and at the floor.
- **The Release,** by chez-curl ADR-0042's recipe:
  - the notes: [extract.py](extract.py) `v0.1.0 0.1.0` gave [out/notes-v0.1.0.md](out/notes-v0.1.0.md),
    3155 bytes, the entry from its intro to its last bullet, with no link reference;
  - the draft, 458397348: `gh release create v0.1.0 --verify-tag --draft`, titled by the tag
    message's subject; [check.py](check.py) found its body the notes, byte for byte
    ([out/check-draft.txt](out/check-draft.txt));
  - published at the owner's word ("yes publish release on green"), once the tag's CI run was
    green, as the latest: `gh release edit v0.1.0 --draft=false --latest`. check.py found the
    published body the notes, byte for byte ([out/check-published.txt](out/check-published.txt)),
    and `releases/latest` answers v0.1.0;
  - its links: all 9 in the rendered body name `blob/v0.1.0/`, none `blob/main` or `untagged-`
    ([out/release-links.txt](out/release-links.txt)), and each file is in the tag.
