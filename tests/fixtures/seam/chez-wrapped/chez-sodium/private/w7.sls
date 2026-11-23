#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private w7)
  (export w7)
  (import (rnrs) (only (prefix (chezscheme) c:) c:threaded?))
  (define w7 1))
