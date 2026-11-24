# M3 plan's probes

The measurements behind [the M3 plan](../../2026-11-24-m3-plan.md)'s §5.1. Two Sonnet agents took
them, each in a directory of its own, and the caller reran each set:

- **[Set A](a/README.md):** the headers, the prototypes, the decoy's pointer rule, the constants,
  every return code on four libraries, and short memory against a wrong password.
  - Rerun by the caller: items 2 to 5 reproduce line for line, once the random salts and tags are
    masked.
  - The source lines of item 6 were read again at both releases.
- **[Set B](b/README.md):** the costs, the password's UTF-8 writer, collect-safe by behaviour
  inside and outside a critical section, and the types `__collect_safe` takes.
  - Rerun by the caller: items 2 and 4 reproduce exactly.
  - Item 3 reproduces: all 20 collect-safe runs are released by the collector, and all 20 plain runs
    by the watchdog. The worst rendezvous under Valgrind was 17 ms, against the agent's 12 ms.
  - A minimum-limits hash costs the same, 0.013 ms plain and 0.36 ms under Valgrind.

They ran from `build/m3-plan/a/` and `build/m3-plan/b/`, which the container can see. To rerun
one, copy its directory there, since the scripts find the libraries at `../../slice5/` and
`../../m1-plan/`.

The outputs' paths read `<repo>` and `<home>`, and the container profile's library reads
`<profile>`. Compiled programs are not kept.
