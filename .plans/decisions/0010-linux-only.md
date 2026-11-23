# ADR-0010: Linux only

- **Status:** Accepted (the owner, 2026-11-22), approved with the brief.
- **Date:** 2026-11-22
- **Scope:** chez-sodium, until a later decision record reverses this one
- **Settles:** [brief](../2026-11-22-chez-sodium-project-brief.md) §7.2 (Techo ADR-0001)
- **Related:** chez-sqlite3 ADR-0004, whose form this follows · Techo ADR-0001 ·
  [ADR-0002] (discovery)

## Context

- **Techo runs on Linux** (Techo ADR-0001). It is deployed as a Docker container on a Linux
  server, its CI runs on Linux, and it sets up no macOS runner.
- **AGENTS.md: "DO NOT setup macos CI runners: linux only!"**
- **chez-sqlite3 supports Linux and macOS** (chez-sqlite3 ADR-0004). Its discovery has a macOS
  candidate, and macOS is checked there by hand on a Mac.

## Decision

**chez-sodium supports and tests Linux alone.** There are no macOS or Windows code paths, no
macOS or Windows CI, and no abstraction that exists only so another platform could be added
later.

## Consequences

- **Discovery knows Linux's two worlds alone,** Guix and FHS ([ADR-0002]).
- **CI is Linux only,** and nothing is run by hand on a Mac.
- **Assumptions that hold only on Linux need no flag:** `/proc/self/maps` and the
  `libsodium.so.N` sonames ([ADR-0002]), for example.
- **Nothing is promised or tested on another platform.**
- **Reversing this takes its own decision record, and real work.**

[ADR-0002]: 0002-runtime-discovery-and-the-sonames.md
