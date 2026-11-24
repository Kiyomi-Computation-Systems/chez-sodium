# Host-side: medians of run-2c-raw.out into run-2c.out.  python3 -I build/m3-plan/b/medians2.py
import statistics, collections
d = collections.defaultdict(list); order=[]
for l in open('build/m3-plan/b/run-2c-raw.out'):
    mode, lab, v = l.split(); k=(mode,lab)
    if k not in d: order.append(k)
    d[k].append(float(v))
out = ["mode operation runs median_us_per_call min max"]
for k in order:
    v = d[k]; out.append("%s %s %d %s %s %s" % (*k, len(v), statistics.median(v), min(v), max(v)))
open('build/m3-plan/b/run-2c.out', 'w').write("\n".join(out) + "\n"); print("\n".join(out))
