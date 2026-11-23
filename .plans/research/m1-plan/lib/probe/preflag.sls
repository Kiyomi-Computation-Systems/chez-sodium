#!r6rs
(library (probe preflag) (export preflag-set! preflag-set?)
  (import (chezscheme))
  (define flag #f)
  (define (preflag-set!) (set! flag #t))
  (define (preflag-set?) flag))
