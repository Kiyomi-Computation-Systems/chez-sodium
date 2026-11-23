#!r6rs
;;; Fixture for tests/test-check-seam.sps: a prefix over an only over (chezscheme).
(library (chez-sodium private p)
  (export c:threaded?)
  (import (rnrs) (prefix (only (chezscheme) threaded?) c:)))
