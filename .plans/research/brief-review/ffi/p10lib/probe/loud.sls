#!r6rs
;; A library whose body prints when it runs, with its thread.
(library (probe loud) (export lvalue)
  (import (chezscheme))
  (define lvalue (begin (printf "loud body runs on thread ~s\n" (get-thread-id))
                        (let loop ((i 0)) (when (< i 30000000) (loop (+ i 1))))
                        'loaded)))
