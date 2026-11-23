#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private d)
  (export)
  (import (chez-sodium private require-threaded) (rnrs) (rename (chez-sodium private memory) (foreign-block fb))))
