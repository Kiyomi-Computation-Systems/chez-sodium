#!r6rs
;;; Fixture for tests/test-check-seam.sps: a legal tree. Every import is on a list.
(library (chez-sodium)
  (export lib-version)
  (import (chez-sodium private require-threaded) (rnrs) (rnrs io ports) (only (chezscheme) threaded? with-mutex) (chez-sodium private thing))
  (define lib-version thing))
