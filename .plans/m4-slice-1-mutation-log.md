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
