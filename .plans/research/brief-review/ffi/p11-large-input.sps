#!r6rs
;; Probe: the cost of call-with-bytes' byte-by-byte copy, and of a plain
;; crypto_generichash and randombytes_buf, on large inputs: how long another
;; thread's collection would wait on a plain call of each, or on the copy
;; held in a critical section.
;; Usage: scheme --script p11-large-input.sps /path/libsodium.so.23
(import (chezscheme))
(load-shared-object (cadr (command-line)))
(define init (foreign-procedure "sodium_init" () int))
(define gh (foreign-procedure "crypto_generichash" (uptr size_t uptr unsigned-64 uptr size_t) int))
(define rb (foreign-procedure "randombytes_buf" (uptr size_t) void))
(init)
(define (ms thunk)
  (let* ((t0 (current-time 'time-monotonic)) (_ (thunk)) (t1 (current-time 'time-monotonic))
         (d (time-difference t1 t0)))
    (+ (* 1000 (time-second d)) (quotient (time-nanosecond d) 1000000))))
(define (copy-in bv)
  (let* ((n (bytevector-length bv)) (b (foreign-alloc (max 1 n))))
    (let loop ((i 0)) (when (< i n) (foreign-set! 'unsigned-8 b i (bytevector-u8-ref bv i)) (loop (+ i 1))))
    b))
(for-each
 (lambda (mib)
   (let* ((n (* mib 1024 1024)) (bv (make-bytevector n 7)) (block #f) (out (foreign-alloc 64)))
     (printf "~a MiB: byte-loop copy ~s ms; " mib (ms (lambda () (set! block (copy-in bv)))))
     (printf "crypto_generichash ~s ms; " (ms (lambda () (gh out 32 block n 0 0))))
     (printf "randombytes_buf ~s ms\n" (ms (lambda () (rb block n))))
     (foreign-free block) (foreign-free out)))
 '(1 16 64))
