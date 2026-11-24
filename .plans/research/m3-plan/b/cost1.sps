#!r6rs
;; Item 1: ms per call of crypto_pwhash_str and crypto_pwhash_str_verify, plain and __collect_safe.
;; Usage: scheme --program cost1.sps LIBRARY OPS MEMORY REPS
;; Prints: label ms-per-call
(import (chezscheme))
(define args (cdr (command-line)))
(load-shared-object (car args))
(define ops (string->number (cadr args)))
(define mem (string->number (caddr args)))
(define reps (string->number (cadddr args)))
((foreign-procedure "sodium_init" () int))
(define h-plain (foreign-procedure "crypto_pwhash_str" (uptr uptr unsigned-64 unsigned-64 size_t) int))
(define h-cs (foreign-procedure __collect_safe "crypto_pwhash_str" (uptr uptr unsigned-64 unsigned-64 size_t) int))
(define v-plain (foreign-procedure "crypto_pwhash_str_verify" (uptr uptr unsigned-64) int))
(define v-cs (foreign-procedure __collect_safe "crypto_pwhash_str_verify" (uptr uptr unsigned-64) int))
(define (now-ns) (let ((t (current-time 'time-monotonic))) (+ (* 1000000000 (time-second t)) (time-nanosecond t))))
(define pw (foreign-alloc 8))
(define out (foreign-alloc 128))
(do ((i 0 (+ i 1))) ((= i 8)) (foreign-set! 'unsigned-8 pw i (+ 97 i)))
(define (measure label thunk)
  (let ((t0 (now-ns)))
    (do ((i 0 (+ i 1))) ((= i reps)) (let ((rc (thunk))) (if (not (eqv? rc 0)) (error 'cost label rc))))
    (printf "~a ~a\n" label (/ (round (* 1000 (/ (- (now-ns) t0) reps 1e6))) 1000.0))))
(h-plain out pw 8 ops mem) ; warm-up and a hash to verify
(measure "hash-plain" (lambda () (h-plain out pw 8 ops mem)))
(measure "hash-cs" (lambda () (h-cs out pw 8 ops mem)))
(measure "verify-plain" (lambda () (v-plain out pw 8)))
(measure "verify-cs" (lambda () (v-cs out pw 8)))
(foreign-free pw) (foreign-free out)
