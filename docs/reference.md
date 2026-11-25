# Reference

Every name `(chez-sodium)` exports, one entry each. Import it with
`(import (chez-sodium))`. To use it, see the [quick start](quickstart.md);
for the setup, see the [README](../README.org).

Types are written as Typed Racket writes them. `A -> B` is a procedure
that takes an `A` and gives a `B`, `(U a b)` is either one, and
`(Listof a)` is a list. A name in brackets, such as `[Natural]`, is an
optional argument: leave it off and the default is used. Optional
arguments are positional, so to give a later one you give the ones before it.
These names stand for:

```text
Natural                   an exact integer, 0 or more
Limits                    'interactive, 'moderate, 'sensitive or a Password-limits
Password-limits           what make-password-limits gives
Reason                    one of 'invalid-override 'not-found 'load-failed
                          'below-floor 'missing-api 'init-failed
SodiumFailed              a condition that sodium-failed? holds
SodiumLibraryUnavailable  a condition that sodium-library-unavailable? holds
```

## What every call shares

- **Mistakes are refused.** A wrong kind or size of argument raises an
  assertion violation, checked left to right before anything else runs.
  `condition-irritants` gives its details, `(REASON PARAMETER VALUE)`: the
  rule broken, the parameter's name, and the value. A secret parameter, a
  password, a hash, an input, a key or an operand, shows only its kind,
  such as `(kind boolean)`, whatever was passed. Any other value shows as
  itself when it is a number, symbol, boolean or character, and by its kind
  otherwise. An accessor's refusal names no parameter: `(REASON (kind K))`.
  Each entry lists its reasons. A mistake is never a `chez-sodium-error?`.
- **Every input is at most 64 KiB.** A password counts its UTF-8 bytes. A
  hash string counts characters. `random-bytes` is capped the same way.
- **Wiping.** chez-sodium wipes the C memory it uses, and nothing else:
  [What is wiped](passwords.md#what-is-wiped) says what that leaves.
- **Threads.** Never change an argument while a verb reads it. `blake2b` and
  `constant-time-bytevector=?` answer for whatever bytes they read, which
  may be neither the old bytes nor the new. The password verbs refuse only
  some changes, as their entries say.

## How the library loads

- It loads once, at the first reference to a name that reaches libsodium:
  `sodium-version`, the byte verbs, the password verbs and
  `make-password-limits`. The predicates and accessors load nothing.
- If it cannot load, that reference raises `&sodium-library-unavailable`. Each
  later reference raises it again. See [finding libsodium](finding-libsodium.md)
  for where it looks and how to point it at a file.
- A first reference on two threads at once raises Chez's own "cyclic
  dependency" condition, not ours; a later reference answers. A first
  reference inside an engine that is then dropped leaves it stuck for the
  rest of the process. [It loads once](finding-libsodium.md#it-loads-once)
  says how to avoid both.
- A program that names a procedure which reaches libsodium loads it before
  its first line. So a `guard` in a program cannot catch a failure of the
  load. Use `eval` inside the guard:

```scheme
(guard (e ((sodium-library-unavailable? e)
           (sodium-library-unavailable-reason e)))
  (eval '(sodium-version) (environment '(chez-sodium))))
```

- If another library already started libsodium, the load takes that.
- With no source of randomness at all, the process aborts while the library
  loads. Nothing can catch it.

## The library

### `sodium-version`

```text
sodium-version : -> String
```

Gives the loaded libsodium's version, as text. A fresh string each call.
Refuses nothing. It raises the load's failure if libsodium could not load.

## The byte verbs

### `random-bytes`

```text
random-bytes : Natural -> Bytevector
```

Gives a fresh bytevector of N unpredictable bytes. `(random-bytes 0)` is an
empty bytevector. The bytevector is yours to wipe.

```scheme run
(bytevector-length (random-bytes 16))
;; => 16
```

Refuses:

- `not-a-natural`: N is not an exact natural, a string such as `"32"` included.
- `over-the-cap`: N is more than 65536.

It never raises `&sodium-failed`. If the system's random source fails,
libsodium aborts the process.

### `blake2b`

```text
blake2b : Bytevector [Natural] [Bytevector] -> Bytevector
```

Hashes the input with BLAKE2b, an unkeyed or keyed fingerprint. The arguments
are the input, the size and the key.

- The size is how many bytes you get, 16 to 64. It defaults to 32.
- The key is 16 to 64 bytes. With none, the hash is unkeyed. To give a key you
  must give a size first.
- The same input, size and key always give the same bytes.

```scheme run
(bytevector-length (blake2b (u8-list->bytevector '(97 98 99)) 64))
;; => 64
```

Refuses, in this order, the first mistake only:

- `not-a-bytevector`: the input is not a bytevector.
- `over-the-cap`: the input is more than 65536 bytes.
- `not-a-natural`: the size is not an exact natural. `#f` is refused too.
- `size-out-of-range`: the size is not 16 to 64.
- `not-a-bytevector`: the key is not a bytevector. `#f` is refused too.
- `empty-key`: the key is empty.
- `key-length-out-of-range`: the key is not 16 to 64 bytes.

It raises `&sodium-failed` only if libsodium fails a call whose arguments
passed these checks. No release does.

### `constant-time-bytevector=?`

```text
constant-time-bytevector=? : Bytevector Bytevector -> Boolean
```

Answers `#t` when both bytevectors hold the same bytes, and two empty ones do.
Equal-length operands take the same time wherever they differ. Operands of
different lengths answer `#f` at once, so the time shows whether the lengths
match. [Tokens](tokens.md#compare-a-secret-in-constant-time) says when to use
it.

```scheme run
(constant-time-bytevector=? (u8-list->bytevector '(1 2 3))
                            (u8-list->bytevector '(1 2 4)))
;; => #f
```

Refuses, the first operand's type, then its size, then the second's:

- `not-a-bytevector`: an operand is not a bytevector.
- `over-the-cap`: an operand is more than 65536 bytes.

Both operands are checked before their lengths are compared. It never raises
`&sodium-failed`.

## The password verbs

A hash is a string, and any change to it makes it verify `#f`. A password is
hashed as its UTF-8 bytes, exactly as given, never normalised.
[Passwords](passwords.md) says how to use these verbs: logging in, what to
check before a verify, memory, and threads.

### `password-hash`

```text
password-hash : String [Limits] -> String
```

Gives a fresh hash string of the password at the limits. The limits default to
`'interactive`. The salt is fresh each call, so two hashes of one password
differ. Each preset costs more than the one before it, in time and memory.
The calling thread takes no interrupts while a hash runs.

Refuses, in this order, the first mistake only:

- `not-a-string`: the password is not a string. A bytevector is refused too.
- `over-the-cap`: its UTF-8 is more than 65536 bytes.
- `length-out-of-range`: its UTF-8 is outside libsodium's own range. No
  release's range excludes anything the cap allows.
- `not-password-limits`: the limits are no preset and no Password-limits.
- `changed-during-call`: another thread changed the password's length as
  UTF-8 while it ran. Any other change is not seen, and the hash is of the
  string as it stood mid-change.

It raises `&sodium-failed` when libsodium cannot do the hash, as when it cannot
get the memory. The function is `"crypto_pwhash_str"`, and the code is what
libsodium answered. Under a container's memory limit the process is killed
instead: see [Memory](passwords.md#memory).

### `password-verify`

```text
password-verify : String String -> Boolean
```

Answers `#t` when the password is the one the hash was made from. The hash
comes first, then the password. Anything else is `#f`:

- a wrong password;
- a hash libsodium cannot read, such as `"garbage"` or one over the cap;
- memory libsodium could not get.

Nothing tells the three apart: see [What `#f` means](passwords.md#what-f-means).

A hash is read only when it has 1 to 65536 characters, each from `!` to `~`,
U+0021 to U+007E: no space, tab, newline, DEL, other control character or
non-ASCII character. Any other hash answers `#f` without running libsodium. A
hash's own limits set what verifying it costs.

Every refusal comes before that check, so a bad password is refused even
against a bad hash. It refuses, the hash first, then the password:

- `not-a-string`: the hash is not a string.
- `not-a-string`: the password is not a string. `#f` from a missing form
  field is refused.
- `over-the-cap`: the password's UTF-8 is more than 65536 bytes.
- `length-out-of-range`: as for `password-hash`.
- `changed-during-call`: another thread put a character outside `!` to `~` in
  the hash, or changed the password's length as UTF-8, while it ran. Any
  other change is not seen, and the answer is for the strings as they stood
  mid-change.

It never raises `&sodium-failed`.
[Before you verify](passwords.md#before-you-verify) says what to check first.

### `password-needs-rehash?`

```text
password-needs-rehash? : String [Limits] -> Boolean
```

Answers `#f` only when the hash was made with the algorithm and parallelism
`password-hash` uses, at the limits, which default to `'interactive`, and
libsodium can read it. Everything else is `#t`: a hash made at other limits,
a hash libsodium cannot read, `"garbage"` and `""`. It never raises because
of the hash.

It never checks the salt's or the tag's size, or whether the hash is whole.
So it may answer `#f` for a hash that was damaged but still reads, or for one
of a shape `password-hash` never makes: it is no check that a hash is intact.
Call it only after `password-verify` answers `#t`: see
[Logging in](passwords.md#logging-in).

Refuses, the hash first, then the limits, before it looks at the hash:

- `not-a-string`: the hash is not a string.
- `not-password-limits`: the limits are no preset and no Password-limits.

It never raises `&sodium-failed`.

### `make-password-limits`

```text
make-password-limits : Natural Natural -> Password-limits
```

Makes custom limits: the number of passes, and the memory in KiB. A
Password-limits is opaque. Two made from the same numbers are not `equal?`,
but every verb treats them alike. It runs no libsodium call, but it reads the
library's bounds, so naming it runs the load.

```scheme run
(let ((h (password-hash "pw" (make-password-limits 1 8))))
  (list (password-verify h "pw") (password-verify h "no")))
;; => (#t #f)
```

Refuses:

- `not-a-natural`: the passes are not an exact natural.
- `ops-out-of-range`: the passes are not 1 to 4294967295.
- `not-a-natural`: the memory is not an exact natural. `64.0` is refused.
- `memory-out-of-range`: the memory is not 8 to 4294967295.

The smallest limits are fast and weak. Use them to test, never to store a
password.

## The conditions

A condition is what a failure raises. This is the tree:

```text
&error
 +- &chez-sodium-error
     +- &sodium-library-unavailable   reason path source detail candidates
     +- &sodium-failed                function code
```

You ask a condition with its predicate and read it with its accessors. The
library exports no condition's `&` name and no constructor. The two kinds are:

- **When libsodium cannot load.** Raised by the load, as described above. It
  names the remedy in its message.
- **When libsodium fails.** Raised by `password-hash` and `blake2b`.

A mistake of yours is neither: it is an assertion violation, listed in each
entry. Each accessor refuses anything that is not its condition, with the
reason `not-a-sodium-failed` or `not-a-sodium-library-unavailable`. An
uncaught condition prints one line and the program exits 255. A long
`not-found` list is cut to `...` there, so read it with
`sodium-library-unavailable-candidates`.

### `chez-sodium-error?`

```text
chez-sodium-error? : Any -> Boolean
```

Answers `#t` for either kind of condition above, and `#f` for anything else,
a refused mistake included. It loads nothing.

### `sodium-library-unavailable?`

```text
sodium-library-unavailable? : Any -> Boolean
```

Answers `#t` for a condition the load raised. It loads nothing, so a program
that names only predicates survives a failed load.

### `sodium-library-unavailable-reason`

```text
sodium-library-unavailable-reason : SodiumLibraryUnavailable -> Reason
```

Gives why the load failed, one of six symbols:

| Reason | Meaning |
|---|---|
| `invalid-override` | `CHEZ_SODIUM_LIBRARY` is set, but not to an absolute path |
| `not-found` | no candidate exists |
| `load-failed` | the loader refused the chosen file |
| `below-floor` | the library is too old, or its version cannot be read |
| `missing-api` | a function chez-sodium needs is absent |
| `init-failed` | libsodium's start-up answered with a failure |

### `sodium-library-unavailable-path`

```text
sodium-library-unavailable-path : SodiumLibraryUnavailable -> (U String #f)
```

Gives the file the load refused, or `#f` when none was chosen.

### `sodium-library-unavailable-source`

```text
sodium-library-unavailable-source : SodiumLibraryUnavailable -> (U Symbol #f)
```

Gives where that path came from, such as `override`, or `#f` for `not-found`.
[Finding libsodium](finding-libsodium.md) lists them.

### `sodium-library-unavailable-detail`

```text
sodium-library-unavailable-detail : SodiumLibraryUnavailable -> Any
```

Gives more, by reason:

- `invalid-override`: the value that was set;
- `load-failed`: the loader's message;
- `below-floor`: the version text, or `#f` when libsodium gave none;
- `missing-api`: the missing function's C name;
- `init-failed`: the integer libsodium answered;
- `not-found`: `#f`.

### `sodium-library-unavailable-candidates`

```text
sodium-library-unavailable-candidates : SodiumLibraryUnavailable -> (Listof String)
```

Gives every path the load checked, in order. It is not empty for `not-found`.

### `sodium-failed?`

```text
sodium-failed? : Any -> Boolean
```

Answers `#t` for a condition a verb raised when libsodium failed a call. It is
an error, but not an assertion violation. It loads nothing.

### `sodium-failed-function`

```text
sodium-failed-function : SodiumFailed -> String
```

Gives the name of the C function that failed, such as `"crypto_pwhash_str"`.
`condition-who` gives the verb that raised it.

### `sodium-failed-code`

```text
sodium-failed-code : SodiumFailed -> Integer
```

Gives the integer that function answered. Real libsodium answers -1 when it
cannot get the memory.
