#!r6rs
;;; Fixture for tests/test-check-seam.sps: imports (chez-sodium private extra), which rule (h) finds defined: only rule (i) names where it stands.
(library (chez-sodium private x)
  (export x)
  (import (rnrs) (chez-sodium private extra))
  (define x 1))
