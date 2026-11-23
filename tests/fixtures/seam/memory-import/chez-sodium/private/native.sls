#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private native)
  (export call-with-block)
  (import (chez-sodium private require-threaded) (rnrs) (chez-sodium private memory))
  (define (call-with-block size proc) (proc size)))
