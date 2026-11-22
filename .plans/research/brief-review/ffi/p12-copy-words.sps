#!r6rs
;; Probe: a word-wise copy (foreign-set! 'unsigned-64 of
;; bytevector-u64-native-ref) against the byte loop, for 16 MiB. Still no
;; Scheme object crosses to C.
;; Usage: scheme --program p12-copy-words.sps
(import (chezscheme))
(define (ms thunk)
  (let* ((t0 (current-time 'time-monotonic)) (_ (thunk)) (t1 (current-time 'time-monotonic))
         (d (time-difference t1 t0)))
    (+ (* 1000 (time-second d)) (quotient (time-nanosecond d) 1000000))))
(define n (* 16 1024 1024))
(define bv (make-bytevector n 7))
(define b (foreign-alloc n))
(printf "byte loop: ~s ms\n"
  (ms (lambda () (let loop ((i 0)) (when (< i n) (foreign-set! 'unsigned-8 b i (bytevector-u8-ref bv i)) (loop (+ i 1)))))))
(printf "word loop: ~s ms\n"
  (ms (lambda () (let loop ((i 0)) (when (< i n) (foreign-set! 'unsigned-64 b i (bytevector-u64-native-ref bv i)) (loop (+ i 8)))))))
(foreign-free b)
