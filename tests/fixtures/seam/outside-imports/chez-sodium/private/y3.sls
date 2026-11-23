#!r6rs
;;; Fixture for tests/test-check-seam.sps: imports the test helpers: the import allowlist, rule (e).
(library (chez-sodium private y3)
  (export y3)
  (import (rnrs) (chez-sodium-testing))
  (define y3 1))
