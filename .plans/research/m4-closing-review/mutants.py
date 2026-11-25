#!/usr/bin/env python3
"""Plant one fault per whole copy of the tree, for M4's checks.

Run from the repository root on the host:

    python3 -I .plans/research/m4-closing-review/mutants.py

It makes build/m4-closing-review/mut/<name>/, each a copy of the working tree
(symlinks kept; no .git, build or .claude), with build/akku copied in, so
make site-deps finds its archive offline, and a scheme-libs link to the real
build/scheme-libs for the suites run directly. make deps, in a copy, links
the copy's own vendor/chez-srfi into the copy's own build/scheme-libs. It
writes build/m4-closing-review/mut/run.sh, which runs each mutant's checks in
the container and prints each one's exit status and its last lines. Nothing
in the tree itself is touched.
"""
import os
import shutil
import sys

ROOT = os.getcwd()
OUT = os.path.join(ROOT, "build", "m4-closing-review", "mut")

DOCS = '"$CHEZ" --libdirs src:tests:scheme-libs --program tests/test-docs.sps'
REF = '"$CHEZ" --libdirs src:tests:scheme-libs --program tests/test-reference.sps'
MAN = '"$CHEZ" --libdirs src:tests:scheme-libs --program tests/test-manifest.sps'
FLOORS = ('"$CHEZ" --libdirs tests --program tests/check-floors.sps packaging/floors.sexp '
          'README.org .github/workflows scripts/ci docs CONTRIBUTING.md SECURITY.md')
MAKE_FLOORS = 'make -s check-floors'
SITE_MAIN = 'make -s check-site'
SITE_TAG = 'SITE_REF=v0.1.0 make -s check-site'
RENDER_TAG = 'SITE_REF=v0.1.0 make -s site && grep -c "blob/v0.1.0/" build/site/index.html'
CTF = 'make -s check-test-fails'

PAGES = "docs/passwords.md"
TOKENS = "docs/tokens.md"
REFP = "docs/reference.md"

RELEASE_ENTRY = """## [Unreleased]

## [0.1.0] - 2026-11-26

The first release: password hashing for Chez Scheme, bound to libsodium's own C
library, which is found and loaded when a program first needs it.

### Added

- **Passwords:** `password-hash`, `password-verify`, `password-needs-rehash?`
  and `make-password-limits` ([Passwords](docs/passwords.md)).

### Known limitations

- Linux only, on x86_64; arm64 has not run.

[Unreleased]: https://github.com/Kiyomi-Computation-Systems/chez-sodium/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Kiyomi-Computation-Systems/chez-sodium/releases/tag/v0.1.0
"""

CLONE = "git clone https://github.com/Kiyomi-Computation-Systems/chez-sodium.git"
CLONE_TAG = "git clone --branch v0.1.0 https://github.com/Kiyomi-Computation-Systems/chez-sodium.git"

RELEASE_EDITS = [
    ("Akku.manifest", '(akku-package ("chez-sodium" "0.0.0")', '(akku-package ("chez-sodium" "0.1.0")'),
    ("CHANGELOG.md", "## [Unreleased]\n", RELEASE_ENTRY),
    ("README.org", CLONE, CLONE_TAG),
    ("docs/quickstart.md", CLONE, CLONE_TAG),
]


def edit(path, old, new, count=1):
    text = open(path, encoding="utf-8").read()
    found = text.count(old)
    if found != count:
        sys.exit(f"{path}: {old!r} occurs {found} times, not {count}")
    open(path, "w", encoding="utf-8").write(text.replace(old, new))


# name -> ([checks], [(file, old, new)], what it shows)
MUTANTS = {
    # controls
    "clean": ([DOCS, REF, MAN, FLOORS], [], "the unmutated copy"),
    "clean-make": ([MAKE_FLOORS, SITE_MAIN], [], "the unmutated copy, through make"),

    # the pages a reader copies: lines the examples run but no output holds
    "all-together-no-dummy-refusal": (
        [DOCS],
        [(PAGES, "          ((eq? hash no-account) 'refused)\n", "")],
        "the login program's refusal of the dummy hash removed: a verify #t against it would log in"),
    "all-together-dummy-row": (
        [DOCS],
        [(PAGES, '(show (log-in! "ada" #f))\n', '(show (log-in! "ada" #f))\n(show (log-in! "cal" "no one\'s password"))\n'),
         (PAGES, "refused\nrefused\n```\n\nAda logs in", "refused\nrefused\nrefused\n```\n\nAda logs in")],
        "the fix: a row that tries the dummy's own password on a name with no account, refused"),
    "all-together-dummy-row-mutant": (
        [DOCS],
        [(PAGES, '(show (log-in! "ada" #f))\n', '(show (log-in! "ada" #f))\n(show (log-in! "cal" "no one\'s password"))\n'),
         (PAGES, "refused\nrefused\n```\n\nAda logs in", "refused\nrefused\nrefused\n```\n\nAda logs in"),
         (PAGES, "          ((eq? hash no-account) 'refused)\n", "")],
        "the fix holds the line: with the row, the dummy's refusal removed fails"),
    "all-together-no-bound": (
        [DOCS],
        [(PAGES, "    (cond ((not (and (string? password) (<= (string-length password) 1024)))\n"
                 "           'refused)\n          ((not (password-verify hash password)) 'refused)\n",
                 "    (cond ((not (password-verify hash password)) 'refused)\n")],
        "the login program's bound removed: (log-in! \"ada\" #f) raises"),
    "all-together-swapped": (
        [DOCS],
        [(PAGES, "((not (password-verify hash password)) 'refused)", "((not (password-verify password hash)) 'refused)")],
        "the login program's verify given its arguments swapped"),
    "all-together-output": (
        [DOCS],
        [(PAGES, "logged-in\n#t\n#f\nrefused\nlogged-in\nrefused\nrefused\n",
                 "logged-in\n#t\n#f\nrefused\nlogged-in\nrefused\nlogged-in\n")],
        "the login program's stated output changed"),
    "login-run-no-guard": (
        [DOCS],
        [(PAGES, "             (guard (e ((sodium-failed? e) #f))\n"
                 "               (store-hash! account (password-hash password my-limits))))\n",
                 "             (store-hash! account (password-hash password my-limits)))\n")],
        "the run block's rehash left unwrapped, as the bullet below it says not to"),
    "tokens-no-length-check": (
        [DOCS],
        [(TOKENS, "  (and (string? key)\n       (= (string-length key) 64)\n       (hashtable-ref",
                  "  (and (string? key)\n       (hashtable-ref")],
        "the token lookup's length check, which its bullet explains, removed"),

    # the reference's refusals
    "ref-bullet-dropped": (
        [DOCS, REF],
        [(REFP, "- `empty-key`: the key is empty.\n", "")],
        "a refusal blake2b raises dropped from its entry"),
    "ref-order-swapped": (
        [DOCS, REF],
        [(REFP, "- `not-a-natural`: the size is not an exact natural. `#f` is refused too.\n"
                "- `size-out-of-range`: the size is not 16 to 64.\n",
                "- `size-out-of-range`: the size is not 16 to 64.\n"
                "- `not-a-natural`: the size is not an exact natural. `#f` is refused too.\n")],
        "two of blake2b's refusals swapped, under \"in this order\""),
    "ref-reason-wrong-verb": (
        [DOCS],
        [(REFP, "- `not-password-limits`: the limits are no preset and no Password-limits.\n"
                "- `changed-during-call`: another thread changed the password's length as\n",
                "- `not-password-limits`: the limits are no preset and no Password-limits.\n"
                "- `empty-key`: the key is empty.\n"
                "- `changed-during-call`: another thread changed the password's length as\n")],
        "control: a reason password-hash never raises, listed under it"),
    "ref-glossary-limits": (
        [DOCS, REF],
        [(REFP, "Limits                    'interactive, 'moderate, 'sensitive or a Password-limits",
                "Limits                    'interactive, 'moderate or a Password-limits")],
        "the glossary's Limits without 'sensitive"),
    "src-limits-comment": (
        [DOCS, REF],
        [("src/chez-sodium.sls",
          ";;   Limits = (U 'interactive 'moderate 'sensitive Password-limits), by default 'interactive",
          ";;   Limits = (U 'interactive 'moderate Password-limits), by default 'interactive")],
        "the source's Limits definition without 'sensitive"),
    "ref-needs-rehash-first-wording": (
        [DOCS, REF],
        [(REFP, "It may answer `#f` for a hash that was damaged but still reads, so it is no\n"
                "check that a hash is intact. Call it only",
                "It answers `#t` for a hash that was damaged, so it is a check that a hash is\n"
                "intact. Call it only")],
        "the reference says needs-rehash finds a damaged hash"),

    # floors
    "floor-issue-template": (
        [FLOORS, MAKE_FLOORS],
        [(".github/ISSUE_TEMPLATE/bug_report.md", "- Chez Scheme version (`scheme --version`):",
          "- Chez Scheme version (`scheme --version`, 10.4.0 or later):")],
        "a floor in the bug-report template"),
    "floor-contributing-unwired": (
        [MAKE_FLOORS, CTF],
        [("Makefile", "scripts/ci docs CONTRIBUTING.md SECURITY.md\n", "scripts/ci docs SECURITY.md\n"),
         ("CONTRIBUTING.md", "Scheme (threaded) and libsodium.", "Scheme (threaded) and libsodium 1.0.18.")],
        "CONTRIBUTING.md dropped from the Makefile's check-floors line, and a floor planted in it"),

    # the release, dry run
    "release": (
        [MAN, DOCS, FLOORS, SITE_MAIN, SITE_TAG, RENDER_TAG],
        RELEASE_EDITS,
        "the release's edits: the manifest at 0.1.0, a [0.1.0] entry, both clone lines at v0.1.0"),
    "release-rc-tag": (
        ['SITE_REF=v0.1.0-rc.1 make -s check-site', 'SITE_REF=v0.2 make -s check-site'],
        [],
        "a v* tag that is no X.Y.Z, at the manifest's 0.0.0: check-site holds nothing"),
    "release-manifest-alone": (
        [MAN, SITE_TAG],
        [RELEASE_EDITS[0]],
        "control: the manifest bumped alone"),
}


def copy_tree(dst):
    def ign(d, names):
        if os.path.abspath(d) == ROOT:
            return [n for n in names if n in ("build", ".git", ".claude")]
        return []
    shutil.copytree(ROOT, dst, symlinks=True, ignore=ign)
    os.makedirs(os.path.join(dst, "build"))
    shutil.copytree(os.path.join(ROOT, "build", "akku"), os.path.join(dst, "build", "akku"), symlinks=True)
    os.symlink(os.path.join(ROOT, "build", "scheme-libs"), os.path.join(dst, "scheme-libs"))


def main():
    names = sys.argv[1:] or list(MUTANTS)
    os.makedirs(OUT, exist_ok=True)
    for name in names:
        checks, edits, _ = MUTANTS[name]
        dst = os.path.join(OUT, name)
        if os.path.exists(dst):
            shutil.rmtree(dst)
        copy_tree(dst)
        for f, old, new in edits:
            edit(os.path.join(dst, f), old, new)
        with open(os.path.join(dst, "checks.sh"), "w") as out:
            out.write('cd "$(dirname "$0")" || exit 2\n')
            for i, c in enumerate(checks):
                out.write(f'( {c} ) > check-{i}.out 2>&1; echo "check {i} exit $?: {c}"\n')
                out.write(f'grep -E "FAIL|unexpected|problems|check-site:|check-floors: FAILED|ok |test: ran" check-{i}.out | head -8\n')
        print("made", name)
    with open(os.path.join(OUT, "run.sh"), "w") as out:
        out.write('cd "$(dirname "$0")" || exit 2\n')
        for name in names:
            out.write(f'echo "=== {name}: {MUTANTS[name][2]}"\nsh {name}/checks.sh\n')


main()
