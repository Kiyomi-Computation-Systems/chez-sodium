# M4's closing review's fixes: mutation log

Each check watched failing, by a mutant in a whole copy of the tree, never in place.

## The fix agents

- **`test-docs`** (Sonnet), M4C-F8: [research/m4-slice-1/1c.md](research/m4-slice-1/1c.md), "After the
  closing review": nine mutants, each failing the row for its rule.
- **The site and the Makefile** (Sonnet), M4C-F5, F9, F10: [research/m4-slice-1/1f.md](research/m4-slice-1/1f.md),
  "After the closing review": five of six mutants fail. The survivor, `check-site`'s refusal of a
  release-like ref turned off, is held only by a run of `check-site` with the tag, as `pages.yml`
  runs it.
- **The pages** (Opus), M4C-F3: the "All together" program's `(eq? hash no-account)` line removed,
  in a copy: `test-docs` fails, "docs/passwords.md:141: the whole program, run as written, prints
  the text block after it", `refused` become `logged-in`.
- **Comments and the synopsis** (Sonnet): the datum check, watched failing on a planted rename,
  then the same for both edited files.

## The caller's

| Guards | Mutation | Result | Clean rerun |
|---|---|---|---|
| the reference's refusal lists, both ways (M4C-F8) | `random-bytes`' `over-the-cap` bullet dropped from `docs/reference.md` | "each verb's entry names each reason the verb raises…" fails | 158 of 158 |
| `check-site`'s release-like refs (M4C-F5) | `SITE_REF=v0.1.0-rc.1`, then `v0.2` | both exit 2 | `main` exits 0 |
| `test-native-codes`' 0xC3 row, made deterministic (the flake of PR #19's run) | the row's salt chosen to begin with `/`, at 1.0.18 | fails, `(0 0)` for `(0 -1)`, which is CI's failure | 32 of 32, at 1.0.22 and at the floor |
| the new alias row | its salt chosen not to begin with `/`, at 1.0.18 | fails, -1 for 0 | 32 of 32 |

**In the container, after the fixes:** `make test` 44 of 44, `check-test-fails` 18 cases,
`check-site` all green, `check-clean`, `make build` with no block left.
