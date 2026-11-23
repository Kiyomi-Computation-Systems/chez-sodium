#!r6rs
;;; Fixture for tests/test-check-seam.sps: a legal library, so the file under test is the only fault.
(library (chez-sodium-testing)
  (export t)
  (import (rnrs))
  (define t 1))
