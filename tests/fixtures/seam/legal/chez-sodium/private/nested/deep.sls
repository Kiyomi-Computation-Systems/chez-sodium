#!r6rs
;;; Fixture for tests/test-check-seam.sps: a private library below another directory, importing a sibling.
(library (chez-sodium private nested deep)
  (export deep)
  (import (chez-sodium private thing) (rnrs))
  (define deep thing))
