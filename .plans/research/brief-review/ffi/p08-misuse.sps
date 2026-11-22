#!r6rs
;; Probe: which bad arguments make libsodium 1.0.18 answer -1, and which
;; abort the process through sodium_misuse. One case per run, by name.
;; Usage: scheme --script p08-misuse.sps /path/libsodium.so.23 CASE
(import (chezscheme))
(define args (cdr (command-line)))
(load-shared-object (car args))
(define init (foreign-procedure "sodium_init" () int))
(define gh (foreign-procedure "crypto_generichash" (uptr size_t uptr unsigned-64 uptr size_t) int))
(define rb (foreign-procedure "randombytes_buf" (uptr size_t) void))
(define cmp (foreign-procedure "sodium_memcmp" (uptr uptr size_t) int))
(define pw (foreign-procedure __collect_safe "crypto_pwhash_str" (uptr uptr unsigned-64 unsigned-64 size_t) int))
(define nr (foreign-procedure "crypto_pwhash_str_needs_rehash" (uptr unsigned-64 size_t) int))
(init)
(define out (foreign-alloc 256))
(define in (foreign-alloc 16))
(do ((i 0 (+ i 1))) ((= i 16)) (foreign-set! 'unsigned-8 in i 0))
(define c (string->symbol (cadr args)))
(printf "~a: ~s\n" c
  (case c
    ((gh-null-in) (gh out 32 0 1 0 0))
    ((gh-null-key-len) (gh out 32 in 16 0 16))
    ((gh-outlen-0) (gh out 0 in 16 0 0))
    ((gh-outlen-65) (gh out 65 in 16 0 0))
    ((gh-keylen-65) (gh out 32 in 16 in 65))
    ((gh-null-in-zero) (gh out 32 0 0 0 0))
    ((pw-memlimit-huge) (pw out in 1 1 -1))
    ((pw-opslimit-0) (pw out in 1 0 8192))
    ((pw-null-passwd-0) (pw out 0 0 1 8192))
    ((nr-bad-memlimit) (begin (foreign-set! 'unsigned-8 out 0 0) (nr out 1 -1)))
    ((rb-null-0) (begin (rb 0 0) 'returned))
    (else 'unknown-case)))
