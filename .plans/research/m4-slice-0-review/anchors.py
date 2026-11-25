"""Check every relative link and #anchor in the given Markdown files, by
GitHub's heading rule: lower case; drop every char but a letter, digit, _,
space or -; spaces to -; repeats numbered -1, -2. Links inside code are
skipped. Prints each link that names no file or no heading, and a count."""
import os, re, sys

def slugs(path):
    out, seen, fence = [], {}, None
    for line in open(path, encoding="utf-8"):
        m = re.match(r"^ {0,3}(`{3,}|~{3,})", line)
        if m:
            if fence is None:
                fence = m.group(1)[0]
            elif m.group(1)[0] == fence:
                fence = None
            continue
        if fence:
            continue
        h = re.match(r"^ {0,3}#{1,6}\s+(.*?)\s*#*\s*$", line)
        if not h:
            continue
        t = h.group(1)
        t = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", t)
        t = t.replace("`", "").replace("*", "").lower()
        t = "".join(c for c in t if c.isalnum() or c in "_- ")
        t = t.replace(" ", "-")
        n = seen.get(t, 0)
        seen[t] = n + 1
        out.append(t if n == 0 else f"{t}-{n}")
    return set(out)

bad = 0
for f in sys.argv[1:]:
    text = open(f, encoding="utf-8").read()
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    text = re.sub(r"`[^`\n]*`", "", text)
    for target in re.findall(r"\]\(([^)\s]+)\)", text):
        if re.match(r"^[a-z]+:", target):
            continue
        file, _, anchor = target.partition("#")
        dest = os.path.normpath(os.path.join(os.path.dirname(f), file)) if file else f
        if not os.path.exists(dest):
            print(f"{f}: {target}: no such file"); bad += 1; continue
        if anchor and dest.endswith(".md") and anchor not in slugs(dest):
            print(f"{f}: {target}: no such heading"); bad += 1
print(f"bad links: {bad}")
