#!r6rs
;;; What the time of constant-time-bytevector=? shows: the median, in µs, of
;;; many calls, for operands that are equal, that differ only in their first
;;; byte, only in their last byte, and that differ in length.
(import (rnrs) (chez-sodium) (only (chezscheme) current-time time-second time-nanosecond))

(define (now-us)
  (let ((t (current-time 'time-monotonic)))
    (+ (* 1e6 (time-second t)) (/ (time-nanosecond t) 1e3))))

(define (median xs)
  (let* ((s (list-sort < xs)) (n (length s)))
    (list-ref s (div n 2))))

(define (time-of n thunk)
  (let loop ((i 0) (acc '()))
    (if (= i n)
        (median acc)
        (let* ((t0 (now-us)) (v (thunk)) (t1 (now-us)))
          (loop (+ i 1) (cons (- t1 t0) acc))))))

(define (round1 x) (/ (round (* 10 x)) 10))

(define (case-set size n)
  (let* ((a (make-bytevector size 7))
         (same (make-bytevector size 7))
         (first (let ((b (make-bytevector size 7))) (bytevector-u8-set! b 0 8) b))
         (last (let ((b (make-bytevector size 7))) (bytevector-u8-set! b (- size 1) 8) b))
         (shorter (make-bytevector (- size 1) 7)))
    (for-each
     (lambda (c)
       (let ((answer (constant-time-bytevector=? a (cdr c))))
         ;; warm up, then measure
         (time-of 20 (lambda () (constant-time-bytevector=? a (cdr c))))
         (write (list size (car c) 'answer answer 'median-us
                      (round1 (time-of n (lambda () (constant-time-bytevector=? a (cdr c)))))))
         (newline)))
     (list (cons 'equal same) (cons 'differ-first first) (cons 'differ-last last)
           (cons 'one-byte-shorter shorter)))))

(case-set 32 2001)
(case-set 65536 61)
