#!r6rs
;; A library body first referenced inside an engine, the engine abandoned
;; once the body has started (read from (probe flag)), never resumed.
;; What does a later plain reference do, in a program that imports the
;; library (reference by name) and through eval?
;; Usage: scheme --libdirs lib --program engine-invoke2.sps import|eval
(import (chezscheme) (probe flag) (probe engbody2))
(define mode (string->symbol (cadr (command-line))))
(define (reference)
  (if (eq? mode 'import)
      (list value (runs))
      (eval '(list value (runs)) (environment '(rnrs) '(only (probe engbody2) value runs)))))
(define (shown thunk)
  (guard (e (#t (if (condition? e)
                    (list 'raised (if (message-condition? e) (condition-message e) 'no-message)
                          (if (irritants-condition? e) (condition-irritants e) '()))
                    (list 'raised e))))
    (thunk)))
(define (step engine)
  (engine 50 (lambda (left v) (list 'completed v)) (lambda (k) (list 'expired k))))
(let loop ((r (step (make-engine reference))) (n 1))
  (cond ((eq? (car r) 'completed)
         (printf "completed before the flag was seen, after ~s steps: ~s\n" n (cadr r)))
        ((flag-set?)
         (printf "body started; engine abandoned after ~s expiries\n" n))
        (else (loop (step (cadr r)) (+ n 1)))))
(printf "then a plain reference: ~s\n" (shown reference))
(printf "and another: ~s\n" (shown reference))
