#!r6rs
;;; Fixture for tests/test-check-seam.sps: imports (chez-sodium util2), which this tree defines: rule (h) is satisfied.
(library (chez-sodium private y2)
  (export y2)
  (import (rnrs) (chez-sodium util2))
  (define y2 1))
