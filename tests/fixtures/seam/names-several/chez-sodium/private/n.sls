#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private n)
  (export n)
  (import (rnrs) (only (chezscheme) threaded? format eval $primitive make-mutex))
  (define n 1))
