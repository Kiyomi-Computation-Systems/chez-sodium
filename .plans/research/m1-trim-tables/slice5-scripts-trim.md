# Slice 5, the libsodium scripts: phase 1 (trim tables, design note, rows and mutants, flags)

Author: the libsodium-scripts builder, phase 1. No project file was changed. Sources read:
AGENTS.md; the M1 plan §2.3, §4.2 items 10 and 11, §5.2, §6 (slice 5 and "Every brief restates
these"); ADR-0002, 0003, 0011; `global-constraints.md`; `traps.md`; chez-sqlite3 `traps.md`; v0.1.1
(`960d9f0`) `build-sqlite.sh` (202 lines), `check-sqlite.sh` (408), `test-ci-sqlite.sps` (1804);
ours `floor.sh`, `report-sodium.sh`, `check-chez.sh`, `tests/preflight.sps`, `check-floors.sps`,
`floors.sls`'s `scripts-problems`, the `floors-script` plant in `check-test-fails.sh`, the
Makefile's `build` and `test-memory`, `gated-command`.

Probes run (container, from this tree, under `build/slice5-scripts/` unless noted):

| Probe | Result |
|---|---|
| Chez FFI probe (`load-shared-object`, four `foreign-procedure`s) against `build/slice5/prefix-1.0.18` and `-1.0.22` | prints `version 1.0.18, major 10, minor 3, minimal 0` and `1.0.22, 26, 4, 0`. A path that is no file: `Exception: (while loading /nonexistent) ... cannot open shared object file`, exit 255. |
| `$CC -E -M` of `#include <sodium.h>` with `C_INCLUDE_PATH=PREFIX/include` alone | fails: first lines are `In file included from .../bits/posix1_lim.h ... limits.h` (the container trap). |
| the same with `C_INCLUDE_PATH=PREFIX/include:$C_INCLUDE_PATH` | passes. The listing is `find.o: find.c \` then `stdc-predef.h`, `PREFIX/include/sodium.h`, `PREFIX/include/sodium/version.h`, in that order. `-dM -E` lists `SODIUM_VERSION_STRING "1.0.18"`, `SODIUM_LIBRARY_VERSION_MAJOR 10`, `_MINOR 3` (and 1.0.22's 26 and 4). |
| the container's ambient `C_INCLUDE_PATH` | `<profile>/include`, which holds the real `sodium.h` (1.0.22). A row that needs "no sodium.h on the include path" cannot be a real-compiler row here (nor on `main`, where `/usr/include/sodium.h` exists). |
| `scripts/guix-env sh -c 'make build'`, and preflight with `CHEZ_SODIUM_LIBRARY` unset | stdout is exactly four lines: `chez-sodium: libsodium loaded and accepted`, `  path:       P (SOURCE)`, `  version:    V (library M.N)`, `  counts:     ((block . 0))`. Unset: source is `guix-environment`; an FHS world's source is `system` (`discovery.sls`). |
| libsodium's `configure` | `--with-pthreads` is on by default (`AX_PTHREAD`); when it fails, `configure` only notes "pthread mutexes are not available" and builds with no mutex. Plain configure of both releases defines `HAVE_PTHREAD=1` (`grep -c -- -DHAVE_PTHREAD=1 src/libsodium/Makefile` gives 1 on each). See F3. |
| a minimal build | `configure.ac` writes `#define SODIUM_LIBRARY_MINIMAL 1` into `version.h` and drops functions (`Makefile.am` has `if !MINIMAL`). Neither default build defines it. |
| serial build, 1.0.22 in a copy (`make distclean`, `./configure --prefix=...`, `make -j1`, `make install`) | 58 s in all on this machine, against the host's 17 s on 18 cores. |
| row cost: stub compile + `-E -M` + `-dM -E` + Chez probe, 10 times | 1.0 s, so about 0.1 s of work per `check-sodium.sh` row. |
| `make test-memory MEMORY_SUITES=tests/test-check-floors.sps` (404 rows, 5.1 s plain) | 24 s under the gate. |
| the same for `tests/test-check-ci.sps` (374 rows, 11.2 s plain) | 54 s under the gate. |

Side effect to disclose: the two `test-memory` runs wrote `build/memory/test-check-floors.*` and
`test-check-ci.*` (ignored files), outside `build/slice5-scripts/`. `build/slice5/` was only read.

---

## 1. Trim tables

"Protects" is what the v0.1.1 part guarded. "Now" is where that lives here, or why nothing here
needs it. File names: `build-sodium.sh` (B), `check-sodium.sh` (C), `test-ci-sodium.sps` (T).

### 1.1 `build-sodium.sh` from `build-sqlite.sh`

| Part of v0.1.1 | Verdict | Protects | Now |
|---|---|---|---|
| Header comment | **Changed** | A reader's account of roles, pins, flags, env | Rewritten for libsodium. It names no floor text, no milestone, no date, no `maintainer`. It says: roles `floor` and `current`; pins keyed by role; floor from `floor.sh sodium`; env read is `CC`, `CHEZ`, `TMPDIR`, `C_INCLUDE_PATH`; PREFIX absolute. |
| `usage`, argument parse | **Changed** | A mistyped lane | `PREFIX [--current]`; any other word is exit 2. `--no-load` becomes a usage error, a row (B-u5). |
| `--no-load` role, its second build, its pins | **Dropped** | A library without `sqlite3_load_extension`, as Apple's, so suites ran their unavailable branches | libsodium has no optional entry point: every one is required (ADR-0002, decision 4). The nearest hazard, a minimal build that drops functions, is refused by C's `sodium_library_minimal()` check (C-m1, C-m2). Plan §2.3 drops it too. |
| Absolute-PREFIX test | **Kept** | A relative prefix resolved against the wrong directory | Same; exit 2, before any download (B-u7). |
| `fail`, `here` | **Kept** | Messages and the scripts' own place | Same, `build-sodium.sh:` prefix. |
| `current_version=3.54.1` | **Changed** | The one place the current release is written | `current_version=1.0.22`. Written in B and C, as v0.1.1 wrote it in three places; T holds a reviewed copy. A change that misses one fails at B's own call to C, before a cache saves (row B-c5). |
| `floor_year`, `current_year`, `year` | **Dropped** | sqlite.org's year directory for the archive | libsodium's two URLs hold no year. The same fact, "where the tarball lives today", is the fallback: `releases/`, then `releases/old/` (B-d1..B-d4). |
| `floor_archive`, `current_archive` (SHA3-256) | **Changed** | The tarball is the one the project measured | SHA-256, same names, keyed by role. Values in the brief's table. |
| `floor_source`, `current_source` (sqlite3.c's SHA3-256 from the release log) | **Dropped** | A second, independent digest, from the publisher's own log, over the one file compiled | The whole tarball is pinned, so every file in it is. libsodium publishes no per-file digest in a log; its `.minisig` is checked once, when the pin is made (ADR-0003, decision 6), not in the lane, since the runner has no `minisign`. Nothing here needs a second pin. The cost is named in F7. |
| Role/pin selection block | **Changed** | Floor and current never share a pin; the floor's version never written here | Same shape. `version=$(sh "$here/floor.sh" sodium)` for `floor`; `current_version` for `current`. No floor text in `scripts/ci/`: `check-floors` refuses it (rows B-f1, B-f2 and the `floors-script` plant). |
| Archive-number arithmetic (`%d%02d%02d00`) | **Dropped** | `sqlite-autoconf-NNNNNNN` names for versions with two-digit parts | The name is the dotted version: `libsodium-$version.tar.gz`. One row has a multi-digit floor so a padded name is red (B-f3). |
| `need` list: curl, openssl, tar, cc | **Changed** | A missing tool named before any download | curl, `sha256sum`, tar, make, cc, each named with why, before any download. `openssl` goes. `gzip` is not named: `tar xzf` fails with its own words (both runner and container have it or the row stands in). |
| Work directory, `trap` | **Kept** | No file left behind | Same (`build-sodium.XXXXXX`). Rows count the directories and assert `tmp/` empty after success and failure. |
| `sha3_of` (`openssl dgst -sha3-256 -r`) | **Changed** | A digest read the same way for archive and source | `sha256_of` runs `sha256sum FILE` and takes field 1. The stand-in refuses any other argv, as v0.1.1's refused any argv but `dgst -sha3-256 -r FILE`. |
| `curl -fsSL --retry 3 -o` one URL, with the "pins may be stale" hint | **Changed** | Download failure says which pin may be old | Two attempts, `releases/` then `releases/old/`; both failing names both URLs and the same hint, per role. |
| Digest check refusing before unpack | **Kept** | Nothing unpacked unless the pin matches | Same order: download, digest, unpack. |
| `tar xzf` of three named members | **Changed** | Only the files wanted leave the archive | Whole archive unpacked into the work directory; then `libsodium-V/configure` must be a file. Wrong members cannot happen (the archive is pinned). The `configure` test replaces tar's own failure on a missing member (B-t3). |
| Second digest, of `sqlite3.c` | **Dropped** | See the source pin | See the source pin. |
| The three `cc -shared ...` lines | **Replaced** | One compile with fixed flags, by role | In a subshell in the unpacked directory: `CC=$cc ./configure --prefix=$prefix`, `make`, `make install`, each logged to the work directory and, on failure, its last 30 lines printed. No flag differs by role; no flag beyond `--prefix` (measured). Serial `make`: 58 s here, once per cold cache; no `nproc` to find or stand in for (F10). |
| `-DSQLITE_THREADSAFE=1` (the build never depends on a default) | **Changed** | A non-threadsafe library | libsodium's analogue is `--with-pthreads`, on by default, silently off when `AX_PTHREAD` fails. F3 offers a post-configure assertion. |
| `-Wl,-z,defs` (an unresolved symbol fails the build, not the load) | **Dropped** | A library with an unresolved symbol failing only when loaded | libsodium's libtool link has no unresolved external but libc and pthread. The probe at the end of C loads the library and calls four functions, before any cache saves. Lazy binding could hide an unused symbol; none is bound but by name at chez-sodium's own load, which every lane runs. |
| `mkdir -p prefix/lib prefix/include`, `cp sqlite3.h sqlite3ext.h` | **Dropped** | The header and library placed where C looks | `make install` places `lib/libsodium.so.NN` and `include/sodium.h` and `include/sodium/*.h` (`sodium/version.h` holds the three macros C reads). C then checks both. |
| Call to `check-sqlite.sh` with `CHEZ_SQLITE3_LIBRARY` and `C_INCLUDE_PATH` for that call only | **Kept** | A build that came out other than asked is no build | `CHEZ_SODIUM_LIBRARY=$prefix/lib/libsodium.so.NN` (`.23` floor, `.26` current), `C_INCLUDE_PATH=$prefix/include${C_INCLUDE_PATH:+:$C_INCLUDE_PATH}`, `sh C PREFIX [--current]`. This already is correct in the container (prepends the ambient value) and on the runner (unset). |
| Last `echo` | **Kept** | The lane's log says what was built | `build-sodium.sh: libsodium V built into PREFIX`. |

### 1.2 `check-sodium.sh` from `check-sqlite.sh`

| Part of v0.1.1 | Verdict | Protects | Now |
|---|---|---|---|
| Header comment | **Changed** | The account of what is checked, in order | Rewritten. Floor text and milestone words stay out. |
| Roles floor, `--current`, `--no-load` | **Changed** | A lane tests the build it names | `PREFIX`, `PREFIX --current`, and `--discovery` alone. `--no-load` is a usage error. `--discovery` with a prefix, or a prefix with `--discovery`, is a usage error. |
| `LC_ALL=C` | **Kept** | Bytes, not characters | Same. |
| `current_version`, floor from `floor.sh` | **Kept** | The version a role must be | `floor` and `discovery` read `floor.sh sodium`; `current` reads no floors file. |
| `floor_source_id`, `current_source_id` | **Dropped** | A same-version, different-build library | libsodium has no source id. Cache-served or mislabelled builds are caught by version, soname, major/minor and minimal; a same-release patched build of a pinned tarball cannot arise, since the tarball is pinned. `main`'s distribution build is the one patched libsodium, and no check can name its patches (ADR-0003, decision 5). |
| `SQLITE_VERSION_NUMBER` arithmetic | **Dropped** | The number form of the version | `sodium.h` has no number form of the release. `SODIUM_LIBRARY_VERSION_MAJOR` and `_MINOR` are libtool numbers, and are compared with the library's, not the floor (F9). |
| `floor_options`, `current_options`, `no_load_options` (three heredocs, 37 to 40 lines) | **Dropped** | `DEFAULT_MEMSTATUS=0` (breaking the memory check), `THREADSAFE=0`, a current build without FTS5, a no-load build without both | libsodium lists no compile options and has no optional feature the suites need. The two hazards with libsodium analogues: a minimal build (checked, C-m1/C-m2) and no pthreads (build-time assertion, F3). |
| The `COMPILER=` computation (`compiler.c`, `-E -P`) | **Dropped** | The one option SQLite derives from the compiler | No option list to complete. |
| `cc_failed` | **Kept** | The compiler's own words when it fails | Same. In the container, a `C_INCLUDE_PATH` of `PREFIX/include` alone makes `-E -M` fail; this reports it (see §2.3). |
| Step 1, files | **Changed** | The lane's library and header exist | `PREFIX/lib/libsodium.so.23` (floor) or `.so.26` (current), `PREFIX/include/sodium.h`, each `-f`. `make install` leaves the soname as a link to `libsodium.so.NN.x.y`; `-f` follows it and fails on a dangling one. |
| Step 2, override equals the library | **Kept** | `make build` and `make test` load what was checked | Same with `CHEZ_SODIUM_LIBRARY`. |
| Step 3, `$CC -E -M` finds the header, with awk over the make rule | **Kept** | The suites compile against the library's own header | Same, for `sodium.h`. The pattern is `(^|/)sodium\.h$`, which `sodium/version.h` does not match. `-M`, never `-MM`: directories on `C_INCLUDE_PATH` count as system ones and `-MM` leaves them out (mutant C-h3). |
| Step 4, `SQLITE_VERSION`, number, source id from `-dM -E` | **Changed** | The header declares the role's release | `SODIUM_VERSION_STRING` equals the role's version; `SODIUM_LIBRARY_VERSION_MAJOR` and `_MINOR` are each a natural (else refused, naming the header). They are kept for step 5. |
| Step 5, Chez probe of a stub's six functions | **Changed** | The library, read as the loader reads it, never through the binding | Probe of its own: `load-shared-object`, then `sodium_version_string`, `sodium_library_version_major`, `_minor`, `sodium_library_minimal`. Library version equals the role's; major and minor equal the header's; minimal is 0. §2.3. |
| `sqlite3_threadsafe()` answers 1 | **Dropped** | The serialized threading mode | libsodium has no such function (F3). |
| `diff -u` of the options | **Dropped** | An option list whole, line for line | No list. |
| Success lines | **Changed** | The log shows what was checked | Two lines, §2.2. |
| `--discovery` | **New** | Plan §4.2 item 10: `main` loaded the floor | §2.2. |

### 1.3 `test-ci-sodium.sps` from `test-ci-sqlite.sps` (1804 lines)

| Part of v0.1.1 | Verdict | Protects | Now |
|---|---|---|---|
| Header comment | **Changed** | The suite's method, said once | Rewritten, including the gate paragraph (§2.5). |
| `runner`, failure printer, `outcome` | **Kept** | Failing rows name expected and actual | Same. |
| `CHEZ` set, `CC` one word, each a test then `(exit 1)` | **Kept** | A row that cannot run fails, never skips | Same. |
| String helpers (`q`, `text-of`, `indented`, `text-lines`, `string-prefix?`) | **Kept**, as many as used | Whole outputs written by hand | Used ones only. |
| `defines`, `unquoted`, `compiler-option`, `with-compiler`, their 3 rows | **Dropped** | The `COMPILER=` entry expected by rows | No option list. |
| `floor-source-id`, current id/number, `floor-options`, `current-options`, `no-load-options`, the count row | **Dropped** | Reviewed copies of what SQLite lists | Nothing to copy. Two SHA-256 literals and `current_version` remain as reviewed copies. |
| `write-file`, `checked`, `write-file-in`, `floors-text`, `with-tree`, `env-order` | **Kept**, `floors-text` writes the `sodium` key | A fresh tree per row with the row's own floors file | Same. |
| Stub library of six functions, header of three `#define`s | **Changed** | A library and header answering exactly what a row says | Stub of four functions; `sodium.h` of three `#define`s. A stub library answers a NULL string by returning 0. |
| `lane-env` | **Changed** | The env a lane's check step gives | Sets `CHEZ_SODIUM_LIBRARY`; `C_INCLUDE_PATH=PREFIX/include` followed by the suite's own ambient `C_INCLUDE_PATH` when it is set (the container needs it, the runner has none); `CC`, `CHEZ`; `-u CPATH`. §2.3. |
| `spec-with`, `make-prefix!`, `check-row`, `check-run`, `matches?` | **Kept** | One row is one edit of a passing row | Same. |
| `passes`, `refused`, `identity`, `library-refused`, `header-refused`, `threadsafe-refused`, `library-env-refused`, `header-elsewhere` | **Changed** | Expected whole stdout and stderr by hand | Rewritten for libsodium's messages. `threadsafe-refused` goes. |
| `options-refused`, `sublist`, `position`, `hunk` (about 110 lines), the options-edit rows | **Dropped** | The diff an options mismatch prints | No diff. |
| `no-load-*` specs and rows | **Dropped** | The no-load role | None. |
| Build-tree machinery: `shim-text`, `build-env`, `make-build-tree!`, `work-written`, `normalized`, `prefix-state`, `build-row` | **Kept**, adapted | Calls whole and in order; `PATH` holds shims and linked tools only; work directories counted and removed | Shims: `curl`, `sha256sum`, `tar` (makes `configure`), `make`, `cc`. `openssl` goes. `row-tools` becomes the tools the scripts call, §2.4. Every tool a row names, `sh`, `CHEZ` and the real `cc`, is handed over by its path. |
| `padded-number` and rows for two-digit parts | **Dropped**, one row kept | `NNNNNNN` names | Replaced by B-f3. |
| Flag rows (`floor-flags`, `current-flags`, `no-load-flags`) | **Replaced** | Each compile line | Rows on the three build calls (B-b rows). |
| Execute-bit row | **Kept** | CI runs the scripts by name | Same. |
| Usage rows | **Kept**, adapted | Exit 2 and the usage line | §3. |
| Discovery rows | **New** | Plan §4.2 item 10 | §3. |
| The Makefile row | **New** | The preflight command line equals `make build`'s | §3, X1. |

No fixtures are needed: every tree, stub library and header is generated by the suite, as v0.1.1's
were. `tests/fixtures/ci-sodium/` is not created.

---

## 2. Design note

### 2.1 `build-sodium.sh PREFIX [--current]`

Steps, in order. Each says what it refuses, the exit status, and the stderr form (`build-sodium.sh:`
prefix on every message).

1. **Arguments.** One or two words; the second is exactly `--current`. Otherwise `usage: build-sodium.sh PREFIX [--current]`, exit 2. PREFIX must start with `/` and have a name after it, else `PREFIX must be an absolute path, not '...'`, exit 2.
2. **Role and pins.** `floor`: `version=$(sh "$here/floor.sh" sodium)`, failing as `no libsodium floor to build` (after floor.sh's own line), exit 1. `current`: `version=$current_version`. Pin `archive_pin=${role}_archive`. The file name is `libsodium-$version.tar.gz`. Nothing from the environment names version, pin or role (variables are assigned, never defaulted).
3. **Tools.** `curl`, `sha256sum`, `tar`, `make`, and `${CC:-cc}`, each missing one named as `cannot find T, which ...`, all named in that order, then exit 1, before any download.
4. **Work directory.** `mktemp -d "${TMPDIR:-/tmp}/build-sodium.XXXXXX"`, removed by a `trap` on EXIT.
5. **Download.** `curl -fsSL --retry 3 -o WORK/NAME https://download.libsodium.org/libsodium/releases/NAME`. On failure print `build-sodium.sh: NAME is not under .../releases/, trying .../releases/old/` and try `.../releases/old/NAME` the same way, after removing any partial file. Both failing: `could not download NAME from .../releases/ or .../releases/old/: if the libsodium floor in packaging/floors.sexp was raised, floor_archive in this script may still be the old floor's` (for `current`: `if current_version was changed, current_archive in this script may still be the old release's`), exit 1. Order matters: the floor is under `old/` today and `releases/` 404s for it; the current release is under `releases/` and `old/` 404s for it, so the floor lane always shows the notice.
6. **Digest.** `sha256sum WORK/NAME`, field 1, equals the pin, else `NAME has SHA-256 GOT, but ${role}_archive in this script pins PIN`, exit 1, before anything is unpacked.
7. **Unpack.** `tar xzf WORK/NAME -C WORK`, failing as `tar could not unpack NAME`; then `WORK/libsodium-$version/configure` must be a file, else `NAME holds no libsodium-V/configure`, exit 1.
8. **Build,** in a subshell in `WORK/libsodium-$version`: `CC="$cc" ./configure --prefix="$prefix"`, then `make`, then `make install`, each output to `WORK/build.log`. A failing step prints `build-sodium.sh: configure failed (or make, or make install); the last 30 lines of its output:` and those lines, exit 1. (F3 adds an optional step 8a.) Nothing is written to PREFIX before `make install`.
9. **Check.** `CHEZ_SODIUM_LIBRARY=$prefix/lib/libsodium.so.NN C_INCLUDE_PATH=$prefix/include${C_INCLUDE_PATH:+:$C_INCLUDE_PATH} sh "$here/check-sodium.sh" PREFIX [--current]`. Its refusal is the script's exit status and words (nothing added).
10. Last line `build-sodium.sh: libsodium V built into PREFIX`, exit 0.

Env read: `CC`, `CHEZ` (for step 9), `TMPDIR`, `C_INCLUDE_PATH`. `CFLAGS`, `CPPFLAGS`, `LDFLAGS` reach `configure` unchanged: the build is plain, and C refuses a build that differs in what matters (F10).

### 2.2 `check-sodium.sh PREFIX [--current]` and `--discovery`

Floor and current, in order, stopping at the first problem (`check-sodium.sh:` prefix):

1. Arguments, as B's: usage exit 2, relative PREFIX exit 2. `--discovery` is accepted only as the sole argument.
2. Role words: version from `floor.sh sodium` (floor), or `current_version` (current); soname `libsodium.so.23` or `.so.26`; the wording `the libsodium floor` or `the pinned current libsodium`.
3. **Files:** `PREFIX/lib/SONAME` and `PREFIX/include/sodium.h` are each a file (`no library at ...: it is not a regular file`).
4. **Override:** `CHEZ_SODIUM_LIBRARY` set (an empty one counts as set) and equal to `PREFIX/lib/SONAME`, else two messages, as v0.1.1's, that say it must be that path "so that make build and make test load it".
5. **Header found:** `$CC -E -M` of `#include <sodium.h>` in a work directory. Compiler failure: `$cc could not preprocess a file that includes <sodium.h>:` and its words, whole. No `sodium.h` among the listed: `$cc lists no sodium.h among the files #include <sodium.h> reads`. The first one listed must be `PREFIX/include/sodium.h`, else `$cc finds <sodium.h> at X, not H: C_INCLUDE_PATH must name PREFIX/include first, so that the suites compile against the library's own header`.
6. **Header says the release:** `$CC -dM -E` of the same file; `SODIUM_VERSION_STRING` must be `"V"` exactly; `SODIUM_LIBRARY_VERSION_MAJOR` and `_MINOR` must each be digits. Else the three values are named (`H defines SODIUM_VERSION_STRING X, ... but the pinned ... is "V"`).
7. **Library, by a probe of its own,** §2.3. The library must answer version V, major and minor equal to the header's, and minimal 0. Each refusal names the library, what it answered, and what the header or role says.
8. Success, on stdout, two lines:
   - `check-sodium.sh: PREFIX/lib/SONAME is libsodium V (library M.N), the libsodium floor, and no minimal build` (role words as chosen)
   - `check-sodium.sh: CC finds <sodium.h> at PREFIX/include/sodium.h, which declares the same release, and CHEZ_SODIUM_LIBRARY names the library`

`--discovery` (env `CHEZ`, and `CC` if not `cc`), in order:

1. `CHEZ_SODIUM_LIBRARY` is unset: set, empty or not, is `CHEZ_SODIUM_LIBRARY is set, but main loads libsodium by discovery`. Refused before anything runs.
2. Floor V from `floor.sh sodium`.
3. **The report.** Runs preflight itself: `"$chez" --libdirs "$root/src" --program "$root/tests/preflight.sps"`, `root` two directories above the script (as `floor.sh` finds its root), stdout and stderr captured apart. Status must be 0 and stderr empty, else it says so and prints preflight's stderr whole (refusal text). Why it runs preflight itself and does not read something else: `make build` writes nothing, so there is no report to read; the workflow's step order is fixed by the interface (`--discovery` has `CHEZ` alone, no pipe from the `make build` step); and `make build`'s own recipe would add `make`'s noise and an error line of its own on refusal. The cost is one more Chez start, measured at tens of milliseconds, plus a command line that duplicates the Makefile's: row X1 holds the two equal.
4. **Header,** steps 5 and 6 above for the header `/usr/include/sodium.h` (the found header must be exactly that; `C_INCLUDE_PATH` that finds another is refused with the same "finds X, not H" words), version V, and major and minor digits.
5. The report must equal, whole, four lines: `chez-sodium: libsodium loaded and accepted`; `  path:       /usr/lib/x86_64-linux-gnu/libsodium.so.23 (system)`; `  version:    V (library M.N)` with the header's M and N; and a line that starts `  counts:     `. The counts line's value is not compared (it is native's counters and changes when M2 adds a kind); its presence and that the report is exactly four lines are. Anything else, an extra line, a missing one, another path, source, version, major or minor: refused, naming what was expected and what was read.
6. Success, two lines: `check-sodium.sh: make build loaded /usr/lib/x86_64-linux-gnu/libsodium.so.23 (system), libsodium V (library M.N), the floor` and `check-sodium.sh: CC finds <sodium.h> at /usr/include/sodium.h, which declares the same release, and CHEZ_SODIUM_LIBRARY is unset`.

The path `/usr/lib/x86_64-linux-gnu/...` is a literal: `main` is Ubuntu 24.04 on x86_64 only, and discovery's own candidate list names that triple (F4).

### 2.3 How C reads the library, and the include-path trap

**The probe.** C writes `WORK/read.ss` and runs `"$chez" -q --script WORK/read.ss LIB`. No `--libdirs`, no `--program`, no import of any `(chez-sodium ...)` library. The script is:

```scheme
(let ((lib (car (command-line-arguments))))
  (load-shared-object lib)
  (let ((version (foreign-procedure "sodium_version_string" () string))
        (major (foreign-procedure "sodium_library_version_major" () int))
        (minor (foreign-procedure "sodium_library_version_minor" () int))
        (minimal (foreign-procedure "sodium_library_minimal" () int)))
    (printf "version ~a~%major ~a~%minor ~a~%minimal ~a~%" (version) (major) (minor) (minimal))))
```

I ran exactly this against both prefixes (table above). It calls no function that needs `sodium_init`; it passes nothing to C, so no Scheme object crosses; `string` is a result type only. It is a script under `scripts/ci/`, which `check-seam` (it reads `src/` alone) does not cover. A NULL version is printed `#f` and is refused as a mismatch. A Chez that cannot run the probe, or a library that does not load, is `$chez could not read LIB:` and Chez's stderr whole, exit 1. A row in a tree with no `src/` at all proves the probe never reaches chez-sodium, and a recording CHEZ stand-in proves its argv has no `--libdirs`.

**The trap.** Under Guix, `C_INCLUDE_PATH=PREFIX/include` alone breaks every compile, because gcc finds the kernel headers through that variable too (probe above). The scripts never set or rewrite `C_INCLUDE_PATH` for the compiler; they use the value they are given:
- B builds the value for its call to C as `$prefix/include${C_INCLUDE_PATH:+:$C_INCLUDE_PATH}`: the container's ambient value follows, the runner's unset value adds nothing.
- C's `-E -M` uses that environment unchanged. Given `PREFIX/include` alone in the container, the compile fails and C says so with the compiler's words (`cc_failed`); given it first and the ambient value after, it lists `PREFIX/include/sodium.h` first. On the runner, either works.
- The suite's `lane-env` builds the value the same way, reading its own `C_INCLUDE_PATH`; no row sets it alone. The rows that need "another `sodium.h` first" put a directory of their own first and the ambient value last, and expect that directory's `sodium.h`, not any path the machine holds. The "lists no `sodium.h`" refusal is a row with a CC stand-in, since the container's ambient directory and `main`'s `/usr/include` each hold a real one.

### 2.4 The stand-ins `test-ci-sodium` puts on `PATH`

Check rows (like v0.1.1's) run with the real `PATH`, a real `CC` and `CHEZ`, and a compiled stub library and header, except where a row needs a stand-in for `CC` or `CHEZ`, handed over by absolute path in `CC=` or `CHEZ=`.

Build rows run with `PATH=ROOT/shim:ROOT/tools`; `sh`, `CHEZ` and the real compiler are named by their paths (`command -v`, in tests, as v0.1.1), never found on `PATH`. Every shim appends one line to `ROOT/calls`: its name and arguments. Work directories are normalised as `WORK` (B's) and `CWORK` (C's).

| Stand-in | Behaviour | Records |
|---|---|---|
| `curl` | prints `curl: URL` to stderr. Serves `ROOT/served` to its `-o` file for a URL listed in `ROOT/serves`; exits 22 (as `-f` does on a 404) for any other. | `curl -fsSL --retry 3 -o WORK/NAME URL`, one line per attempt |
| `sha256sum` | accepts exactly one argument, a file; answers `DIGEST  FILE` from `ROOT/digests`, keyed by the file's name; exit 1 when no digest, exit 64 on any other argv | `sha256sum WORK/NAME` |
| `tar` | accepts exactly `xzf ARCHIVE -C DIR`; makes `DIR/libsodium-V/` (V from the archive's name) holding an executable `configure`, unless `ROOT/no-configure` exists | `tar xzf WORK/NAME -C WORK` |
| `configure` (made by `tar`) | writes `.prefix` from `--prefix=`; exit 1 with three stderr lines when `ROOT/configure-fails`; (F3) writes a `src/libsodium/Makefile` line `-DHAVE_PTHREAD=1` unless `ROOT/no-pthread` | `configure [CC=$CC] ARGS [cwd=WORK/libsodium-V]` |
| `make` | exit 2 `no Makefile` unless `.prefix` exists (so a `make` before `configure` is red); `install` copies `ROOT/stub-lib` to `PREFIX/lib/SONAME` (the name from `ROOT/soname`) and `ROOT/header` to `PREFIX/include/sodium.h`; failure files `make-fails`, `install-fails` | `make ARGS [cwd=...]` |
| `cc` | as v0.1.1: logs its call with `[C_INCLUDE_PATH=...]` and `[CHEZ_SODIUM_LIBRARY=...]` when set; runs the real compiler (path in `ROOT/realcc`) for every call, or, with no `realcc`, prints nothing and exits 0 (so C's `-E -M` lists no header) | `cc [..] [..] ARGS` |
| `CHEZ` stand-in (discovery rows) | prints `ROOT/report-out`, `ROOT/report-err`, exits with `ROOT/report-status` | `chez ARGS [cwd=...]`, no normalisation of `ROOT` but `ROOT` itself |
| `CC` stand-in (discovery rows) | for `-E -M` prints `ROOT/find.d`; for `-dM -E` prints `ROOT/macros`; each with the exit status in a file | its argv, whole |

`row-tools` (linked into `ROOT/tools`) is every tool the scripts call besides the shims: `sh dirname sed tr grep awk mktemp rm mkdir cp cat cmp tail head cut` (final list is whatever the finished scripts call, and one row per tool proves `PATH` holds nothing else by leaving a tool out: that row's script fails by name). The five `chmod`s of v0.1.1's tree become one batched call.

### 2.5 The memory gate, and the suite's time

`gated-command` children: **none.** The rule binds a child that reaches `(chez-sodium private native)`, and "a child that runs only Scheme is outside it" (global constraints; ADR-0011). The suite's children are `sh`, the C compiler, the shims and, inside `check-sodium.sh`, a Chez that loads a stub library through its own FFI call: it imports no chez-sodium library and loads no libsodium. The gate also cannot hold a shell: its rule for a child's `Command:` line is Chez or `libsodium-oracle`. v0.1.1's `test-ci-sqlite` ran its script's Chez inside the script the same way, all through `capture-command`, outside the gate, and `test-check-floors` does so here today for `check-chez.sh` (24 s under the gate). The suite itself runs under Valgrind in `make test-memory`; its children run unseen, as intended. The suite's header says so, and says no row needs a gated child.

Children and time (estimates, calibrated by the probes above):

| Rows | About | `capture-command` children per row | Total |
|---|---|---|---|
| `check-sodium.sh` floor/current | 52 | mkdir, `cp -R scripts/ci`, stub compile, the run, cleanup: about 6 | about 310 |
| discovery | 24 | about 5 | about 120 |
| `build-sodium.sh` | 46 | about 8 (one batched tool-link) | about 370 |
| suite-level (CHEZ, CC, sh, exec bits, Makefile, counts) | 8 | 1 to 3 | about 15 |

About 130 rows and 800 children, none gated. Plain time: about 25 to 30 s (0.1 s of work per check row, a few tenths per build row). Under the gate: the driver is slowed by Valgrind and the children are not. `test-check-ci` runs 5 times slower under the gate than plain (11 s to 54 s); at that ratio this suite would take about 140 s; at `test-check-floors`' fixed overhead of about 19 s it would take about 50 s. Expect 60 to 140 s, against 450 s. If the measured time passes 225 s, split the suite by role into two programs that each carry their own helpers (a shared include body is forbidden); do not do it before.

---

## 3. Rows and mutants

Each row is one edit of a passing row, asserts exit status, whole stdout and whole stderr (and, for build rows, whole calls, work-directory counts, `tmp/` left, and PREFIX's state), written by hand. A mutant is one edit of the script, applied alone in a whole copy of the tree, the copy compared with the original afterwards. "Red" means the named row fails and no unnamed row is needed to see it. "Control" is the passing row that shows the mutant is not red for another reason.

### 3.1 `build-sodium.sh`

Base: floor 8.1.2, every shim serving, digests right, stub library/header, soname `libsodium.so.23`.

| ID | Row | Mutant that turns it red |
|---|---|---|
| B-p1 | **Each pin, floor.** The floor's pin is the brief's `6f50...36c1`: the real-copy row passes the digest check (calls reach `tar`) | `floor_archive` with one hex character changed |
| B-p2 | **Each pin, current.** `--current` with `adbd...3be3349` reaches `tar` | `current_archive` with one hex character changed |
| B-p3 | Floor archive with the current archive's digest refused naming `floor_archive`, both digests, nothing unpacked | the floor role reads `current_archive` |
| B-p4 | `--current` with the floor's digest refused naming `current_archive` | the current role reads `floor_archive` |
| B-p5 | An archive with a digest no pin has: refused, nothing unpacked, calls end at `sha256sum` | digest compare as `true \|\| fail ...` (the trap: not `false &&`) |
| B-p6 | The env sets `floor_archive`, `current_archive`, `version`, `current_version`, `role`, `pins` to the other release's: nothing moves | an assignment written `x=${x:-...}` |
| B-d1 | **Fails over.** `releases/` refused (curl exits 22), `old/` served: calls are curl twice, then `sha256sum`, `tar`, `configure`, `make`, `make install`, then C; stderr carries the notice | no fallback (single curl) |
| B-d2 | Both served: one curl only (control for B-d1) | `old/` tried first |
| B-d3 | **Fails both.** Neither served: two curls, nothing else, stderr names both URLs and the stale-pin hint; no PREFIX | the second failure ignored (`\|\| true`): calls continue to `sha256sum` of a missing file |
| B-d4 | Fails both, `--current`: the hint is the current one's | the two hints swapped |
| B-d5 | Only `releases/` served, `--current` (the real situation of the current release): one curl | `releases/old/` only |
| B-f1 | The real floors file: the floor's tarball name and URL come from `floor.sh` (calls name the name computed from `floors.sexp`) | the version written into the script (the brief's floor: also red in `make check-floors`) |
| B-f2 | A floor of 8.1.2: `libsodium-8.1.2.tar.gz`, the floor's pin goes with the role | the pin chosen by version |
| B-f3 | A floor of 8.12.103: `libsodium-8.12.103.tar.gz`, no padding | the name padded as v0.1.1's `%02d` |
| B-f4 | A malformed floors file: floor.sh's line, then `build-sodium.sh: no libsodium floor to build`, no download | `floor.sh` failure ignored |
| B-f5 | **The floor's text in `scripts/ci/`:** `make check-floors` plus the existing `floors-script` plant. A copy of the real tree with `build-sodium.sh` holding the real floor's dotted text on one line: `check-floors` fails naming `scripts/ci/build-sodium.sh: line N contains the libsodium floor ...`, `make test` runs no suite | the floor's text written into `build-sodium.sh`, then again into `check-sodium.sh`, once in a comment, once in code (two mutants). Not a suite row: `check-floors` is the check, as for every other script. |
| B-c1 | `--current` and no floors file: builds the pinned release, reads no floors file | `current` reads `floor.sh` |
| B-c2 | `--current` with a floor of 8.1.2 in the tree: still `current_version`'s tarball | `version` taken from the floor in both roles |
| B-c3 | The env sets `current_version`: the pinned release is still reached | `current_version=${current_version:-...}` |
| B-t1 | Each missing tool is named, before any download: `curl`, `sha256sum`, `tar`, `make`, `cc` (five rows) | the corresponding `need` line deleted (five mutants) |
| B-t2 | All five missing: five lines, in order, no download | the `[ -z "$missing" ]` test deleted |
| B-t3 | An archive holding no `configure`: `NAME holds no libsodium-V/configure`, nothing built | the `configure` test deleted |
| B-t4 | `tar` failing: `tar could not unpack NAME` | `\|\| fail` removed (set -e exits silently) |
| B-t5 | Unpack happens only after the digest (calls order) | `tar` call moved before `sha256sum` |
| B-b1 | **The build calls, whole:** `configure` (cwd `WORK/libsodium-V`, `CC=cc`, `--prefix=PREFIX`), `make`, `make install`, in order | `--enable-minimal` added; `--prefix` wrong; `make install` before `make`; no `make install`; built in another directory (five mutants) |
| B-b2 | `CC` names another compiler: that one is `CC` for `configure` | `CC` not passed |
| B-b3 | `configure` fails: its last lines on stderr, `make` never called, PREFIX absent | failure of `configure` ignored |
| B-b4 | `make` fails: same, `make install` never called | same |
| B-b5 | `make install` fails: same, no check | same |
| B-b6 | `make` called before `configure` fails by the stand-in (control for the order) | n/a: control |
| B-b7 | PREFIX untouched before `make install` (state `no-prefix` after a failed `make`) | `mkdir -p "$prefix"` early |
| B-e1 | **The check, floor:** the call to C carries `CHEZ_SODIUM_LIBRARY=PREFIX/lib/libsodium.so.23`, `C_INCLUDE_PATH=PREFIX/include`, no `--current` | soname `.so.26` in the override (C refuses the override) |
| B-e2 | **The check, current:** `.so.26`, `--current` | `--current` not passed (C checks the floor and refuses) |
| B-e3 | `C_INCLUDE_PATH=ELSE` in the env: C's compiler gets `PREFIX/include:ELSE` | `C_INCLUDE_PATH=$prefix/include` alone (the container trap; red here, in the container, and on the runner) |
| B-e4 | **Success, floor,** library and header agreeing: stdout is C's two lines then B's last, exit 0, work directories removed | the final `echo` dropped |
| B-e5 | **Success, current** | the same |
| B-e6 | `tmp/` empty after success and after each failure above | the `trap` deleted |
| B-c5 | `current_version` changed in B alone: B's call to C refuses (C's copy is the old one) | n/a: it is this row's edit of B; red by C's refusal in the check, stderr whole |
| B-u1..B-u7 | usage: none, two prefixes, `--nothreads`, three words, `--discovery`, `--no-load`, `--current --current`, a relative prefix (exit 2, `usage: build-sodium.sh PREFIX [--current]`, no download) | `*) ;;` in the flag case; the prefix test deleted |
| B-x1 | Executable bit on both scripts (one row, `test -x`) | `chmod 644` |

### 3.2 `check-sodium.sh`, floor and current

Base floor row: stub reports `8.1.2`, major 10, minor 3, minimal 0 in `PREFIX/lib/libsodium.so.23`; header defines `"8.1.2"`, 10, 3; floors file `8.1.2`; override right; `C_INCLUDE_PATH` is PREFIX/include then the ambient value. Base current row: `1.0.22` (the reviewed copy), 26 and 4, `.so.26`, no floors file.

| ID | Row | Mutant that turns it red |
|---|---|---|
| C-0a | Floor passes, whole stdout | any wording change |
| C-0b | `--current` passes with no floors file; and with a floor of 8.1.2 in the tree (the file is not read) | `current` reads `floor.sh` |
| C-0c | The env sets `version`, `current_version`, `soname` to other values: nothing moves | `x=${x:-...}` |
| C-s1 | **Wrong soname.** Floor given a prefix whose only library is `libsodium.so.26`: refused naming `.../libsodium.so.23` | the floor's soname `.so.26` |
| C-s2 | `--current` given only `libsodium.so.23`: refused naming `.so.26` | the current soname `.so.23` |
| C-s3 | Floor, with both sonames present and the override naming `.so.26`: refused at the override | the override compared with a glob, `*libsodium.so.*` |
| C-s4 | The soname is a directory; a dangling link: refused | `-e` for `-f` (the directory passes); the dangling link: `-L` for `-f` |
| C-f1 | No header file: refused naming it | the header test deleted |
| C-o1 | `CHEZ_SODIUM_LIBRARY` unset | the test deleted |
| C-o2 | set but empty | `-z "${V:-}"` |
| C-o3 | relative (`lib/libsodium.so.23`) | compared by suffix |
| C-o4 | a copy of the same library elsewhere | compared by content |
| C-o5 | the bare `PREFIX/lib/libsodium.so` link | compared by `readlink -f` |
| C-h1 | **Wrong header (elsewhere first).** `C_INCLUDE_PATH` names a directory with its own `sodium.h` first, PREFIX second: refused, naming that directory's header | the found header not compared with PREFIX's |
| C-h2 | PREFIX's directory missing from `C_INCLUDE_PATH` (a directory of its own, then the ambient value): refused naming the one found | same |
| C-h3 | PREFIX's header found (positive control) | `-MM` for `-M`: the include directory is a system one, so nothing is listed and every positive row is red |
| C-h4 | A compiler that lists no `sodium.h` (CC stand-in): refused `lists no sodium.h` | the empty-listing test deleted |
| C-h5 | A compiler that fails with words (CC stand-in, exit 1): `cc could not preprocess ...:` and its words | the status ignored |
| C-v1 | **Wrong header version.** Header defines `"8.1.3"`: refused naming the header, the three values, the role's | the string compared to the library's, not the role's |
| C-v2 | `"8.1.23"`, the floor with a digit after it | a prefix or glob compare |
| C-v3 | Header and library both `8.1.3` (agreeing with each other, not the floor): refused at the header | library compared with header only |
| C-v4 | `SODIUM_VERSION_STRING` undefined | an empty value accepted |
| C-v5 | `SODIUM_LIBRARY_VERSION_MAJOR` undefined; `_MINOR` undefined; either not digits | the digit test deleted |
| C-l1 | **Wrong library version.** Library answers `8.1.3`, header and role 8.1.2: refused naming library, answer, role | the library's version not compared |
| C-l2 | Library answers `8.1.23` | glob compare |
| C-l3 | Library answers NULL (stub returns 0; Chez prints `#f`): refused | none: the compare |
| C-l4 | Library answers an empty string | none: the compare |
| C-mm1 | **Major disagrees.** Library 11, header 10: refused naming both | major not compared |
| C-mm2 | **Minor disagrees.** Library minor 4, header 3 | minor not compared |
| C-mm3 | Both agree on 9 and 7, which are no real numbers: passes | major/minor compared with the floor's 10.3 written in the script (the real libtool numbers must not be there; they are not the floor) |
| C-mm4 | Major right, minor wrong, and the reverse (two rows, whole text) | a `&&` where `\|\|` is needed |
| C-m1 | **Minimal build.** Library answers `sodium_library_minimal() = 1` : refused | the check deleted |
| C-m2 | Answers 2 | compare to 1 |
| C-m3 | Version, major and minor all right and only minimal is 1 (so the minimal answer alone is the cause) | n/a: the control for C-m1 |
| C-p1 | A Chez that cannot run (`CHEZ` names a file that is not executable): `could not read LIB:` and its words | the status ignored |
| C-p2 | A "library" that is a text file named `libsodium.so.23`: the probe's load error is shown | the stderr dropped |
| C-p3 | A tree with no `src/` passes (the probe never reaches chez-sodium) | a probe that imports `(chez-sodium ...)` or `--libdirs src` |
| C-p4 | A recording CHEZ stand-in: its argv is exactly `-q --script CWORK/read.ss LIB`, no `--libdirs`, no `--program` | `--libdirs` or `--program` added |
| C-r1 | Floor, malformed floors file: floor.sh's line, then `no libsodium floor to check against` | the failure ignored |
| C-r2 | Floor, no floors file | same |
| C-r3 | `--current` with the floor's library and header: refused at the header (checked first) | reorder |
| C-r4 | `--current` with the current header and the floor's library: refused at the library | the library check dropped for `current` |
| C-r5 | `--current`, floor's text in `current_version`'s env and the floor's library: still refused | `current_version` from the environment |
| C-u1..C-u8 | usage: none; two prefixes; `--nothreads`; `--no-load`; `--discovery` with a prefix; a prefix then `--discovery`; three words; `--current --current`; a relative prefix | `*) ;;`; the sole-argument rule dropped |

### 3.3 `check-sodium.sh --discovery`

Base: CHEZ stand-in prints the four-line report for floor 8.1.2, library 10.3, path `/usr/lib/x86_64-linux-gnu/libsodium.so.23 (system)`, exit 0, no stderr; CC stand-in lists `/usr/include/sodium.h` and defines `"8.1.2"`, 10, 3; `CHEZ_SODIUM_LIBRARY` unset (`env -u`).

| ID | Row | Mutant that turns it red |
|---|---|---|
| D-0 | Passes; the calls are `chez --libdirs ROOT/src --program ROOT/tests/preflight.sps` once, then the compiler's `-E -M` and `-dM -E`, whole | any change of the command line |
| D-o1 | **Given an override.** `CHEZ_SODIUM_LIBRARY=/x/libsodium.so.23`: refused, and the calls are empty (nothing ran) | the test deleted; or moved after preflight (calls then show the run) |
| D-o2 | Override set to the empty string | `-z "${V:-}"` |
| D-o3 | Override naming the right system path: still refused | the override compared instead of refused |
| D-r1 | Preflight exits 1 with a stderr refusal and, as a plant, the accepted report on stdout: refused, stderr shown | the status ignored |
| D-r2 | Exit 0 with stderr non-empty: refused | the stderr not checked |
| D-r3 | The CHEZ stand-in missing (`CHEZ` names no file): `could not run` | none: this is the spawn failure |
| D-p1 | **Another path.** `/usr/local/lib/libsodium.so.23 (system)` | a substring or glob compare |
| D-p2 | `/usr/lib/x86_64-linux-gnu/libsodium.so.26 (system)` | the soname not compared |
| D-p3 | `/usr/lib/x86_64-linux-gnu/libsodium.so.23 (override)` (the right path, another source) | the source dropped |
| D-p4 | `/usr/lib/libsodium.so.23 (system)` | same as D-p1 |
| D-v1 | **Another version.** Report says `8.1.3 (library 10.3)` | the version not compared |
| D-v2 | `8.1.23` | glob |
| D-v3 | Report 8.1.2, header 8.1.3: refused at the header | the header compared with the report instead of the floor |
| D-v4 | Report and header 8.1.3, floor 8.1.2: refused | the floor not read (floor written in the script) |
| D-v5 | A floor of 8.1.2 written in the tree, report 8.1.2 and passing; the same with a floor of 9.0.1 and a matching report (the floor is read, not written in the script) | the real floor's text in the script |
| D-v6 | Floors file malformed or absent: floor.sh's line, then the script's | the failure ignored |
| D-m1 | Report `(library 10.4)` against header 10.3 | minor not compared |
| D-m2 | Report `(library 11.3)` against header 10.3 | major not compared |
| D-m3 | Report and header both `9.7` pass: the numbers are the header's, not written | `10.3` written in the script |
| D-w1 | The report holds one extra line; a line short; the counts line missing; a blank line first; a first line other (`chez-sodium: libsodium refused`) (five rows) | compare of lines 2 and 3 alone |
| D-w2 | A different counts value (`((block . 3))`) passes | counts compared |
| D-h1 | Compiler finds `/usr/local/include/sodium.h` | the header path not compared |
| D-h2 | Compiler finds no `sodium.h` | the test deleted |
| D-h3 | Compiler fails with words | status ignored |
| D-h4 | The header says `"8.1.3"`, `"8.1.23"`, or defines nothing | glob; missing-value case |
| D-x1 | The compiler stand-in sees `CHEZ_SODIUM_LIBRARY` unset (calls whole) | n/a |

### 3.4 Suite-level rows

| ID | Row | Mutant |
|---|---|---|
| X0 | `CHEZ` set; `CC` one word; `sh`, real cc and real Chez found as files (each a test, then `(exit 1)`) | n/a (harness) |
| X1 | **The preflight command line is `make build`'s:** the suite reads the Makefile as data, takes the words after `$(CHEZ)` on `build`'s recipe, and expects D-0's call to be those words with `ROOT/` before `src` and `tests`. Red when either side moves | `--program tests/other.sps` in the script; or in a copy of the tree, the Makefile's recipe changed |
| X2 | Both scripts executable (B-x1) | `chmod 644` |
| X3 | The pins are reviewed copies: the two SHA-256 literals and `current_version` in the suite equal the script's (rows B-p1, B-p2, B-c5 already fail when they differ; no row reads the script's text) | n/a |
| X4 | Every row's expected value is not `#f`; every thing that can raise is under a guard with a sentinel | harness |

The brief's "watched to fail" list maps to rows: each pin, by role (B-p1 to B-p6); fails over and
fails both (B-d1 to B-d5); wrong soname, header, version, override, minimal build, major/minor
disagreement (C-s, C-h/C-v, C-l, C-o, C-m, C-mm); `--discovery` with an override, another path or
another version (D-o, D-p, D-v); the floor's text in `scripts/ci/` (B-f1 and B-f5 with the
existing `floors-script` plant; `check-floors` is the check). The lanes' step order and env
exception belong to the lanes builder's `test-check-ci` rows, not to these three files.

---

## 4. Flags

**F1. The plan says `--discovery` asserts "make build's report" and does not say how it gets it.**
Plan §4.2 item 10 and the brief's `--discovery` paragraph leave open whether the script reads a
file, runs `make build`, or runs preflight. `make build` writes nothing to a file, and the
interface gives the step `CHEZ` alone. Decision proposed: the script runs `tests/preflight.sps`
itself, and a row (X1) holds its command line equal to the Makefile's. Please confirm; the plan's
sentence should then read "runs preflight, the program `make build` runs".

**F2. The container trap needs two edits beyond `check-sodium.sh`.** `test-ci-sqlite`'s `lane-env`
sets `C_INCLUDE_PATH=PREFIX/include` alone, which here fails in the container for every row. The
suite's `lane-env` must prepend the ambient value, and so must every row that moves the header
(§2.3). No script sets or rewrites the variable except B's call to C, which already prepends.
Beyond this brief: the suite's rows cannot assert "no `sodium.h` is on the path" against the real
compiler, in the container (ambient `<profile>/include`) or on `main` (`/usr/include/sodium.h`).
Those rows use a CC stand-in.

**F3. libsodium has a threading switch the plan's "Dropped" column does not know.**
Plan §2.3 drops "threadsafe" with SQLite's options. libsodium's `configure` has
`--with-pthreads` (default yes), and when `AX_PTHREAD` fails, it only notes "pthread mutexes are
not available" and builds with `sodium_crit_enter` doing nothing. `sodium_init`'s mutex is what
makes the library safe under a threaded Chez. Plain configure defines `-DHAVE_PTHREAD=1` on both
releases (measured). No function or header macro shows it afterwards. Proposal: a step 8a in
`build-sodium.sh`, after `configure`, requiring `grep -q -- -DHAVE_PTHREAD=1 src/libsodium/Makefile`
(refusal: `configure built libsodium without pthreads`), with a row and a stand-in file
(`no-pthread`), and the mutant "step deleted". It is not in the plan and costs a few lines; the
owner decides whether it belongs in slice 5. If not, the suite's header says what no check reaches.

**F4. `--discovery`'s path is a literal for x86_64 Ubuntu.** `/usr/lib/x86_64-linux-gnu/libsodium.so.23`
and `/usr/include/sodium.h` are written in the script, as the brief says. `main` is
`ubuntu-24.04` (x86_64) only, so they hold; an arm runner would fail `--discovery` by name.
Raising the floor past 1.0.18 changes the soname Ubuntu ships, so the literal moves with it.

**F5. Raising the floor edits more than the records list.** ADR-0003 ("Raising the floor is a new
record and the edits chez-sqlite3 ADR-0008 lists") and ADR-0011 name the floors file, README, the
code's check and the literal rows. They do not name the places this slice adds: `floor_archive`
and the floor's soname in `build-sodium.sh`, the floor's soname in `check-sodium.sh`, the path in
`--discovery`, and the suite's reviewed copies. The scripts' comments say so, as v0.1.1's did for
its pins; the records should too.

**F6. `current_version=1.0.22` and a raised floor can collide.** `check-floors` refuses the floor's
dotted text on any line under `scripts/ci/`. If the floor is ever raised to the current release's
version, `current_version=...` in B and C fails `check-floors`. chez-sqlite3 has the same property
(3.45.1 and 3.54.1); it is not a problem while the floor is 1.0.18. Noted so that the first
floor raise is not surprised.

**F7. The source pin's loss.** v0.1.1 pinned the archive and, separately, `sqlite3.c`'s digest from
sqlite.org's release log. This slice has one pin per role. The reasoning (the whole tarball is
pinned; the `.minisig` was checked once) is sound, but the lane never verifies the signature,
since the runner has no `minisign`. The plan's "Dropped" column should say the second pin was
dropped on purpose, and why.

**F8. The brief's "floor's text written into `scripts/ci/`" is not a row of the suite.** It is the
existing `floors-script` plant (`check-test-fails.sh`) and `check-floors`, which scan the new
files the moment they exist. The mutants B-f5 are run by hand in a copy, and the suite's B-f1 and
D-v5 rows prove the behaviour (the floor read, not written). No new plant is needed. One caution
for the builder: no comment in `scripts/ci/` may write the floor's dotted text, `10.4.0` or
`1.0.18`; say "the floor".

**F9. "Major and minor never compared" (ADR-0003, decision 3; global constraints) and the brief's
check read as contradictory.** Those rules govern the load: major and minor are never compared with
the floor. `check-sodium.sh` compares the library's with the header's, which the plan and brief
require. They do not conflict; a reader may think so. One sentence in the script's header comment
saying "the header's, never the floor's" is enough. C-mm3 and D-m3 are the checks.

**F10. `make` is serial; the build's env is mostly the caller's.** A serial `make` took 58 s here
(host with 18 cores: 17 s); with `-j"$(nproc)"` on a runner it would take about 20 s, at the cost
of one more tool to find and stand in for. Proposed: serial, once per cold cache. `CFLAGS`,
`CPPFLAGS` and `LDFLAGS` from the environment reach `configure`; a build changed by them is caught
only where it matters (version, soname, minimal). If you want the build immune to them, the script
can `unset` the three before `configure`; one row and one mutant.

**F11. A minimal build also writes `#define SODIUM_LIBRARY_MINIMAL 1` into `version.h`.** The
brief checks only `sodium_library_minimal()`. The header macro is a free second check (a
`-dM` line already read). I did not add it; adding it needs a row and a mutant. Say if you want it.

**F12. `--discovery` and the counts line.** The plan says the report is accepted "whole". Its last
line, `counts:`, prints native's counters, whose set M2 may grow. The design compares that line's
presence and the report's four-line shape, not its value. If you want it compared whole, the line is
`  counts:     ((block . 0))` today.

**F13. The probe's `load-shared-object` and `$CC`'s ambient `C_INCLUDE_PATH` are not the
runner's.** On the runner the probe loads `PREFIX/lib/libsodium.so.23` through Chez; nothing there
sets `LD_LIBRARY_PATH`. Both libsodium builds have no dependency but libc, so the load needs none.
Measured here only for 1.0.18 and 1.0.22 on a Guix glibc 2.41; the first Ubuntu 24.04 run is the
first evidence for the floor's build by gcc 13 and for `main`'s discovery (no row can hold either).

**F14. Nothing in this slice runs the real scripts against a real build in the suite.** The suite's
libraries are stubs. A phase 2 builder should run each finished script by hand, once, against
`build/slice5/prefix-1.0.18` and `-1.0.22` (with `C_INCLUDE_PATH=PREFIX/include:$C_INCLUDE_PATH`
and `CHEZ_SODIUM_LIBRARY` as the check wants), and record it in the mutation log as the positive
control for the stubs; `build-sodium.sh` itself can only be run for real on CI, or on the host
(it needs `curl`, `tar`, network).

**F15. The brief's "children's count" reading.** I counted `capture-command` children of the suite
(about 800), not the processes each script starts. The gate sees none of them; they are plain
children outside it, as `test-check-floors`'. If a count of the scripts' own processes is wanted
(about 12 per check row, 8 per build row), say so.
