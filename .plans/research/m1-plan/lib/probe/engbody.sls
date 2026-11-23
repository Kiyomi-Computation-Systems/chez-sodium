#!r6rs
;; A library whose body takes many engine ticks, and counts its runs.
(library (probe engbody) (export runs value)
  (import (chezscheme))
  (define counter 0)
  (define value
    (begin
      (set! counter (+ counter 1))
      (let loop ((i 0)) (when (< i 200000) (loop (+ i 1))))
      (list 'body-ran counter)))
  (define (runs) counter))
