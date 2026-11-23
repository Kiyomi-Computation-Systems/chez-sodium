#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private w10)
  (export w10)
  (import (rnrs) (only (only (chezscheme) threaded? car) threaded?))
  (define w10 1))
