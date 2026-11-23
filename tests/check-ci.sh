#!/bin/sh
# check-ci: hold .github/workflows/ci.yml to the one shape this check reads.
#
#   sh tests/check-ci.sh DIR
#
# DIR must hold ci.yml alone, a regular file and no link: a second workflow
# would run jobs this check does not read. Its entries are read by a glob, so
# a name that holds a newline is one name, shown with a ? for each byte that is
# not printable ASCII. On a pass it prints one line on stdout and exits 0. On a
# failure it prints each problem on stderr, as "check-ci: FILE:LINE: problem",
# then "check-ci: FAILED (problems: N)", and exits 1. A usage error exits 2.
#
# The workflow is read as text, line by line, with awk (POSIX: nothing gawk
# only; CI's Ubuntu runs mawk), and the check fails closed: a spelling that a
# text reader could misread is a problem, whatever it means to YAML. It checks:
#
#   - on every line, a comment and a block scalar's content included: a tab,
#     or a character beyond ASCII, which a YAML reader may also take for a
#     line break, so a comment's line could end early and a key follow it.
#     Blank lines hold neither;
#   - on every line that is not a block scalar's content: an explicit key (?),
#     an alias or anchor where a key goes (* or &, then a letter, digit, _ or
#     -: a shell case pattern *) and && are none), a quoted key, white space
#     between a key and its colon, a flow mapping ({ outside a quoted scalar
#     and a ${{ }} expression), a quoted scalar left open, and a backslash after
#     a double quote;
#   - the shape: the top-level keys, the three blocks `on`, `permissions` and
#     `concurrency` line for line, the three jobs (main, memory and nothreads)
#     and each key in them, each step's keys, with: and env: keys, the one if:
#     and where it may be, the Chez cache's path and keys, one restore and one
#     save of it in each job, and the checks each job must run, each as one
#     step's whole run line, in order:
#       main        the Chez build, check-chez, the two report steps, the
#                   checks, then the launcher's tests;
#       memory      the Chez build, check-chez, make check-memory-gate, then
#                   make test-memory, both bare;
#       nothreads   the --nothreads Chez build, its check-chez, then make
#                   check-nothreads;
#     each job's Chez build carries the cache's if and no other step does but
#     the cache's save, a step that runs make carries the env CHEZ of its job's
#     Chez, and in job main, between its check-chez step and its make step, the
#     steps "Report the versions this run uses" (its run block, line for line)
#     and "Report the runner's libsodium" (its run line), in that order;
#   - a uses: step may only be actions/checkout@, actions/cache/restore@ or
#     actions/cache/save@; the cache's restore comes before its build, and its
#     save after the build and before the cache's check; and the checkout of
#     main and memory is with submodules: recursive;
#   - every step whose whole run line begins scripts/ci/NAME: that file exists
#     and is executable, under CHECK_CI_ROOT (the repository root if unset);
#     floor.sh is run with sh by the others, so it needs no bit and is not held;
#   - no other line names scripts/, a comment apart: it is a step's whole run
#     line in that form, or a cache key's hashFiles( list;
#   - the names no line but a comment may hold: GITHUB_ENV, GITHUB_PATH, and
#     as words the variables that would steer a check (MAKEFLAGS, VALGRIND_*,
#     MEMORY_*, ...), the compiler's and the loader's among them (CC,
#     C_INCLUDE_PATH, CPATH, LIBRARY_PATH, LD_LIBRARY_PATH, LD_PRELOAD), which
#     could steer the library the suites load or the report, the library's own
#     (CHEZ_SODIUM_LIBRARY), and CHECK_CI_ROOT, which would point this check's
#     execute-bit rule at another tree; and
#   - check-memory-gate, test-memory and check-nothreads anywhere but as the
#     whole run line of a step that runs them: check-memory-gate and
#     test-memory in job memory, and check-nothreads in job nothreads.
#
# A block scalar starts at a key whose value is | or > and holds every later
# line that is blank or indented deeper than that key (a "- " counts toward the
# key's column). Its lines are text, not YAML structure: a line there that
# begins with # is no comment but the script's text, which GitHub expands and
# the shell runs, so it is held to the rules of the block's other lines (the
# names, the gates and scripts/ among them), and no comment's rule frees it.
#
# Every rule is held by a row of tests/test-check-ci.sps, which plants it in a
# copy of the real workflow. A change to ci.yml changes this file with it.

usage() {
  printf 'check-ci: usage: sh tests/check-ci.sh DIR\n' >&2
  exit 2
}

[ $# -eq 1 ] || usage
dir=$1

tmp=$(mktemp -d "${TMPDIR:-/tmp}/check-ci.XXXXXX") || {
  printf 'check-ci: cannot make a scratch directory\n' >&2
  exit 1
}
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM

problems=$tmp/problems
: >"$problems"

# note TEXT: one problem, with no line.
note() {
  printf 'check-ci: %s\n' "$1" >>"$problems"
}

file=$dir/ci.yml

if [ ! -d "$dir" ]; then
  note "$dir: is not a directory"
else
  read_ok=0
  if [ -L "$file" ] || [ ! -f "$file" ]; then
    note "$file: is not a regular file: a link, a directory or nothing there"
  else
    read_ok=1
  fi
  # Read by a glob, never by lines of ls: a name may hold a newline.
  for entry in "$dir"/* "$dir"/.[!.]* "$dir"/..?*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    name=${entry##*/}
    case $name in
      ci.yml) ;;
      *)
        shown=$(printf '%s' "$name" | LC_ALL=C tr -c '[:print:]' '[?*]')
        note "$dir: $shown is not ci.yml: the directory must hold ci.yml alone" ;;
    esac
  done

  if [ "$read_ok" -eq 1 ]; then
    # The three blocks the file must hold, line for line.
    cat >"$tmp/expected" <<'EXPECTED'
on:
  push:
    branches: [main]
    tags: ["v*"]
  pull_request:
  workflow_dispatch:
permissions:
  contents: read
concurrency:
  group: ${{ github.workflow }}-${{ github.event_name == 'pull_request' && github.ref || github.run_id }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
EXPECTED

    cat >"$tmp/check.awk" <<'AWKPROGRAM'
function prob(n, m) { printf "check-ci: %s:%d: %s\n", F, n, m }

# odd(s): whether s holds a byte that is not printable ASCII (a tab apart).
function odd(s,   i, n, c) {
  n = length(s)
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (c != "\t" && index(ascii, c) == 0) return 1
  }
  return 0
}

# colonpos(s): where the first colon followed by a space or the end is, or 0.
function colonpos(s,   i, n) {
  n = length(s)
  for (i = 1; i <= n; i++)
    if (substr(s, i, 1) == ":" && (i == n || substr(s, i + 1, 1) == " ")) return i
  return 0
}

# flowscan(s): 1 for a { outside a quoted scalar and a ${{ }} expression, 2 for
# a quoted scalar left open, else 0. A trailing comment ends the scan.
function flowscan(s,   i, n, c, q, prev, j) {
  n = length(s); q = ""
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (q != "") {
      if (q == "\"" && c == "\\") { i++; continue }
      if (c == q) q = ""
      continue
    }
    if (c == "$" && substr(s, i, 3) == "${{") {
      j = index(substr(s, i + 3), "}}")
      if (j == 0) return 1
      i = i + 3 + j
      continue
    }
    prev = (i == 1) ? " " : substr(s, i - 1, 1)
    if ((c == "\"" || c == "'") && (prev == " " || prev == "[" || prev == "," || prev == ":")) { q = c; continue }
    if (c == "{") return 1
    if (c == "#" && prev == " ") return 0
  }
  if (q != "") return 2
  return 0
}

function addblk(k) {
  an[k]++
  al[k, an[k]] = raw
  aln[k, an[k]] = ln
}

function closeblock(k,   i, top) {
  top = (an[k] > en[k]) ? an[k] : en[k]
  for (i = 1; i <= top; i++) {
    if (i > an[k]) { prob(aln[k, an[k]], "the \"" k "\" block ends early: expected \"" el[k, i] "\""); return }
    if (i > en[k]) { prob(aln[k, i], "the \"" k "\" block has a line it must not: \"" al[k, i] "\""); return }
    if (al[k, i] != el[k, i]) {
      prob(aln[k, i], "the \"" k "\" block differs from the one check-ci holds: expected \"" el[k, i] "\", found \"" al[k, i] "\"")
      return
    }
  }
}

# gaterun(g, j): the one rest of a line that may name gate g in job j, its
# step's whole run line, or "" where no line may name it.
function gaterun(g, j) {
  if (g == "check-memory-gate" && j == "memory") return "run: make check-memory-gate"
  if (g == "test-memory" && j == "memory") return "run: make test-memory"
  if (g == "check-nothreads" && j == "nothreads") return "run: make check-nothreads"
  return ""
}

# nreq(j): fills rq[1..n] with the run lines job j must run, in order, and
# rqk[i] with what each one is: bld (the Chez build, which carries the cache's
# if) or env (a make line, which carries the env CHEZ).
function nreq(j,   n) {
  split("", rqk)
  if (j == "nothreads") {
    rq[1] = BLDN; rqk[1] = "bld"; rq[2] = CHKN
    rq[3] = "make check-nothreads"; rqk[3] = "env"
    return 3
  }
  rq[1] = BLDT; rqk[1] = "bld"; rq[2] = CHKT
  if (j == "main") {
    rq[3] = MAKELINE; rqk[3] = "env"; rq[4] = LAUNCHER; rqk[4] = "env"
    return 4
  }
  rq[3] = "make check-memory-gate"; rqk[3] = "env"; rq[4] = "make test-memory"; rqk[4] = "env"
  return 4
}

# keyok(v): v is a restore's key: the job's prefix, then the hashFiles list,
# then nothing or a "-" and more.
function keyok(v,   want, tail) {
  want = prefix[job] "${{ hashFiles(" HASHLIST ") }}"
  if (substr(v, 1, length(want)) != want) return 0
  tail = substr(v, length(want) + 1)
  return (tail == "" || substr(tail, 1, 1) == "-")
}

function stepkey(   u) {
  subk = ""
  if (p == 0) { prob(ln, NOKEY); return }
  if (!(key in stepkeys)) { prob(ln, "step key \"" key "\" is not one of " STEPKEYS); return }
  if (key in sseen) { prob(ln, "step key \"" key "\" is written twice in one step"); return }
  sseen[key] = 1
  if (key == "with" || key == "env") {
    subk = key
    if (val != "") prob(ln, HASVAL)
  } else if (key == "if") {
    S_if[sn] = rest; S_ifln[sn] = ln
  } else if (key == "name") {
    S_name[sn] = rest
  } else if (key == "run") {
    S_run[sn] = rest; S_runln[sn] = ln
  } else if (key == "uses") {
    u = val; sub(/ +#.*$/, "", u); S_uses[sn] = u
  } else if (key == "id") {
    S_id[sn] = val; S_idln[sn] = ln
  }
}

function subkey(   want) {
  if (p == 0) { prob(ln, NOKEY); return }
  if (subk == "with") {
    if (!(key in withkeys)) { prob(ln, "with key \"" key "\" is not one of " WITHKEYS); return }
    if (key in wseen) { prob(ln, "with key \"" key "\" is written twice in one step"); return }
    wseen[key] = 1
    if (key == "submodules") S_sub[sn] = val
    if (key == "path") { S_path[sn] = val; S_pathln[sn] = ln }
    if (key == "key") { S_key[sn] = val; S_keyln[sn] = ln }
  } else {
    if (key != "CHEZ") { prob(ln, "env key \"" key "\" is not CHEZ"); return }
    if (key in eseen) { prob(ln, "env key \"" key "\" is written twice in one step"); return }
    eseen[key] = 1
    S_ev[sn, key] = 1; S_evln[sn, key] = ln
    want = chezpath[job]
    if (val != want) prob(ln, "env " key " in job " job " is not " want)
  }
}

# cachestep(): a Chez cache step's path, key and id, for the step just ended.
function cachestep(   restore, want) {
  restore = (S_uses[sn] ~ /^actions\/cache\/restore@/)
  if (S_path[sn] != cachepath[job])
    prob(S_pathln[sn] ? S_pathln[sn] : S_ln[sn], "the cache path in job " job " is not " cachepath[job])
  if (restore) {
    if (!keyok(S_key[sn]))
      prob(S_keyln[sn] ? S_keyln[sn] : S_ln[sn], "the cache key in job " job " does not begin with " prefix[job] "${{ hashFiles(" HASHLIST ") }}")
    # The id names the restore's outputs, which the build's if and the save's
    # key read.
    if (S_id[sn] != "chez")
      prob(S_idln[sn] ? S_idln[sn] : S_ln[sn], "the cache's restore in job " job " is not id: chez")
  } else {
    want = "${{ steps.chez.outputs.cache-primary-key }}"
    if (S_key[sn] != want)
      prob(S_keyln[sn] ? S_keyln[sn] : S_ln[sn], "the cache key of the save in job " job " is not exactly " want)
  }
}

function endstep() {
  if (!instep) return
  instep = 0
  if (S_if[sn] != "") {
    if (S_if[sn] != IFLINE) prob(S_ifln[sn], "if is not exactly \"" IFLINE "\"")
    if (!(S_run[sn] ~ /^run: scripts\/ci\/build-chez\.sh( |$)/ || S_uses[sn] ~ /^actions\/cache\/save@/))
      prob(S_ifln[sn], "if is on a step that neither runs scripts/ci/build-chez.sh nor uses actions/cache/save")
  }
  if (S_uses[sn] ~ /^actions\/cache\/(restore|save)@/) cachestep()
}

# stepnamed(nm, first, last): the one step of job main named nm, or 0 (and a
# problem) when there is not exactly one.
function stepnamed(nm, first, last,   s, c, at) {
  c = 0; at = 0
  for (s = first; s <= last; s++) if (S_name[s] == "name: " nm) { c++; at = s }
  if (c != 1) { prob(jln, "job main has " c " steps named \"" nm "\", not one"); return 0 }
  return at
}

# mainsteps(first, last): the two report steps of job main. atrun[CHKT] and
# atrun[MAKELINE] are the steps that run check-chez and the make line, or 0 when
# one is missing (a problem already told).
function mainsteps(first, last,   v, q, i, n, m, w, rl) {
  v = stepnamed(VERS, first, last)
  q = stepnamed(SODN, first, last)
  if (v && atrun[CHKT] && v < atrun[CHKT]) prob(S_ln[v], "job main runs step \"" VERS "\" before \"" CHKT "\", and must run it after")
  if (v && atrun[MAKELINE] && v > atrun[MAKELINE]) prob(S_ln[v], "job main runs step \"" VERS "\" after \"" MAKELINE "\", and must run it before")
  if (q && atrun[CHKT] && q < atrun[CHKT]) prob(S_ln[q], "job main runs step \"" SODN "\" before \"" CHKT "\", and must run it after")
  if (q && atrun[MAKELINE] && q > atrun[MAKELINE]) prob(S_ln[q], "job main runs step \"" SODN "\" after \"" MAKELINE "\", and must run it before")
  if (v && q && q < v) prob(S_ln[q], "job main's step \"" SODN "\" comes before step \"" VERS "\", and must come after")
  if (v) {
    rl = S_runln[v] ? S_runln[v] : S_ln[v]
    if (S_run[v] != "run: |") prob(rl, "job main's step \"" VERS "\" does not run a block: it must be run: |")
    else {
      n = bn[v]
      m = (n > nvl) ? n : nvl
      for (i = 1; i <= m; i++) {
        if (i > n) { prob(bln[v, n] ? bln[v, n] : rl, "job main's step \"" VERS "\" has a run block that ends early: expected \"" vl[i] "\""); break }
        if (i > nvl) { prob(bln[v, i], "job main's step \"" VERS "\" has a run line it must not: \"" bl[v, i] "\""); break }
        if (bl[v, i] != vl[i]) {
          prob(bln[v, i], "job main's step \"" VERS "\" has a run line that differs from the one check-ci holds: expected \"" vl[i] "\", found \"" bl[v, i] "\"")
          break
        }
      }
    }
  }
  if (q) {
    rl = S_runln[q] ? S_runln[q] : S_ln[q]
    if (S_run[q] != "run: " SODRUN) prob(rl, "job main's step \"" SODN "\" is not run: " SODRUN)
  }
}

function needenv(at, x, k) {
  if (!((at, k) in S_ev)) prob(S_ln[at], "job " job "'s step that runs \"" x "\" has no env " k)
}

# runs(s, what, prog): whether step s runs scripts/ci/WHAT-PROG.sh.
function runs(s, what, prog) {
  return (S_run[s] ~ ("^run: scripts/ci/" what "-" prog "\\.sh( |$)"))
}

# cacheorder(first, last): the Chez cache's restore before its build, and its
# save after the build and before its check, and one of each.
function cacheorder(first, last,   s, t, restore, nr, ns) {
  nr = 0; ns = 0
  for (s = first; s <= last; s++) {
    if (S_uses[s] != "" && !(S_uses[s] ~ /^actions\/(checkout|cache\/restore|cache\/save)@/))
      prob(S_ln[s], "job " job " has a step that uses \"" S_uses[s] "\", which is not actions/checkout@, actions/cache/restore@ or actions/cache/save@")
    if (!(S_uses[s] ~ /^actions\/cache\/(restore|save)@/)) continue
    restore = (S_uses[s] ~ /^actions\/cache\/restore@/)
    if (restore) nr++; else ns++
    for (t = first; t <= last; t++) {
      if (runs(t, "build", "chez")) {
        if (restore && s > t) prob(S_ln[s], "job " job " restores the Chez cache after the Chez build, and must restore it before")
        if (!restore && s < t) prob(S_ln[s], "job " job " saves the Chez cache before the Chez build, and must save it after")
      }
      if (!restore && runs(t, "check", "chez") && s > t)
        prob(S_ln[s], "job " job " saves the Chez cache after the Chez check, and must save it before")
    }
  }
  if (nr != 1) prob(jln, "job " job " has " nr " restores of the Chez cache, not one")
  if (ns != 1) prob(jln, "job " job " has " ns " saves of the Chez cache, not one")
}

function endjob(   i, s, c, at, pos, lastp, m, x, lastx, first, last, isb) {
  if (job == "") return
  endstep()
  for (i = 1; i <= 4; i++)
    if (!jbad && !(jk2[i] in jkseen)) prob(jln, "job " job " has no key \"" jk2[i] "\"")
  first = jfirst; last = sn; lastp = 0; lastx = "the start"
  if (job == "main" || job == "memory") {
    if (first > last || !(S_uses[first] ~ /^actions\/checkout@/ && S_sub[first] == "recursive" && S_run[first] == "" && S_if[first] == ""))
      prob((first <= last) ? S_ln[first] : jln, "job " job "'s first step is not uses: actions/checkout@ with submodules: recursive")
  }
  if (job == "main") {
    if (first + 1 > last || S_run[first + 1] != "run: " PINRUN)
      prob((first + 1 <= last) ? S_ln[first + 1] : jln, "job main's second step is not run: " PINRUN)
    lastp = 2; lastx = PINRUN
  }
  m = nreq(job)
  # A required line must be the run line of exactly one step.
  split("", rqn); split("", hn); split("", hit)
  for (i = 1; i <= m; i++) rqn[rq[i]]++
  for (s = first; s <= last; s++) {
    x = substr(S_run[s], 6)
    if (substr(S_run[s], 1, 5) == "run: " && (x in rqn)) { hn[x]++; hit[x, hn[x]] = s }
  }
  for (i = 1; i <= m; i++) {
    x = rq[i]
    atrun[x] = 0
    c = hn[x] + 0
    if (c != 1) { prob(jln, "job " job " has " c " steps that run \"" x "\", not one"); continue }
    at = hit[x, 1]
    atrun[x] = at
    pos = at - first + 1
    if (pos <= lastp) prob(S_runln[at], "job " job " runs \"" x "\" before \"" lastx "\", and must run it after")
    else { lastp = pos; lastx = x }
    isb = (rqk[i] == "bld")
    if (isb) {
      if (S_if[at] == "") prob(S_ln[at], "job " job "'s step that runs \"" x "\" has no if")
    } else if (S_if[at] != "") prob(S_ifln[at], "job " job "'s step that runs \"" x "\" has an if")
    if (rqk[i] == "env") needenv(at, x, "CHEZ")
  }
  cacheorder(first, last)
  if (job == "main") mainsteps(first, last)
  job = ""
}

function endsec(   i) {
  endjob()
  if (curblk != "") { closeblock(curblk); curblk = "" }
  if (sec == "jobs")
    for (i = 1; i <= 3; i++)
      if (!(jn[i] in jobseen)) prob(jobsln, "job \"" jn[i] "\" is missing")
  sec = ""
}

BEGIN {
  F = ENVIRON["CI_FILE"]
  for (i = 32; i < 127; i++) ascii = ascii sprintf("%c", i)
  TABMSG = "holds a tab, which YAML may read as white space beside a key"
  ODDMSG = "holds a character beyond ASCII, which GitHub may fold into a key's letters"
  TOPS = "name, on, permissions, concurrency, jobs"
  split("name on permissions concurrency jobs", tk, " ")
  for (i = 1; i <= 5; i++) topidx[tk[i]] = i
  isblock["on"] = 1; isblock["permissions"] = 1; isblock["concurrency"] = 1
  JOBS = "main, memory, nothreads"
  split("main memory nothreads", jn, " ")
  for (i = 1; i <= 3; i++) wantjob[jn[i]] = 1
  JOBKEYS = "name, runs-on, timeout-minutes, steps"
  split("name runs-on timeout-minutes steps", jk2, " ")
  for (i = 1; i <= 4; i++) jobkey[jk2[i]] = 1
  STEPKEYS = "name, id, uses, with, run, env, if"
  split("name id uses with run env if", sk, " ")
  for (i = 1; i <= 7; i++) stepkeys[sk[i]] = 1
  WITHKEYS = "submodules, path, key"
  split("submodules path key", wk, " ")
  for (i = 1; i <= 3; i++) withkeys[wk[i]] = 1
  gname[1] = "check-memory-gate"; gname[2] = "test-memory"; gname[3] = "check-nothreads"
  nbw = split("MAKEFLAGS MFLAGS GNUMAKEFLAGS VALGRIND MEMORY_SUITES MEMORY_TIMEOUT TEST_TIMEOUT LIBDIRS TIMEOUT SUITES CHEZ_SODIUM_LIBRARY CHEZ_SODIUM_GATE_CHILD CC C_INCLUDE_PATH CPATH LIBRARY_PATH LD_LIBRARY_PATH LD_PRELOAD CHECK_CI_ROOT", bw, " ")
  for (i = 1; i <= nbw; i++) banned[bw[i]] = 1
  HASHLIST = "'packaging/floors.sexp', 'scripts/ci/floor.sh', 'scripts/ci/build-chez.sh', 'scripts/ci/check-chez.sh'"
  IFLINE = "if: steps.chez.outputs.cache-hit != 'true'"
  PINRUN = "scripts/ci/check-action-pins.sh .github/workflows"
  BLDT = "scripts/ci/build-chez.sh \"$RUNNER_TEMP/chez-threads\""
  CHKT = "scripts/ci/check-chez.sh \"$RUNNER_TEMP/chez-threads\""
  BLDN = "scripts/ci/build-chez.sh \"$RUNNER_TEMP/chez-nothreads\" --nothreads"
  CHKN = "scripts/ci/check-chez.sh \"$RUNNER_TEMP/chez-nothreads\" --nothreads"
  MAKELINE = "make check-help check-suites check-pins check-floors check-ci test check-test-fails check-clean"
  LAUNCHER = "sh tests/guix-env-launcher.sh"
  VERS = "Report the versions this run uses"
  SODN = "Report the runner's libsodium"
  SODRUN = "scripts/ci/report-sodium.sh"
  nvl = 5
  vl[1] = "          \"$RUNNER_TEMP/chez-threads/bin/scheme\" --version"
  vl[2] = "          cc --version | head -n 1"
  vl[3] = "          valgrind --version"
  vl[4] = "          echo \"image: ${ImageOS:-unknown} ${ImageVersion:-unknown}\""
  vl[5] = "          echo \"kernel: $(uname -r)\""
  chezpath["main"] = "${{ runner.temp }}/chez-threads/bin/scheme"
  chezpath["memory"] = chezpath["main"]
  chezpath["nothreads"] = "${{ runner.temp }}/chez-nothreads/bin/scheme"
  cachepath["main"] = "${{ runner.temp }}/chez-threads"
  cachepath["memory"] = cachepath["main"]
  cachepath["nothreads"] = "${{ runner.temp }}/chez-nothreads"
  prefix["main"] = "chez-threads-"; prefix["memory"] = "chez-threads-"
  prefix["nothreads"] = "chez-nothreads-"
  HASVAL = "this key must hold a block, not a value"
  NOKEY = "is not a key line check-ci reads"
  PLACE = "is not a line check-ci reads at this place"
  job = ""; sec = ""; curblk = ""; lastidx = 0
}

FNR == 1 { fileno++ }

# The first file: the blocks the workflow must hold, line for line.
fileno == 1 {
  if ($0 ~ /^[^ ]/) { ek = $0; sub(/:.*/, "", ek) }
  en[ek]++
  el[ek, en[ek]] = $0
  next
}

# The second file: the workflow.
{
  ln = FNR; lastline = FNR; raw = $0
  if (raw ~ /^ *$/) next
  ind = 0
  while (substr(raw, ind + 1, 1) == " ") ind++
  content = 0
  if (inblock) { if (ind > blockcol) content = 1; else inblock = 0 }
  if (content && instep) { bn[sn]++; bl[sn, bn[sn]] = raw; bln[sn, bn[sn]] = ln }
  # A comment's line is held to the text rules, and to nothing else. A line of
  # a block scalar's content that begins with # is no comment: it goes on.
  if (!content && substr(raw, ind + 1, 1) == "#") {
    if (index(raw, "\t") > 0) prob(ln, TABMSG)
    if (odd(raw)) prob(ln, ODDMSG)
    next
  }

  bad = 0
  if (index(raw, "\t") > 0) { prob(ln, TABMSG); bad = 1 }
  if (odd(raw)) { prob(ln, ODDMSG); bad = 1 }

  rest = ""; col = ind; dashed = 0
  if (!content) {
    rest = substr(raw, ind + 1)
    while (rest == "-" || substr(rest, 1, 2) == "- ") {
      dashed++; rest = substr(rest, 2); col++
      while (substr(rest, 1, 1) == " ") { rest = substr(rest, 2); col++ }
    }
  }

  # The names no line but a comment may hold, a block scalar's content
  # included.
  if (index(raw, "GITHUB_ENV") > 0) prob(ln, "names GITHUB_ENV, which could steer a check or a later step")
  if (index(raw, "GITHUB_PATH") > 0) prob(ln, "names GITHUB_PATH, which could steer a check or a later step")
  w = raw; gsub(/[^A-Za-z0-9_]+/, " ", w)
  nw = split(w, ws, " "); split("", seen)
  for (k = 1; k <= nw; k++) {
    x = ws[k]
    if (!(x in seen) && ((x in banned) || x ~ /^VALGRIND_/ || x ~ /^MEMORY_/)) {
      seen[x] = 1
      prob(ln, "names " x ", which could steer a check or a later step")
    }
  }
  for (g = 1; g <= 3; g++)
    if (index(raw, gname[g]) > 0 && !(!content && (gr = gaterun(gname[g], job)) != "" && rest == gr))
      prob(ln, "names " gname[g] " other than as the whole run line of the one step that runs it")

  # The shell's rule for scripts/, after this program, reads no line that
  # begins with #: here, a block scalar's line that does.
  if (content && substr(raw, ind + 1, 1) == "#" && index(raw, "scripts/") > 0)
    prob(ln, "names scripts/ other than as a step's whole run line of scripts/ci/ or a cache key's hashed files")

  if (content) next

  # Spellings that a text reader could misread.
  p = colonpos(rest); key = ""; val = ""
  if (p > 0) { key = substr(rest, 1, p - 1); val = (p < length(rest)) ? substr(rest, p + 2) : "" }
  if (rest ~ /^\?( |$)/) { prob(ln, "writes an explicit key, with ?, whose colon may be on another line"); bad = 1 }
  if (rest ~ /^[*&][A-Za-z0-9_-]/) { prob(ln, "puts an alias or an anchor where a key goes"); bad = 1 }
  if (rest ~ /^["']/) { prob(ln, "writes a quoted key"); bad = 1 }
  if (p > 1 && substr(rest, p - 1, 1) == " ") { prob(ln, "has white space between a key and its colon"); bad = 1 }
  fl = flowscan(raw)
  if (fl == 1) { prob(ln, "holds a flow mapping, with {, outside a quoted scalar and a ${{ }} expression"); bad = 1 }
  if (fl == 2) { prob(ln, "holds a quoted scalar that runs past the line's end"); bad = 1 }
  q = index(raw, "\"")
  if (q > 0 && index(substr(raw, q + 1), "\\") > 0) { prob(ln, "holds a backslash after a double quote, which YAML may read as an escape"); bad = 1 }

  if (!bad && p > 0 && val ~ /^[|>][-+0-9]*( +#.*)?$/) { inblock = 1; blockcol = col }

  # The shape.
  if (ind == 0 && dashed == 0) {
    endsec(); sec = "ignore"; curblk = ""
    if (bad) next
    if (p == 0) { prob(ln, NOKEY); next }
    if (!(key in topidx)) { prob(ln, "top-level key \"" key "\" is not one of " TOPS); next }
    if (key in topseen) { prob(ln, "top-level key \"" key "\" is written twice"); next }
    topseen[key] = 1
    if (topidx[key] < lastidx) prob(ln, "top-level key \"" key "\" comes out of order: the order is " TOPS)
    else lastidx = topidx[key]
    sec = key
    if (key in isblock) { curblk = key; addblk(key) }
    if (key == "jobs") { jobsln = ln; if (val != "") prob(ln, HASVAL) }
    next
  }
  if (curblk != "") { addblk(curblk); next }
  if (sec != "jobs") next

  if (ind == 2 && dashed == 0) {
    endjob()
    if (bad) next
    if (p == 0) { prob(ln, NOKEY); next }
    if (!(key in wantjob)) { prob(ln, "job \"" key "\" is not one of " JOBS); next }
    if (key in jobseen) { prob(ln, "job \"" key "\" is written twice"); next }
    jobseen[key] = 1; job = key; jln = ln; jfirst = sn + 1
    split("", jkseen); curjk = ""; instep = 0; jbad = 0
    if (val != "") prob(ln, HASVAL)
    next
  }
  if (job == "") next

  if (ind == 4 && dashed == 0) {
    endstep(); curjk = ""
    if (bad) { jbad = 1; next }
    if (p == 0) { prob(ln, NOKEY); next }
    if (!(key in jobkey)) { prob(ln, "job " job " has the key \"" key "\", which is not one of " JOBKEYS); next }
    if (key in jkseen) { prob(ln, "job " job " has the key \"" key "\" twice"); next }
    jkseen[key] = 1; curjk = key
    if (key == "runs-on" && val != "ubuntu-24.04") prob(ln, "job " job " has runs-on other than ubuntu-24.04")
    if (key == "timeout-minutes" && val !~ /^[0-9]+$/) prob(ln, "job " job " has a timeout-minutes that is not a whole number")
    if (key == "steps" && val != "") prob(ln, HASVAL)
    next
  }
  if (ind == 6 && dashed == 1 && col == 8 && curjk == "steps") {
    endstep(); sn++; instep = 1; subk = ""
    split("", sseen); split("", wseen); split("", eseen)
    S_ln[sn] = ln; S_run[sn] = ""; S_runln[sn] = 0; S_if[sn] = ""; S_ifln[sn] = 0; S_uses[sn] = ""; S_sub[sn] = ""
    S_id[sn] = ""; S_idln[sn] = 0; S_path[sn] = ""; S_pathln[sn] = 0; S_key[sn] = ""; S_keyln[sn] = 0; S_name[sn] = ""
    if (!bad) stepkey()
    next
  }
  if (ind == 8 && dashed == 0 && instep) { if (!bad) stepkey(); next }
  if (ind == 10 && dashed == 0 && instep && (subk == "with" || subk == "env")) { if (!bad) subkey(); next }
  if (!bad) prob(ln, PLACE)
}

END {
  endsec()
  for (i = 1; i <= 5; i++)
    if (!(tk[i] in topseen)) prob(lastline, "top-level key \"" tk[i] "\" is missing")
}
AWKPROGRAM

    CI_FILE=$file LC_ALL=C awk -f "$tmp/check.awk" \
      "$tmp/expected" "$file" >>"$problems" 2>"$tmp/awkerr"
    status=$?
    if [ "$status" -ne 0 ]; then
      note "$file: the check (awk) exited $status: $(cat "$tmp/awkerr")"
    fi

    # A step whose whole run line begins scripts/ci/NAME runs that file by its
    # path, so the file must be there and carry the execute bit: a runner
    # fails the step otherwise, and nothing else here would see it. The files
    # are read under CHECK_CI_ROOT, which is the repository root when unset
    # (tests/test-check-ci.sps points it at a copy). scripts/ci/floor.sh is
    # no such step's script: the other scripts run it with sh, so it needs no
    # bit and is not held.
    root=${CHECK_CI_ROOT:-$(dirname "$0")/..}
    grep -n -E '^( {8}| {6}- )run: scripts/ci/[A-Za-z0-9._-]+( |$)' "$file" >"$tmp/runs" || :
    while IFS= read -r entry; do
      lineno=${entry%%:*}
      cmd=${entry#*run: }
      name=${cmd%% *}
      if [ ! -f "$root/$name" ] || [ ! -x "$root/$name" ]; then
        note "$file:$lineno: runs $name, which is missing or not executable: a step runs it by its path, so it must be there and carry the execute bit"
      fi
    done <"$tmp/runs"

    # The rule above reads one spelling of a step that runs a script of
    # scripts/ci/. A line that names scripts/ci/ in any other spelling (a
    # quoted path, a block scalar, ./scripts/ci/, scripts/ci//, a path with a
    # slash after the directory, a command after the name, or a path to the
    # directory that holds no scripts/ci/, such as scripts/./ci/) would run a
    # script the rule never held, so it is a problem itself: bar a comment, a
    # line of the workflow that names scripts/ is a step's whole run line, in
    # the form the rule reads, or a cache key's hashFiles( list.
    grep -n 'scripts/' "$file" |
      grep -v -E '^[0-9]+: *#' |
      grep -v -E '^[0-9]+:( {8}| {6}- )run: scripts/ci/[A-Za-z0-9._-]+( |$)' |
      grep -v -E '^[0-9]+: +key: .*hashFiles\(' >"$tmp/stray" || :
    while IFS= read -r entry; do
      lineno=${entry%%:*}
      note "$file:$lineno: names scripts/ other than as a step's whole run line of scripts/ci/ or a cache key's hashed files"
    done <"$tmp/stray"
  fi
fi

count=$(wc -l <"$problems" | tr -d ' ')
if [ "$count" -eq 0 ]; then
  printf 'check-ci: %s has the one shape check-ci reads\n' "$file"
  exit 0
fi
cat "$problems" >&2
printf 'check-ci: FAILED (problems: %s)\n' "$count" >&2
exit 1
