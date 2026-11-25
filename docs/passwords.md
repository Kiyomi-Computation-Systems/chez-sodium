# Passwords

How to store passwords and check logins. You never store a password: you
store its hash, and check each login against it.

## Hash and check

`password-hash` makes a hash string from a password. Store that string.
`password-verify` takes the stored hash and a password, in that order, and
answers `#t` only when the password is the one the hash was made from.

```scheme run
(define hash (password-hash "correct horse"))
(list (string? hash)
      (password-verify hash "correct horse")
      (password-verify hash "Correct horse"))
;; => (#t #t #f)
```

The hash string holds everything a check needs: the algorithm, argon2id;
a salt, fresh for every hash; and the limits it was made with. So the same
password hashes to a different string each time, and every one verifies.

## How slow, and how much memory

A password hash is slow on purpose, so that guessing passwords is slow too.
Its limits say how slow, and how much memory it takes. Pass a preset, or
your own limits; the default is `'interactive`.

| Limits | Memory | Time, here |
|---|---|---|
| `'interactive`, the default | 64 MiB | about 50 ms |
| `'moderate` | 256 MiB | about 0.3 s |
| `'sensitive` | 1 GiB | about 2 s |

```scheme
(password-hash "correct horse" 'moderate)
```

Each hash, and each verify of it, takes that memory and time while it runs.
The times were measured on one development machine; yours will differ.

## Your own limits

`make-password-limits` takes the number of passes and the memory, in KiB.
OWASP's minimum for argon2id is 2 passes over 19 MiB, which is 19456 KiB:

```scheme run
(define mine (make-password-limits 2 19456))
(define hash (password-hash "correct horse" mine))
(list (password-verify hash "correct horse")
      (password-needs-rehash? hash mine)
      (password-needs-rehash? hash))
;; => (#t #f #t)
```

- **Give your limits to `password-needs-rehash?` too,** as well as to
  `password-hash`. Without them it compares with `'interactive`, and every
  login rehashes.
- **Memory is in KiB,** as argon2's own strings and OWASP write it:
  19456 is 19 MiB, not 19 KB.

## Logging in

At each login: verify the password, and only after a `#t` ask whether its
hash needs redoing. If it does, hash the password again at today's limits,
and store the new hash. Here one account, its hash made at older limits,
stands in for your store:

```scheme run
(define my-limits 'interactive)
(define stored (password-hash "correct horse" (make-password-limits 2 19456)))
(define (stored-hash account) stored)
(define (store-hash! account hash) (set! stored hash))

(define (log-in! account password)
  (let ((hash (stored-hash account)))
    (cond ((password-verify hash password)
           (when (password-needs-rehash? hash my-limits)
             (guard (e ((sodium-failed? e) #f))
               (store-hash! account (password-hash password my-limits))))
           'logged-in)
          (else 'refused))))

(let* ((wrong (log-in! "ada" "wrong horse"))
       (right (log-in! "ada" "correct horse")))
  (list wrong right (password-needs-rehash? stored my-limits)))
;; => (refused logged-in #f)
```

The right password logs in, and its hash is redone at `my-limits`.

- **Verify first.** `password-needs-rehash?` answers `#t` for `"garbage"`
  and for `""`. A program that rehashes on that `#t` without verifying
  first stores a password nobody verified.
- **Wrap the rehash.** It can raise a condition that `sodium-failed?` holds,
  when libsodium can't get the memory. Then keep the old hash, and log the
  user in all the same: the password was right.
- **What needs-rehash checks.** `password-needs-rehash?` answers `#t` when
  the hash was not made with today's algorithm, parallelism and the limits
  you give it, or when libsodium can't read it. It is no check that the
  hash is intact: only `password-verify`, with the password, can tell.

## No such account

For a name with no account, still verify the password: against one real
hash, made at your current limits, and refuse whatever it answers. Any
string that is not a real hash, such as `""` or `"*"`, answers in
microseconds instead of about 50 ms, and that time would tell an attacker
which names have accounts. An account whose hash was made at older limits
answers in another time than that real hash does, until its next login
rehashes it.

## Before you verify

`password-verify` refuses some passwords instead of answering `#f`. It
raises an assertion violation for a password that is no string, such as
`#f` from a missing form field, as `not-a-string`; and for one over
64 KiB as UTF-8, as `over-the-cap`. It does so even against the real hash
an unknown name is checked against.

So check that the password is a string of at most 16384 characters first,
or catch `assertion-violation?`. A character takes at most 4 bytes as
UTF-8, so such a string always fits.

The stored hash is never refused for its length or its characters: any
string that is no hash, however long, answers `#f`.

Any string is a password, even `""`. Refuse ones too short for your rules
yourself.

## All together

This program signs up two users and logs them in. Ada's hash was made at
older limits, so her first login replaces it.

```scheme
(import (rnrs) (chez-sodium))

;; Each account's stored hash, by name.
(define accounts (make-hashtable string-hash string=?))

;; The limits new hashes use.
(define limits 'interactive)

;; One real hash, checked for a name that has no account.
(define no-account (password-hash "no one's password" limits))

(define (sign-up! name password)
  (hashtable-set! accounts name (password-hash password limits)))

(define (log-in! name password)
  (let ((hash (hashtable-ref accounts name no-account)))
    ;; A string, and short: any bound up to 16384 characters fits the cap.
    (cond ((not (and (string? password) (<= (string-length password) 1024)))
           'refused)
          ((not (password-verify hash password)) 'refused)
          ((eq? hash no-account) 'refused)
          (else
           (when (password-needs-rehash? hash limits)
             (guard (e ((sodium-failed? e) #f))   ; keep the old hash
               (hashtable-set! accounts name (password-hash password limits))))
           'logged-in))))

(define (show x) (write x) (newline))

(hashtable-set! accounts "ada"
                (password-hash "correct horse" (make-password-limits 2 19456)))
(sign-up! "bea" "battery staple")

(show (log-in! "ada" "correct horse"))
(show (password-verify (hashtable-ref accounts "ada" #f) "correct horse"))
(show (password-needs-rehash? (hashtable-ref accounts "ada" #f) limits))
(show (log-in! "ada" "wrong horse"))
(show (log-in! "bea" "battery staple"))
(show (log-in! "cal" "correct horse"))
(show (log-in! "ada" #f))
```

It prints:

```text
logged-in
#t
#f
refused
logged-in
refused
refused
```

Ada logs in, and her new hash verifies and is current. A wrong password, a
name with no account and a missing password are each refused.

## Store the hash exactly

Store the hash string exactly as `password-hash` gave it: ASCII, with no
spaces. Any change, even one trailing space or newline, makes it verify `#f`
for ever. `password-needs-rehash?` may not notice, since it reads a hash's
limits, not whether the hash is whole.

So keep it in a text column of no fixed width, never a `CHAR(n)`, which
pads it with spaces. Its length grows with its limits.

## What `#f` means

`password-verify` answers `#f` for a wrong password, for a hash libsodium
can't read, and when libsodium could not get the memory to check. Nothing
tells the three apart.

To guess at memory: after a `#f`, hash a throwaway string at your current
limits. If that raises a condition `sodium-failed?` holds, memory is short.

```scheme run
(define my-limits 'interactive)
(define stored (password-hash "correct horse" my-limits))

(define (check hash password)
  (cond ((password-verify hash password) 'right)
        ((guard (e ((sodium-failed? e) #t))
           (password-hash "throwaway" my-limits)
           #f)
         'out-of-memory)
        (else 'wrong)))

(list (check stored "correct horse") (check stored "wrong horse"))
;; => (right wrong)
```

- It doubles what a wrong password costs: a verify, then a hash. Guess
  only where you use the answer, such as in a log line.
- Under short memory, a wrong password reads as short memory too.
- It sees only a failure libsodium is told of, as under `ulimit -v`. A
  container's memory limit kills the process instead.
- It fits only hashes made at your current limits.

## Memory

Each hash and each verify takes its limits' memory while it runs.

- **Under `ulimit -v`,** libsodium is told it can't have the memory:
  `password-hash` raises a condition `sodium-failed?` holds, and
  `password-verify` answers `#f`.
- **Under a container's memory limit,** the kernel kills the process, and
  nothing is raised. Size a container for every hash that can run at once:
  64 MiB each at `'interactive`, 256 MiB at `'moderate` and 1 GiB at
  `'sensitive`, plus the program's own memory.

## Where hashes live

A hash's own limits set what verifying it costs, whatever limits you hash
new passwords at. An `'interactive` hash edited to ask for 1 GiB and 4
passes took about 1.8 s here to answer `#f`. So keep hashes where only you
can write them.

## Threads and Ctrl-C

While a hash or a verify runs, its thread takes no interrupts. Ctrl-C,
timers and an engine's running out of time, on that thread, wait until it
ends: about 50 ms at `'interactive`, and about 2 s at `'sensitive`, here.
Other threads run on, so hash on a worker thread to keep a program
responsive.

Never change a string while a verb reads it. Another thread's change is
seen only when it alters the password's length as UTF-8, or puts a space,
control or non-ASCII character in a hash. Then `password-hash` and
`password-verify` refuse the call, as `changed-during-call`. Any other
change goes unseen: the verb hashes or checks the string as it stood
mid-change, which may be neither the old string nor the new.

A program that first reaches chez-sodium through `eval` or the REPL should
do it on one thread, before engines or other threads can:
[It loads once](finding-libsodium.md#it-loads-once) says why.

## Text

A password is hashed as its exact UTF-8 bytes. chez-sodium never
normalises it. So `"café"` written with `é`, U+00E9, and written with `e`
and a combining accent, U+0301, are two passwords, and each verifies only
against its own hash:

```scheme run
(define composed (string #\c #\a #\f #\xE9))
(define decomposed (string #\c #\a #\f #\e #\x301))
(define hash (password-hash composed))
(list (password-verify hash composed)
      (password-verify hash decomposed))
;; => (#t #f)
```

If your users' keyboards may differ, normalise passwords yourself, the same
way every time, before you hash or verify.

## What is wiped

chez-sodium wipes the C memory it copies a password into, before it frees
it. It can't wipe your own string, the request it came in or a parser's
copies, the strings and bytevectors a verb returns, or copies the collector
leaves behind. `string-fill!` clears your own string, not the others.
