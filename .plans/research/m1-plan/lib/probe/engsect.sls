#!r6rs
;; As engbody2, but the body's work runs in one critical section, after a
;; pre-flag set just before it.
(library (probe engsect) (export runs value)
  (import (chezscheme) (probe flag) (probe preflag))
  (define counter 0)
  (define value
    (begin
      (preflag-set!)
      (critical-section
        (set! counter (+ counter 1))
        (flag-set!)
        (let loop ((i 0)) (when (< i 200000) (loop (+ i 1)))))
      (list 'body-ran counter)))
  (define (runs) counter))
