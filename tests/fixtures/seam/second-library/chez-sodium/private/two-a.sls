#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private two-a)
  (export a)
  (import (rnrs))
  (define a 1))
(library (chez-sodium private two-b) (export b) (import (rnrs) (chezscheme)) (define b 1))
