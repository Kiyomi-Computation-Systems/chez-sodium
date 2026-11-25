#!/bin/sh
# A memory-limited container, as a cgroup: run on the host, from the
# repository root. First make a 'sensitive hash at each library, with no
# limit, in the container:
#
#   scripts/guix-env sh -c 'p=.plans/research/m4-plan/b/probes/oom.sps; s=build/m4-plan/b/oom;
#     mkdir -p $s; rm -f $s/s22.hash $s/s18.hash;
#     scheme --libdirs src --program $p make sensitive $s/s22.hash;
#     CHEZ_SODIUM_LIBRARY=$PWD/build/slice5/prefix-1.0.18/lib/libsodium.so.23
#       scheme --libdirs src --program $p make sensitive $s/s18.hash'
#
# Then run this inside a 512 MiB scope with no swap:
#
#   systemd-run --user --scope -q -p MemoryMax=512M -p MemorySwapMax=0 \
#     scripts/guix-env sh .plans/research/m4-plan/b/probes/cgroup.sh
#
# Exit 137 is SIGKILL, the kernel's OOM killer; nothing is raised.
set -u
p=.plans/research/m4-plan/b/probes/oom.sps
s=build/m4-plan/b/oom
floor=$PWD/build/slice5/prefix-1.0.18/lib/libsodium.so.23
for lib in "$CHEZ_SODIUM_LIBRARY" "$floor"; do
  v=1.0.22; h=$s/s22.hash
  [ "$lib" = "$floor" ] && { v=1.0.18; h=$s/s18.hash; }
  export CHEZ_SODIUM_LIBRARY="$lib"
  rm -f "$s/cg.hash"
  echo "-- $v: password-hash at 'interactive"
  scheme --libdirs src --program "$p" make interactive "$s/cg.hash"; echo "   exit $?"
  rm -f "$s/cg.hash"
  echo "-- $v: password-hash at 'sensitive"
  scheme --libdirs src --program "$p" make sensitive "$s/cg.hash"; echo "   exit $?"
  echo "-- $v: password-verify of a 'sensitive hash, the right password"
  scheme --libdirs src --program "$p" fallback "$h" "correct horse" sensitive; echo "   exit $?"
done
