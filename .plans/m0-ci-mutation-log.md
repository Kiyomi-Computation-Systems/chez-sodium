# M0 CI mutation log

Evidence that each rule of `tests/check-ci.sh`, of the workflow and script rules `check-floors` read
again, and of `scripts/ci/report-sodium.sh`'s failure path fails when it is broken. Format of
`m0-memory-gate-mutation-log.md`: Guards, Mutation, Result, then a clean rerun.

Every run was in the Guix container (`scripts/guix-env`): Chez 10.4.0 (threaded), libsodium 1.0.22,
gcc, Valgrind, x86_64. Each mutant changed one file in place, by one exact replacement that matched
once (a replacement that matched twice was not run, and says so), the suite named in the Result column
ran, and the file was restored from the text read before. A mutant is KILLED when the suite fails. The
first pass over `check-ci.sh` left four survivors; each is below, with the row added to
`tests/test-check-ci.sps` that kills it, or why it cannot be killed.

Suites: `tests/test-check-ci.sps` for `check-ci.sh` (359 rows after the survivors' rows),
`tests/test-check-floors.sps` for `floors.sls`, `check-floors.sps` and `scripts/ci/*.sh` (404 rows).
A Makefile mutant ran the target it names.

## Survivors of the first pass, and what became of them

| Mutation | Guards | Result |
|---|---|---|
| C12: `check-ci.sh`'s `flowscan`, the skip of a character after a backslash inside a double-quoted scalar, removed | an escaped quote does not end a quoted scalar | SURVIVED: every line holding `\"` inside quotes is already named for its backslash. Row added: `name: "a\"{b"`, whose one problem must be the backslash. With the row, KILLED |
| S2: the stray-`scripts/` rule's exemption widened from `key: ...hashFiles(` to any `key: ` line | only a cache key's hashFiles list may name scripts/ | SURVIVED: no row put scripts/ in another key line. Row added (`key: scripts/ci/x` under a checkout's `with:`). With the row, KILLED |
| C39 (first try): `p == 0` to `0`, text occurring twice | a line with no colon | not run: the replacement matched twice. Split into C39a (a step line) and C39e (a with/env line), each KILLED by rows added for them |
| E3: the execute-bit test reduced to `[ ! -x file ]` | a script a step runs is present and executable | SURVIVED, and cannot be killed: an executable file exists, so the `-f` test is implied. An equivalent mutant (E2, which drops the `-x`, is killed) |
| S07: `check-floors.sps` reads the directory unsorted | files in path order | SURVIVED, equivalent: `workflows-problems` and `scripts-problems` sort by path themselves, so the program's sort adds nothing |

Not mutated: the `awk` exit-status note at the end of the `check-ci.sh` awk run. A well-formed program
does not fail, and no row can make this awk fail without breaking the file's own text.

## `tests/check-ci.sh`

| Mutation | Guards | Result |
|---|---|---|
| C01: `  if (index(raw, "\t") > 0) { prob(ln, TABMSG); bad = 1 }` to `  if (0) { prob(ln, TABMSG); bad = 1 }` | a tab on a structural line | 2 rows fail, first: `a tab in a structural line` |
| C02: `    if (index(raw, "\t") > 0) prob(ln, TABMSG)\n    if (odd(raw)) prob(ln, ODDMSG)\n    ne...` to `    next` | a tab or a non-ASCII byte in a comment line | 3 rows fail, first: `a tab in a comment` |
| C03: `  if (odd(raw)) { prob(ln, ODDMSG); bad = 1 }` to `  if (0) { prob(ln, ODDMSG); bad = 1 }` | a non-ASCII byte on a structural line | 5 rows fail, first: `a character beyond ASCII in a structural line` |
| C04: `  if (rest ~ /^\?( \|$)/) {` to `  if (0) {` | an explicit key (`?`) | 2 rows fail, first: `an explicit key, ? if` |
| C05: `  if (rest ~ /^[*&][A-Za-z0-9_-]/) {` to `  if (0) {` | an alias or anchor where a key goes | 3 rows fail, first: `an anchor where a key goes` |
| C06: `  if (rest ~ /^["']/) {` to `  if (0) {` | a quoted key | 2 rows fail, first: `a quoted key, "if": false` |
| C07: `  if (p > 1 && substr(rest, p - 1, 1) == " ") {` to `  if (0) {` | white space between a key and its colon | 1 rows fail, first: `white space between a key and its colon, if : false` |
| C08: `  if (fl == 1) {` to `  if (0) {` | a flow mapping (`{`) | 2 rows fail, first: `a flow mapping in a name` |
| C09: `  if (fl == 2) {` to `  if (0) {` | a quoted scalar left open | 1 rows fail, first: `a quoted scalar left open` |
| C10: `  if (q > 0 && index(substr(raw, q + 1), "\\") > 0) {` to `  if (0) {` | a backslash after a double quote | 1 rows fail, first: `a backslash after a double quote` |
| C11: `    if (c == "$" && substr(s, i, 3) == "${{") {` to `    if (0) {` | `${{ }}` expressions are not flow mappings | 349 rows fail, first: `a stray scripts/ci/ line: a double-quoted path` |
| C12: `      if (q == "\"" && c == "\\") { i++; continue }` to `      if (0) { i++; continue }` | an escaped quote does not end a quoted scalar | 1 rows fail, first: `an escaped quote does not end a quoted scalar: the { after it is quoted, and only the back...` |
| C13: `  if (index(raw, "GITHUB_ENV") > 0) prob(` to `  if (0) prob(` | `GITHUB_ENV` named | 3 rows fail, first: `an expression in a comment line of a run block names GITHUB_ENV and MAKEFLAGS` |
| C14: `  if (index(raw, "GITHUB_PATH") > 0) prob(` to `  if (0) prob(` | `GITHUB_PATH` named | 1 rows fail, first: `GITHUB_PATH in a block scalar` |
| C15a: `((x in banned) \|\| x ~ /^VALGRIND_/ \|\| x ~ /^MEMORY_/)` to `(x ~ /^VALGRIND_/ \|\| x ~ /^MEMORY_/)` | the variables on the banned list | 27 rows fail, first: `an expression in a comment line of a run block names GITHUB_ENV and MAKEFLAGS` |
| C15b: `((x in banned) \|\| x ~ /^VALGRIND_/ \|\| x ~ /^MEMORY_/)` to `((x in banned) \|\| x ~ /^MEMORY_/)` | `VALGRIND_*` | 3 rows fail, first: `a block scalar names VALGRIND_OPTS` |
| C15c: `((x in banned) \|\| x ~ /^VALGRIND_/ \|\| x ~ /^MEMORY_/)` to `((x in banned) \|\| x ~ /^VALGRIND_/)` | `MEMORY_*` | 4 rows fail, first: `a block scalar names MEMORY_SHARD` |
| C16a: `!content && (gr = gaterun(gname[g], job)) != "" && rest == gr))` to `!content && (gr = gaterun(gname[g], job)) != "" && 1))` | a gate named other than as its step's whole run line | 6 rows fail, first: `memory's gate step with an argument` |
| C16b: `  if (g == "check-memory-gate" && j == "memory") return` to `  if (g == "check-memory-gate" && j == "main") return` | `check-memory-gate` only in job memory | 345 rows fail, first: `a stray scripts/ci/ line: a double-quoted path` |
| C16c: `  if (g == "test-memory" && j == "memory") return` to `  if (g == "test-memory" && j == "main") return` | `test-memory` only in job memory | 340 rows fail, first: `a stray scripts/ci/ line: a double-quoted path` |
| C16d: `  if (g == "check-nothreads" && j == "nothreads") return` to `  if (g == "check-nothreads" && j == "main") return` | `check-nothreads` only in job nothreads | 345 rows fail, first: `a stray scripts/ci/ line: a double-quoted path` |
| C17: `  if (content && substr(raw, ind + 1, 1) == "#" && index(raw, "scripts/") > 0)` to `  if (0)` | `scripts/` in a block scalar's comment-looking line | 1 rows fail, first: `a comment line of a run block names scripts/` |
| C19: `    if (topidx[key] < lastidx) prob(` to `    if (0) prob(` | top-level key order | 1 rows fail, first: `permissions after concurrency` |
| C20: `    if (key in topseen) {` to `    if (0) {` | a top-level key twice | 1 rows fail, first: `a top-level key twice` |
| C21: `    if (!(tk[i] in topseen))` to `    if (0)` | a top-level key missing | 1 rows fail, first: `no jobs key` |
| C22: `    if (al[k, i] != el[k, i]) {` to `    if (0) {` | the on, permissions and concurrency blocks, line for line | 3 rows fail, first: `the on block gets a path filter` |
| C23: `    if (i > en[k]) {` to `    if (0) {` | an extra line in those blocks | 1 rows fail, first: `the on block gets another trigger` |
| C23b: `    if (i > an[k]) {` to `    if (0) {` | a missing line in those blocks | 1 rows fail, first: `the on block loses a trigger` |
| C24: `      if (!(jn[i] in jobseen))` to `      if (0)` | a job missing | 3 rows fail, first: `the nothreads job deleted` |
| C25: `    if (!(key in wantjob)) {` to `    if (0) {` | a job outside main, memory, nothreads | 1 rows fail, first: `a job added` |
| C26: `    if (key in jobseen) {` to `    if (0) {` | a job twice | 1 rows fail, first: `a job twice` |
| C27a: `    if (!(key in jobkey)) {` to `    if (0) {` | a job key outside the four | 33 rows fail, first: `main: a job key if` |
| C27b: `    if (key in jkseen) {` to `    if (0) {` | a job key twice | 3 rows fail, first: `main: a job key twice` |
| C28: `    if (key == "runs-on" && val != "ubuntu-24.04")` to `    if (0)` | runs-on is ubuntu-24.04 | 3 rows fail, first: `main: the job's runs-on changes` |
| C29: `    if (key == "timeout-minutes" && val !~ /^[0-9]+$/)` to `    if (0)` | timeout-minutes is a whole number | 3 rows fail, first: `main: the job's timeout-minutes is no number` |
| C30: `    if (!jbad && !(jk2[i] in jkseen))` to `    if (0)` | each job has its four keys | 6 rows fail, first: `main: the job has no timeout-minutes` |
| C31: `    if (key == "steps" && val != "") prob` to `    if (0) prob` | steps holds a block | 3 rows fail, first: `main: steps with a value where a block goes` |
| C32: `  if (!(key in stepkeys)) {` to `  if (0) {` | a step key outside the seven (`continue-on-error` among them) | 12 rows fail, first: `an explicit key, ? if` |
| C33: `  if (key in sseen) {` to `  if (0) {` | a step key twice | 1 rows fail, first: `a step key written twice` |
| C34: `    if (!(key in withkeys)) {` to `    if (0) {` | a with key outside the three | 2 rows fail, first: `a with key outside the three` |
| C34b: `    if (key in wseen) {` to `    if (0) {` | a with key twice | 1 rows fail, first: `a with key written twice` |
| C35: `    if (key != "CHEZ") {` to `    if (0) {` | an env key but CHEZ | 13 rows fail, first: `CHEZ_SODIUM_LIBRARY in a step's env` |
| C35b: `    if (key in eseen) {` to `    if (0) {` | an env key twice | 5 rows fail, first: `main: the step that runs make check-help check-suites check-pins check-floors check-ci tes...` |
| C36: `    if (val != want) prob(ln, "env "` to `    if (0) prob(ln, "env "` | the value of a step's CHEZ | 6 rows fail, first: `main: the step that runs make check-help check-suites check-pins check-floors check-ci tes...` |
| C37: `    if (val != "") prob(ln, HASVAL)\n  } else if (key == "if") {` to `    if (0) prob(ln, HASVAL)\n  } else if (key == "if") {` | with and env hold a block, not a value | 2 rows fail, first: `a with holding a value` |
| C38: `  if (!bad) prob(ln, PLACE)` to `  if (0) prob(ln, PLACE)` | a line at a place check-ci reads nothing | 2 rows fail, first: `a line indented where no key is read` |
| C39b: `    if (p == 0) { prob(ln, NOKEY); next }\n    if (!(key in wantjob))` to `    if (0) { prob(ln, NOKEY); next }\n    if (!(key in wantjob))` | (not run: text occurs twice) | 1 rows fail, first: `a job header line with no colon` |
| C39c: `    if (p == 0) { prob(ln, NOKEY); next }\n    if (!(key in jobkey))` to `    if (0) { prob(ln, NOKEY); next }\n    if (!(key in jobkey))` | (not run: text occurs twice) | 1 rows fail, first: `a job line with no colon` |
| C39d: `    if (p == 0) { prob(ln, NOKEY); next }\n    if (!(key in topidx))` to `    if (0) { prob(ln, NOKEY); next }\n    if (!(key in topidx))` | (not run: text occurs twice) | 1 rows fail, first: `a top-level line with no colon` |
| C40a: `    if (S_if[sn] != IFLINE) prob(` to `    if (0) prob(` | the one if is the Chez cache's | 11 rows fail, first: `main: the Chez build with another if` |
| C40b: `    if (!(S_run[sn] ~ /^run: scripts\/ci\/build-chez\.sh( \|$)/ \|\| S_uses[sn] ~ /^action...` to `    if (0)\n      prob(S_ifln[sn]` | the if is only on the Chez build and the cache save | 13 rows fail, first: `main: the step that runs make check-help check-suites check-pins check-floors check-ci tes...` |
| C41: `  if (S_path[sn] != cachepath[job])` to `  if (0)` | the cache path of each job | 6 rows fail, first: `main: the restore's path is another` |
| C42: `    if (!keyok(S_key[sn]))` to `    if (0)` | the restore key's prefix and hash list | 15 rows fail, first: `main: the restore's key drops the prefix` |
| C43: `    if (S_id[sn] != "chez")` to `    if (0)` | the restore's id is chez | 6 rows fail, first: `main: the restore's id is another` |
| C44: `    if (S_key[sn] != want)` to `    if (0)` | the save is keyed by the restore's primary key | 6 rows fail, first: `main: the save is keyed as a restore is` |
| C45: `  return (tail == "" \|\| substr(tail, 1, 1) == "-")` to `  return 1` | the restore key's tail is empty or starts with `-` | 3 rows fail, first: `main: the restore's key has a tail that is no suffix` |
| C46: `  if (substr(v, 1, length(want)) != want) return 0` to `  if (0) return 0` | the restore key starts with prefix and hashFiles | 3 rows fail, first: `main: the restore's key is no expression at all` |
| C47: `    if (S_uses[s] != "" && !(S_uses[s] ~ /^actions\/(checkout\|cache\/restore\|cache\/save...` to `    if (0)` | a step may use only checkout and the cache restore and save | 6 rows fail, first: `main: the restore uses actions/cache, not actions/cache/restore` |
| C48: `        if (restore && s > t) prob(` to `        if (0) prob(` | the cache restore before the build | 3 rows fail, first: `main: the restore moved below the build` |
| C49: `        if (!restore && s < t) prob(` to `        if (0) prob(` | the cache save after the build | 3 rows fail, first: `main: the save moved above the build` |
| C50: `      if (!restore && runs(t, "check", "chez") && s > t)` to `      if (0)` | the cache save before the check | 3 rows fail, first: `main: the save moved below the check` |
| C51a: `  if (nr != 1) prob(` to `  if (0) prob(` | exactly one restore: none | 9 rows fail, first: `main: the Chez restore deleted` |
| C51b: `  if (ns != 1) prob(` to `  if (0) prob(` | exactly one save: none | 6 rows fail, first: `main: the Chez save deleted` |
| C51c: `  if (nr != 1) prob(` to `  if (nr < 1) prob(` | exactly one restore: two | 3 rows fail, first: `main: the Chez restore written twice` |
| C51d: `  if (ns != 1) prob(` to `  if (ns < 1) prob(` | exactly one save: two | 3 rows fail, first: `main: the Chez save written twice` |
| C52a: `  if (job == "main" \|\| job == "memory") {\n    if (first > last` to `  if (job == "main") {\n    if (first > last` | memory's first step is the checkout with submodules | 2 rows fail, first: `memory's checkout without submodules` |
| C52b: `S_sub[first] == "recursive"` to `S_sub[first] != "x"` | main's checkout is with submodules: recursive | 4 rows fail, first: `main's checkout without submodules` |
| C52c: `S_run[first] == "" && S_if[first] == ""))` to `S_if[first] == ""))` | the checkout has no run | 1 rows fail, first: `main's checkout with a run` |
| C52d: `S_run[first] == "" && S_if[first] == ""))` to `S_run[first] == ""))` | the checkout has no if | 1 rows fail, first: `main's checkout with an if` |
| C53: `    if (first + 1 > last \|\| S_run[first + 1] != "run: " PINRUN)` to `    if (0)` | main's second step is the pin check | 2 rows fail, first: `main's pin step deleted` |
| C54: `    if (c != 1) { prob(jln,` to `    if (c < 1) { prob(jln,` | each required line is one step: none | 3 rows fail, first: `main: the Chez build written twice` |
| C54b: `    if (c != 1) { prob(jln,` to `    if (c > 1) { prob(jln,` | each required line is one step: two | 31 rows fail, first: `main: the Chez build deleted` |
| C55: `    if (pos <= lastp) prob(` to `    if (0) prob(` | the required steps run in order | 3 rows fail, first: `main's launcher step before the checks` |
| C56a: `      if (S_if[at] == "") prob(S_ln[at]` to `      if (0) prob(S_ln[at]` | the Chez build carries the cache's if | 3 rows fail, first: `main: the Chez build without its if` |
| C56b: `    } else if (S_if[at] != "") prob(` to `    } else if (0) prob(` | no other required step carries an if | 10 rows fail, first: `main: the step that runs make check-help check-suites check-pins check-floors check-ci tes...` |
| C57: `    if (rqk[i] == "env") needenv(at, x, "CHEZ")` to `    if (0) needenv(at, x, "CHEZ")` | the make steps carry env CHEZ | 6 rows fail, first: `main: the step that runs make check-help check-suites check-pins check-floors check-ci tes...` |
| C57b: `  if (!((at, k) in S_ev)) prob(` to `  if (0) prob(` | the env check itself | 6 rows fail, first: `main: the step that runs make check-help check-suites check-pins check-floors check-ci tes...` |
| C58: `  if (S_uses[sn] ~ /^actions\/cache\/(restore\|save)@/) cachestep()` to `  if (0) cachestep()` | the cache step rules are applied at each step's end | 33 rows fail, first: `main: the restore's path is another` |
| V0: `  if (c != 1) { prob(jln, "job main has " c " steps named` to `  if (0) { prob(jln, "job main has " c " steps named` | each report step is named once | 6 rows fail, first: `the versions step deleted` |
| V1: `  if (v && atrun[CHKT] && v < atrun[CHKT])` to `  if (0)` | the versions step comes after check-chez | 1 rows fail, first: `the versions step moved before Check the Chez` |
| V2: `  if (v && atrun[MAKELINE] && v > atrun[MAKELINE])` to `  if (0)` | the versions step comes before the checks | 1 rows fail, first: `the versions step moved after Checks and suites` |
| V3: `  if (q && atrun[CHKT] && q < atrun[CHKT])` to `  if (0)` | the libsodium step comes after check-chez | 1 rows fail, first: `the libsodium step moved before Check the Chez` |
| V4: `  if (q && atrun[MAKELINE] && q > atrun[MAKELINE])` to `  if (0)` | the libsodium step comes before the checks | 1 rows fail, first: `the libsodium step moved after Checks and suites` |
| V5: `  if (v && q && q < v)` to `  if (0)` | the versions step comes before the libsodium step | 3 rows fail, first: `the two report steps swapped` |
| V6: `    if (S_run[v] != "run: \|") prob(` to `    if (0) prob(` | the versions step runs a block | 1 rows fail, first: `the versions block clipped, run: \|-` |
| V7: `        if (bl[v, i] != vl[i]) {` to `        if (0) {` | the versions block, line for line | 5 rows fail, first: `a line at the start of the versions block` |
| V8: `        if (i > nvl) {` to `        if (0) {` | the versions block has no extra line | 2 rows fail, first: `a line at the end of the versions block` |
| V9: `        if (i > n) {` to `        if (0) {` | the versions block is not short | 1 rows fail, first: `the last line removed from the versions block` |
| V10: `    if (S_run[q] != "run: " SODRUN) prob(` to `    if (0) prob(` | the libsodium step's run line | 1 rows fail, first: `the libsodium step's run line changed` |
| E1: `      if [ ! -f "$root/$name" ] \|\| [ ! -x "$root/$name" ]; then` to `      if false; then` | the execute bit and presence of a script a step runs | 6 rows fail, first: `check-action-pins.sh without its execute bit: every step that runs it is named` |
| E2: `      if [ ! -f "$root/$name" ] \|\| [ ! -x "$root/$name" ]; then` to `      if [ ! -f "$root/$name" ]; then` | a script a step runs is present | 4 rows fail, first: `check-action-pins.sh without its execute bit: every step that runs it is named` |
| E3: `      if [ ! -f "$root/$name" ] \|\| [ ! -x "$root/$name" ]; then` to `      if [ ! -x "$root/$name" ]; then` | (equivalent: an executable file exists) | SURVIVED (a file that is executable exists, so the presence test is implied) |
| E4: `    grep -n -E '^( {8}\| {6}- )run: scripts/ci/[A-Za-z0-9._-]+( \|$)' "$file" >"$tmp/runs"...` to `    grep -n -E '^( {8}\| {6}- )run: scripts/ci/[A-Za-z0-9._-]+( \|$\|;...` | the stray `scripts/` rule reads the same run lines as the bit rule | 1 rows fail, first: `a stray scripts/ci/ line: NAME;true` |
| E5: `    root=${CHECK_CI_ROOT:-$(dirname "$0")/..}` to `    root=${CHECK_CI_ROOT:-/nowhere}` | CHECK_CI_ROOT is the tree the bit rule reads | 341 rows fail, first: `a stray scripts/ci/ line: a double-quoted path` |
| S1: `      grep -v -E '^[0-9]+: *#' \|\n` to `      cat \|\n` | comments may name scripts/ | 349 rows fail, first: `a stray scripts/ci/ line: a double-quoted path` |
| S2: `      grep -v -E '^[0-9]+: +key: .*hashFiles\(' >"$tmp/stray" \|\| :` to `      grep -v -E '^[0-9]+: +key: ' >"$tmp/stray" \|\| :` | only hashFiles key lines may name scripts/ | 1 rows fail, first: `a key line that names scripts/ outside a hashFiles list` |
| S3: `      grep -v -E '^[0-9]+:( {8}\| {6}- )run: scripts/ci/[A-Za-z0-9._-]+( \|$)' \|` to `      grep -v -E '^[0-9]+:( {8}\| {6}- )run: scripts/ci/[A-Za-z0-9._-]...` | the exceptions of the stray rule are the bit rule's | 1 rows fail, first: `a stray scripts/ci/ line: NAME;true` |
| S4: `    while IFS= read -r entry; do\n      lineno=${entry%%:*}\n      note "$file:$lineno: na...` to `    while false; do\n      lineno=${entry%%:*}\n      note "$file:$lin...` | the stray rule reports | 13 rows fail, first: `a stray scripts/ci/ line: a double-quoted path` |
| D1: `      ci.yml) ;;` to `      ci.yml \| pages.yml) ;;` | the directory holds ci.yml alone | 1 rows fail, first: `a second workflow in the directory` |
| D2: `  if [ -L "$file" ] \|\| [ ! -f "$file" ]; then` to `  if [ ! -f "$file" ]; then` | ci.yml is no link | 1 rows fail, first: `ci.yml is a link` |
| D3: `  if [ -L "$file" ] \|\| [ ! -f "$file" ]; then` to `  if [ -L "$file" ]; then` | ci.yml is a regular file | 2 rows fail, first: `ci.yml is named ci.yaml` |
| D4: `if [ ! -d "$dir" ]; then\n  note` to `if false; then\n  note` | DIR is a directory | 1 rows fail, first: `a directory that is not there` |
| D5: `[ $# -eq 1 ] \|\| usage` to `[ $# -ge 1 ] \|\| usage` | one argument exactly | 1 rows fail, first: `two arguments are a usage error` |
| D6: `  for entry in "$dir"/* "$dir"/.[!.]* "$dir"/..?*; do` to `  for entry in "$dir"/* "$dir"/.[!.]*; do` | a hidden file `..x` in the directory | 1 rows fail, first: `a file named ..odd` |
| D7: `  for entry in "$dir"/* "$dir"/.[!.]* "$dir"/..?*; do` to `  for entry in "$dir"/* "$dir"/..?*; do` | a hidden file `.x` in the directory | 1 rows fail, first: `a hidden file in the directory` |
| D8: `        shown=$(printf '%s' "$name" \| LC_ALL=C tr -c '[:print:]' '[?*]')` to `        shown=$name` | a name with a newline is shown with ? | 1 rows fail, first: `a second file named ci.yml, a newline, other.yml` |
| D9: `if [ "$count" -eq 0 ]; then\n  printf 'check-ci: %s has the one shape check-ci reads\n' "$...` to `if [ "$count" -eq 0 ]; then\n  printf 'check-ci: %s is fine\n' "$file"` | the pass line | 8 rows fail, first: `the unedited file passes` |
| C39a: `(rerun)` to `(rerun)` | a step line with no colon | 1 rows fail, first: `a step line with no colon` |
| C39e: `(rerun)` to `(rerun)` | a with or env line with no colon | 1 rows fail, first: `a with line with no colon` |

## `tests/floors.sls`

| Mutation | Guards | Result |
|---|---|---|
| F01: `           (if (assoc ci-path sorted)\n               '()` to `           (if #t\n               '()` | the directory holds ci.yml | 3 rows fail, first: `workflows: a ci.yml in a subdirectory is not the workflow: there is no ci.yml, and its lin...` |
| F02: `           (if (assoc floor-path sorted)\n               '()` to `           (if #t\n               '()` | the scripts hold floor.sh | 4 rows fail, first: `scripts: no floor.sh, and another script that writes no floor` |
| F03: `      (if (null? workflows)\n` to `      (if #f\n` | the workflow directory holds a file | 2 rows fail, first: `workflows: no file at all: the directory is named, once` |
| F04: `      (if (null? scripts)\n` to `      (if #f\n` | the scripts directory holds a file | 2 rows fail, first: `scripts: no file at all: the directory is named, once` |
| F05: `           (if (car joined)\n               (floor-complaints path (string-append "line "` to `           (if #f\n               (floor-complaints path (string-appen...` | a floor in a workflow line | 35 rows fail, first: `workflow: the Chez floor in a run step` |
| F06: `                                       (if (car joined)\n                                 ...` to `                                       (if #f\n                       ...` | a floor in a script line | 31 rows fail, first: `scripts: the libsodium floor at the start of a line` |
| F07: `           (if (backslash-after-quote? (car rest))` to `           (if #f` | a backslash after a double quote in a workflow | 10 rows fail, first: `workflow: a backslash after a double quote spells a floor with none of its text` |
| F08: `           (if (odd-quotes? (car rest))` to `           (if #f` | an odd number of double quotes in a workflow | 3 rows fail, first: `workflow: a backslash after a double quote that is never closed: named twice, as an escape...` |
| F09: `                       ((char=? (string-ref line j) #\\) #t)` to `                       ((char=? (string-ref line j) #\\) #f)` | the backslash scan | 10 rows fail, first: `workflow: a backslash after a double quote spells a floor with none of its text` |
| F10: `      (cond ((= i (string-length line)) (odd? n))` to `      (cond ((= i (string-length line)) (even? n))` | the quote count | 135 rows fail, first: `README: the two lines the floors give, in order` |
| F11: `            (if (and (ends-in-backslash? acc) (pair? more))` to `            (if #f` | a floor split by a backslash and a newline | 22 rows fail, first: `scripts: 8.1.2 split after 1 characters, by a backslash and a newline: found at the first ...` |
| F12: `    (floor-complaints path "its name" (relative-name dir path) fpath floors who))` to `    '())` | a floor in a file's name | 12 rows fail, first: `scripts: a file named for 8.1.2: named by its path, not its lines` |
| F13: `      (if (prefix? prefix path)\n          (substring path (string-length prefix) (string-...` to `      (if #f\n          (substring path (string-length prefix) (string...` | the directory's own name is no part of a file's | 2 rows fail, first: `scripts: the directory's own name is no part of a file's name` |
| F14: `           (sorted (list-sort (lambda (a b) (string<? (car a) (car b))) workflows)))` to `           (sorted workflows))` | workflow files in path order | 1 rows fail, first: `workflows: every file is held, in path order, whatever order they come in; a line names it...` |
| F15: `           (sorted (list-sort (lambda (a b) (string<? (car a) (car b))) scripts)))` to `           (sorted scripts))` | script files in path order | 3 rows fail, first: `scripts: every file is held, in path order, whatever order they come in` |
| F16: `                          (if (cadr entry)\n                              (line-problems` to `                          (if #t\n                              (line-...` | an unreadable workflow is not compared | 3 rows fail, first: `workflows: an unreadable ci.yml, #f, is not compared, and is no missing ci.yml; the others...` |
| F17: `    '((chez "Chez")\n      (sodium "libsodium")))` to `    '((sodium "libsodium")))` | the Chez floor and the libsodium floor are both held | 52 rows fail, first: `workflow: the Chez floor in a run step` |
| F17b: `    '((chez "Chez")\n      (sodium "libsodium")))` to `    '((chez "Chez")))` | the libsodium floor is held | 54 rows fail, first: `workflow: the libsodium floor in a run step` |
| F18: `                    (if workflows (workflows-problems fpath wdir workflows floors) '())))` to `                    '()))` | the workflows are held at all | 52 rows fail, first: `workflow: the Chez floor in a run step` |
| F19: `(define ci-workflow "ci.yml")` to `(define ci-workflow "main.yml")` | the workflow's name is ci.yml | 137 rows fail, first: `README: the two lines the floors give, in order` |
| F20: `(define floor-script "floor.sh")` to `(define floor-script "x.sh")` | the script's name is floor.sh | 78 rows fail, first: `scripts: a floor.sh that states no floor: nothing to report` |
| F21: `                          (if (cadr entry)\n                              (let ((lines (sp...` to `                          (if #t\n                              (let (...` | an unreadable script is not compared | 3 rows fail, first: `scripts: an unreadable floor.sh, #f, is not compared, and is no missing floor.sh; the othe...` |

## `tests/check-floors.sps`

| Mutation | Guards | Result |
|---|---|---|
| S01: `    (when (file-symbolic-link? wdir)` to `    (when #f` | the workflow directory is no symbolic link | 2 rows fail, first: `program: workflows-self-link: the workflow directory is itself a symbolic link to a direct...` |
| S02: `(if (file-directory? path #f) (walk path) (list path))` to `(if (file-directory? path #t) (walk path) (list path))` | a symbolic link inside it is not followed | 1 rows fail, first: `program: workflows-dir-link: a symbolic link to a directory among the workflows is not fol...` |
| S03: `                 (if (and scripts (null? (floors-problems fpath (cadr f))))` to `                 (if #f` | the scripts are held to the floors | 5 rows fail, first: `program: scripts-sodium-literal: a script in a subdirectory of the scripts, lib/fetch.sh, ...` |
| S04: `(check-floors fpath (cadr f) rpath (text-or-false r) wdir (texts files))` to `(check-floors fpath (cadr f) rpath (text-or-false r) wdir #f)` | the workflows are held to the floors | 10 rows fail, first: `program: workflow-chez-literal: ci.yml passes the Chez floor to a build script` |
| S05: `            (unreadable w)\n            (unreadable s))))` to `            (unreadable w))))` | an unreadable scripts directory is named | 5 rows fail, first: `program: scripts-self-link: the scripts directory is itself a symbolic link to a directory...` |
| S06: `(if (not (= (length args) 4))` to `(if (< (length args) 4)` | four arguments exactly | 1 rows fail, first: `program: five arguments: the usage line, exit 1` |
| S07: `(list-sort string<? (walk wdir))` to `(walk wdir)` | (equivalent: the pure procedure sorts) | SURVIVED (the pure `workflows-problems` and `scripts-problems` sort by path themselves, so sorting in the program is redundant) |
| S08: `                               " and " sdir " (" (joined (read-names sdir s)) ")"` to `                               " and " sdir " ()"` | the files read are named on a pass | 3 rows fail, first: `program: legal: floors no real floor equals, a README with their lines among other lists a...` |
| S09: `                     (scripts-problems fpath sdir (texts scripts) (parse-floors (cadr f)))` to `                     '()` | the scripts are held (second path) | 5 rows fail, first: `program: scripts-sodium-literal: a script in a subdirectory of the scripts, lib/fetch.sh, ...` |

## Makefile

| Mutation | Guards | Result |
|---|---|---|
| K01: `packaging/floors.sexp README.org .github/workflows scripts/ci` to `packaging/floors.sexp README.org .github/workflows` | the Makefile passes scripts/ci to check-floors | fails (exit 2): check-floors: usage: scheme --libdirs tests --program tests/check-floors.sps FLOORS README... |
| K02: `packaging/floors.sexp README.org .github/workflows scripts/ci` to `packaging/floors.sexp README.org scripts/ci` | the Makefile passes .github/workflows to check-floors | fails (exit 2): check-floors: usage: scheme --libdirs tests --program tests/check-floors.sps FLOORS README... |
| K03: `	@CHECK_CI_ROOT= sh tests/check-ci.sh .github/workflows` to `	@CHECK_CI_ROOT= sh tests/check-ci.sh tests` | check-ci reads .github/workflows | fails (exit 2): check-ci: tests: test-require-threaded.sps is not ci.yml: the directory must hold ci.yml a... |
| K04: `test: deps check-help check-suites check-floors check-ci ##` to `test: deps check-help check-suites check-floors ##` | make test runs check-ci | fails (exit 1): make check-test-fails: ci case FAILED: make test exited 0 |
| K05: `check-suites check-floors check-ci check-nothreads` to `check-suites check-floors check-nothreads` | check-ci is .PHONY | fails (exit 2): check-help: make help lists 'check-ci', which is not in .PHONY |
| K06: `check-ci: ## Fail unless` to `check-ci: Fail unless` | check-ci has a help line | fails (exit 2): check-help: make help does not list .PHONY target 'check-ci'; give it a '## ' description ... |

## `scripts/ci`, held by `test-check-floors.sps`

| Mutation | Guards | Result |
|---|---|---|
| B01: `  *'#'*) fail "it holds a # outside a ; comment, which this script does not read" ;;` to `  *'#'*) : ;;` | floor.sh refuses a `#` outside a comment | 3 rows fail, first: `floor.sh: a datum comment, which the Scheme reader skips and this script does not read` |
| B02: `form="^$nat\\.$nat\\.$nat\$"` to `form="^$nat\\.$nat"` | floor.sh checks a version's three parts | 6 rows fail, first: `floor.sh: the other floor is well-formed, and the one asked for is not` |
| B03: `[ -n "$entries" ] \|\| fail "it holds no $name entry"` to `true` | floor.sh needs its entry | 2 rows fail, first: `floor.sh: the key is missing` |
| B04: `if [ "$asked" != "$expected" ]; then` to `if false; then` | check-chez.sh compares the version and threads | 2 rows fail, first: `check-chez.sh: a threaded Chez asked for --nothreads fails, naming both answers` |
| B05: `if [ "$got" != "$floor_sha256" ]; then` to `if false; then` | build-chez.sh checks the tarball's sum | 1 rows fail, first: `scripts/ci: build-chez.sh: a floor whose tarball is not the pinned one fails its sum, nami...` |
| B06: `[0-9a-f]{40}[[:space:]]+#` to `[0-9a-f]+[[:space:]]+#` | check-action-pins.sh wants 40 hex digits | 2 rows fail, first: `pins: a short commit` |
| B07: `[ "$count" -ne 0 ] \|\| fail` to `true` | check-action-pins.sh fails on no uses key | 2 rows fail, first: `pins: no file has a uses key: nothing was checked` |
| B08: `  *) echo "build-chez.sh: PREFIX must be an absolute path, not '$prefix'" >&2; exit 2 ;;` to `  *) : ;;` | build-chez.sh wants an absolute prefix | 1 rows fail, first: `scripts/ci: build-chez.sh: a relative prefix is refused` |
| B09: `[ -x "$scheme" ] \|\| {` to `true \|\| {` | check-chez.sh wants an executable scheme | 1 rows fail, first: `check-chez.sh: a prefix with no bin/scheme fails, naming the path` |
## `scripts/ci/report-sodium.sh`'s failure path

No suite holds this script, so each condition ran the script itself, in the container, with stand-ins
on the PATH: a `dpkg-query` that answers `ok`, `empty`, `fail` (stderr, exit 1) or `partial` (one line,
then exit 1), and a `CC` that is missing, or makes a program that dies, prints nothing, or prints one
line. The real script answers: success exit 0 with the packages and both version strings (header and
library, 1.0.22 here); `dpkg-fails`, `dpkg-partial`, `dpkg-empty`, `cc-missing`, `program-dies`,
`program-silent`, `program-half` each exit 1 with a message naming the cause; an argument exits 2.
Each mutant dropped one guard, and every condition ran against it.

| Mutation | Guards | Result |
|---|---|---|
| R1: the `\|\| fail` after `dpkg-query` removed | a `dpkg-query` that fails | `dpkg-fails` and `dpkg-partial` still exit 1 (`set -e`) but print nothing: the cause is lost. KILLED |
| R2: `[ -s packages ] \|\| fail` removed | a `dpkg-query` that lists nothing | `dpkg-empty` exits 0 and prints an empty `packages:` list. KILLED |
| R3: the `\|\| fail` after the compile removed | a compiler that cannot build the program | `cc-missing` exits 127, not 1, with no message. KILLED |
| R4: the `\|\| fail` after running the program removed | a program that dies | `program-dies` exits 3, not 1, with no message. KILLED |
| R5: the `-n header && -n library` guard removed | a program that prints no version | `program-silent` and `program-half` exit 0 and print empty version strings. KILLED |
| R5b: the guard reduced to the header alone | a program that prints one line | `program-half` exits 0 with an empty library line. KILLED |
| R6: the usage guard removed | an argument | `usage` exits 0 and reports. KILLED |
| R7: `set -eu` to `set -u` | | no condition changes: every command is guarded. Equivalent, and kept as it is |

On the host the script fails by its own rule: `report-sodium: cc could not compile and link a program
against sodium.h and -lsodium: ... sodium.h: No such file or directory`, exit 1. The host has the
`libsodium23` library and no header, and nothing was installed.

## `tests/check-memory-gate.sh`'s case o

Mutation: `.github/workflows/ci.yml` given the memory job a job-level `continue-on-error: true`, then
`make check-memory-gate`. Result: one case FAILED, `o ci`, printing `check-ci: ...:161: job memory has
the key "continue-on-error", which is not one of name, runs-on, timeout-minutes, steps`; the other 58
cases passed. After the restore, the gate passed in all 59 cases.

## The `ci` plant of `tests/check-test-fails.sh`

Mutation K04 above: `check-ci` removed from `test`'s prerequisites. `make check-test-fails` fails the
`ci` case twice, `make test exited 0` and `make test's lines differ`; the other 10 cases pass. Restored,
all 11 cases pass.

## The `floors-script` plant of `tests/check-test-fails.sh`

Added after the hand-back, from v0.1.1's, with the libsodium floor for SQLite's.

Guards: `check-floors` is run on `scripts/ci`, so a CI script that writes a floor fails `make test`.

Mutation: the Makefile's `check-floors` handed `tests/fixtures/floors/legal/scripts`, a clean
directory with a `floor.sh`, in place of `scripts/ci`. Result: `make check-test-fails` fails the
`floors-script` case alone, twice: `make test exited 0`, and `make test's lines differ`, wanting
`check-floors: scripts/ci/plant.sh: line 2 contains the libsodium floor 1.0.18, …` and getting
check-floors' pass line. The other 11 cases pass.

An earlier mutant handed `.github/workflows` twice. It failed every case, since that directory holds
no `floor.sh`, so it proved nothing about this plant.

Clean rerun: restored, `cmp` equal; `make test` 7 of 7, and `make check-test-fails` in all 12 cases.

## Clean rerun

After the last restore, `cmp` shows the Makefile and `.github/workflows/ci.yml` equal to the copies
taken before the mutants, and every other mutated file was written back by the harness from the text it
read. In the container: `make test` (`ran 7, passed 7`), `make check-test-fails` (`in all 11 cases`),
`make test-memory` (`ran 7, passed 7, failed 0, hung 0, slow 0`), `make check-memory-gate` (`in all 59
cases`), `make check-clean` and `make check-help` pass. On the host: `make check-guix` prints `ALL
CHECKS PASSED`, `make check-pins` agrees, `bash -n` passes on every script, and
`scripts/ci/check-action-pins.sh .github/workflows` names 9 pinned lines.
