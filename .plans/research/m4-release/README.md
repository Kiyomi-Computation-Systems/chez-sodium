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
