#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private h)
  (export h critical-section)
  (import (chez-sodium) (rnrs) (only (chezscheme) critical-section))
  (define h 1))
