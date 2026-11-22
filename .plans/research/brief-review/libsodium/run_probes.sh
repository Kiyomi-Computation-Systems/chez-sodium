#!/bin/sh
# Build and run every probe against Guix's libsodium 1.0.18 (and the pwhash probe against the host's .so too).
set -e
cd "$(dirname "$0")"
S=/gnu/store/7rr6w0hwsal5abp7l1gb4lacw24c6qar-libsodium-1.0.18
for p in probe_pwhash probe_misc probe_oom probe_timing probe_speed probe_units probe_rfc7693_selftest; do
  gcc -O1 -w -o $p $p.c -I$S/include -L$S/lib -Wl,-rpath,$S/lib -lsodium
done
gcc -O1 -w -pthread -o probe_threads probe_threads.c -I$S/include -L$S/lib -Wl,-rpath,$S/lib -lsodium
gcc -O1 -w -o probe_pwhash_host probe_pwhash.c -I$S/include /lib/x86_64-linux-gnu/libsodium.so.23
./probe_pwhash; ./probe_pwhash_host > out_pwhash_host.txt; ./probe_misc; ./probe_units; ./probe_rfc7693_selftest
./probe_threads; ./probe_timing; ./probe_speed
(ulimit -v 200000; ./probe_oom 268435456 262144) || true
systemd-run --user --scope -q -p MemoryMax=128M -p MemorySwapMax=0 ./probe_oom 268435456 262144 || echo "exit=$? (137 = SIGKILL by the cgroup OOM killer)"
scheme -q < probe_strings.ss
