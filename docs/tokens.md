# Tokens

How to make API keys and other tokens, store them safely, and check them.

## Make a key

`random-bytes` gives fresh bytes from the system's random source. 32 of
them make a key nobody can guess:

```scheme run
(bytevector-length (random-bytes 32))
;; => 32
```

The bytevector it gives is yours. chez-sodium wipes only its own C memory,
so clear your copy with `bytevector-fill!` when you are done with it, as
[What is wiped](passwords.md#what-is-wiped) says for passwords.

## Store only its hash

Store a key's BLAKE2b hash, never the key itself, and show the key to its
owner once. When a request brings a key, hash it, and look the hash up. If
your database leaks, its hashes let no one in.

A fast hash is right here, unlike for a password. A key of 32 random bytes
is far too long to guess, so a slow hash would buy nothing, and would tax
every request.

```scheme
(import (rnrs) (chez-sodium))

;; The bytes as lower-case hex, two characters each.
(define (hex bytes)
  (let ((digits "0123456789abcdef"))
    (apply string-append
           (map (lambda (b)
                  (string (string-ref digits (div b 16))
                          (string-ref digits (mod b 16))))
                (bytevector->u8-list bytes)))))

;; What the server stores for a key: its BLAKE2b hash, in hex.
(define (key-hash key)
  (hex (blake2b (string->utf8 key))))

;; Each key's owner, by the key's hash. The keys themselves are not kept.
(define owners (make-hashtable string-hash string=?))

;; A new key for OWNER: 32 random bytes, as 64 hex characters.
(define (issue-key! owner)
  (let ((key (hex (random-bytes 32))))
    (hashtable-set! owners (key-hash key) owner)
    key))

;; The owner of KEY, or #f.
(define (key-owner key)
  (and (string? key)
       (= (string-length key) 64)
       (hashtable-ref owners (key-hash key) #f)))

(define key (issue-key! "ada"))

(write (list (string-length key)
             (key-owner key)
             (key-owner (hex (random-bytes 32)))
             (key-owner "not a key")))
(newline)
```

It prints:

```text
(64 "ada" #f #f)
```

- **A key travels as text,** here as 64 hex characters, and the server
  hashes that text. `hex` is plain Scheme: chez-sodium has no hex or base64
  helpers.
- **`key-owner` checks a key's length before hashing it.** So a request
  can't make `blake2b` refuse it, as it refuses an input over 64 KiB.
- **This lookup needs no constant-time compare.** Timing could at most show
  part of a stored hash, and a hash lets no one in: they would still need
  the key.

## Compare a secret in constant time

When you must compare a secret itself, such as a raw token or a message's
tag, use `constant-time-bytevector=?`. `bytevector=?` and `equal?` are
plain equality: they may stop at the first byte that differs, and then
their time shows how much matched.

A keyed BLAKE2b hash makes a tag, which proves a message came from someone
who holds the key:

```scheme run
(define key (random-bytes 32))
(define (tag message) (blake2b message 32 key))
(define sent (string->utf8 "pay ada 10"))
(define received (tag sent))
(list (constant-time-bytevector=? (tag sent) received)
      (constant-time-bytevector=? (tag (string->utf8 "pay ada 99")) received))
;; => (#t #f)
```

Two bytevectors of the same length take the same time wherever they
differ. Bytevectors of different lengths answer `#f` at once, so the time
shows whether the lengths match: compare values of a fixed length, such as
hashes and tags.

## Sizes and keys

- **`(blake2b input)`** is 32 bytes. `(blake2b input size)` is `size`
  bytes, from 16 to 64.
- **`(blake2b input size key)`** is keyed, by a key of 16 to 64 bytes. The
  size comes first, so a key needs one. An empty key is refused: leave the
  key out instead.
- **Every input is at most 64 KiB:** `blake2b`'s input, both bytevectors of
  the compare, and what `random-bytes` makes. Anything larger is refused.

```scheme run
(list (bytevector-length (blake2b (string->utf8 "abc")))
      (bytevector-length (blake2b (string->utf8 "abc") 64)))
;; => (32 64)
```

`blake2b` raises a condition `sodium-failed?` holds only if libsodium
fails a call that passed these checks, which no release does. The
[reference](reference.md#blake2b) lists each refusal.

## Threads

Never change a bytevector while a verb reads it. If another thread does,
`blake2b` and `constant-time-bytevector=?` answer for whatever bytes they
read, which may be neither the old bytes nor the new.

## When the system has no randomness

libsodium reads randomness from the kernel, through `getrandom` or
`/dev/urandom`. With neither, as in a sandbox that blocks both, the process
aborts when chez-sodium loads libsodium, before any verb runs.
`random-bytes` aborts only if the source fails after that. Nothing can
catch either.
