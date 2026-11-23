#!r6rs
;; A library body, first referenced inside an engine that expires: is the
;; library wedged when the engine is abandoned, and does it complete when
;; the engine is resumed? The load is native's body, so this is the load
;; reached for the first time under an engine.
;; Usage: scheme --libdirs lib --program engine-invoke.sps abandon|resume
(import (chezscheme))
(define mode (string->symbol (cadr (command-line))))
(define (reference)
  (eval '(list value (runs)) (environment '(rnrs) '(only (probe engbody) value runs))))
(define (shown thunk)
  (guard (e (#t (if (condition? e)
                    (list 'raised (if (message-condition? e) (condition-message e) 'no-message)
                          (if (irritants-condition? e) (condition-irritants e) '()))
                    (list 'raised e))))
    (thunk)))
(define first
  ((make-engine reference) 50
   (lambda (left v) (list 'completed v))
   (lambda (k) (list 'expired k))))
(printf "first reference, in an engine of 50 ticks: ~s\n" (car first))
(case mode
  ((abandon)
   (printf "engine abandoned; then a plain reference: ~s\n" (shown reference))
   (printf "and another: ~s\n" (shown reference)))
  ((resume)
   (let loop ((r first) (n 1))
     (if (eq? (car r) 'expired)
         (loop ((cadr r) 50 (lambda (left v) (list 'completed v)) (lambda (k) (list 'expired k))) (+ n 1))
         (printf "resumed to completion after ~s expiries: ~s\n" n (cadr r))))
   (printf "then a plain reference: ~s\n" (shown reference))))
