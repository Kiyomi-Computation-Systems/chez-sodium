import re, sys, os
d = sys.argv[1]
ids = {}
pages = [f for f in os.listdir(d) if f.endswith('.html')]
for p in pages:
    t = open(os.path.join(d, p), encoding='utf-8').read()
    ids[p] = set(re.findall(r'\sid="([^"]*)"', t))
bad = 0
for p in pages:
    t = open(os.path.join(d, p), encoding='utf-8').read()
    for m in re.finditer(r'<a\s[^>]*href="([^"]*)"', t):
        h = m.group(1)
        if h.startswith('http'):
            continue
        f, _, frag = h.partition('#')
        f = f or p
        if f not in ids and f != 'style.css':
            print('MISSING FILE', p, h); bad += 1; continue
        if frag and frag not in ids.get(f, ()):
            print('MISSING ANCHOR', p, h); bad += 1
    # duplicate ids
    allids = re.findall(r'\sid="([^"]*)"', t)
    dups = {x for x in allids if allids.count(x) > 1}
    if dups: print('DUP IDS', p, dups); bad += 1
print('bad', bad)
