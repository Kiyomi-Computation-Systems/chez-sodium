#!r6rs
;; A library body first referenced, through eval, inside an engine; the
;; engine abandoned once the body has started (read from (probe flag)) and
;; never resumed. The program does not import the library, so nothing runs
;; its body before the engine. What does a later plain reference do?
;; Usage: scheme --libdirs lib --program engine-invoke3.sps
(import (chezscheme) (probe flag))
(define (reference)
  (eval '(list value (runs)) (environment '(rnrs) '(only (probe engbody2) value runs))))
(define (shown thunk)
  (guard (e (#t (if (condition? e)
                    (list 'raised (if (message-condition? e) (condition-message e) 'no-message)
                          (if (irritants-condition? e) (condition-irritants e) '()))
                    (list 'raised e))))
    (thunk)))
(define (step engine)
  (engine 50 (lambda (left v) (list 'completed v)) (lambda (k) (list 'expired k))))
(printf "flag before the engine: ~s\n" (flag-set?))
(let loop ((r (step (make-engine reference))) (n 1))
  (cond ((eq? (car r) 'completed)
         (printf "completed before the flag was seen, after ~s steps: ~s\n" n (cadr r)))
        ((flag-set?)
         (printf "body started; engine abandoned after ~s expiries\n" n))
        (else (loop (step (cadr r)) (+ n 1)))))
(printf "then a plain reference: ~s\n" (shown reference))
(printf "and another: ~s\n" (shown reference))
