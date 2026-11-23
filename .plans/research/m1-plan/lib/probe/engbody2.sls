#!r6rs
;; A library whose body sets (probe flag)'s flag as it starts, then takes
;; many engine ticks, and counts its runs.
(library (probe engbody2) (export runs value)
  (import (chezscheme) (probe flag))
  (define counter 0)
  (define value
    (begin
      (set! counter (+ counter 1))
      (flag-set!)
      (let loop ((i 0)) (when (< i 200000) (loop (+ i 1))))
      (list 'body-ran counter)))
  (define (runs) counter))
