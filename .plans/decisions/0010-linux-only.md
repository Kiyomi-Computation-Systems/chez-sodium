# ADR-0010: Linux only

- **Status:** Accepted (the owner, 2026-11-22), approved with the brief. Amended 2026-11-25 in
  M4's plan, and accepted by the owner that day
  ([amendment](#amendment-2026-11-25-what-010-claims-m4s-plan)).
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

## Amendment, 2026-11-25: what 0.1.0 claims (M4's plan)

Accepted (the owner, 2026-11-25), proposed in [the M4 plan](../2026-11-25-m4-plan.md), §2.1, Q4
item 4, with [ADR-0013], decision 9.

- **0.1.0 claims Linux on x86_64,** with the libsodiums CI runs: Ubuntu 24.04's package, found by
  discovery, and the floor and the current release, each built from source. The development
  container runs Guix's, which no CI job runs. Every CI job runs on `ubuntu-24.04`, x86_64.
- **Linux on arm64 is named as not run,** in README.org's Status and the changelog's Known
  limitations. Discovery's `aarch64-linux-gnu` directory is written, but no run has reached it.
- **No arm64 job is added.** One would be a seventh job, a change to `check-ci`'s shape, for a
  platform Techo does not run. A later record can add one.

[ADR-0002]: 0002-runtime-discovery-and-the-sonames.md
[ADR-0013]: 0013-the-first-release.md
