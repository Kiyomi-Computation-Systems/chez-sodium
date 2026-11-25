#!/usr/bin/env python3
"""Plant one fault per copy of the tree, for the docs checks.

Run from the repository root on the host:

    python3 -I .plans/research/m4-slice-1-docs-review/mutants.py

It makes build/m4s1-review-docs/mut/<name>/, each a whole copy of the tree
(symlinks kept) with a scheme-libs link to the real build/scheme-libs, and
writes build/m4s1-review-docs/mut/run.sh, which runs each mutant's check in
the container. Nothing in the tree itself is touched.
"""
import os
import shutil
import sys

ROOT = os.getcwd()
OUT = os.path.join(ROOT, "build", "m4s1-review-docs", "mut")
DIRS = ["src", "tests", "docs", "packaging", ".github", "scripts", "site", ".plans"]
FILES = ["README.org", "CONTRIBUTING.md", "SECURITY.md", "LICENSE", "CHANGELOG.md",
         "Akku.manifest", "Akku.lock", ".gitattributes", "Makefile", "build-site.sps"]

DOCS = '"$CHEZ" --libdirs src:tests:scheme-libs --program tests/test-docs.sps'
REF = '"$CHEZ" --libdirs src:tests:scheme-libs --program tests/test-reference.sps'
MAN = '"$CHEZ" --libdirs src:tests:scheme-libs --program tests/test-manifest.sps'
FLOORS = ('"$CHEZ" --libdirs tests --program tests/check-floors.sps packaging/floors.sexp '
          'README.org .github/workflows scripts/ci docs CONTRIBUTING.md SECURITY.md')


def edit(path, old, new, count=1):
    text = open(path, encoding="utf-8").read()
    found = text.count(old)
    if found != count:
        sys.exit(f"{path}: {old!r} occurs {found} times, not {count}")
    open(path, "w", encoding="utf-8").write(text.replace(old, new))


# name -> (check, [(file, old, new)], what it shows)
MUTANTS = {
    "clean": (DOCS, [], "the unmutated copy"),
    "clean-ref": (REF, [], "the unmutated copy"),
    "clean-man": (MAN, [], "the unmutated copy"),
    "clean-floors": (FLOORS, [], "the unmutated copy"),
    # what the brief names
    "result": (DOCS, [("docs/tokens.md", ";; => (32 64)", ";; => (32 32)")], "a wrong ;; =>"),
    "span": (DOCS, [("docs/tokens.md", "use `constant-time-bytevector=?`.", "use `constant-time-bytevectors=?`.")],
             "a typo'd export span"),
    "floor-page": (FLOORS, [("docs/finding-libsodium.md", "Ubuntu 24.04's among them,",
                             "Ubuntu 24.04's 1.0.18 among them,")], "a floor in a page"),
    "floor-contrib": (FLOORS, [("CONTRIBUTING.md", "(threaded) and libsodium.", "(threaded) and libsodium 1.0.18.")],
                      "a floor in CONTRIBUTING.md"),
    "floor-security": (FLOORS, [("SECURITY.md", "Chez version,", "Chez version (10.4.0 or later),")],
                       "a floor in SECURITY.md"),
    "dead-link": (DOCS, [("docs/passwords.md", "(finding-libsodium.md#it-loads-once)", "(finding-libsodium.md#it-loads-twice)")],
                  "a dead anchor"),
    "dead-file": (DOCS, [("docs/tokens.md", "(reference.md#blake2b)", "(refrence.md#blake2b)")], "a dead file link"),
    "discovery-order": (DOCS, [("docs/finding-libsodium.md", "`/usr/local/lib`, `/usr/lib/x86_64-linux-gnu`",
                                "`/usr/lib/x86_64-linux-gnu`, `/usr/local/lib`")], "a discovery path out of order"),
    "reason-renamed": (DOCS, [("docs/finding-libsodium.md", "| `init-failed` |", "| `start-failed` |")],
                       "a reason renamed in the finding page's table"),
    "guarded-text": (DOCS, [("docs/quickstart.md", "(newline)\n```\n\n- **Loaded:**",
                             "(newline)\n```\n\n```text\n\"1.0.22\"\n```\n\n- **Loaded:**")],
                     "a guarded program given a text block"),
    "second-clone": (MAN, [("docs/quickstart.md", "git clone https://github.com/Kiyomi-Computation-Systems/chez-sodium.git\n```",
                            "git clone https://github.com/Kiyomi-Computation-Systems/chez-sodium.git\n"
                            "git clone https://github.com/Kiyomi-Computation-Systems/chez-sodium.git\n```")],
                     "a second clone line"),
    "signature": (REF, [("docs/reference.md", "blake2b : Bytevector [Natural] [Bytevector] -> Bytevector",
                         "blake2b : Bytevector [Natural] [Bytes] -> Bytevector")], "a wrong signature"),
    # what the checks cannot see
    "gap-readme-span": (DOCS, [("README.org", "Password hashing is its main job.",
                                "Password hashing, =password-hashes=, is its main job.")],
                        "an export typo in README.org's Org verbatim"),
    "gap-fragment-name": (DOCS, [("docs/passwords.md", "    (cond ((password-verify hash password)\n           (when",
                                  "    (cond ((password-verfy hash password)\n           (when")],
                          "an export typo inside an unrun Scheme fragment"),
    "gap-fragment-order": (DOCS, [("docs/passwords.md", "    (cond ((password-verify hash password)\n           (when",
                                   "    (cond ((password-verify password hash)\n           (when")],
                           "the arguments swapped in the login fragment"),
    "gap-ref-reason": (DOCS + " && " + REF, [("docs/reference.md", "- `key-length-out-of-range`: the key is not 16 to 64 bytes.",
                                              "- `key-size-out-of-range`: the key is not 16 to 64 bytes.")],
                       "a refusal reason renamed in the reference"),
    "gap-ref-table": (DOCS + " && " + REF, [("docs/reference.md", "| `init-failed` | libsodium's start-up",
                                             "| `start-failed` | libsodium's start-up")],
                      "a reason renamed in the reference's own reasons table"),
    "gap-finding-id": (DOCS, [("docs/passwords.md", "## Text\n", "## Text\n\nAs M4S0-F9 found:\n")],
                       "a finding id on a page"),
    "gap-printable": (DOCS, [("docs/passwords.md", "ASCII, with no\nspaces.", "printable ASCII.")],
                      "\"printable ASCII\" for a hash string"),
    "gap-short-floor": (FLOORS, [("docs/quickstart.md", "- Linux.\n", "- Linux, and Chez Scheme 10.4 or later.\n")],
                        "a floor written short"),
}


def copy_tree(dest):
    if os.path.exists(dest):
        shutil.rmtree(dest)
    os.makedirs(dest)
    for d in DIRS:
        shutil.copytree(os.path.join(ROOT, d), os.path.join(dest, d), symlinks=True)
    for f in FILES:
        shutil.copy2(os.path.join(ROOT, f), os.path.join(dest, f))
    os.symlink(os.path.join(ROOT, "build", "scheme-libs"), os.path.join(dest, "scheme-libs"))


def main():
    os.makedirs(OUT, exist_ok=True)
    lines = ["#!/bin/sh", "# Run in the container from the repository root.", "cd build/m4s1-review-docs/mut || exit 2"]
    for name, (check, edits, what) in MUTANTS.items():
        dest = os.path.join(OUT, name)
        copy_tree(dest)
        for (f, old, new) in edits:
            edit(os.path.join(dest, f), old, new)
        lines.append(f"( cd {name} && {check} ) > {name}.out 2>&1; echo \"{name}: exit $? ({what})\"")
    open(os.path.join(OUT, "run.sh"), "w").write("\n".join(lines) + "\n")
    print(f"{len(MUTANTS)} copies under {OUT}")


main()
