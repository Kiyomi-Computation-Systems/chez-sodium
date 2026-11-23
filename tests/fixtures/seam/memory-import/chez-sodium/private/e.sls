#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private e)
  (export)
  (import (chez-sodium private require-threaded) (rnrs) (except (chez-sodium private memory) foreign-block)))
