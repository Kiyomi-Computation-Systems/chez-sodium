The first release: password hashing for Chez Scheme, through a small part
of libsodium's C library, which is found and loaded the first time a
program needs it. Nothing is built: put the clone's `src` on Chez's
library path.

### Added

- **Passwords:** `password-hash`, `password-verify` and
  `password-needs-rehash?`, argon2id through libsodium, at the presets
  `'interactive` (the default), `'moderate` and `'sensitive`, or at
  limits made by `make-password-limits`, with memory in KiB. The
  [passwords page](docs/passwords.md) shows the login pattern, unknown
  accounts and rehashing.
- **API keys and secrets:** `random-bytes`, `blake2b` (sizes 16 to 64,
  with an optional key) for storing a key by its hash, and
  `constant-time-bytevector=?` ([tokens](docs/tokens.md)).
- **Finding libsodium:** discovery in Guix profiles or the standard
  directories, the newer soname first, or `CHEZ_SODIUM_LIBRARY` to name
  one; a refusal says why, by its reason
  ([finding libsodium](docs/finding-libsodium.md)).
- **Conditions:** `&sodium-library-unavailable`, with its reason, path,
  source, detail and candidates, and `&sodium-failed`, with libsodium's
  function and code. A caller's mistake raises `&assertion`, naming its
  rule, and no condition shows a secret
  ([reference](docs/reference.md)).
- **Safety:** each verb runs in one critical section; every block the
  library frees is wiped first; inputs are capped at 64 KiB; and the two
  password calls let other threads collect while a hash runs.
- **The library:** `sodium-version`, the loaded libsodium's version.
- **Docs:** a [quick start](docs/quickstart.md) and four more pages, and
  a site built from them.

### Known limitations

- **The API may change** in any release before 1.0.
- **Platforms:** Linux only. The suites have run on Linux on x86_64;
  Linux on arm64 has not run them.
- **What it is not:** no encryption, signatures, key exchange, AEAD or
  streams; no key derivation from a password; no guarded memory.
  SHA-256 and HMAC-SHA256 are planned for a later release.
- **`password-verify` answers `#f`** for a wrong password, a hash
  libsodium cannot read, and memory libsodium could not get, and nothing
  tells them apart ([what `#f` means](docs/passwords.md#what-f-means)).
- **A container's memory limit** kills the process when a hash needs
  more memory than is left, and nothing is raised
  ([memory](docs/passwords.md#memory)).
- **`password-needs-rehash?` is no check that a hash is whole:** it reads
  a hash's algorithm, parallelism and limits.
- **Another thread's change to a string or a bytevector during a call**
  is refused only when a password's UTF-8 length changes, or a hash's
  character goes out of range. Never change one a verb is reading.
- **Wiping cannot reach** the caller's own strings and bytevectors, the
  bytevectors a verb returns, or copies the collector leaves behind
  ([what is wiped](docs/passwords.md#what-is-wiped)).
- **Not on Akku:** install by a clone of the tag.
- **The tests run from a clone,** not from a release's archive, which is
  no git repository
  ([running the tests](docs/quickstart.md#running-the-tests)).
