#!r6rs
;;; Fixture for tests/test-check-seam.sps: imports no library-only name, so it may export a macro.
(library (chez-sodium private plain)
  (export twice)
  (import (chez-sodium private require-threaded) (rnrs) (only (chezscheme) make-mutex))
  (define-syntax twice (syntax-rules () ((_ x) (begin x x)))))
