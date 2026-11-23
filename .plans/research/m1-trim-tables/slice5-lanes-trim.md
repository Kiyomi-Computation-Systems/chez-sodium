# Slice 5, the lanes: phase 1 (trim tables, design note, rows and mutants, flags)

Sources read: AGENTS.md; the M1 plan (§2.3, §2.4, §4.2 items 10 and 11, §5.2, §6 slice 5 and
"Every brief restates these"); ADR-0003, ADR-0011; `global-constraints.md`; `traps.md`; the
slice-3 mutation log ("CI's `main`"); the current `ci.yml`, `check-ci.sh` (690 lines) and
`test-check-ci.sps`; v0.1.1's (`960d9f0`) `ci.yml` (jobs `floor`, `current`), `check-ci.sh` and
`test-check-ci.sps`, saved for reading under the scratchpad as `v011-*`. Probes run: the real
`ci.yml` passes today's `check-ci.sh` under mawk 1.3.4 (the host's awk is mawk). No project file
was changed; the only write outside the scratchpad is `build/slice5-lanes/d/ci.yml`, a copy.

What slice 3 already put in place, so slice 5 adds only the rest: `main`'s install check
(`make build`) with its rules, `check-dev` on the make line, and a generic one-build-per-job
Chez-cache shape. What slice 5 adds to `main` is the discovery step alone.

Naming used below: `L` is a lane, `floor` or `current`. A lane's libsodium cache is "the sodium
cache"; the Chez cache is "the Chez cache". `isl(j)` is true for the two lanes. Because each lane
makes one build, every table v0.1.1 keyed by build name is keyed by the job name here.

---------------------------------------------------------------------------------------------

## 1. Trim tables

### 1a. v0.1.1's `floor` and `current` jobs (`ci.yml`)

| Part of v0.1.1's job | Here | What it protected / where that lives now |
|---|---|---|
| Checkout with `submodules: recursive` | kept | `make test` needs SRFI-64. |
| Install step (`debian-prereqs.txt`), "Identify the runner image" (`id: image`) | kept, as `main` has them | unchanged text. |
| Chez cache: restore (`id: chez`), build (`if`), save (`if`), check-chez | kept, as `main`'s | unchanged text, `chez-threads` path and key. |
| Step "Name the C compiler for the cache key" (`id: cc`) | kept (plan §4.2 item 11) | the compiler is in each lane's key, so a lane tests a library built by its image's own compiler. The comment above it changes: libsodium lists no compiler, so the reason is the image's, not SQLite's option list. |
| SQLite cache: restore (`id: sqlite`), build (`if`, env `CHEZ`), save (`if`), check, load (`make build`), suites (`make test`) | changed: libsodium for SQLite; `id: sodium`; paths `sodium-floor` and `sodium-current`; `build-sodium.sh` and `check-sodium.sh`; libraries `.so.23` and `.so.26` | the same six steps, one build per job. |
| The floor's key hash list (floors file, `floor.sh`, build script, check script) | kept, scripts renamed | a floor bump, a change to the reader or to the build or check re-keys the cache. |
| The current's key hash list (build script, check script alone) | kept, scripts renamed | the pinned release lives in `build-sodium.sh`, so a pin change re-keys; no floors file, so a floor bump does not rebuild `current`. See F1. |
| Env on the check, `make build` and `make test` steps: `CHEZ`, the library override, `C_INCLUDE_PATH` | kept, `CHEZ_SODIUM_LIBRARY` for `CHEZ_SQLITE3_LIBRARY` | the env exception (plan §2.4). Values differ between the lanes in the soname as well as the directory. |
| Env on the build step: `CHEZ` alone | kept | the build script sets the override for its own check (v0.1.1's `build-sqlite.sh` lines 199-201 do). See F12. |
| `current`'s second build, `--no-load`: five steps (restore `id: sqlite-no-load`, build, save, check, `make test`) | dropped | protected a suite branch for a library without extension loading. libsodium has no such build; the plan drops it. Nothing here needs it. |
| `current`'s comment on the second build | dropped | goes with it. |
| `timeout-minutes: 60`, `runs-on: ubuntu-24.04` | kept | the existing job-key rules hold both. |

### 1b. v0.1.1's `check-ci.sh` rules that concern the lanes, the env exception, or the job set

| Rule (named by what it holds) | Here | Protection and where it lives now |
|---|---|---|
| The job set: seven named jobs, each present once, no other | changed to five: `main`, `memory`, `nothreads`, `floor`, `current` | `JOBS`, `jn`, `wantjob`, `endsec`'s loop, and the messages that list the jobs. |
| `memory-1` and `memory-2`, each running its own shard; `ismem`, `shardrun`, `MEMORY_SHARD` exemption (`shardok`) | dropped | held one shard per job so neither ran the other's. M0 already dropped it: one `memory` job, `MEMORY_SHARD` and `MEMORY_*` refused. Nothing to restore. |
| `site`: six steps, install step held to a copy, no cache, no `if:`, `chezscheme` CHEZ; `INSTALL_FILE`, `cpcheck`, `sitesteps`, `sraw` | dropped | the site waits for M4. M0 already dropped it. |
| `pages.yml` held to a copy | dropped | no `pages.yml` here; the directory rule already says `ci.yml` alone. |
| Lanes: first step is the checkout with `submodules: recursive`, no `if`, no run | kept | `endjob`'s first-step rule gains `isl(job)`. |
| Lanes: the required run lines, in order, each one step's whole run line: check-chez; compiler step; for each build: build, check, `make build` (first build only), `make test` | changed: one build, so one each, in order, plus M0's Chez build line (already required by `nreq` for every job) | v0.1.1's loop over builds and its `k == 1` condition drop with the second build. |
| `make test` required once per build (so `current` required it twice); `cnt[]` ("one"/"two") wording | dropped | one build, one `make test`; today's single-count rule already holds it. |
| The compiler step: its exact line, and `id: cc` | kept | `CCLINE`, `S_id`. |
| The sodium build step carries its own `if` (`steps.sodium.outputs.cache-hit != 'true'`); the check, `make build`, `make test` carry none | kept | `isb` is true for the sodium build. |
| `if:` placement: the Chez `if` only on the Chez build and the Chez cache's save; each SQLite `if` only on its build (found by its directory, any flag) and its save (found by its path) | kept, one sodium `if` | `lanestep` (see 2c). v0.1.1's `ifbuild`, `lanifs` per build and `sqid` shrink to one id. |
| Each build's cache: one restore with `id: sodium`, one save, path held, key held whole, save keyed `steps.sodium.outputs.cache-primary-key` | kept | counted per path. |
| Chez cache in a lane: path, key prefix and hash list, restore `id: chez`, save keyed `steps.chez.outputs.cache-primary-key` | kept (v0.1.1's `cachekey_ok`, `CHEZP`) | already today's `keyok`, `cachestep`. Today's one-restore and one-save count of the Chez cache is stricter than v0.1.1's lanes (which did not count it) and stays; it must count by path (2c). |
| Cache path set: a lane's cache steps may name only the Chez path or its own sodium path | kept, two paths (v0.1.1 listed three in `current`) | `lanpaths`; the `no-load` path drops. |
| Cache order: restore before its build, save after the build and before its check; each sodium restore after the compiler step | kept | `cacheorder`'s sodium half. |
| A later build's restore after the earlier build's `make test` (`bidx`, `attest`) | dropped | protected the `no-load` restore from running before `current`'s tests. One build per lane: nothing earlier. |
| Only `actions/checkout@`, `actions/cache/restore@`, `actions/cache/save@` may be `uses:` | kept, unchanged (today's code reads every job) | `cacheorder`'s first check. |
| Env keys in a lane: `CHEZ`, the library override and `C_INCLUDE_PATH` only; elsewhere `CHEZ` only | kept | `laneenv`; `subkey`. |
| The two names' values held exactly per build (`lanelib`, `laneinc`), checked at the job's end because the step's build is read from its run line | kept; per lane | `envval`. The library differs per lane by soname as well as directory; new rows (3). |
| The two names are for the steps that run a build's check, `make build` and `make test`, and no other step of the lane (`okrun`) | kept | the env exception. |
| The names rule's one exception: the two names as env keys at their own indent in a lane step (`ealk`); every other line, a block scalar and the other jobs included, refuses them | kept | `main`, `memory` and `nothreads` stay refused; so does the discovery step. |
| `MEMORY_SHARD` exemption | dropped | M0. |
| A required line must be exactly one step's whole run line (no arguments, no block scalar) | kept | `hn`/`hit` matching on the whole line, already today's. |
| Execute-bit rule and stray-`scripts/` rule | kept, unchanged | generic; they read `scripts/ci/NAME` lines. New names are held by new rows (3). |
| `main`: report steps, install check, make line, launcher | kept as slice 3 left them | adds the discovery step (2b). |

### 1c. v0.1.1's rows in `test-check-ci.sps` that plant those rules

| v0.1.1 row family | Here | Protection and where it lives now |
|---|---|---|
| `lane-rows` rule 3, the checkout without submodules or with `false` | kept per lane | |
| rule 4, each required line deleted and written twice | kept per lane, for the lane's six lines | the Chez build line's deleted/twice rows are the generic `cache-rows`' (if they run on lanes, 2d). |
| order rows: check after `make build`, `make test` before `make build`, build before check-chez | kept | |
| rows on exactness: `make test X`, `make test` as a block scalar, `make build X`, the check with the other lane's flag, the build with the other lane's flag, the build into another directory, the compiler line changed, no `id: cc`, check-chez with `--nothreads` | kept | |
| rule 5, the ifs (own `if` missing, another value, `always()` on check, `make build`, `make test`, `continue-on-error`, each cache's `if` on the other's step and on `make test`) | kept | |
| rule 6, cache keys (each hash part dropped, one file more, compiler dropped, image dropped, the other lane's prefix, the other lane's whole key, a tail) | kept, with the sodium hash list | |
| rule 6, paths, ids, counts, save keys, the Chez key and path rows | kept | |
| rule 7, env keys (other lane's library, header directory with a second directory, relative library, CHEZ the nothreads Chez, missing keys, the build with the override, the restore with the header directory, the Chez build with the override, each refused name added) | kept | new rows add the soname-only case and a value that names another banned word (3). |
| rule 8, the names on every other line (run block exports, `GITHUB_ENV`, step name, `with` value, run line) | kept | |
| rule 9, spellings over the lane (quoted key, explicit key) | dropped | they planted global spelling rules inside a lane's steps. The code runs before any job dispatch (`bad` is computed from the line alone), and M0's `text-rows` and `structure-rows` plant each spelling in `main`. No lane-specific code exists to mutate. See F7. |
| rule 10, uses and cache order (restore uses `actions/cache`, restore below the check, compiler step below the restore, save below the check, save above the build) | kept | |
| rule 2, job keys per lane (a job key, `runs-on`, no `timeout-minutes`) | replaced: today's generic `job-key-rows` run over the five jobs | one family instead of two; the lane rows' `runs-on` text moves in. See F7. |
| `chez-order-rows "main"` and `"floor"` | kept as the lanes' Chez-cache order rows | generic `cache-rows` cover the same plants if they run on lanes (2d). |
| `lane-global-rows`: floor job deleted, current job deleted, a job beside the seven, each of the two names added, with floor's exact value, to `main`'s install check, a memory step and `nothreads`' step | kept | adds: `main`'s discovery step. |
| `no-load-rows` (the five steps, their keys, ids, order, `make test` twice, the five steps in `floor` and in `main`) | dropped | no `no-load` build. |
| `memory-rows` for shards; `site-rows`; `pages-rows`; execute-bit rows for `build-sqlite.sh`, `check-sqlite.sh`, `report-sqlite.sh` | dropped / replaced | shards, site, pages: M0 dropped them. The execute-bit rows get `build-sodium.sh` and `check-sodium.sh` (3). |

---------------------------------------------------------------------------------------------

## 2. Design note

### 2a. The two jobs' steps, in order

Both jobs: `runs-on: ubuntu-24.04`, `timeout-minutes: 60`, `name:` as the others (a short name that
says what the lane is), placed after `nothreads` in the file (the order the test's `job-order`
must match). `${{ runner.temp }}` is `RT` below. Step names are not held by `check-ci` (only
`main`'s two report names are); the ones below are what the rows will anchor on.

`floor`'s steps. `current`'s are the same with "at the current release", `sodium-current`, `.so.26`, the
key's hash list of build and check alone, and `--current` after the prefix.

| # | Name | `id` | `if:` | env | run / uses |
|---|---|---|---|---|---|
| 1 | (checkout, no name) | | | | `uses: actions/checkout@<same SHA> # v7.0.1`, `with: submodules: recursive` |
| 2 | Install the packages in packaging/debian-prereqs.txt | | | | the same run block as the other jobs, line for line (not held) |
| 3 | Identify the runner image | `image` | | | the same run block as the others |
| 4 | Restore Chez | `chez` | | | `actions/cache/restore@<same SHA> # v6.1.0`, `path: RT/chez-threads`, `key: chez-threads-${{ hashFiles('packaging/floors.sexp', 'scripts/ci/floor.sh', 'scripts/ci/build-chez.sh', 'scripts/ci/check-chez.sh') }}-${{ steps.image.outputs.id }}` |
| 5 | Build Chez | | `if: steps.chez.outputs.cache-hit != 'true'` | | `scripts/ci/build-chez.sh "$RUNNER_TEMP/chez-threads"` |
| 6 | Save Chez | | the same `if` | | `actions/cache/save@<same SHA> # v6.1.0`, `path: RT/chez-threads`, `key: ${{ steps.chez.outputs.cache-primary-key }}` |
| 7 | Check the Chez this job runs | | | | `scripts/ci/check-chez.sh "$RUNNER_TEMP/chez-threads"` |
| 8 | Name the C compiler for the cache key | `cc` | | | `echo "id=$(cc --version \| head -n 1 \| tr -c '[:alnum:].' '-')" >> "$GITHUB_OUTPUT"` (v0.1.1's line) |
| 9 | Restore libsodium at its floor | `sodium` | | | `actions/cache/restore@<same SHA> # v6.1.0`, `path: RT/sodium-floor`, `key: sodium-floor-${{ hashFiles('packaging/floors.sexp', 'scripts/ci/floor.sh', 'scripts/ci/build-sodium.sh', 'scripts/ci/check-sodium.sh') }}-${{ steps.image.outputs.id }}-${{ steps.cc.outputs.id }}` (current: `sodium-current-${{ hashFiles('scripts/ci/build-sodium.sh', 'scripts/ci/check-sodium.sh') }}-...`) |
| 10 | Build libsodium at its floor | | `if: steps.sodium.outputs.cache-hit != 'true'` | `CHEZ: RT/chez-threads/bin/scheme` | `scripts/ci/build-sodium.sh "$RUNNER_TEMP/sodium-floor"` (current: `... "$RUNNER_TEMP/sodium-current" --current`) |
| 11 | Save libsodium at its floor | | the same `if` | | `actions/cache/save@<same SHA> # v6.1.0`, `path: RT/sodium-floor`, `key: ${{ steps.sodium.outputs.cache-primary-key }}` |
| 12 | Check the libsodium this job runs | | | `CHEZ`; `CHEZ_SODIUM_LIBRARY: RT/sodium-floor/lib/libsodium.so.23`; `C_INCLUDE_PATH: RT/sodium-floor/include` | `scripts/ci/check-sodium.sh "$RUNNER_TEMP/sodium-floor"` (current: `.../sodium-current" --current`, `.so.26`) |
| 13 | Load libsodium at its floor | | | the same three | `make build` |
| 14 | The suites against libsodium at its floor | | | the same three | `make test` |

Notes. Every `uses:` line is the SHA and tag the current file pins (`check-pins` stays green; the
action-pin check reads all lines). No comment holds either floor's version, nor a milestone, slice
or date. The comment above step 8 says the compiler is in the key so a lane tests a library its
own image's compiler built. The `ci.yml` header's job list and its description of `check-ci` (it
says "these three jobs" and "no if: but on the Chez cache's own steps") are updated to five jobs
and "the caches' own steps". The comment above each lane says what the lane tests and that its
steps carry the env exception, and that no other step does.

### 2b. `main`'s new step

After the install check, before "Checks and suites":

```
      - name: The runner's libsodium is the floor
        env:
          CHEZ: ${{ runner.temp }}/chez-threads/bin/scheme
        run: scripts/ci/check-sodium.sh --discovery
```

No `if:`, no other env key, and the run line exactly that: no argument, no override. A comment
above says the install check above it found the runner's library with no override named, and this
step requires that to have been the floor. `main`'s required lines become, in order: Chez build
(cache `if`), check-chez, `make build`, `check-sodium.sh --discovery`, the make line, the
launcher; the "Report the versions" and "Report the runner's libsodium" steps stay between
check-chez and the make line, as now. The discovery step is `kind: env` (needs `CHEZ`, no `if`).

### 2c. What `check-ci.sh` must newly hold, and how it reads it

The structure stays slice 3's: one awk program, text line by line, per-step tables `S_*`, and
each job checked at its end by `endjob`. Nothing here needs more than POSIX awk; mawk is the
test shell. Changes, by function:

1. **Job list.** `JOBS`, `jn`, `wantjob` get `floor` and `current`; `endsec`'s missing-job loop
   runs to five; `isl(j)` as v0.1.1's. Tables for the lanes: `chezpath`, `cachepath`, `prefix` as
   `main`'s.
2. **Sodium tables, keyed by job** (v0.1.1's `lane*` tables without the build loop):
   `sodp[L]` = `${{ runner.temp }}/sodium-L`; `sodlib[floor]`, `sodlib[current]` = `sodp "/lib/libsodium.so.23"` and
   `".so.26"`; `sodinc[L]` = `sodp "/include"`; `sodflag[floor]` = `""`, `[current]` = `" --current"`;
   `sodhash[floor]` = floors file, `floor.sh`, `build-sodium.sh`, `check-sodium.sh`; `sodhash[current]` =
   build and check alone; `sodkey[L]` = `"sodium-" L "-${{ hashFiles(" sodhash[L] ") }}-${{ steps.image.outputs.id }}-${{ steps.cc.outputs.id }}"`;
   `sodbld[L]` and `sodchk[L]` = `scripts/ci/build-sodium.sh "$RUNNER_TEMP/sodium-L"` and `...check-sodium.sh ...`
   plus the flag; `IFSOD` = `if: steps.sodium.outputs.cache-hit != 'true'`; `CCLINE`; `TESTLINE` = `make test`;
   `DISCOVERY` = `scripts/ci/check-sodium.sh --discovery`; `laneenv` = `CHEZ`, `CHEZ_SODIUM_LIBRARY`, `C_INCLUDE_PATH`.
3. **The job list's order of required lines, `nreq`.** Lane: `BLDT` (kind `bld`: carries the
   Chez `if`), `CHKT`, `CCLINE` (kind `cc`), `sodbld[L]` (kind `sbld`: carries `IFSOD`, needs
   `CHEZ`), `sodchk[L]` (kind `schk`), `BUILDLINE` (kind `sbuild`), `TESTLINE` (kind `stest`);
   the last three need `CHEZ`, the library and the header directory. `main`: `BLDT`, `CHKT`,
   `BUILDLINE`, `DISCOVERY` (kind `env`), `MAKELINE`, `LAUNCHER`. The existing `hn`/`hit` match
   of a required line to a step's whole run line gives "exactly one", "no argument" and "no
   block scalar" for free. The existing `pos <= lastp` gives the order, which is what puts the
   discovery step after the install check and before the make line.
4. **`subkey`, env.** For a lane the key may be any of `laneenv`; for every other job `CHEZ`
   alone, as now (this is where the names stay refused in `main`, `memory`, `nothreads`, the
   discovery step included). `CHEZ` is held to `chezpath[job]` as now. The two names' values are
   held at the job's end, by `envval` against `sodlib[L]` and `sodinc[L]`, because only the step's
   run line says which build it is for (v0.1.1's reason).
5. **`endstep`, the `if:`.** For a lane: a step with an `if` must carry `IFLINE` on a run line of
   `build-chez.sh` or a cache save whose path is the Chez path, or `IFSOD` on a run line of
   `build-sodium.sh` on `sodp[L]` (found by `argof`, so any flag) or a cache save whose path is
   `sodp[L]`; any other `if` or placement is a problem, in v0.1.1's `lanestep` wording with
   "SQLite" read "libsodium". For the other jobs `endstep` is today's.
6. **`cachestep`, by path.** A cache step's path decides which cache it is: `cachepath[job]`
   (Chez: today's rules, `keyok`, `id: chez`, save keyed `steps.chez.outputs.cache-primary-key`) or, in a
   lane, `sodp[job]` (`S_id == "sodium"`, restore key exactly `sodkey[job]`, save key exactly
   `${{ steps.sodium.outputs.cache-primary-key }}`). A path that is neither is a problem: in a lane,
   "is not one of CHEZ-path or SODIUM-path"; elsewhere today's message.
7. **`cacheorder`.** The Chez half is today's, over the cache steps whose path is not `sodp[job]`
   (so a lane's two caches are not counted together: without this a lane has two restores and
   fails whole-file). The sodium half, per lane: exactly one restore and one save at `sodp[job]`; the
   restore before the step that runs `build-sodium.sh` on that directory (`argof`); the save after
   it and before the step that runs `check-sodium.sh` on that directory; the restore after the
   compiler step. A path that is the Chez or sodium cache's, whichever, does not stop a wrong
   path at a restore being counted as the Chez cache's (matching today's row for a wrong path).
8. **`endjob`.** The first-step rule applies to lanes. For lane kinds: `cc` needs `id: cc`;
   `sbld` needs an `if`; `bld` as now; `schk`, `sbuild`, `stest` need `CHEZ`, the library and the
   header directory, with `envval` against `sodlib`/`sodinc`; `sbld` needs `CHEZ`. After the loop:
   for each step whose run line is not one of the three (`okrun`: check, `make build`, `make test`),
   an env key naming either name is the problem "only for the steps that run the libsodium check,
   make build and make test".
9. **The names rule.** `ealk` as v0.1.1: set when the line is, outside a block, a dash-less env-key line
   at indent 10 of a lane's step and its first word is exactly one of the two names; only that
   first word is exempt. The `MEMORY_SHARD` exemption stays gone. `CHEZ_SODIUM_LIBRARY` and
   `C_INCLUDE_PATH` stay in the banned list.
10. **The execute-bit and stray-`scripts/` rules** are unchanged. The key lines of the lanes'
    caches name `scripts/ci/...` inside `hashFiles(`, which the stray rule already allows.
11. **Header comment of `check-ci.sh`:** the shape list says five jobs and the lanes' rules, in
    the form v0.1.1's header gives them, without its SQLite-only parts.

### 2d. How the rows plant faults, as slice 3's do

* Every row copies the real `ci.yml` into a directory of its own, applies its edits (old text
  must occur once in the real file and once in the text so far; a job edit once in that job's
  text of each), runs `sh tests/check-ci.sh DIR`, and compares exit status, stdout and stderr in
  whole. Each expected problem is written by hand in the suite, anchored on the one line of the
  edited file holding an anchor text, never a number read from the script.
* `job-order` becomes `("main" "memory" "nothreads" "floor" "current")`, the file's order, so a
  job's text ends at the next job's header. The lanes copy text from `main` and each other, so
  edits to a lane use `le` (per-job, once in that job); `lane-step`, `se`, `del-step` and the
  anchor `(A job header text)` are v0.1.1's, with sodium names. Fault rows edit one step.
* The helpers `restore-text`, `build-text`, `save-text`, `chk-text` and the generic `cache-rows`
  and `job-key-rows` run over the lanes too if each of their expected messages is the same in a
  lane. The only one that differs is the path message (a lane lists two paths), so
  `cache-path`'s helper takes the job and gives the lane's longer message. The rows whose faults
  concern the Chez path (restore's or save's path another) then show both messages exist. If a
  generic row's expected problems differ in a lane for any other reason, the row gets its own
  expected list rather than loosening the generic one.
* Existing rows with a global `e` edit (old text once in the whole file) will raise once the
  lanes copy text; the audit is to run the suite against the new `ci.yml` before changing any
  row, and convert each raiser to `le`. See F10.
* **Red first, as slice 3's log has it:** rows written against the unchanged `ci.yml` and
  script fail; then `ci.yml` is changed (the real workflow then fails `check-ci` for named
  reasons: "job floor is not one of main, memory, nothreads"); then `check-ci.sh`; then the
  suite is green and `make check-ci` passes.
* The execute-bit rows' `script-steps` gain the three steps that run `check-sodium.sh` (the
  discovery step, and each lane's check) and the two that run `build-sodium.sh`; `script-names`
  gains both names; one "missing" row is added for `check-sodium.sh`.

---------------------------------------------------------------------------------------------

## 3. Rows, and the mutant of `check-ci.sh` that turns each red

A mutant is one exact replacement in the phase-2 `tests/check-ci.sh`, written against its final
text (which does not exist yet; each entry says what it turns off). "Rows" names the families
that must fail; "all of them" is never a target, only the rows named. The fault each row plants
is one edit to one step of one lane, unless said; every row is run for both lanes except where it
says otherwise.

### 3a. `main`'s discovery step (rows follow slice 3's install-check rows)

| Id | Rows | Mutant (what is turned off) |
|---|---|---|
| D1 | the discovery step deleted; written twice | `nreq`'s `main` branch loses `DISCOVERY`: rows that expect "has 0 steps that run" and "2" report nothing |
| D2 | moved before the install check (out of order against `make build`) | the order test skips when `x == DISCOVERY` and `lastx == BUILDLINE` |
| D3 | moved after "Checks and suites" (out of order against the make line, reported at the make line) | the order test skips when `lastx == DISCOVERY` |
| D4 | its env dropped (control rows from `make-steps` listing it: other CHEZ, a second key, `CHEZ` twice, `CC`, `continue-on-error` are global rules, controls only) | `needenv`'s `env`-kind branch skipped when `x == DISCOVERY` |
| D5 | an `if: always()` on it; the cache's `if` on it | the "has an if" test skipped when `x == DISCOVERY` |
| D6 | with an argument (`--discovery X`); with the lane's PREFIX instead (`check-sodium.sh "$RUNNER_TEMP/sodium-floor"` in its place); as a block scalar | the match of a required line to a run line loosened to a prefix match for `DISCOVERY` |
| D7 | main's discovery step gains `CHEZ_SODIUM_LIBRARY` with floor's exact value; gains `C_INCLUDE_PATH` with floor's exact value (also, for the memory gate steps and the nothreads step, as v0.1.1's global rows plant) | the `ealk` exception stops testing `isl(job)` (so it covers every job): rows then expect the names rule's problem and the env-key problem, and get neither |
| D8 | the install check and the discovery step both present, the make line run first | covered by D3 |

### 3b. The lanes, per lane `L`

Order rows (each is one move, expected problems named by anchor):

| Id | Rows | Mutant |
|---|---|---|
| S4 | the check after `make build`; `make test` before `make build`; the sodium build before check-chez (two problems: out of order and the restore after it); `make build` before the check (the same plant read the other way) | `endjob`'s `if (pos <= lastp)` made `if (pos <= lastp && !isl(job))` |
| S19 | the compiler step moved below the sodium restore | `cacheorder`'s restore-after-compiler test skipped |
| S16 | the sodium restore moved below the check | the sodium half's restore-before-build test skipped (the move puts it after build and check) |
| S17 | the sodium save moved above the build | the save-after-build test skipped |
| S18 | the sodium save moved below the check | the save-before-check test skipped |
| S21 | the sodium restore uses `actions/cache`, not `actions/cache/restore` | the allowed-`uses` list is not applied to the lanes |

Step presence and exactness (each deleted, each written twice):

| Id | Rows | Mutant |
|---|---|---|
| S1 | the checkout without submodules; with `submodules: false` | the first-step rule drops `isl(job)` |
| S2a..S2g | the step that runs, in turn, the Chez build, check-chez, the compiler line, the sodium build, the sodium check, `make build`, `make test`, deleted (one mutant per line, by dropping that line from the lane's `nreq`) | each mutant removes its own line from `nreq`'s lane branch; the "has 0 steps" rows for that line report nothing |
| S3 | the same lines written twice | the count test `c != 1` becomes `c < 1` for lane jobs |
| S23 | `make test X`; `make test` as a block scalar; `make build X` (and the unrelated rows' second problem: the env keys now on a step that is none of the three); the check with the other lane's flag (floor with `--current`, current without); the build with the other lane's flag; the build into another directory `sodium-x` (also the sodium `if` now on a step that builds no cache); the compiler line with `head -n 2`; check-chez with `--nothreads` | the required-line match is loosened to "the run line begins with the required line" for lane jobs |
| S22 | the compiler step without `id: cc` | the `S_id != "cc"` test is skipped for lanes |

The `if:` rows:

| Id | Rows | Mutant |
|---|---|---|
| S5 | the sodium build without its `if` | `sbld` is not treated as carrying an `if` |
| S6 | the sodium build with `if: false`; `if: always()` on the check, `make build` and `make test` (first problem of each: the lane lists its two ifs) | `lanestep` accepts an `if` of any value |
| S7 | `if: always()` on the check, `make build`, `make test`, and `continue-on-error` is a step key (second problem) | the "step that runs X has an if" test is skipped for the lane kinds `schk`, `sbuild`, `stest` |
| S8 | the Chez `if` on the sodium build; on the sodium save; on `make test` | the check of where `IFLINE` may stand is skipped for lanes |
| S9 | the sodium `if` on the Chez build; on the Chez save; on `make test`; the build into another directory | the check of where `IFSOD` may stand is skipped |

The cache rows:

| Id | Rows | Mutant |
|---|---|---|
| S10 | the sodium key drops each hash part (floors file and `floor.sh` and the two scripts for `floor`; the two scripts for `current`); hashes one file more; drops the compiler; drops the image; takes the other lane's prefix; is the other lane's whole key; has a tail | `S_key != sodkey[job]` skipped for the sodium restore |
| S10b | the sodium key drops the compiler; drops the image; has a tail | the key compare reads only up to the end of the `hashFiles(...)` expression |
| S11 | the Chez key drops a file; the Chez cache's key rows of `cache-rows` over the lanes (prefix, tail, no expression, one file more, the other Chez's prefix) | `keyok` skipped for lanes |
| S12 | the sodium restore without `id`; with `id: sodium-x` | the `S_id != "sodium"` test skipped |
| S13 | the sodium save keyed by the Chez cache; the sodium save keyed as a restore is | the sodium save's key test skipped |
| S13b | the Chez save keyed by the sodium cache | the Chez save's key test skipped in lanes |
| S14 | the sodium restore's path is the other lane's; the sodium save's path is the other lane's (its `if` then stands on a step that is no cache's save, a second problem); the restore with a `with` value naming a banned word | the path-set test (two paths) skipped |
| S15 | the sodium restore deleted; written twice; the save deleted | `nr != 1` and `ns != 1` skipped for the sodium path |
| S15b | the generic `cache-rows` over the lanes: restore or save of the Chez cache deleted or written twice | the Chez count test counts every cache step, sodium included (this mutant refuses the real file, so it is not a valid mutant; the real-file check catches it. The Chez counts are guarded by the generic rows' deleted/twice plants and by the real file passing) |

The env exception rows:

| Id | Rows | Mutant |
|---|---|---|
| S24 | the suites' env gains `CPATH`, `LD_LIBRARY_PATH`, `CC`, `MAKEFLAGS`, `CHEZ_SODIUM_DECOY`-style names (second problem: the lane's env-key list) | `key in laneenv` test skipped |
| S25 | the check's `CHEZ` is the nothreads Chez | `CHEZ`'s value test skipped for lanes |
| S26 | the check without `CHEZ`; the check without any env; the sodium build without `CHEZ` | `needenv(..., "CHEZ")` skipped for lane kinds |
| S27 | `make build` without `CHEZ_SODIUM_LIBRARY`; the check without any env (library) | `needenv(..., "CHEZ_SODIUM_LIBRARY")` skipped |
| S28 | `make test` without `C_INCLUDE_PATH`; the check without any env (header) | `needenv(..., "C_INCLUDE_PATH")` skipped |
| S29 | the check's library is the other lane's; the library relative; **new:** the library is this lane's directory with the other release's soname (floor with `.so.26`, current with `.so.23`) | `envval` of the library skipped |
| S30 | the suites' header directory has a second directory (`:/usr/include`) | `envval` of the header directory skipped |
| S31 | the sodium build with the override; the sodium restore with the header directory; the Chez build with the override; and the second problem of the rows that change a step's run line (`make test X`, a block scalar, the check with the other flag) | the final loop ("only for the steps that run check, make build and make test") skipped |
| S32 | `main`'s install check, a memory step and `nothreads`' step each gain a name with floor's exact value; **new:** the discovery step does | same as D7 |
| S33 | **new:** a lane env line `C_INCLUDE_PATH: <its value with CPATH in it>` (a banned word in the value) | the exemption `x == ealk` widened to `x in banned` |
| S34 | **new:** a lane step's `with:` gains the key `C_INCLUDE_PATH` (the names rule and the with-key problem) | the `ealk` test drops its `subk == "env"` condition |
| S35 | a run block exports `CHEZ_SODIUM_LIBRARY`; `C_INCLUDE_PATH` written to `GITHUB_ENV`; a step name that names `C_INCLUDE_PATH`; a `with` value naming `CHEZ_SODIUM_LIBRARY`; a run line naming `C_INCLUDE_PATH` | these are the names rule on the lane's lines: mutant: the rule's `banned` test skipped for lane jobs. Valid: the lane's own env lines go through `ealk` and still pass |

The job-set rows:

| Id | Rows | Mutant |
|---|---|---|
| S36 | the `floor` job deleted; the `current` job deleted | the missing-job loop in `endsec` ends before the lanes |
| S37 | a job beside the five (`extra`) | `wantjob` accepts any name |
| S38 | the generic `job-key-rows` run on the lanes (a job key, `runs-on`, no `timeout-minutes`, no name, steps with a value) | no lane-specific code: control rows only. A mutant in `jobkey`/`JOBKEYS` is M0's, global |

The execute-bit rows:

| Id | Rows | Mutant |
|---|---|---|
| X1 | `build-sodium.sh` without its execute bit: the two steps that run it are named; `build-sodium.sh` missing | the execute-bit loop exempts `scripts/ci/build-sodium.sh` |
| X2 | `check-sodium.sh` without its execute bit: its three steps are named (discovery, two lanes' check); `check-sodium.sh` missing | the loop exempts `scripts/ci/check-sodium.sh` |

### 3c. Showing the real `ci.yml` passes under every mutant

As slice 3's log did, and for the same reason (a mutant that refuses the whole input turns every
row red and proves none):

1. Each mutant is applied to a copy, not the live file. Another builder runs `make test` in this
   tree, whose `check-ci` reads `tests/check-ci.sh`; an in-place edit would fail their run. The
   copy is a whole copy of the tree under `build/slice5-lanes/mut/` (tracked files plus the
   untracked ones the suite reads), with stub executables for `build-sodium.sh` and
   `check-sodium.sh` in the copy if the other builder's are not there yet.
2. Per mutant: assert that the old text occurs once in the copy's `tests/check-ci.sh`; apply
   it; run `sh tests/check-ci.sh DIR` on a directory that holds the real `ci.yml` alone, with
   mawk, and require exit 0 and the exact pass line; only then run the whole suite on the
   copy, record which rows failed by name, and restore the copy. The log records both lines.
3. After all mutants: `diff -r` the copy against the tree, the real files compared; the suite
   run green in the real tree; `make check-ci`; and the suite under the gate with its time.
4. Mutants that cannot pass step 2 (S15b above) are marked and not counted. Their rules are
   held by the real file passing, which is itself step 2 with no mutant.
5. Every mutant must also fail some row: a mutant that survives is reported, with the row that
   would kill it, not hidden (the "Result: killed / survived" column of slice 3's log).

---------------------------------------------------------------------------------------------

## 4. Flags

**F1. The cache keys depend on what the other builder's scripts read.** The floor's key hashes the
floors file, `floor.sh`, `build-sodium.sh` and `check-sodium.sh`; the current's hashes the two
scripts alone. That holds only if the floor role reads its version from `floor.sh`/`floors.sexp`
and nothing else, and the `--current` role reads its pinned version and checksum from
`build-sodium.sh` itself. If `check-sodium.sh --current` takes the release from a file the key
does not hash (a pins file, a sourced helper), a pin change leaves a stale library in the cache
and the lane passes on it. `check-ci` can hold only the text of the list. Ask the other builder
for the files each script reads or sources, before phase 2; if there is a third, it joins both
lists and the awk tables.

**F2. A lane has two caches, and today's `cacheorder` counts every cache step as the Chez one.**
Added whole, the two sodium cache steps give "2 restores of the Chez cache" and fail the real
file. The Chez half must skip steps at the sodium path, and the sodium half must be per path
(2c, items 6 and 7). Not a defect in the plan, but the one place a straight copy of v0.1.1 into
slice 3's structure goes wrong, since v0.1.1's lanes did not count the Chez cache at all. M0's
count is stricter and stays.

**F3. Ordering dependency on the other builder's files.** The execute-bit rule reads
`scripts/ci/NAME` in the real tree for each step that runs one by its path; `make check-ci` and
the suite's real-file row fail until both new scripts exist and are executable. The rows named for
them copy `scripts/ci` and fail in the same way. I will test with stubs in a copy; the join
reruns `make check-ci` and the suite in the real tree once both land. I touch neither script.

**F4. The plan and the brief place the discovery step slightly differently.** The plan's §2.3 row
says "then the floor step"; §2.4 says after the install check; §4.2 item 10 says "a step, after
`make build`"; the brief says after the install check and before the make step. They agree
(the brief is the narrowest); `check-ci` holds both sides through the required-line order. Also
§2.3 and §2.4 list the install check and `check-dev` among what slice 5 gives `main`: slice 3
already did, and slice 5 adds the discovery step alone.

**F5. "As v0.1.1 plants them" leaves one gap.** v0.1.1's two lanes shared the soname
(`libsqlite3.so.0`), so none of its rows can show that the library value is held to the soname and
not only the directory. Here the lanes differ (`.so.23`, `.so.26`). New row S29 (same directory,
the other release's soname) and the mutant that compares the value only up to `/lib/`. Also new
(beyond v0.1.1): S33 and S34 (the names-rule exception's two edges), and the discovery step's
refusal of the two names (S32/D7), which v0.1.1 could not plant.

**F6. Time of `test-check-ci.sps`.** Slice 3 measured 55 s under the gate for 374 passes against a
450 s ceiling (three quarters of `MEMORY_TIMEOUT` 600). Each row starts a `sh`, a `mktemp` and an
awk, and the lanes are the bulk of v0.1.1's suite; expect it several times slower. Measure the
plain run and the gated run in phase 2. If a gated run nears the ceiling, the suite must split,
and a new `tests/test-*.sps` is outside what I own, so that is the caller's call.

**F7. Two v0.1.1 row families are dropped or merged, a judgment for the caller.** Rule 9 (the
spelling rules planted in a lane's steps) are global rules that run before job dispatch, with
M0's rows planting each in `main`; nothing in the lane code can be mutated. Rule 2 (job keys per
lane) is replaced by today's generic `job-key-rows` run over five jobs (its lane copies were
twins of it). If you want the rule-9 rows kept as controls, they are two rows per lane with no
mutant.

**F8. Not held in any job, in v0.1.1 or here: "Identify the runner image".** Every cache key reads
`steps.image.outputs.id`. Delete the step and the key ends in an empty id, with no problem. v0.1.1
and M0 are the same. Out of scope; say if you want it required in the lanes.

**F9. Nothing keeps `check-sodium.sh --discovery` out of a lane, or the PREFIX form out of `main`.**
A step in `main` running `check-sodium.sh "$RUNNER_TEMP/sodium-floor"` is not refused by
`check-ci` (it would need the override in its env, which the names rule refuses, so the script
would fail it at run time). Left as is: required lines are exact, and no rule here bans extra
steps in `main`, as with other scripts. A gate-style rule (`--discovery` only as `main`'s one
whole run line) is possible, cheap, and unneeded unless you want it.

**F10. Existing rows may raise once the lanes copy text.** `apply-edit` requires an old text to
occur exactly once in the real file; slice 3's rows use `e` (whole-file) for some steps and `le`
(per job) for others, and any `e` whose text a lane now repeats (for instance run lines
`make build`, `make test`-like text, the install block, the cache steps) will raise and fail its
row by name. The audit in 2d finds them before any row is changed; each becomes `le`.

**F11. The `ci.yml` header and `check-ci.sh` header both describe the shape in words that go
stale** ("these three jobs", "no if: but on the Chez cache's own steps", the Chez-only
cache paragraph). Both are mine in phase 2; AGENTS.md's comment rule applies (no milestone,
slice, date, "the maintainer"; no floor's version in any file under `.github/`).

**F12. The scripts' interface relies on `build-sodium.sh` setting the override for its own check.**
The build step carries `CHEZ` alone (the env exception does not cover it); `check-sodium.sh`
needs `CHEZ_SODIUM_LIBRARY` and `C_INCLUDE_PATH`. v0.1.1's `build-sqlite.sh` sets both itself
(prefix first in `C_INCLUDE_PATH`, with a `${C_INCLUDE_PATH:+:...}` tail); this one must too, with
the same shape. On the runner the tail is empty, so `PREFIX/include` alone, which is what the
lanes' check step carries (traps.md, "In the container, `C_INCLUDE_PATH` set alone loses the
kernel headers"). Worth confirming with the other builder; no change here either way.

**F13. Minor: `check-sodium.sh` in the cache key.** Its `--discovery` role lives in the same file,
so an edit to that role re-keys both lanes and rebuilds libsodium (17 s). Harmless, noted so
nobody takes it for a defect.
