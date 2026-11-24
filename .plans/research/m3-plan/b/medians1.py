# Host-side: medians of run-1-raw.out into run-1.out.  python3 -I build/m3-plan/b/medians1.py
import statistics, collections
d = collections.defaultdict(list); order=[]
for l in open('build/m3-plan/b/run-1-raw.out'):
    lib, lim, mode, lab, v = l.split()
    k=(lib,lim,mode,lab)
    if k not in d: order.append(k)
    d[k].append(float(v))
out = ["library limits mode operation runs median_ms_per_call min max"]
for k in order:
    v = d[k]; out.append("%s %s %s %s %d %s %s %s" % (*k, len(v), statistics.median(v), min(v), max(v)))
open('build/m3-plan/b/run-1.out', 'w').write("\n".join(out) + "\n"); print("\n".join(out))
