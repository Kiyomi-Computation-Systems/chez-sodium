#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private memory)
  (export allocate)
  (import (chez-sodium private require-threaded) (rnrs) (only (chezscheme) foreign-alloc foreign-free critical-section make-mutex with-mutex))
  (define allocate 1))
