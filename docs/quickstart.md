# Quick start

chez-sodium binds a small part of libsodium for Chez Scheme: password
hashing, which is its main job, plus random bytes, BLAKE2b and a
constant-time compare. It is no general libsodium binding, and no crypto
toolkit; [README.org](../README.org) lists what it leaves out.

This page goes from a clone to a first program.

## What you need

- Linux.
- Chez Scheme, built with threads, and libsodium, at the versions
  [README.org's Requirements](../README.org) name.

A program needs nothing else: no C compiler, no headers and no build step.
chez-sodium is Scheme source, and it loads libsodium when your program runs.

On a Chez built without threads, importing chez-sodium is refused:
"chez-sodium needs a threaded Chez Scheme, and (threaded?) is #f in this
one. Chez builds threaded unless configured with --nothreads". On a Chez
older than Requirements names, it is refused too, and the message names
the version it needs.

## On Ubuntu 24.04

Ubuntu's `chezscheme` package is too old, so build Chez from its release
tarball. Pick a release from [Chez's releases](https://github.com/cisco/ChezScheme/releases),
the one README.org's Requirements name or a later one, and put its number
where `X.Y.Z` is:

```sh
sudo apt-get update
sudo apt-get install build-essential ca-certificates curl git libsodium23
version=X.Y.Z
curl -fLO https://github.com/cisco/ChezScheme/releases/download/v$version/csv$version.tar.gz
tar xzf csv$version.tar.gz
cd csv$version
./configure --disable-x11 --disable-curses
make
sudo make install
cd ..
```

- `build-essential` is the C compiler and `make` that Chez's build needs.
  The two `--disable` flags drop the line editor's need for X11 and curses.
- Chez builds with threads unless told not to, and installs as `scheme`.
- `libsodium23` is Ubuntu's libsodium. chez-sodium finds it by itself.

## Get it

```sh
git clone https://github.com/Kiyomi-Computation-Systems/chez-sodium.git
```

There is nothing to build. `src/` holds the library you import,
`(chez-sodium)`.

## Put it on the library path

Put the clone's `src` on Chez's library path, and run your program:

```sh
scheme --libdirs chez-sodium/src --program app.sps
```

## A first program

Save this as `app.sps`, beside the clone:

```scheme
(import (rnrs) (chez-sodium))

(define hash (password-hash "correct horse"))

(write (list (password-verify hash "correct horse")
             (password-verify hash "battery staple")
             (bytevector-length (random-bytes 32))))
(newline)
```

Run it with the command above. It prints:

```text
(#t #f 32)
```

- `password-hash` turns a password into a hash string. You store the
  string, never the password.
- `password-verify` takes that hash and a password, and answers `#t` only
  for the right password.
- `random-bytes` gives fresh random bytes, here 32, for a key or a token.

The examples on these pages often leave out the `import` and the `write`.
A block whose last line is `;; =>` is a program's body, which the tests
run, and that line says what it gives. This is the same check:

```scheme run
(define hash (password-hash "correct horse"))
(list (password-verify hash "correct horse")
      (password-verify hash "battery staple"))
;; => (#t #f)
```

## Which libsodium did it load?

This program says which version of libsodium it loaded, or why it refused
one:

```scheme
(import (rnrs) (rnrs eval) (chez-sodium))

(write
 (guard (e ((sodium-library-unavailable? e)
            (list 'refused
                  (sodium-library-unavailable-reason e)
                  (sodium-library-unavailable-path e))))
   (eval '(sodium-version) (environment '(chez-sodium)))))
(newline)
```

- **Loaded:** libsodium's version, as a string.
- **Refused:** `refused`, the reason, such as `not-found` or `below-floor`,
  and the path, or `#f` when none was chosen.
  [Finding libsodium](finding-libsodium.md#when-it-is-refused) says what
  each reason means.

A program that names a procedure which needs libsodium loads it as it
starts, before any `guard` in it is in place. So this program names
`sodium-version` only inside `eval`, within the `guard`. The conditions'
predicates and accessors load nothing.

To see the file too, run `make build` in the clone. It prints the path it
loaded, where it found it, and the version.

## Running the tests

The tests run from a clone, never from a release's archive: they need a
pinned submodule, which git fetches once, and an archive is no git
repository. They also need a C compiler, libsodium's headers and GNU
`timeout`; `make test-memory` needs Valgrind too. On Ubuntu 24.04, from
the folder you cloned into:

```sh
sudo apt-get install libsodium-dev valgrind
cd chez-sodium
git submodule update --init --recursive
make test
```

The tests compile small C programs against libsodium's header, `sodium.h`.
To test another libsodium, name its file with `CHEZ_SODIUM_LIBRARY`, and
put its `include` folder first on `C_INCLUDE_PATH`, so that those programs
read its headers and not the system's:

```sh
export CHEZ_SODIUM_LIBRARY=/opt/libsodium/lib/libsodium.so.26
export C_INCLUDE_PATH=/opt/libsodium/include${C_INCLUDE_PATH:+:$C_INCLUDE_PATH}
make test
```

`make help` lists every target.

## Next

- [Passwords](passwords.md): hash and check passwords, and log users in
  safely.
- [Tokens](tokens.md): make API keys, store them, and compare secrets.
- [Finding libsodium](finding-libsodium.md): which library is loaded, and
  how to name another.
- [Reference](reference.md): every name `(chez-sodium)` exports.
