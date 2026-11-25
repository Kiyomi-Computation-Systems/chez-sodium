#!r6rs
;;; The time, in ms, of one hash and one verify at OWASP's least argon2id
;;; limits, (make-password-limits 2 19456): the median of 9.
(import (rnrs) (chez-sodium) (only (chezscheme) current-time time-second time-nanosecond))
(define (now-ms)
  (let ((t (current-time 'time-monotonic)))
    (+ (* 1000.0 (time-second t)) (/ (time-nanosecond t) 1e6))))
(define (median xs) (list-ref (list-sort < xs) (div (length xs) 2)))
(define (times n thunk)
  (let loop ((i 0) (acc '()))
    (if (= i n) acc
        (let* ((a (now-ms)) (v (thunk)) (b (now-ms))) (loop (+ i 1) (cons (- b a) acc))))))
(define l (make-password-limits 2 19456))
(define h (password-hash "correct horse" l))
(write (list 'hash-ms (median (times 9 (lambda () (password-hash "correct horse" l))))
             'verify-ms (median (times 9 (lambda () (password-verify h "correct horse"))))))
(newline)
