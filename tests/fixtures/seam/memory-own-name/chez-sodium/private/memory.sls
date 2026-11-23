#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private memory)
  (export foreign-block free-foreign-block!)
  (import (rnrs))
  (define (foreign-block size) size)
  (define (free-foreign-block! address) address))
