#!r6rs
;; A library whose body takes a while and records each run of it.
(library (probe slowbody) (export runs value)
  (import (chezscheme))
  (define counter 0)
  (define value
    (begin
      (set! counter (+ counter 1))
      (let loop ((i 0)) (when (< i 30000000) (loop (+ i 1))))
      (list 'body-ran counter (get-thread-id))))
  (define (runs) counter))
