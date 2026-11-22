#!r6rs
;; Probe: what a wipe after the free does, the "outer" design of p06: zero a
;; block's bytes once foreign-free has returned it to malloc, then allocate
;; that size again, as the next verb would. sodium_memzero is used, bound as
;; the binding would bind it.
;; Usage: scheme --script p18-wipe-after-free.sps /path/libsodium.so.23
(import (chezscheme))
(load-shared-object (cadr (command-line)))
(define memzero (foreign-procedure "sodium_memzero" (uptr size_t) void))
(define size 24)
(define a (foreign-alloc size))
(define b (foreign-alloc size))
(foreign-free a)
(foreign-free b)
(memzero b size)          ; the wipe, after the free
(printf "wiped a freed block; allocating ~s bytes three times\n" size)
(define c (foreign-alloc size))
(define d (foreign-alloc size))
(define e (foreign-alloc size))
(printf "allocated: ~s ~s ~s (b was ~s)\n" c d e b)
