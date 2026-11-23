#!r6rs
;;; Fixture for tests/test-check-seam.sps: (chez-sodium private extra) is defined nowhere in this tree.
(library (chez-sodium private x)
  (export x)
  (import (rnrs) (chez-sodium private y) (prefix (chez-sodium private extra) e:))
  (define x 1))
