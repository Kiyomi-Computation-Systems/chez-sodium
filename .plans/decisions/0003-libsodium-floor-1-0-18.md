# ADR-0003: The libsodium floor is 1.0.18, read from the version string

- **Status:** Accepted (the owner, 2026-11-22), brief §11.7. Decisions 4 and 5, the versions
  tested, are brief §11.5; decision 6, the tarball, is brief §7.2 (P-F16).
- **Date:** 2026-11-22
- **Scope:** every libsodium chez-sodium loads, and the ones CI tests
- **Settles:** [brief](../2026-11-22-chez-sodium-project-brief.md) §3.4, §7.2, §8.3, §11.5's
  supported versions and §11.7's floor
- **Related:** chez-sqlite3 ADR-0003, whose form this follows · [ADR-0002] (where the check
  runs) · [ADR-0011] (where the floor is written)

## Context

What ships where (brief §8.3, from packages.ubuntu.com on 2026-11-22; the review):

| Where | libsodium | Package or soname |
|---|---|---|
| Ubuntu 22.04, 24.04 and 26.04 | 1.0.18 | `libsodium23` |
| Ubuntu 24.04, exactly (CI's `main`) | 1.0.18 | `1.0.18-1ubuntu0.24.04.1` |
| Ubuntu 26.10 | 1.0.22 | `libsodium26` |
| Guix, at the pinned channel `b532aa7` | 1.0.22 | `libsodium.so.26` |

- **`sodium_version_string` answers the release,** `"1.0.18"`, before `sodium_init`.
- **`sodium_library_version_major` and `_minor` are libtool numbers, not the release:** 10.3 at
  1.0.18, and 26.1 to 26.4 at 1.0.19 to 1.0.22 (L-F14). No floor held to `floors.sexp` can be
  read from them (X-M5, P-F2).
- **1.0.17 shares 1.0.18's soname,** `libsodium.so.23` ([ADR-0002]).
- **Every function bound exists at 1.0.18** (brief §3.4; X-m3).

## Decision

1. **The floor is 1.0.18,** written once, as `(sodium "1.0.18")` in `packaging/floors.sexp`
   ([ADR-0011]).
2. **The floor is read from `sodium_version_string`,** parsed strictly as three naturals and
   compared with the file. A lower version is refused as `below-floor` ([ADR-0002]), 1.0.17
   among them.
3. **Major and minor are reported beside the string, never compared.**
4. **Supported versions** (brief §11.5):
   - test the floor, Guix's version and the latest point release;
   - bump `current` at each point release;
   - raise the floor only by a record.
5. **Where each runs** (brief §8.3):

   | libsodium | Where | Why |
   |---|---|---|
   | 1.0.18, Ubuntu 24.04's package | CI's `main`, found by discovery. `main` asserts that it loaded the floor. | a distribution's build, with its own patches |
   | 1.0.18, built from `libsodium-1.0.18.tar.gz` | CI's `floor`, through `CHEZ_SODIUM_LIBRARY` and `C_INCLUDE_PATH` | ours, with known flags. chez-sqlite3 runs both for the same reason (P-F3). |
   | 1.0.22, Guix's at `b532aa7` | the development container | |
   | the latest point release, built from source | CI's `current`, through `CHEZ_SODIUM_LIBRARY` and `C_INCLUDE_PATH` | 1.0.22 today |

   1.0.19 to 1.0.21 share `libsodium.so.26` and are not run.
6. **CI builds libsodium from a point-release tarball,** never `-stable` or `LATEST`, which are
   rebuilt in place. It pins a SHA-256 the project computes itself, checked once against the
   `.minisig` with libsodium's published minisign key. It falls back to `releases/old/`, where
   older tarballs move (P-F16).

### Rejected

- **A higher floor.** 1.0.18 is the only version on every Ubuntu LTS still supported, so a
  higher floor would exclude them all (brief §11.7).
- **Reading the floor from major and minor.** They are libtool numbers (L-F14).

## Consequences

- **No entry point is optional:** every one exists at the floor ([ADR-0002]).
- **Every supported Ubuntu LTS ships a libsodium at the floor.**
- **A row holds decision 2** (brief §8.1, row 20): a decoy whose version string and major and
  minor disagree shows that the string decides.
- **Raising the floor** is a new record, and the edits chez-sqlite3 ADR-0008 lists
  ([ADR-0011]).

[ADR-0002]: 0002-runtime-discovery-and-the-sonames.md
[ADR-0011]: 0011-the-harness-after-chez-sqlite3.md
