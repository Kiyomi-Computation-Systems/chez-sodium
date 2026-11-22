#!r6rs
;; Probe: when does Chez invoke an imported library's body in a top-level
;; program, at the start, or at the first run-time reference, and on which
;; thread when two worker threads make the first reference at once?
;; Usage: scheme --libdirs p10lib --program p14-invoke-when.sps
(import (chezscheme) (probe loud))
(printf "program body starts on thread ~s\n" (get-thread-id))
(define m (make-mutex)) (define c (make-condition)) (define n 0)
(define (worker)
  (fork-thread (lambda () (let ((v lvalue)) (with-mutex m (set! n (+ n 1)) (printf "thread ~s read ~s\n" (get-thread-id) v) (condition-signal c))))))
(worker) (worker)
(with-mutex m (let loop () (when (< n 2) (condition-wait c m) (loop))))
