#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private other)
  (export other)
  (import (rnrs) (only (chezscheme) define-ftype lock-object foreign-callable foreign-callable-entry-point fork-thread condition-wait mutex-acquire))
  (define other 1))
