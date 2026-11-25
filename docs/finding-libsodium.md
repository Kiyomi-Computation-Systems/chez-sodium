# Finding libsodium

chez-sodium loads libsodium once, the first time your program needs it.
This page says which file it picks, why it can refuse one, and how to name
your own.

## Name it yourself

Set `CHEZ_SODIUM_LIBRARY` to the library's absolute path:

```sh
export CHEZ_SODIUM_LIBRARY=/opt/libsodium/lib/libsodium.so.26
```

chez-sodium loads that file as given, with no search of its own, and has
nothing to fall back to. A relative path, a bare name and `""` are refused.
It never reads `LD_LIBRARY_PATH`.

## Or let it look

With `CHEZ_SODIUM_LIBRARY` unset, it takes the first file that exists on a
short list. In each folder it tries `libsodium.so.26` first, then
`libsodium.so.23`. The list depends on which C library Chez runs on:

| System | Where it looks, in order | Source |
|---|---|---|
| Linux, when Chez runs on Guix's C library, as Guix's Chez does | `libsodium.so.26`, then `libsodium.so.23` in `$GUIX_ENVIRONMENT/lib`, `$GUIX_PROFILE/lib`, `~/.guix-home/profile/lib`, `~/.guix-profile/lib`, then `/run/current-system/profile/lib` | `guix-environment`, `guix-profile`, `guix-home`, `guix-user-profile`, `guix-system` |
| Other Linux | `libsodium.so.26`, then `libsodium.so.23` in `/usr/local/lib`, `/usr/lib/x86_64-linux-gnu` (`/usr/lib/aarch64-linux-gnu` on arm64), `/usr/lib64`, then `/usr/lib` | `system` |

A `GUIX_ENVIRONMENT` or `GUIX_PROFILE` that is unset, empty or not an
absolute path adds nothing.

The source names where a file came from: `make build` prints it beside the
path it loaded, and `sodium-library-unavailable-source` gives it for a file
that was refused. It is `override` for `CHEZ_SODIUM_LIBRARY`.

## Which file name

libsodium's newer releases are `libsodium.so.26`. The oldest releases
chez-sodium takes, Ubuntu 24.04's among them, are `libsodium.so.23`. The
name never decides whether a library is new enough: its version does, and
one too old is refused. The bare `libsodium.so`, which a `-dev` package
adds, is never tried.

## When it is refused

When no file can be chosen, or the chosen one fails to load or fails its
checks, the load is refused, and no other file is tried. The refusal is a
condition that `sodium-library-unavailable?` holds, and
`sodium-library-unavailable-reason` gives one of these:

| Reason | Why |
|---|---|
| `invalid-override` | `CHEZ_SODIUM_LIBRARY` is set, but not to an absolute path. |
| `not-found` | No file on the list exists. `sodium-library-unavailable-candidates` gives every path it looked at. |
| `load-failed` | The system's loader refused the file, as when an override names no file, or a file that is no shared library. |
| `below-floor` | The library is older than [README.org's Requirements](../README.org) allow, or its version can't be read. |
| `missing-api` | The library lacks a function chez-sodium needs. |
| `init-failed` | libsodium's own start-up, `sodium_init`, failed. |

Each refusal's message says what to do. `sodium-library-unavailable-path`,
`sodium-library-unavailable-source` and `sodium-library-unavailable-detail`
give the details: the path, where it came from, and more by reason, such as
the loader's message or the version found. The fix is to name a libsodium
that passes with `CHEZ_SODIUM_LIBRARY`; or, with it unset, to install one
where the list looks before the file refused, such as `/usr/local/lib`.

## Who needs the override

- **Ubuntu 24.04:** no one, with its `libsodium23` package installed.
- **Guix:** no one, when libsodium is in the profile or the `guix shell`.
- **A Chez from Guix, on another distribution:** it runs on Guix's C
  library, so chez-sodium looks only in Guix profiles, never in `/usr/lib`.
  A profile without libsodium is `not-found`. That is by design: add
  libsodium to the profile, or name a file.
- **A library off the list,** such as one under `/opt`, one from Nix, or
  your own build installed outside the list's folders.
- **A system whose libsodium is too old:** it is found, then refused as
  `below-floor`. Name a newer one.

## It loads once

The load runs once per process, at the first use of a name that needs
libsodium. A refusal is remembered: every later use raises the same
condition, and setting `CHEZ_SODIUM_LIBRARY` afterwards changes nothing.
Fix the cause, and start the program again.

- **A program that names a verb loads libsodium as it starts,** before its
  first line runs, so a `guard` in it can't catch a refusal. Reach the
  library through `eval` inside the `guard` instead, as the
  [quick start](quickstart.md#which-libsodium-did-it-load) shows. The
  conditions' predicates and accessors load nothing.
- **Through `eval` or the REPL, reach it once, on one thread, before
  engines or other threads can.** A first use inside an engine that is then
  dropped leaves the library unusable until the process restarts. Two
  threads that first reach it at once give the second Chez's own "cyclic
  dependency" error, not a refusal; a later use works.
- **If another library in the process started libsodium first,**
  chez-sodium loads all the same.
