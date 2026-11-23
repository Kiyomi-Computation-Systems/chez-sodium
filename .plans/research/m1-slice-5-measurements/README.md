# M1 slice 5's measurements

The plan's §5.2 slice 5 items, taken before any code was written. The host has the network; the
container builds and tests. `<repo>` is the checkout.

## On the host: the tarballs

| Release | Under `https://download.libsodium.org/libsodium/` | SHA-256 |
|---|---|---|
| 1.0.18 | `releases/old/` (404 under `releases/`) | `6f504490b342a4f8a4c4a02fc9b866cbef8622d5df4e5452b46be121e46636c1` |
| 1.0.22 | `releases/` (404 under `releases/old/`) | `adbdd8f16149e81ac6078a03aca6fc03b592b89ef7b5ed83841c086191be3349` |

- **Three tools agree on each SHA-256:** `sha256sum`, `openssl dgst -sha256` and
  `shasum -a 256`.
- **The key.** libsodium's documentation, `installation/README.md` in `jedisct1/libsodium-doc`,
  section "Integrity checking", gives the minisign key
  `RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3`.
- **Each tarball verifies against its `.minisig`.** The check was
  `minisign -VP <key> -m <tarball>`, with Guix's minisign, and each printed "Signature and
  comment signature verified". The trusted comments:
  - `timestamp:1633778368 file:libsodium-1.0.18.tar.gz hashed`;
  - `timestamp:1775774745 file:libsodium-1.0.22.tar.gz hashed`.
- **Each unpacks to `libsodium-X.Y.Z/`.** The container has no `tar`, so the trees were unpacked
  on the host, under `build/`.

## In the container: the builds

- **Configure:** `./configure --prefix=PREFIX` with no other flag, then `make -j18` and
  `make install`.
- **Time:** 10 s to configure, and 6 to 7 s to build and install, for each release, on 18 cores
  with `make -j18`. The lanes' `build-sodium.sh` runs `make` serially: the scripts builder
  measured 58 s in all for 1.0.22 that way, once per cold cache.

| Release | Library | `SONAME` | `version.h` | Answers |
|---|---|---|---|---|
| 1.0.18 | `lib/libsodium.so.23` → `.so.23.3.0` | `libsodium.so.23` | `1.0.18`, major 10, minor 3 | `1.0.18`, 10, 3, minimal 0 |
| 1.0.22 | `lib/libsodium.so.26` → `.so.26.4.0` | `libsodium.so.26` | `1.0.22`, major 26, minor 4 | `1.0.22`, 26, 4, minimal 0 |

- **What the columns are.** "Answers" is what a probe compiled `-Wall -Werror` against each
  build's own header printed: `sodium_version_string()`, `sodium_library_version_major()` and
  `_minor()`, and `sodium_library_minimal()`.
- **`version.h` defines no `SODIUM_LIBRARY_MINIMAL`** in either build.
- **The compile needs the headers prepended in the container:**
  `C_INCLUDE_PATH=PREFIX/include` alone fails with "`linux/limits.h`: No such file or
  directory", and `PREFIX/include:$C_INCLUDE_PATH` compiles (`.plans/traps.md`).

## In the container: `make test` against each build

- **Command:** `CHEZ_SODIUM_LIBRARY=PREFIX/lib/libsodium.so.2N`, with
  `C_INCLUDE_PATH=PREFIX/include:$C_INCLUDE_PATH`.
- **1.0.18:** ran 25, passed 25, in 35 s. `make build` reports
  `<repo>/build/slice5/prefix-1.0.18/lib/libsodium.so.23 (override)`, `1.0.18 (library 10.3)`.
- **1.0.22:** ran 25, passed 25, in 35 s. `make build` reports
  `<repo>/build/slice5/prefix-1.0.22/lib/libsodium.so.26 (override)`, `1.0.22 (library 26.4)`.
