#!r6rs
;;; Fixture for tests/test-check-seam.sps: imports (chez-sodium util), defined nowhere: rule (h).
(library (chez-sodium private y1)
  (export y1)
  (import (rnrs) (chez-sodium util))
  (define y1 1))
