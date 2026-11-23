#!r6rs
;;; Fixture for tests/test-check-seam.sps: an internal macro, never exported, is legal.
(library (chez-sodium private native)
  (export run)
  (import (chez-sodium private require-threaded) (rnrs) (only (chezscheme) foreign-procedure))
  (define-syntax helper (syntax-rules () ((_ x) (foreign-procedure x))))
  (define (run) (let-syntax ((local (syntax-rules () ((_ y) y)))) (local 1))))
