#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private native)
  (export foreign-block)
  (import (chez-sodium private require-threaded) (rnrs) (only (chez-sodium private memory) free-foreign-block!))
  (define (foreign-block size) size))
