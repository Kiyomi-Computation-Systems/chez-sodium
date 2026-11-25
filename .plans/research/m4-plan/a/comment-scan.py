#!/usr/bin/env python3
"""comment-scan.py ROOT: count the comments under src/, tests/, the Makefile,
scripts/ and packaging/ that AGENTS.md's comment rule bans, and those that
carry the build's history in other words. Reads `git ls-files` of ROOT.

A comment is: in Scheme (.sps, .sls, .sexp), text after a ; outside a string
or a #\\ character, and #| |# blocks; in C (.c, .h), // and /* */ outside a
string; in shell, the Makefile, awk and text files, a line whose first
non-blank is #, or a # after a blank outside quotes, the line-1 #! apart.
Heredoc bodies in shell count as shell lines (an approximation).

Prints, per category, the count of comment lines and of files, split into
tests/fixtures/ and the rest, then every banned hit as FILE:LINE: TEXT.
"""
import re, subprocess, sys

root = sys.argv[1]
files = subprocess.run(["git", "-C", root, "ls-files", "src", "tests", "Makefile",
                        "scripts", "packaging"], capture_output=True, text=True,
                       check=True).stdout.split()

def scheme_comments(text):
    out = {}  # line -> comment text
    i, n, line = 0, len(text), 1
    state, depth = "code", 0
    buf, start = [], 1
    def add(ln, s):
        out[ln] = (out.get(ln, "") + " " + s).strip()
    while i < n:
        c = text[i]
        if state == "code":
            if c == "\n": line += 1; i += 1; continue
            if c == "#" and i + 1 < n and text[i+1] == "\\":
                i += 3; continue  # #\x: skip the character after #\
            if c == "#" and i + 1 < n and text[i+1] == "|":
                state, depth, buf, start = "block", 1, [], line; i += 2; continue
            if c == '"': state = "string"; i += 1; continue
            if c == ";":
                j = text.find("\n", i)
                j = n if j < 0 else j
                add(line, text[i:j]); i = j; continue
            i += 1
        elif state == "string":
            if c == "\\": i += 2; continue
            if c == "\n": line += 1
            if c == '"': state = "code"
            i += 1
        else:  # block comment, nestable
            if text.startswith("|#", i):
                depth -= 1; i += 2
                if depth == 0:
                    state = "code"
                continue
            if text.startswith("#|", i): depth += 1; i += 2; continue
            if c == "\n": line += 1
            else: out[line] = out.get(line, "") + c
            i += 1
    return out

def c_comments(text):
    out = {}
    i, n, line, state = 0, len(text), 1, "code"
    while i < n:
        c = text[i]
        if state == "code":
            if c == "\n": line += 1
            elif text.startswith("//", i):
                j = text.find("\n", i); j = n if j < 0 else j
                out[line] = out.get(line, "") + text[i:j]; i = j; continue
            elif text.startswith("/*", i): state = "block"; i += 2; continue
            elif c == '"': state = "string"
            elif c == "'": state = "char"
            i += 1
        elif state in ("string", "char"):
            if c == "\\": i += 2; continue
            if c == "\n": line += 1
            if (state == "string" and c == '"') or (state == "char" and c == "'"): state = "code"
            i += 1
        else:
            if text.startswith("*/", i): state = "code"; i += 2; continue
            if c == "\n": line += 1
            else: out[line] = out.get(line, "") + c
            i += 1
    return out

def hash_comments(text):
    out = {}
    for ln, l in enumerate(text.split("\n"), 1):
        if ln == 1 and l.startswith("#!"): continue
        s = l.lstrip()
        if s.startswith("#"): out[ln] = s; continue
        q = None
        for k, ch in enumerate(l):
            if q:
                if ch == q: q = None
                elif ch == "\\" and q == '"': pass
                continue
            if ch in "'\"": q = ch; continue
            if ch == "#" and k > 0 and l[k-1] in " \t":
                out[ln] = l[k:]; break
    return out

def kind(path):
    if re.search(r"\.(sps|sls|sexp|scm)$", path): return "scheme"
    if re.search(r"\.[ch]$", path): return "c"
    return "hash"

BANNED = [
    ("milestone", re.compile(r"\bM[0-9]+\b|\bmilestones?\b", re.I)),
    ("slice", re.compile(r"\bslices?\b", re.I)),
    ("finding id", re.compile(r"\b[A-Z][A-Z0-9]*-[A-Za-z][0-9]+\b")),
    ("research path", re.compile(r"research/|\.plans\b|build/m[0-9]")),
    ("date", re.compile(r"\b20[0-9]{2}-[0-9]{2}-[0-9]{2}\b")),
    ("the maintainer", re.compile(r"\bthe maintainer\b", re.I)),
]
OTHER = [
    ("the owner", re.compile(r"\bthe owner\b|\bowner's\b", re.I)),
    ("amended", re.compile(r"\bamend(ed|ment)\b", re.I)),
    ("decision N", re.compile(r"\bdecisions? [0-9]+", re.I)),
    ("traps.md or AGENTS.md", re.compile(r"traps\.md|AGENTS\.md")),
    ("review", re.compile(r"\breview(s|ed|er|'s)?\b", re.I)),
    ("brief or plan section", re.compile(r"\bbrief\b|§|\bplan\b", re.I)),
    ("row N", re.compile(r"\brows? [0-9]+\b", re.I)),
]

hits = {name: [] for name, _ in BANNED + OTHER}
for f in files:
    try:
        text = open(f"{root}/{f}", encoding="utf-8").read()
    except (UnicodeDecodeError, IsADirectoryError, FileNotFoundError):
        continue
    k = kind(f)
    cs = scheme_comments(text) if k == "scheme" else c_comments(text) if k == "c" else hash_comments(text)
    for ln, c in sorted(cs.items()):
        for name, rx in BANNED + OTHER:
            if rx.search(c):
                hits[name].append((f, ln, c.strip()))

def summary(name):
    rest = [h for h in hits[name] if not h[0].startswith("tests/fixtures/")]
    fix = [h for h in hits[name] if h[0].startswith("tests/fixtures/")]
    return (len(rest), len({h[0] for h in rest}), len(fix), len({h[0] for h in fix}))

print(f"files read: {len(files)}")
print("category | lines | files | in tests/fixtures/: lines | files")
for name, _ in BANNED + OTHER:
    a, b, c, d = summary(name)
    print(f"{name} | {a} | {b} | {c} | {d}")
banned_lines = {(h[0], h[1]) for name, _ in BANNED for h in hits[name] if not h[0].startswith("tests/fixtures/")}
print(f"banned, any category, outside fixtures: {len(banned_lines)} lines in {len({f for f, _ in banned_lines})} files")
for name, _ in BANNED + OTHER:
    print(f"\n## {name}" + ("" if (name, _) in BANNED else " (other words)"))
    for f, ln, c in hits[name]:
        print(f"{f}:{ln}: {c[:160]}")
