#!r6rs
;; Probe: two threads first reference a library at once. Does its body (the
;; load, in native.sls) run once, and does the second thread wait for it?
;; Usage: scheme --libdirs p10lib --script p13-concurrent-invoke.sps
(import (chezscheme))
(define m (make-mutex)) (define c (make-condition)) (define results '())
(define (worker)
  (fork-thread
   (lambda ()
     (let ((r (guard (e (#t (list 'raised (condition-message e))))
                (eval '(list value (runs)) (environment '(rnrs) '(only (probe slowbody) value runs))))))
       (with-mutex m (set! results (cons r results)) (condition-signal c))))))
(worker) (worker) (worker)
(with-mutex m (let loop () (when (< (length results) 3) (condition-wait c m) (loop))))
(for-each (lambda (r) (printf "~s\n" r)) results)
