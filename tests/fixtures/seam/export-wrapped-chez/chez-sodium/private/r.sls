#!r6rs
;;; Fixture for tests/test-check-seam.sps: a rename over an only over (chezscheme).
(library (chez-sodium private r)
  (export tt)
  (import (rnrs) (rename (only (chezscheme) threaded?) (threaded? tt))))
