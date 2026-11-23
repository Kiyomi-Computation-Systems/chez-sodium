#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private u9)
  (export u9)
  (import (rnrs) (only (srfi :64) test-begin))
  (define u9 1))
