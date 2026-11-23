#!r6rs
;; Usage: sweep.sps LIB WHEN, LIB engbody2|engsect, WHEN pre|post.
;; Steps an engine at fuel 1 that reaches LIB through eval; abandons it at
;; the first expiry where the pre-flag is set and the flag is not (pre), or
;; where the flag is set (post); then makes two plain references.
(import (chezscheme) (probe flag) (probe preflag))
(define lib (string->symbol (cadr (command-line))))
(define when-to (string->symbol (caddr (command-line))))
(define (reference)
  (eval '(list value (runs)) (environment '(rnrs) `(only (probe ,lib) value runs))))
(define (shown thunk)
  (guard (e (#t (list 'raised (if (message-condition? e) (condition-message e) e))))
    (thunk)))
(define (step engine) (engine 1 (lambda (left v) (list 'completed v)) (lambda (k) (list 'expired k))))
(let loop ((r (step (make-engine reference))) (n 1))
  (cond ((eq? (car r) 'completed) (printf "~a ~a: completed after ~s expiries, never stopped\n" lib when-to n))
        ((and (eq? when-to 'pre) (preflag-set?) (not (flag-set?)))
         (printf "~a pre: abandoned at expiry ~s, pre-flag set, flag not\n" lib n))
        ((and (eq? when-to 'post) (flag-set?))
         (printf "~a post: abandoned at expiry ~s, flag set\n" lib n))
        ((and (eq? when-to 'pre) (flag-set?))
         (printf "~a pre: no expiry fell between the pre-flag and the flag (expiry ~s)\n" lib n))
        (else (loop (step (cadr r)) (+ n 1)))))
(printf "  then: ~s\n" (shown reference))
