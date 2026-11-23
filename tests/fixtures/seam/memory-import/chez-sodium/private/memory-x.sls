#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private memory-x)
  (export x)
  (import (rnrs))
  (define x 1))
