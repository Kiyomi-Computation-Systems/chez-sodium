#!r6rs
;; Probe: the per-call cost of __collect_safe against a plain binding, on a
;; call that does almost nothing (sodium_memcmp of 16 bytes), and the time a
;; plain randombytes_buf of 64 MiB holds another thread's collect-rendezvous.
;; Usage: scheme --program p16-collect-safe-cost.sps /path/libsodium.so.23
(import (chezscheme))
(load-shared-object (cadr (command-line)))
((foreign-procedure "sodium_init" () int))
(define cmp-plain (foreign-procedure "sodium_memcmp" (uptr uptr size_t) int))
(define cmp-safe (foreign-procedure __collect_safe "sodium_memcmp" (uptr uptr size_t) int))
(define rb-plain (foreign-procedure "randombytes_buf" (uptr size_t) void))
(define (us thunk)
  (let* ((t0 (current-time 'time-monotonic)) (_ (thunk)) (t1 (current-time 'time-monotonic))
         (d (time-difference t1 t0)))
    (+ (* 1000000 (time-second d)) (quotient (time-nanosecond d) 1000))))
(define a (foreign-alloc 16)) (define b (foreign-alloc 16))
(define n 1000000)
(printf "plain: ~s ns per call\n" (quotient (* 1000 (us (lambda () (do ((i 0 (+ i 1))) ((= i n)) (cmp-plain a b 16))))) n))
(printf "collect-safe: ~s ns per call\n" (quotient (* 1000 (us (lambda () (do ((i 0 (+ i 1))) ((= i n)) (cmp-safe a b 16))))) n))
(define big (* 64 1024 1024))
(define buf (foreign-alloc big))
(let* ((m (make-mutex)) (c (make-condition)) (calling #f) (done #f))
  (fork-thread (lambda ()
                 (with-mutex m (set! calling #t) (condition-signal c))
                 (rb-plain buf big)
                 (with-mutex m (set! done #t) (condition-signal c))))
  (with-mutex m (let loop () (unless calling (condition-wait c m) (loop))))
  (printf "collect-rendezvous during a plain 64 MiB randombytes_buf: ~s us\n" (us collect-rendezvous))
  (with-mutex m (let loop () (unless done (condition-wait c m) (loop)))))
