# The container pin, measured for chez-sodium

Pin: Guix `b532aa7d0bb345aafabf6b63cbfbda45abbec091`, the one chez-sqlite3's `channels.scm` holds.
Manifest measured: `chez-scheme libsodium gcc-toolchain valgrind bash coreutils make grep sed gawk findutils diffutils`.

Command, run on the host from a scratch directory:

    guix time-machine -C channels.scm -- shell -m m.scm -- sh measure.sh

`measure.sh` prints `scheme --version`, `(threaded?)`, `gcc --version`, `valgrind --version`,
`ls -l $GUIX_ENVIRONMENT/lib/libsodium.so*`, `ls include/sodium.h`, and, through a bare
`load-shared-object` of `lib/libsodium.so.26`, `sodium_version_string()`.

Output:

    scheme: 10.4.0
    threaded: #t
    gcc: gcc (GCC) 16.2.0
    valgrind: valgrind-3.27.0
    lib/libsodium.so -> .../libsodium-1.0.22/lib/libsodium.so
    lib/libsodium.so.26 -> .../libsodium-1.0.22/lib/libsodium.so.26
    lib/libsodium.so.26.4.0 -> .../libsodium-1.0.22/lib/libsodium.so.26.4.0
    include/sodium.h exists
    sodium_version_string 1.0.22

Verdict: Chez 10.4.0 (floor 10.4.0) threaded; libsodium 1.0.22 (floor 1.0.18), soname
`libsodium.so.26`, header present. The pin stays.
