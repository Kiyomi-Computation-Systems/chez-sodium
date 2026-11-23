# Host-side: medians of run-5-raw.out into run-5.out.  python3 -I build/m2-plan/medians.py
import statistics, collections
d = collections.defaultdict(list)
for l in open('build/m2-plan/run-5-raw.out'):
    s, m, lab, v = l.split(); d[(int(s), m, lab)].append(float(v))
out = ["size mode operation runs median_us_per_call min max"]
for k in sorted(d, key=lambda k: (-k[0], k[1])):
    v = d[k]; out.append("%d %s %s %d %s %s %s" % (k[0], k[1], k[2], len(v), statistics.median(v), min(v), max(v)))
open('build/m2-plan/run-5.out', 'w').write("\n".join(out) + "\n"); print("\n".join(out))
