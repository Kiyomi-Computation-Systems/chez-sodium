#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private u8)
  (export u8)
  (import (rnrs) (sodium))
  (define u8 1))
