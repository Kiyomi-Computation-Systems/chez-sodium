#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private b)
  (export)
  (import (chez-sodium private require-threaded) (rnrs) (only (chez-sodium private memory) foreign-block)))
