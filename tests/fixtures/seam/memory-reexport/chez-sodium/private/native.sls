#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private native)
  (export call-with-block foreign-block (rename (free-foreign-block! release)))
  (import (chez-sodium private require-threaded) (rnrs) (chez-sodium private memory))
  (define (call-with-block size proc) (proc size)))
