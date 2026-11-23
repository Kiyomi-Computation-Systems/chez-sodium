# M1 slice 5's review

Read-only and adversarial, on Opus, over slice 5: CI's `floor` and `current` lanes, the libsodium
scripts and their suite. Its line numbers are those of the tree it read. How each finding was
resolved is at the end.

Read-only, adversarial, on `m1-slice-5` (working tree over `f875188`). No project file was changed;
every probe ran in a copy under the scratchpad (`review-s5/`, removed at the end), in the container
or on the host as noted. "Host" means the development workstation, Ubuntu 22.04-based: `/usr/bin/dash`, mawk 1.3.4,
Ubuntu GCC 11.4, GNU tar, Ubuntu's `libsodium23` 1.0.18-1ubuntu0.22.04.1, and the Guix-home Chez
10.4.0.

**Counts:** 0 blockers, 2 majors, 10 minors.

## Findings

### S5-F1 (major): `test-ci-sodium` reads the floors file unguarded at top level

- **Where:** `tests/test-ci-sodium.sps:1562`, `(define real-floor (floor-text (read-floors) 'sodium))`,
  used by the row at `:1564-1570`.
- **Rule:** AGENTS.md: "SRFI-64 does not catch an exception ... in a suite's top-level
  definitions: the suite dies and no test is named. Compute anything that can raise under a
  guard." The plan §6 brief list repeats it. `test-verify.sps:99-101` and
  `test-require-threaded.sps:79-82` guard the same call with a sentinel.
- **Probe:**
  - Guard: the rule above.
  - Mutation: a copy whose `packaging/floors.sexp` holds two `sodium` entries.
  - Result: the suite exits 255, printing `Exception in parse-floors: packaging/floors.sexp: the
    key sodium appears 2 times`. No test is named, no summary is printed, and every row after
    line 1562 never runs.
- **Reachable:** `make test` runs `check-floors` first, but `make test-memory` (`Makefile:418`,
  prerequisite `deps` only) does not, and neither does a suite run alone.
- **Fix:** `(define real-floor (guard (e (#t 'floors-file-unreadable)) (floor-text (read-floors) 'sodium)))`.
  The row then fails by name, because `(tarball real-floor)` raises inside `outcome`. Watch it
  fail with the same plant.

### S5-F2 (major): two build rows end before the check's compiler calls, so what they claim can't show

- **Where:** `tests/test-ci-sodium.sps:1492-1499` (the env row) and `:1700-1711`.
- **What happens:** both rows run with no stub library, so `make install` installs nothing. The
  check then refuses with `no library at PREFIX/lib/libsodium.so.23`, which names
  `check-sodium.sh`'s own soname. `calls-through ... 5` stops before the check's two `cc` calls,
  and those calls are the only place the override and `C_INCLUDE_PATH` handed to the check
  would show.
- **Probe (a): the soname.**
  - Guard: the env row, which plants `soname=libsodium.so.26`.
  - Mutation: `build-sodium.sh:90`, `soname=libsodium.so.23` becomes
    `soname=${soname:-libsodium.so.23}`.
  - Result: 144 of 144 pass. No row holds the floor's soname against the environment.
- **Probe (b): the include path.**
  - Guard: the row "C_INCLUDE_PATH in the env: the check gets PREFIX/include before it".
  - Mutation: the check's `C_INCLUDE_PATH=$prefix/include${C_INCLUDE_PATH:+:$C_INCLUDE_PATH}`
    becomes `C_INCLUDE_PATH=$prefix/include`.
  - Result: that row passes. Only the success row at `:1747` fails. So row (b) passes whether
    the code is right or wrong (AGENTS.md: "worse than no test"), and another row holds its
    claim.
- **Impact:** low in practice. `check-ci` keeps any variable named `soname` out of a step's env.
  But the env row's plant list overclaims.
- **Fix:**
  - Give the env row `'stub floor-lib 'header floor-header`, and expect the success output with
    the seven calls. Its `cc` calls then show `[CHEZ_SODIUM_LIBRARY=PREFIX/lib/libsodium.so.23]`.
    Watch the soname mutant fail.
  - Drop row (b), or make it the success row.

### S5-F3 (minor): `curl` follows an HTTPS-to-HTTP redirect

- **Where:** `scripts/ci/build-sodium.sh:125,128`. The same flags are at `scripts/ci/build-chez.sh:72`,
  which this slice did not change.
- **Probe:**
  - Setup: a loopback HTTPS server, with a self-signed cert and `-k`, that answers 302 to
    `http://127.0.0.1:…`.
  - curl 8.21 with the script's flags, `-fsSL --retry 3 -o`: exits 0 and writes the HTTP body.
  - With `--proto '=https'`: exits 1, `Protocol "http" is disabled (in redirect)`.
  - curl's manual: "By default curl only allows HTTP, HTTPS, FTP and FTPS on redirects."
- **Impact:** the SHA-256 is checked before anything is unpacked, so a downgraded fetch only
  fails closed.
- **Fix:** add `--proto '=https'` to both calls, which also covers redirects (probed), and
  update `curl-call` (`test-ci-sodium.sps:1397`). Record `build-chez.sh` for M1's closing review.

### S5-F4 (minor): the new trap gives a false cause

- **Where:** `.plans/traps.md:134`, "Guix's gcc has no system include directory."
- **Probe:**
  - In the container, `env -u C_INCLUDE_PATH gcc -xc -E -v /dev/null` searches gcc's `include`
    and `include-fixed`, and `/gnu/store/…-glibc-2.41/include`.
  - `#include <linux/limits.h>` alone then fails.
  - The entry's own "What happened" reaches glibc's `limits.h`, which could not happen with no
    system directory.
- **Fix:** "Guix's gcc searches only its own headers and glibc's. The kernel's headers, and every
  other package's, reach it through the profile's `C_INCLUDE_PATH`, and setting the variable
  drops them." The rule, and AGENTS.md's new line, are right as written.

### S5-F5 (minor): the lists of what a floor raise moves are incomplete

- **Where:** `build-sodium.sh:42-48`, `check-sodium.sh:45-52`, and ADR-0011 `:101-103`
  ("Changing a floor edits the file, README.org's Requirements, the code's check and the
  literal rows").
- **What they leave out:** raising the libsodium floor past 1.0.18 moves the floor's soname in
  three more places:
  - `ci.yml:381,388,395`;
  - `check-ci.sh:622` (`sodso["floor"]`);
  - `test-check-ci.sps:1322` (`sod-so`).
  It also needs a new `floor_archive`, checked once against its `.minisig`. The scripts' comments
  omit the three files, and the record omits all of it.
- **Impact:** each missed place still fails by name. `check-ci` holds `ci.yml`'s value, and
  `check-sodium.sh` refuses a wrong override or soname. So this is documentation only.
- **Fix:** name them in both scripts' comments, and amend ADR-0011's bullet, or ADR-0003's
  "Raising the floor" consequence.
- **Also for that record:** a floor raised to `current_version` makes `current_version=1.0.22`
  in `scripts/ci/` fail `check-floors` (scripts builder, F6).

### S5-F6 (minor): README says no verb exists, then names one

- **Where:** `README.org:26`, "*No verb is built yet.* … and =sodium-version= names the version
  it loaded."
- **Why it is wrong:** the M1 plan §1 (`:40-46`) says "A verb is a name `(chez-sodium)` exports
  … M1 delivers `sodium-version`" and "with `sodium-version` the only verb".
- **Fix:** "*None of the four jobs is built yet.*" AGENTS.md's "No verb exists yet." has the
  same mismatch, for M1's close.

### S5-F7 (minor): the plan says "whole" where the script uses a pattern

- **Where:** M1 plan §4.2 item 10, `:316-320`: "the report of preflight … whole".
- **What the script does:** it compares lines 1 to 3 whole and line 4 by a pattern, any list of
  `(kind . 0)`. That was the caller's decision.
- **Fix:** "its first three lines whole, then a counts line whose every count is 0, and nothing
  on stderr".

### S5-F8 (minor): the measurements record a parallel build, and the lane builds serially

- **Where:** `.plans/research/m1-slice-5-measurements/README.md:28-30`. It records `make -j18`:
  10 s to configure, 6 to 7 s to build.
- **What the lane runs:** a serial `make`. The scripts builder measured 58 s serial in the
  container. My real serial runs on the host took 58 s and 38 s in total, for 1.0.18 and
  1.0.22.
- **Fix:** add the serial time.
- **Otherwise accurate** against `dl-sodium/`: both SHA-256s, the key, both trusted comments
  (tab-separated in the files), and one top directory each.

### S5-F9 (minor): `packaging/debian-prereqs.txt` doesn't name the new users

- **Where:** `:30-35` names only `build-chez.sh` as the user of `curl` and `tar`; `:38-42` lists
  `sodium.h`'s users.
- **What is missing:**
  - `build-sodium.sh`, which needs curl, tar, gzip, make, cc and sha256sum;
  - `check-sodium.sh --discovery`, which needs libsodium-dev's `/usr/include/sodium.h` in
    `main`;
  - the lanes, which install the same 1.0.18 header that their `C_INCLUDE_PATH` must shadow.
- **Why it matters:** the file claims to be "the whole truth about a bare machine."
- **Fix:** name them in the comments.

### S5-F10 (minor): `ci.yml`'s header misdescribes two things

- **`ci.yml:14-16`:** `main`'s line never says it asserts the floor
  (`check-sodium.sh --discovery`).
- **`ci.yml:42-44`:** it says the two names stand on "the steps that name a libsodium build".
  They stand on the check, `make build` and `make test`, and the build step may not carry them.
- **Fix:** reword both lines.

### S5-F11 (minor): slice 5 has no mutation log yet

- **What is missing:** `.plans/m1-slice-5-mutation-log.md` is not in the tree. Plan §6 wants one
  per slice, in the form Guards, Mutation, Result, Clean rerun.
- **Fix:** write it from `slice5-scripts-log.md` and `slice5-lanes-log.md`, adding this review's
  probes, before the PR.

### S5-F12 (minor): a signal leaves the work directory behind

- **Where:** `build-sodium.sh:122` and `check-sodium.sh:115` (`trap … EXIT` only).
- **Probe:**
  - Guard: the EXIT trap.
  - Setup: dash, with an EXIT trap and a `sleep`, sent SIGTERM.
  - Result: the `mktemp -d` directory is left. With `trap 'exit 1' HUP INT TERM` added, as
    `check-ci.sh:111` has it, it is removed.
- **Impact:** harmless on an ephemeral runner. A Ctrl-C on a developer's host leaves the
  directory in `/tmp`.
- **Fix:** add the same line to both scripts. A row can't hold it cheaply, so record it.

## The probes

| Guard | Mutation or setup | Result |
|---|---|---|
| `real-floor` at top level (S5-F1) | floors file with two `sodium` entries | exit 255, no test named |
| env row's `soname` (S5-F2a) | `soname=${soname:-libsodium.so.23}` | 144/144 pass: survives |
| row "the check gets PREFIX/include before it" (S5-F2b) | include tail dropped | that row passes; only `:1747` fails |
| HTTPS only (S5-F3) | loopback 302 to HTTP | followed; `--proto =https` refuses |
| the trap's cause (S5-F4) | `gcc -v` with `C_INCLUDE_PATH` unset, in the container | glibc's include dir is built in |
| cleanup on a signal (S5-F12) | SIGTERM to dash | directory left |
| the real `build-sodium.sh` (host) | dash; `PATH=/usr/bin:/bin` plus a loopback `curl` stand-in serving `dl-sodium/`, 404 for 1.0.18 under `releases/` | both built; fallback taken; pthreads grep and check pass; TMPDIR empty |
| the floor lane's three steps (host) | the build above; `C_INCLUDE_PATH=PREFIX/include` alone | check and `make build` pass; `make test` 25 of 26. The one failure is `test-library-loading-discovery`'s Guix-world rows: the Guix Chez runs outside its container, with `GUIX_ENVIRONMENT` unset. On the runner that suite takes its FHS branch. |
| `main`'s `--discovery` end to end (host) | copy with discovery forced to FHS; Ubuntu's `libsodium.so.23`; overlay `/usr/include` holding the 1.0.18 tarball's headers; Ubuntu gcc; dash | passes; real report `counts: ((block . 0))` |
| the current lane's header (host) | overlay 1.0.18 header in `/usr/include`, `C_INCLUDE_PATH` = 1.0.22 build | the build's header wins; unset, it refuses naming `/usr/include/sodium.h` |
| GCC on the runner (approx.) | decoy ×8, oracle, free-watch, `-Wall -Werror`, Ubuntu gcc 11, each build's header alone | all compile; oracle reads 1.0.18 10.3 and 1.0.22 26.4 |
| mawk and dash | `test-ci-sodium`, `test-check-ci`, `check-ci.sh` on the real workflow | 144/144, 675/675, pass |
| README held | floor in the prose line; list line 1.0.19 | `check-floors` fails each, by name |

## Checked and sound

- **Item 1, the contract.** Every "watched to fail" item has rows: each pin by role, the
  failover and both-fail cases, and every `check-sodium.sh` check by a stub that breaks it. So do
  `--discovery` given an override, another path or another version, and the lanes' order and env
  exception. The floor's text in `scripts/ci/` is held by `check-floors` (its pass line names both
  new scripts) and the existing `floors-script` plant.
  - The SRFI-64 traps in `test-check-ci`'s new rows are clean:
    - `row` delays every edit and expectation under `run-row`'s guard;
    - top-level helpers use the suite's own literals only;
    - nothing depends on argument order.
  - `test-ci-sodium` is clean apart from S5-F1:
    - work runs under `outcome` or a guard;
    - no row expects `#f`;
    - no test runs inside another;
    - `let*` is used where order matters.
- **Item 2, checks that cannot fail.** Beyond S5-F2 I found none:
  - the stand-ins accept and refuse what the real tools would, and the tar, sha256sum and make
    stand-ins check their argument shapes;
  - the 158 builders' mutants are all killed;
  - my reads of `lanestep`, `argof`, the `ealk` exemption and `cacheorder` found every loosening
    caught by a second rule.
- **Item 3, CI's first run.**
  - **The runner.** Ubuntu's library answers 1.0.18, 10, 3, minimal 0. Its header's major and
    minor are 10 and 3, from the 1.0.18 `configure.ac` and a distribution build (Guix's
    `version.h`).
  - **The download.** The fallback runs on curl's exit 22, and `--retry` does not retry a 404.
  - **The build.** GCC 16 (container) and GCC 11 (host) both build 1.0.18 and 1.0.22, and both
    define `-DHAVE_PTHREAD=1`.
  - **The caches.**
    - Cold run: the build saves only after its own check passes.
    - Warm run: the check runs on the restored prefix. The `.so.23` link survives the cache's
      tar.
  - **The cache keys.** The hash lists are exactly what each role reads: the floor's is
    `floor.sh` → `floors.sexp` and both scripts; the current's is both scripts. Rows hold that
    `--current` reads no floors file. The Chez floor and the `--discovery` code re-key both
    lanes for nothing, which was accepted (lanes builder, F13).
- **Item 4, security.**
  - Both URLs are HTTPS, apart from S5-F3.
  - The digest is checked before unpack, and rows assert the call order.
  - Each tarball has one top directory, no `..` and no links. Both pins match by `sha256sum` and
    `openssl`.
  - Both `.minisig` files verify independently, with PyNaCl, against the key in
    `doc-installation.md`.
  - A partial or hostile download fails the pin.
  - No env variable, and nothing a workflow says, moves the version or the pin. Rows hold this,
    and `check-ci` bans every other env key.
- **Item 5, AGENTS.md.**
  - No floor text in `scripts/ci/`.
  - No milestone, slice, date or maintainer in a new comment.
  - No SQLite leftovers but the deliberate `--no-load` usage refusals.
  - Both scripts are executable.
  - `dash -n` parses them.
- **Item 6, the caller's edits.** These hold:
  - README's Status and Requirements, apart from S5-F6;
  - the plan's §2.3 and §2.4 rows;
  - the AGENTS.md line;
  - the measurements, apart from S5-F8.
- **Item 7, the records.** The slice does what ADR-0002 and ADR-0003 (decisions 5 and 6) say,
  and ADR-0011 decision 5. Nothing contradicts them, apart from S5-F5's list.

## Watch on the first CI run (not findings)

- **`main`.** The slice 3 and 4 logs of `make build` should already show
  `/usr/lib/x86_64-linux-gnu/libsodium.so.23 (system)` and `1.0.18 (library 10.3)`. If they do,
  `--discovery` passes. A libsodium under `/usr/local/lib`, which FHS order searches first, would
  fail it, by name.
- **Reaching libsodium.org.** Both lanes depend on reaching `download.libsodium.org` from
  GitHub's runners.
- **`test-check-ci` under the gate.** It takes 144 s in the container. Slice 2 measured CI at
  about 1.5× (`test-native`, 12 s on CI against 8 s), which gives about 220 s against the 450 s
  SLOW line. Record it.

## For M1's closing review

1. "Identify the runner image" is unheld, in every job (carried).
2. ADR-0011's floor-change list (S5-F5), and the collision of `current_version` with a raised
   floor.
3. `build-chez.sh`'s curl without `--proto =https` (S5-F3), and the scripts' missing signal traps
   (S5-F12).
4. CI's measured times: `test-check-ci` under the gate, and each lane's serial build.

---

## How each finding was resolved

Before fixing them, the caller confirmed:
- S5-F1, by reading the top-level `define`;
- S5-F4, with `gcc -v` in the container: the profile's `include` is first on the list, and glibc's is built in;
- S5-F2's soname mutant, which killed one row after the fix.

The scripts builder watched each new assertion fail, in whole copies of the tree.

- **S5-F1:** `real-floor` is read under a guard with its own sentinel, and a new row names it.
  - Before the fix, with two `sodium` entries in the floors file, the suite died with exit 255 and named no test.
  - After it, two rows fail by name, and the suite runs on.
- **S5-F2:** the floor's and the current release's env rows now run to the check, with a stub library and header. Each expects the whole success output and every call.
  - The row that ended before the compiler is dropped: the success row with the same env shows the check's `C_INCLUDE_PATH`.
  - Watched: the soname default fails one row, and `C_INCLUDE_PATH=$prefix/include` alone fails seven.
- **S5-F3:** both `curl` calls carry `--proto '=https'`. Dropping it from the first call fails 31 rows, and from the second, 5. `build-chez.sh` is carried to M1's closing review.
- **S5-F4:** the trap's cause now says that glibc's headers are built in, and the kernel's come only through the profile's `include`, which `C_INCLUDE_PATH` names.
- **S5-F5:** both scripts' floor-raise comments name the floor lane's library in `ci.yml`, `check-ci.sh` and `test-check-ci`. ADR-0003's and ADR-0011's lists are carried to M1's closing review, in `progress.md`, since changing a record needs the owner.
- **S5-F6:** README says one verb is built so far, `sodium-version`, and that the four jobs come next.
- **S5-F7:** plan §4.2, item 10, says the report's first three lines are held whole, and its counts line all zeros.
- **S5-F8:** the measurements record that the lanes build serially. The builder measured 58 s for 1.0.22 that way.
- **S5-F9:** `debian-prereqs.txt` names `build-sodium.sh`'s tools, and what `--discovery` requires of `libsodium23` and `libsodium-dev`.
- **S5-F10:** `ci.yml`'s header says `main` asserts the floor. It also says the two names stand on a lane's check, `make build` and `make test`.
- **S5-F11:** `.plans/m1-slice-5-mutation-log.md` is written.
- **S5-F12:** both scripts trap `HUP`, `INT` and `TERM` beside `EXIT`. No row holds it.
