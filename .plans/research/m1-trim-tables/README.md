# M1's trim tables

Each of M1's builders, before writing any code, wrote down every part of the chez-sqlite3 v0.1.1
(`960d9f0`) file it was to copy:
- whether that part was kept, changed or dropped;
- for each drop, what the part protected, and where that protection lives here now, or why
  nothing here needs it.

The caller checked each reason before any code was written (plan §2). They are the record behind
the plan's "Dropped" columns. M3 copies more of v0.1.1, `call-with-c-string` among it, and reads
them first.

| File | Slice | Covers |
|---|---|---|
| [slice1-core-trim.md](slice1-core-trim.md) | 1 | `conditions`, `load-state`, `discovery` and `verify`, and their suites |
| [slice2-load-trim.md](slice2-load-trim.md) | 2 | `memory`, `native`, the oracle, `preflight`, `test-wipe` |
| [slice2-seam-trim.md](slice2-seam-trim.md) | 2 | `check-seam`, its suite and fixtures, the Makefile's targets |
| [slice2-conventions-trim.md](slice2-conventions-trim.md) | 2 | `foreign-conventions`, `test-conventions`, `test-constants` |
| [slice3-refusals-trim.md](slice3-refusals-trim.md) | 3 | the decoy, the probe, `library-loading` and its six suites, `check-dev` |
| [slice3-ci-trim.md](slice3-ci-trim.md) | 3 | `main`'s install check in `ci.yml` and `check-ci` |
| [slice4-public-trim.md](slice4-public-trim.md) | 4 | `(chez-sodium)`, `test-public`, `test-never-loads` |
| [slice5-scripts-trim.md](slice5-scripts-trim.md) | 5 | `build-sodium.sh`, `check-sodium.sh`, `test-ci-sodium` |
| [slice5-lanes-trim.md](slice5-lanes-trim.md) | 5 | the `floor` and `current` jobs, and `check-ci`'s rules for them |

Each is as its builder wrote it, with local paths replaced by `<repo>`, `<scratch>`, `<home>` and
`<store>`. Flags in them, F1, F2 and so on, are the builder's own, and were settled as the slice's
mutation log and the plan's edits record.
