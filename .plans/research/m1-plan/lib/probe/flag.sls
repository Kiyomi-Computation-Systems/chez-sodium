#!r6rs
;; A flag another library's body sets when it starts, read by the program
;; without referencing that library.
(library (probe flag) (export flag-set! flag-set?)
  (import (chezscheme))
  (define flag #f)
  (define (flag-set!) (set! flag #t))
  (define (flag-set?) flag))
