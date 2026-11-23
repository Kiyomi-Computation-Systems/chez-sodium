#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private u3)
  (export u3)
  (import (rnrs) (only ($system) eval))
  (define u3 1))
